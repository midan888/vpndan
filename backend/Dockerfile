FROM golang:1.25-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /vpn-dan ./cmd/server
RUN CGO_ENABLED=0 go build -o /seed-geoip ./cmd/seed-geoip

FROM alpine:3.21

RUN apk add --no-cache wireguard-tools

COPY --from=builder /vpn-dan /usr/local/bin/vpn-dan
COPY --from=builder /seed-geoip /usr/local/bin/seed-geoip

EXPOSE 8080

CMD ["vpn-dan"]
