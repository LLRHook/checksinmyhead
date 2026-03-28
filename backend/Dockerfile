FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY go.mod go.sum ./
ENV GOTOOLCHAIN=local
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bill-service ./cmd/bill-service

FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata
RUN addgroup -S app && adduser -S app -G app
COPY --from=builder --chown=app:app /bill-service /bill-service
USER app
EXPOSE 8080
CMD ["/bill-service"]
