# Keep the image toolchain aligned with backend/go.mod and current security fixes.
FROM golang:1.27.3@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b AS build
ENV GOTOOLCHAIN=local

WORKDIR /app
COPY . .
RUN go build -o web-service ./cmd/web-service


FROM gcr.io/distroless/base-nossl-debian13:nonroot@sha256:e6b0f82595aa1edde72c8054de7a9dca30f0f8f54820c37a167c0ddfc21c5c67
COPY --from=build /app/web-service /app/web-service
WORKDIR /app
COPY --from=build /app/internal/web/templates ./internal/web/templates
USER 65532:65532
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD ["./web-service", "--healthcheck"]
CMD ["./web-service"]
