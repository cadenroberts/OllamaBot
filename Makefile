# Obot CLI - Makefile
# Build, install, and release targets

VERSION := 1.0.0
BINARY := obot
BUILD_DIR := bin
DIST_DIR := dist
MAIN_PKG := ./cmd/obot

# Build flags
GIT_COMMIT := $(shell git rev-parse --short=12 HEAD 2>/dev/null || echo "none")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILT_BY := $(shell whoami 2>/dev/null || echo "unknown")
LDFLAGS := -ldflags "-X main.Version=$(VERSION) -X main.Commit=$(GIT_COMMIT) -X main.Date=$(BUILD_DATE) -X main.BuiltBy=$(BUILT_BY) -s -w"

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
CYAN := \033[0;36m
NC := \033[0m

.PHONY: all build install clean test release deps fmt lint help

all: deps build

## Build the binary for current platform
build:
	@echo "$(CYAN)Building $(BINARY)...$(NC)"
	@mkdir -p $(BUILD_DIR)
	go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY) $(MAIN_PKG)
	@echo "$(GREEN)✓ Built $(BUILD_DIR)/$(BINARY)$(NC)"

## Install to ~/.local/bin (user-level, no sudo needed)
install: build
	@echo "$(CYAN)Installing $(BINARY) to ~/.local/bin...$(NC)"
	@mkdir -p $(HOME)/.local/bin
	@cp $(BUILD_DIR)/$(BINARY) $(HOME)/.local/bin/
	@echo "$(GREEN)✓ Installed to ~/.local/bin/$(BINARY)$(NC)"
	@if ! echo "$$PATH" | grep -q "$(HOME)/.local/bin"; then \
		echo "$(YELLOW)Add ~/.local/bin to your PATH:$(NC)"; \
		echo '  echo '\''export PATH="$$HOME/.local/bin:$$PATH"'\'' >> ~/.zshrc && source ~/.zshrc'; \
	else \
		echo "$(GREEN)✓ Run 'obot --help' to get started$(NC)"; \
	fi

## Install to /usr/local/bin (requires sudo)
install-global: build
	@echo "$(CYAN)Installing $(BINARY) to /usr/local/bin (requires sudo)...$(NC)"
	@sudo cp $(BUILD_DIR)/$(BINARY) /usr/local/bin/
	@echo "$(GREEN)✓ Installed! Run 'obot --help' to get started$(NC)"

## Install dependencies
deps:
	@echo "$(CYAN)Installing dependencies...$(NC)"
	go mod download
	go mod tidy
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

## Run tests
test:
	@echo "$(CYAN)Running tests...$(NC)"
	go test -v ./...

## Format code
fmt:
	@echo "$(CYAN)Formatting code...$(NC)"
	go fmt ./...
	@echo "$(GREEN)✓ Code formatted$(NC)"

## Run linter
lint:
	@echo "$(CYAN)Running linter...$(NC)"
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run; \
	else \
		echo "$(YELLOW)golangci-lint not installed, skipping...$(NC)"; \
	fi

## Clean build artifacts
clean:
	@echo "$(CYAN)Cleaning...$(NC)"
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@echo "$(GREEN)✓ Cleaned$(NC)"

## Build releases for all platforms
release: clean
	@echo "$(CYAN)Building releases...$(NC)"
	@mkdir -p $(DIST_DIR)
	
	@echo "  → darwin/arm64 (Apple Silicon)"
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY)-darwin-arm64 $(MAIN_PKG)
	
	@echo "  → darwin/amd64 (Intel Mac)"
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY)-darwin-amd64 $(MAIN_PKG)
	
	@echo "  → linux/amd64"
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY)-linux-amd64 $(MAIN_PKG)
	
	@echo "  → linux/arm64"
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY)-linux-arm64 $(MAIN_PKG)
	
	@echo "  → windows/amd64"
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(DIST_DIR)/$(BINARY)-windows-amd64.exe $(MAIN_PKG)
	
	@echo "$(GREEN)✓ Releases built in $(DIST_DIR)/$(NC)"
	@ls -la $(DIST_DIR)/

## Generate checksums for releases
checksums: release
	@echo "$(CYAN)Generating checksums...$(NC)"
	@cd $(DIST_DIR) && shasum -a 256 * > checksums.txt
	@echo "$(GREEN)✓ Checksums generated$(NC)"
	@cat $(DIST_DIR)/checksums.txt

## Run the CLI (for development)
run: build
	@$(BUILD_DIR)/$(BINARY) $(ARGS)

## Show help
help:
	@echo "$(CYAN)obot$(NC) - Local AI code fixer CLI"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make [target]"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build     # Build for current platform"
	@echo "  make install   # Build and install to /usr/local/bin"
	@echo "  make release   # Build for all platforms"
	@echo "  make test      # Run tests"
