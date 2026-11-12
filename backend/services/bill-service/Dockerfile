# Keep the image toolchain aligned with backend/go.mod and current security fixes.
FROM golang:1.27.4@sha256:5e8afd493a7124a8586e134d9b532731161d4b9becf9dee5a5956b107426f93d AS build
ENV GOTOOLCHAIN=local

WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o bill-service ./cmd/bill-service


FROM gcr.io/distroless/static-debian13:nonroot@sha256:25ac8f0c3b2334a9eb05452266bd4697864a8c8ef0ef71e5e6480d7f92868329
COPY --from=build /app/bill-service /app/bill-service
WORKDIR /app
USER 65532:65532
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD ["./bill-service", "--healthcheck"]
CMD ["./bill-service"]
