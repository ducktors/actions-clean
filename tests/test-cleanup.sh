#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

# Test framework for cleanup.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_SCRIPT="${SCRIPT_DIR}/../cleanup.sh"
TEST_FAILED=0
TOTAL_TESTS=0
PASSED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test utilities
setup_test_env() {
    export GITHUB_WORKSPACE="${TMPDIR}test_workspace_$$"
    export HOME="${TMPDIR}test_home_$$"
    mkdir -p "${GITHUB_WORKSPACE}" "${HOME}"
    cd "${GITHUB_WORKSPACE}"
}

cleanup_test_env() {
    rm -rf "${GITHUB_WORKSPACE}" "${HOME}" 2>/dev/null || true
    unset GITHUB_WORKSPACE HOME
    unset INPUT_CLEANUP_HOME INPUT_CLEANUP_WORKSPACE INPUT_DRY_RUN
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TOTAL_TESTS++))
    echo -e "${YELLOW}Running test: ${test_name}${NC}"
    
    if ${test_function}; then
        echo -e "${GREEN}✓ PASSED: ${test_name}${NC}"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}✗ FAILED: ${test_name}${NC}"
        TEST_FAILED=1
    fi
    echo
}

# Test cases
test_dry_run_mode() {
    setup_test_env
    
    # Create test files
    touch "${GITHUB_WORKSPACE}/test1.txt"
    touch "${HOME}/test2.txt"
    
    # Run in dry run mode
    export INPUT_DRY_RUN="true"
    export INPUT_CLEANUP_HOME="true"
    export INPUT_CLEANUP_WORKSPACE="true"
    
    local output
    output=$("${CLEANUP_SCRIPT}" 2>&1)
    
    # Check files still exist after dry run
    if [[ -f "${GITHUB_WORKSPACE}/test1.txt" ]] && [[ -f "${HOME}/test2.txt" ]] && 
       [[ "${output}" == *"DRY RUN"* ]] && [[ "${output}" == *"no files were actually deleted"* ]]; then
        cleanup_test_env
        return 0
    fi
    
    cleanup_test_env
    return 1
}

test_actual_cleanup() {
    setup_test_env
    
    # Create test files
    touch "${GITHUB_WORKSPACE}/test1.txt"
    mkdir "${GITHUB_WORKSPACE}/testdir"
    touch "${GITHUB_WORKSPACE}/testdir/nested.txt"
    touch "${HOME}/test2.txt"
    
    # Run actual cleanup
    export INPUT_DRY_RUN="false"
    export INPUT_CLEANUP_HOME="true"
    export INPUT_CLEANUP_WORKSPACE="true"
    
    "${CLEANUP_SCRIPT}" >/dev/null 2>&1
    
    # Check files are removed but directories still exist
    if [[ ! -f "${GITHUB_WORKSPACE}/test1.txt" ]] && [[ ! -d "${GITHUB_WORKSPACE}/testdir" ]] && 
       [[ ! -f "${HOME}/test2.txt" ]] && [[ -d "${GITHUB_WORKSPACE}" ]] && [[ -d "${HOME}" ]]; then
        cleanup_test_env
        return 0
    fi
    
    cleanup_test_env
    return 1
}

test_selective_cleanup() {
    setup_test_env
    
    # Create test files
    touch "${GITHUB_WORKSPACE}/test1.txt"
    touch "${HOME}/test2.txt"
    
    # Run cleanup with only HOME enabled
    export INPUT_DRY_RUN="false"
    export INPUT_CLEANUP_HOME="true"
    export INPUT_CLEANUP_WORKSPACE="false"
    
    "${CLEANUP_SCRIPT}" >/dev/null 2>&1
    
    # Check only HOME is cleaned
    if [[ -f "${GITHUB_WORKSPACE}/test1.txt" ]] && [[ ! -f "${HOME}/test2.txt" ]]; then
        cleanup_test_env
        return 0
    fi
    
    cleanup_test_env
    return 1
}

test_empty_directories() {
    setup_test_env
    
    # Use empty directories
    export INPUT_DRY_RUN="false"
    export INPUT_CLEANUP_HOME="true"
    export INPUT_CLEANUP_WORKSPACE="true"
    
    local output
    output=$("${CLEANUP_SCRIPT}" 2>&1)
    
    # Should complete successfully with "already clean" message
    if [[ "${output}" == *"already clean"* ]] && [[ "${output}" == *"Cleanup completed successfully"* ]]; then
        cleanup_test_env
        return 0
    fi
    
    cleanup_test_env
    return 1
}

test_missing_github_env() {
    # Test without GITHUB_WORKSPACE
    unset GITHUB_WORKSPACE
    export HOME="${TMPDIR}test_home_$$"
    mkdir -p "${HOME}"
    
    local output
    output=$("${CLEANUP_SCRIPT}" 2>&1) && exit_code=$? || exit_code=$?
    
    # Should exit with error
    if [[ ${exit_code} -eq 1 ]] && [[ "${output}" == *"Not running in GitHub Actions environment"* ]]; then
        rm -rf "${HOME}" 2>/dev/null || true
        unset HOME
        return 0
    fi
    
    rm -rf "$HOME" 2>/dev/null || true
    unset HOME
    return 1
}

test_security_check() {
    setup_test_env
    
    # Create test files
    touch "${GITHUB_WORKSPACE}/test1.txt"
    
    # Change to a different directory (simulate security issue)
    cd /tmp
    
    export INPUT_DRY_RUN="false"
    export INPUT_CLEANUP_WORKSPACE="true"
    
    local output
    output=$("${CLEANUP_SCRIPT}" 2>&1)
    
    # Should skip cleanup with security warning
    if [[ "${output}" == *"Not executing from within GITHUB_WORKSPACE"* ]] && [[ -f "${GITHUB_WORKSPACE}/test1.txt" ]]; then
        cleanup_test_env
        return 0
    fi
    
    cleanup_test_env
    return 1
}

# Run all tests
echo "Starting cleanup.sh tests..."
echo "=========================="

run_test "Dry run mode preserves files" test_dry_run_mode
run_test "Actual cleanup removes files" test_actual_cleanup
run_test "Selective cleanup works" test_selective_cleanup
run_test "Empty directories handled correctly" test_empty_directories
run_test "Missing GitHub environment detection" test_missing_github_env
run_test "Security check prevents unsafe cleanup" test_security_check

# Results
echo "=========================="
echo -e "Tests completed: ${PASSED_TESTS}/${TOTAL_TESTS} passed"

if [[ ${TEST_FAILED} -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi