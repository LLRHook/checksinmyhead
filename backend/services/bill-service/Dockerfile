# Pinned: 1.25.12 carries the crypto/tls, crypto/x509, net/http and
# html/template fixes govulncheck flags against earlier 1.25.x patches.
FROM golang:1.25.12 AS build

WORKDIR /app
COPY . .
RUN go build -o bill-service ./cmd/bill-service


FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/bill-service .
CMD ["./bill-service"]
