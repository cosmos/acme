#!/usr/bin/env bash
set -Eeuo pipefail

# Print failing command with file and line number on error
trap 'rc=$?; echo "Error ($rc) at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR

# Clean deploy script for acme
# - Verifies not running, prompts to stop if it is
# - Confirms existing config deletion
# - Builds (make install)
# - Deletes previous configuration
# - Runs common genesis/bootstrap
# - Applies config tweaks
# - Creates/overwrites systemd service and starts it
# - Verifies active and API status

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/env-setup.sh"

# Using CHAIN_DIR as the home path (flattened layout)

# Parse -y/--yes for non-interactive mode
if [ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ]; then
  AUTO_YES=1
  shift || true
fi

confirm() {
  if [ "${AUTO_YES:-0}" = "1" ]; then
    return 0
  fi
  read -r -p "${1:-Continue?} [y/N]: " reply || true
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# 1) Verify the chain isn't running (ps and systemctl)
ACTIVE_FROM_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    ACTIVE_FROM_SYSTEMD=1
  fi
fi

ACTIVE_FROM_PS=0
if pgrep -f "$BIN" >/dev/null 2>&1; then
  ACTIVE_FROM_PS=1
fi

if [ "$ACTIVE_FROM_SYSTEMD" = 1 ] || [ "$ACTIVE_FROM_PS" = 1 ]; then
  echo "acme appears to be running."
  if confirm "Stop it now?"; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl stop "$SERVICE_NAME" || true
    fi
    pkill -f "$BIN" || true
  else
    echo "Aborting as requested."
    exit 1
  fi
fi

# 2) Confirm deletion if existing configuration is present
if [ -d "$CHAIN_DIR" ]; then
  if ! confirm "Delete existing chain data at $CHAIN_DIR?"; then
    echo "Aborting as requested."
    exit 1
  fi
fi

# 3) Build and install binary
( cd "$ROOT_DIR" && make install )

# 4) Delete previous configuration
rm -rf "$CHAIN_DIR"

# 5) Genesis/bootstrap via common-genesis.sh, using CHAIN_DIR
"$SCRIPT_DIR/common-genesis.sh"

# 6) Apply configuration tweaks
APP_TOML="$CHAIN_DIR/config/app.toml"
CFG_TOML="$CHAIN_DIR/config/config.toml"

# gRPC listen 0.0.0.0:9090
sed -i -e 's/address = "localhost:9090"/address = "0.0.0.0:9090"/g' "$APP_TOML"
# API enable = true
sed -i -e 's/enable = false/enable = true/g' "$APP_TOML"
# REST listen 0.0.0.0:1317
sed -i -e 's/address = "tcp:\/\/localhost:1317"/address = "tcp:\/\/0.0.0.0:1317"/g' "$APP_TOML"
# RPC listen 0.0.0.0:26657
sed -i -e 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' "$CFG_TOML"
# CORS allow all
sed -i -e 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["*"\]/g' "$CFG_TOML"

# 7) Create systemd service (overwrite if exists)
SERVICE_FILE="$SERVICE_UNIT_PATH"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description="acme"
After=network-online.target

[Service]
User=root
ExecStart=$BIN_PATH start --home $CHAIN_DIR
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# 8) Start the service
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" || true
systemctl restart "$SERVICE_NAME"

# 9) Verify service and RPC status
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "Service is active."
else
  echo "Service failed to start (systemctl is-active != active)." >&2
  exit 1
fi

# Give the node a few seconds to bring up RPC, then require it to be reachable
RPC_URL="http://127.0.0.1:26657/status"
echo "Waiting for RPC at $RPC_URL ..."
READY=0
for i in $(seq 1 30); do
  if curl -sf "$RPC_URL" >/dev/null; then
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" -eq 1 ]; then
  echo "RPC status OK."
else
  echo "RPC status check failed at $RPC_URL" >&2
  exit 1
fi

# 10) Run common post-genesis actions (create uacmeusd denom)
bash "$SCRIPT_DIR/common-post-genesis-block.sh"

