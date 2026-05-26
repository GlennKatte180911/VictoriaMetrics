# Makefile for VictoriaMetrics
# Provides common build, test, and deployment targets

APP_NAME := victoria-metrics
GO := go
GOFLAGS := -trimpath
LDFLAGS := -s -w
BUILD_DIR := bin
CMD_DIR := app/victoria-metrics

# Version information
GIT_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME := $(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

LD_VERSION_FLAGS := \
	-X main.Version=$(GIT_TAG) \
	-X main.BuildTime=$(BUILD_TIME) \
	-X main.GitCommit=$(GIT_COMMIT)

.PHONY: all build clean test lint fmt vet docker-build docker-push help

## all: Build the application (default target)
all: build

## build: Compile the application binary
build:
	@echo ">> Building $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build $(GOFLAGS) \
		-ldflags "$(LDFLAGS) $(LD_VERSION_FLAGS)" \
		-o $(BUILD_DIR)/$(APP_NAME) \
		./$(CMD_DIR)/
	@echo ">> Binary available at $(BUILD_DIR)/$(APP_NAME)"

## build-race: Compile with race detector enabled
build-race:
	@echo ">> Building $(APP_NAME) with race detector..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build -race $(GOFLAGS) \
		-ldflags "$(LDFLAGS) $(LD_VERSION_FLAGS)" \
		-o $(BUILD_DIR)/$(APP_NAME)-race \
		./$(CMD_DIR)/

## test: Run all unit tests
test:
	@echo ">> Running tests..."
	$(GO) test ./... -count=1 -timeout 120s

## test-race: Run tests with race detector
test-race:
	@echo ">> Running tests with race detector..."
	$(GO) test -race ./... -count=1 -timeout 120s

## bench: Run benchmarks
bench:
	@echo ">> Running benchmarks..."
	$(GO) test ./... -bench=. -benchmem -run='^$$'

## bench-cpu: Run benchmarks and generate a CPU profile for analysis
bench-cpu:
	@echo ">> Running benchmarks with CPU profiling..."
	@mkdir -p $(BUILD_DIR)/profiles
	$(GO) test ./... -bench=. -benchmem -run='^$$' -cpuprofile=$(BUILD_DIR)/profiles/cpu.prof
	@echo ">> CPU profile written to $(BUILD_DIR)/profiles/cpu.prof"
	@echo ">> Inspect with: go tool pprof $(BUILD_DIR)/profiles/cpu.prof"

## lint: Run golangci-lint
lint:
	@echo ">> Running linter..."
	@which golangci-lint > /dev/null || (echo "golangci-lint not found, install via: https://golangci-lint.run/usage/install/" && exit 1)
	golangci-lint run ./...

## fmt: Format Go source files
fmt:
	@echo ">> Formatting code..."
	$(GO) fmt ./...

## vet: Run go vet
vet:
	@echo ">> Running go vet..."
	$(GO) vet ./...

## tidy: Tidy go modules
tidy:
	@echo ">> Tidying modules..."
	$(GO) mod tidy

## clean: Remove build artifacts
clean:
	@echo ">> Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo ">> Done."

## docker-build: Build Docker image
docker-build:
	@echo ">> Building Docker image $(APP_NAME):$(GIT_TAG)..."
	docker build \
		--build-arg GIT_TAG=$(GIT_TAG) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(APP_NAME):$(GIT_TAG) \
		-t $(APP_NAME):latest \
		.

## check: Run fmt, vet, and lint in sequence (useful before committing)
check: fmt vet lint
	@echo ">> All checks passed."

## help: Show this help message
help:
	@echo "Available targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/^## /  /'

# Personal fork - added help target so I can quickly remind myself what each target does
