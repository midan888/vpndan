FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY gateway/go.mod ./
COPY gateway/cmd ./cmd

RUN CGO_ENABLED=0 go build -o /wireguard-gateway ./cmd/gateway

FROM ubuntu:24.04

# Install AmneziaWG tools. The official apt repo ships awg and awg-quick
# which are drop-in replacements for wg/wg-quick with obfuscation support.
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:amnezia/ppa && \
    apt-get update && \
    apt-get install -y amneziawg-tools iptables iproute2 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /wireguard-gateway /usr/local/bin/wireguard-gateway

EXPOSE 9080

CMD ["wireguard-gateway"]
