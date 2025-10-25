#!/bin/bash

#####################################################################
# ZeroTier Toolkit Test Suite
# 
# Basic tests to verify script functionality
#####################################################################

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    local status="$1"
    local message="$2"
    
    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$status" == "FAIL" ]]; then
        echo -e "${RED}[FAIL]${NC} $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    else
        echo -e "${YELLOW}[INFO]${NC} $message"
    fi
}

echo "========================================"
echo "ZeroTier Toolkit Test Suite"
echo "========================================"
echo ""

# Test 1: Check all scripts are executable
log_test INFO "Test 1: Checking script permissions..."
for script in "$SCRIPT_DIR"/../scripts/zerotier-*.sh; do
    if [[ -x "$script" ]]; then
        log_test PASS "$(basename "$script") is executable"
    else
        log_test FAIL "$(basename "$script") is not executable"
    fi
done

# Test 2: Check syntax of all scripts
log_test INFO "Test 2: Checking script syntax..."
for script in "$SCRIPT_DIR"/../scripts/zerotier-*.sh; do
    if bash -n "$script" 2>/dev/null; then
        log_test PASS "$(basename "$script") syntax is valid"
    else
        log_test FAIL "$(basename "$script") syntax check failed"
    fi
done

# Test 3: Check help flags work
log_test INFO "Test 3: Checking help flags..."
for script in "$SCRIPT_DIR"/../scripts/zerotier-*.sh; do
    if "$script" --help >/dev/null 2>&1 || [[ $? -eq 0 ]]; then
        log_test PASS "$(basename "$script") --help works"
    else
        log_test FAIL "$(basename "$script") --help failed"
    fi
done

# Test 4: Check version flags work
log_test INFO "Test 4: Checking version flags..."
for script in "$SCRIPT_DIR"/../scripts/zerotier-*.sh; do
    version=$("$script" --version 2>&1)
    if [[ -n "$version" ]]; then
        log_test PASS "$(basename "$script") --version works (v$version)"
    else
        log_test FAIL "$(basename "$script") --version failed"
    fi
done

# Test 5: Check example configurations exist
log_test INFO "Test 5: Checking example configurations..."
for config in gateway.conf hub-spoke-topology.conf mesh-topology.conf; do
    if [[ -f "$SCRIPT_DIR/../examples/$config" ]]; then
        log_test PASS "Example configuration $config exists"
    else
        log_test FAIL "Example configuration $config missing"
    fi
done

# Test 6: Check documentation exists
log_test INFO "Test 6: Checking documentation..."
for doc in README.md TROUBLESHOOTING.md scripts/README.md; do
    if [[ -f "$SCRIPT_DIR/../$doc" ]]; then
        log_test PASS "Documentation $doc exists"
    else
        log_test FAIL "Documentation $doc missing"
    fi
done

# Test 7: Verify diagnostics runs without ZeroTier
log_test INFO "Test 7: Testing diagnostics without ZeroTier..."
output=$(timeout 10 "$SCRIPT_DIR/../scripts/zerotier-diagnostics.sh" 2>&1 | head -30 || true)
if echo "$output" | grep -qE "(not installed|Install with)"; then
    log_test PASS "Diagnostics gracefully handles missing ZeroTier"
else
    log_test FAIL "Diagnostics does not handle missing ZeroTier correctly"
fi

# Test 8: Verify topology validation works
log_test INFO "Test 8: Testing topology validation..."
output=$(timeout 10 "$SCRIPT_DIR/../scripts/zerotier-topology.sh" -c "$SCRIPT_DIR/../examples/hub-spoke-topology.conf" validate 2>&1 || true)
if echo "$output" | grep -qE "(hub-spoke|hub.spoke)"; then
    log_test PASS "Topology validation works"
else
    log_test FAIL "Topology validation failed"
fi

# Test 9: Verify dry-run mode works
log_test INFO "Test 9: Testing dry-run mode..."
output=$(timeout 10 "$SCRIPT_DIR/../scripts/zerotier-conf.sh" --dry-run -n a1b2c3d4e5f6a7b8 2>&1 | head -20 || true)
if echo "$output" | grep -qE "(Dry-run|DRY-RUN)"; then
    log_test PASS "Dry-run mode works"
else
    log_test FAIL "Dry-run mode failed"
fi

# Test 10: Check shellcheck if available
if command -v shellcheck &>/dev/null; then
    log_test INFO "Test 10: Running shellcheck..."
    for script in "$SCRIPT_DIR"/../scripts/zerotier-*.sh; do
        # Run shellcheck but only fail on errors (not warnings)
        if shellcheck -S error "$script" &>/dev/null; then
            log_test PASS "$(basename "$script") passes shellcheck (errors only)"
        else
            log_test FAIL "$(basename "$script") has shellcheck errors"
        fi
    done
else
    log_test INFO "Test 10: Shellcheck not available, skipping"
fi

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "========================================"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
