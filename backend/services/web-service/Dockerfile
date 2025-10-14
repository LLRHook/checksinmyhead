FROM golang:1.25 AS build

WORKDIR /app
COPY . .
RUN go build -o web-service ./cmd/web-service


FROM gcr.io/distroless/base-debian12
WORKDIR /app
COPY --from=build /app/web-service .
COPY --from=build /app/internal/web/templates ./internal/web/templates
CMD ["./web-service"]
