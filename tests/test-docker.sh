#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

# Test framework for Docker image build and functionality
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
TEST_FAILED=0
TOTAL_TESTS=0
PASSED_TESTS=0
IMAGE_NAME="actions-clean-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test utilities
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

cleanup_docker() {
    docker rmi "${IMAGE_NAME}" 2>/dev/null || true
}

# Test cases
test_docker_build() {
    cd "${PROJECT_DIR}"
    
    # Build the Docker image
    if docker build -t "${IMAGE_NAME}" . >/dev/null 2>&1; then
        return 0
    fi
    
    return 1
}

test_docker_entrypoint() {
    # Test that entrypoint script is accessible and executable
    local output
    output=$(docker run --rm "${IMAGE_NAME}" echo "test" 2>&1)
    
    if [[ "${output}" == *"Cleanup setup to run when all jobs are completed"* ]] && 
       [[ "${output}" == *"test"* ]]; then
        return 0
    fi
    
    return 1
}

test_docker_dry_run() {
    # Create a temporary directory to mount
    local temp_dir="${TMPDIR}docker_test_$$"
    mkdir -p "${temp_dir}/workspace" "${temp_dir}/home"
    echo "test file" > "${temp_dir}/workspace/test.txt"
    echo "home file" > "${temp_dir}/home/home.txt"
    
    # Run container in dry run mode
    local output
    output=$(docker run --rm \
        -e GITHUB_WORKSPACE="/github/workspace" \
        -e HOME="/github/home" \
        -e INPUT_DRY_RUN="true" \
        -e INPUT_CLEANUP_HOME="true" \
        -e INPUT_CLEANUP_WORKSPACE="true" \
        -v "${temp_dir}/workspace:/github/workspace" \
        -v "${temp_dir}/home:/github/home" \
        -w "/github/workspace" \
        "${IMAGE_NAME}" /cleanup.sh 2>&1) || true
    
    # Check files still exist and dry run message appears
    if [[ -f "${temp_dir}/workspace/test.txt" ]] && [[ -f "${temp_dir}/home/home.txt" ]] && 
       [[ "${output}" == *"DRY RUN"* ]]; then
        rm -rf "${temp_dir}"
        return 0
    fi
    
    rm -rf "$temp_dir"
    return 1
}

test_docker_actual_cleanup() {
    # Create a temporary directory to mount
    local temp_dir="${TMPDIR}docker_test_$$"
    mkdir -p "${temp_dir}/workspace" "${temp_dir}/home"
    echo "test file" > "${temp_dir}/workspace/test.txt"
    echo "home file" > "${temp_dir}/home/home.txt"
    
    # Run container with actual cleanup
    docker run --rm \
        -e GITHUB_WORKSPACE="/github/workspace" \
        -e HOME="/github/home" \
        -e INPUT_DRY_RUN="false" \
        -e INPUT_CLEANUP_HOME="true" \
        -e INPUT_CLEANUP_WORKSPACE="true" \
        -v "${temp_dir}/workspace:/github/workspace" \
        -v "${temp_dir}/home:/github/home" \
        -w "/github/workspace" \
        "${IMAGE_NAME}" /cleanup.sh >/dev/null 2>&1 || true
    
    # Check files are removed
    if [[ ! -f "${temp_dir}/workspace/test.txt" ]] && [[ ! -f "${temp_dir}/home/home.txt" ]]; then
        rm -rf "${temp_dir}"
        return 0
    fi
    
    rm -rf "$temp_dir"
    return 1
}

test_image_size() {
    # Check that image is reasonably small (< 10MB)
    local size
    size=$(docker images "${IMAGE_NAME}" --format "{{.Size}}" | head -n1)
    
    # Convert size to MB for comparison (basic check)
    if [[ "${size}" == *"MB"* ]]; then
        local size_num=${size%MB}
        if (( $(echo "${size_num} < 10" | bc -l) )); then
            return 0
        fi
    fi
    
    # If size is in KB or bytes, it's definitely small enough
    if [[ "${size}" == *"kB"* ]] || [[ "${size}" == *"B"* ]]; then
        return 0
    fi
    
    echo "Image size is ${size} (may be too large)"
    return 1
}

# Ensure Docker is available
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}Docker is not available. Skipping Docker tests.${NC}"
    exit 0
fi

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker daemon is not running. Skipping Docker tests.${NC}"
    exit 0
fi

# Run all tests
echo "Starting Docker tests..."
echo "======================="

cleanup_docker

run_test "Docker image builds successfully" test_docker_build
run_test "Docker entrypoint works correctly" test_docker_entrypoint
run_test "Docker dry run mode works" test_docker_dry_run
run_test "Docker actual cleanup works" test_docker_actual_cleanup
run_test "Docker image size is reasonable" test_image_size

cleanup_docker

# Results
echo "======================="
echo -e "Tests completed: ${PASSED_TESTS}/${TOTAL_TESTS} passed"

if [[ ${TEST_FAILED} -eq 0 ]]; then
    echo -e "${GREEN}All Docker tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some Docker tests failed!${NC}"
    exit 1
fi