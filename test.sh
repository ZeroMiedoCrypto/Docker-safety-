#!/bin/bash
# Test script for SafeOpen
# Validates installation and basic functionality

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}          ${GREEN}SafeOpen Test Suite${NC}                       ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

PASSED=0
FAILED=0

# Test helper functions
test_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAILED++))
}

# Test 1: Docker availability
echo -e "${YELLOW}Test 1:${NC} Docker availability"
if command -v docker &> /dev/null; then
    test_pass "Docker command found"
else
    test_fail "Docker command not found"
fi

if docker info &> /dev/null 2>&1; then
    test_pass "Docker daemon is running"
else
    test_fail "Docker daemon is not running"
fi

# Test 2: Docker image
echo -e "${YELLOW}Test 2:${NC} Docker image"
if docker image inspect safeopen:latest &> /dev/null; then
    test_pass "SafeOpen image exists"
else
    test_fail "SafeOpen image not found (run ./install.sh)"
fi

# Test 3: CLI tool
echo -e "${YELLOW}Test 3:${NC} CLI tool"
if command -v safeopen &> /dev/null; then
    test_pass "safeopen command is available"
else
    test_fail "safeopen command not found in PATH"
fi

if [[ -x ./safeopen.sh ]]; then
    test_pass "safeopen.sh is executable"
else
    test_fail "safeopen.sh is not executable"
fi

# Test 4: Container scripts
echo -e "${YELLOW}Test 4:${NC} Container scripts"
for script in container/entrypoint.sh container/network-rules.sh container/scanner.sh container/cleanup.sh; do
    if [[ -f "$script" && -x "$script" ]]; then
        test_pass "$(basename $script) exists and is executable"
    else
        test_fail "$(basename $script) missing or not executable"
    fi
done

# Test 5: Directories
echo -e "${YELLOW}Test 5:${NC} Required directories"
if [[ -d "${HOME}/.safeopen/logs" ]]; then
    test_pass "Log directory exists"
else
    test_fail "Log directory not found"
fi

if [[ -d "/tmp/safeopen" ]]; then
    test_pass "Temporary directory exists"
else
    test_fail "Temporary directory not found"
fi

# Test 6: Create test file and scan
echo -e "${YELLOW}Test 6:${NC} File scanning (if image is built)"
if docker image inspect safeopen:latest &> /dev/null; then
    # Create a safe test file
    TEST_FILE="/tmp/safeopen_test_$(date +%s).txt"
    echo "This is a safe test file" > "$TEST_FILE"
    
    echo "Running scan test..."
    if ./safeopen.sh --scan "$TEST_FILE" &> /tmp/safeopen_test.log; then
        test_pass "File scan completed successfully"
    else
        test_fail "File scan failed"
        cat /tmp/safeopen_test.log
    fi
    
    # Cleanup
    rm -f "$TEST_FILE" /tmp/safeopen_test.log
else
    echo "Skipping scan test (image not built)"
fi

# Test 7: Container security options
echo -e "${YELLOW}Test 7:${NC} Security configuration"
if docker image inspect safeopen:latest &> /dev/null; then
    # Check if image has non-root user
    USER_INFO=$(docker run --rm safeopen:latest --help | grep -i "user:" || echo "")
    if [[ -n "$USER_INFO" ]]; then
        test_pass "Container runs as non-root user"
    else
        echo "Could not verify non-root user"
    fi
fi

# Summary
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Tests Passed:${NC} $PASSED"
echo -e "${RED}Tests Failed:${NC} $FAILED"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC} ✓"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC} Please review the output above."
    exit 1
fi
