FROM golang:1.25 AS build

WORKDIR /app
COPY . .
RUN go build -o bill-service ./cmd/bill-service


FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/bill-service .
CMD ["./bill-service"]
