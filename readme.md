# acme

[![Go Version](https://img.shields.io/badge/go-1.26.10-blue.svg)](https://golang.org/)
[![Lint](https://github.com/cosmos/acme/workflows/Lint/badge.svg)](https://github.com/cosmos/acme/actions/workflows/lint.yml)
[![Test](https://github.com/cosmos/acme/workflows/Test/badge.svg)](https://github.com/cosmos/acme/actions/workflows/test.yml)

**acme** is a blockchain built using Cosmos SDK and Tendermint.

## Deploying the chain

- Run `scripts/clean-deploy.sh`.
  - This script should not be run locally, as it will attempt to create a systemd  service.
  - The script will look for any existing deployments and stop and 🚨 delete it.
  - It will then set up a fresh genesis with configurations from `contrib/config.json`, and finally create a service and start the chain.
...


## Development setup

To run locally `make single-node`. This will spin up the blockchain with the following addresses preloaded with
`uacme` and `uacmeusd` token.

`make kill-single-node` to kill the chain.

### Build and Run

Build the Docker image:
```bash
make docker-build
```

