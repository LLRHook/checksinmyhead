# Keep the image toolchain aligned with backend/go.mod and current security fixes.
FROM golang:1.27.3@sha256:2920bb124f1a2e12a1d39f0cab756ae0068441ee1da7655dec7f5e374944095b AS build
ENV GOTOOLCHAIN=local

WORKDIR /app
COPY . .
RUN go build -o bill-service ./cmd/bill-service


FROM gcr.io/distroless/base-nossl-debian13:nonroot@sha256:e6b0f82595aa1edde72c8054de7a9dca30f0f8f54820c37a167c0ddfc21c5c67
COPY --from=build /app/bill-service /app/bill-service
WORKDIR /app
USER 65532:65532
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD ["./bill-service", "--healthcheck"]
CMD ["./bill-service"]
