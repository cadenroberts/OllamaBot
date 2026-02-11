#!/usr/bin/env bash
set -euo pipefail

# OllamaBot demo/smoke verification script.
# Exits non-zero on any failure.
# Does NOT require Ollama to be running.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

echo "=== OllamaBot Smoke Test ==="
echo "Repository: $REPO_ROOT"
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# Step 1: Build the Go CLI
echo "--- Step 1: Build ---"
make build
echo ""

# Step 2: Verify version
echo "--- Step 2: Version ---"
VERSION_OUTPUT="$(./bin/obot --version 2>&1)"
echo "$VERSION_OUTPUT"
if ! echo "$VERSION_OUTPUT" | grep -q "obot version"; then
    echo "FAIL: version output did not contain 'obot version'"
    exit 1
fi
echo ""

# Step 3: Run Go tests
echo "--- Step 3: Tests ---"
TEST_OUTPUT="$(go test ./internal/... 2>&1)"
echo "$TEST_OUTPUT" | tail -5
PASS_COUNT="$(echo "$TEST_OUTPUT" | grep -c "^ok" || true)"
FAIL_COUNT="$(echo "$TEST_OUTPUT" | grep -c "^FAIL" || true)"
echo "Packages passed: $PASS_COUNT"
echo "Packages failed: $FAIL_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
    echo "FAIL: $FAIL_COUNT test package(s) failed"
    exit 1
fi
echo ""

# Step 4: Static analysis
echo "--- Step 4: Vet ---"
go vet ./internal/...
echo "go vet: clean"
echo ""

# Step 5: Module consistency
echo "--- Step 5: Module consistency ---"
cp go.mod go.mod.bak
cp go.sum go.sum.bak
go mod tidy
if ! diff -q go.mod go.mod.bak >/dev/null 2>&1 || ! diff -q go.sum go.sum.bak >/dev/null 2>&1; then
    echo "FAIL: go mod tidy produced changes (modules inconsistent)"
    mv go.mod.bak go.mod
    mv go.sum.bak go.sum
    exit 1
fi
rm go.mod.bak go.sum.bak
echo "go.mod/go.sum: consistent"
echo ""

echo "=== All checks passed ==="
echo "SMOKE_OK"
