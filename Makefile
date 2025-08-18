# Makefile for actions-clean

.PHONY: help test test-unit test-docker lint build clean check-deps install-deps

# Default target
help:
	@echo "Available targets:"
	@echo "  test        - Run all tests"
	@echo "  test-unit   - Run unit tests only"
	@echo "  test-docker - Run Docker tests only"
	@echo "  lint        - Run linting checks"
	@echo "  build       - Build Docker image"
	@echo "  clean       - Clean up test artifacts and Docker images"
	@echo "  check-deps  - Check if required dependencies are installed"
	@echo "  install-deps- Install required dependencies (Ubuntu/Debian)"

# Test targets
test: test-unit test-docker

test-unit:
	@echo "Running unit tests..."
	@./tests/test-cleanup.sh

test-docker: check-docker
	@echo "Running Docker tests..."
	@./tests/test-docker.sh

# Linting
lint: check-shellcheck
	@echo "Running shellcheck on all shell scripts..."
	@shellcheck *.sh tests/*.sh
	@echo "✓ All shell scripts passed linting"

# Build Docker image
build:
	@echo "Building Docker image..."
	@docker build -t actions-clean:latest .
	@echo "✓ Docker image built successfully"

# Clean up
clean:
	@echo "Cleaning up test artifacts..."
	@rm -rf test-* 2>/dev/null || true
	@docker rmi actions-clean:latest actions-clean:test 2>/dev/null || true
	@echo "✓ Cleanup completed"

# Dependency checks
check-deps: check-bash check-docker check-shellcheck

check-bash:
	@command -v bash >/dev/null 2>&1 || { echo "Error: bash is required but not installed."; exit 1; }

check-docker:
	@command -v docker >/dev/null 2>&1 || { echo "Error: docker is required but not installed."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Error: Docker daemon is not running."; exit 1; }

check-shellcheck:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Error: shellcheck is required but not installed. Run 'make install-deps' or install manually."; exit 1; }

# Install dependencies (Ubuntu/Debian)
install-deps:
	@echo "Installing dependencies..."
	@sudo apt-get update
	@sudo apt-get install -y shellcheck bc
	@echo "✓ Dependencies installed"

# CI targets (used by GitHub Actions)
ci-test: test lint
	@echo "✓ All CI tests passed"

ci-build: build
	@echo "✓ CI build completed"