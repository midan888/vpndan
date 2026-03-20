FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod ./
COPY cmd ./cmd

RUN CGO_ENABLED=0 go build -o /wireguard-gateway ./cmd/gateway

FROM alpine:3.21

RUN apk add --no-cache wireguard-tools iptables iproute2

COPY --from=builder /wireguard-gateway /usr/local/bin/wireguard-gateway

EXPOSE 9080

CMD ["wireguard-gateway"]
