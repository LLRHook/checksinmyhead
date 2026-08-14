# Keep the image toolchain aligned with backend/go.mod. Go 1.25.13 includes
# the standard-library security fixes required by govulncheck.
FROM golang:1.25.13 AS build

WORKDIR /app
COPY . .
RUN go build -o bill-service ./cmd/bill-service


FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/bill-service .
CMD ["./bill-service"]
