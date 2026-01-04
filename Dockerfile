# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Install Air for hot reloading
RUN go install github.com/air-verse/air@v1.52.3

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# Development stage with Air
FROM golang:1.23-alpine

WORKDIR /app

# Install Air
RUN go install github.com/air-verse/air@v1.52.3

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# Expose port
EXPOSE 8080

# Run Air for hot reloading
CMD ["air", "-c", ".air.toml"]
