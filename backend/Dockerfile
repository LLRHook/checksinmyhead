FROM golang:1.25-alpine AS builder
RUN apk add --no-cache git
WORKDIR /app
COPY . .
ENV GOTOOLCHAIN=local
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o /bill-service ./cmd/bill-service

FROM alpine:3.21
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /bill-service /bill-service
EXPOSE 8080
CMD ["/bill-service"]
