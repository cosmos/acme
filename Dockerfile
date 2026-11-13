# Based on https://github.com/cosmos/gaia/blob/a3a21856c1a1e67206373c9e79c81cfc76b51e31/Dockerfile
ARG IMG_TAG=latest

# Compile the acmed binary
FROM golang:1.26.10-alpine AS acmed-builder
WORKDIR /src/app/
ENV PACKAGES="curl build-base git bash file linux-headers eudev-dev"
RUN apk add --no-cache $PACKAGES

ARG CGO_CFLAGS="-D__BLST_PORTABLE__"
ENV CGO_CFLAGS=$CGO_CFLAGS

ARG GIT_VERSION=""
ARG GIT_COMMIT=""

# Must match github.com/CosmWasm/wasmvm/v3 in go.mod. See https://github.com/CosmWasm/wasmvm/releases
ARG WASMVM_VERSION=v3.0.7
ADD https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERSION}/libwasmvm_muslc.aarch64.a /lib/libwasmvm_muslc.aarch64.a
ADD https://github.com/CosmWasm/wasmvm/releases/download/${WASMVM_VERSION}/libwasmvm_muslc.x86_64.a /lib/libwasmvm_muslc.x86_64.a
RUN sha256sum /lib/libwasmvm_muslc.aarch64.a | grep ef3e3125e1ce588a9bc698f695a1a4793432b9903a0928018c0d7872e874cc97
RUN sha256sum /lib/libwasmvm_muslc.x86_64.a | grep 49ecd70da281b6ee08b31770a54bb529d1de96b3e54013e025df9f0c39fff7f4
RUN cp "/lib/libwasmvm_muslc.$(uname -m).a" /lib/libwasmvm_muslc.a

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN LEDGER_ENABLED=false LINK_STATICALLY=true BUILD_TAGS=muslc \
    VERSION=$GIT_VERSION COMMIT=$GIT_COMMIT make build
RUN echo "Ensuring binary is statically linked ..."  \
    && file /src/app/build/acmed | grep "statically linked"

FROM alpine:$IMG_TAG
RUN apk add --no-cache build-base jq
RUN addgroup -g 1025 nonroot
RUN adduser -D nonroot -u 1025 -G nonroot
ARG IMG_TAG
COPY --from=acmed-builder /src/app/build/acmed /usr/local/bin/
EXPOSE 26656 26657 1317 9090
USER nonroot

ENTRYPOINT ["acmed", "start"]
