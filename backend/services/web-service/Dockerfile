# Keep the image toolchain aligned with backend/go.mod and current security fixes.
FROM golang:1.27.3@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b AS build
ENV GOTOOLCHAIN=local

WORKDIR /app
COPY . .
RUN go build -o web-service ./cmd/web-service


FROM gcr.io/distroless/base-debian12@sha256:fabbf1c0c357a3d42550111351daed089b20a2c954df13ee2fcff60602515e84
WORKDIR /app
COPY --from=build /app/web-service .
COPY --from=build /app/internal/web/templates ./internal/web/templates
CMD ["./web-service"]
