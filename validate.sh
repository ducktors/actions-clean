#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

# Build validation script for actions-clean
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VALIDATION_FAILED=0

log_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    VALIDATION_FAILED=1
}

check_command() {
    local cmd="$1"
    local description="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_success "$description is available"
        return 0
    else
        log_error "$description is not available (command: $cmd)"
        return 1
    fi
}

validate_file_structure() {
    log_info "Validating file structure..."
    
    local required_files=(
        "action.yml"
        "Dockerfile"
        "entrypoint.sh"
        "cleanup.sh"
        "README.md"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Found required file: $file"
        else
            log_error "Missing required file: $file"
        fi
    done
    
    # Check test files
    if [[ -d "tests" ]]; then
        log_success "Tests directory exists"
        
        local test_files=(
            "tests/test-cleanup.sh"
            "tests/test-docker.sh"
        )
        
        for file in "${test_files[@]}"; do
            if [[ -f "$file" ]] && [[ -x "$file" ]]; then
                log_success "Found executable test file: $file"
            elif [[ -f "$file" ]]; then
                log_warning "Test file exists but is not executable: $file"
            else
                log_error "Missing test file: $file"
            fi
        done
    else
        log_error "Tests directory not found"
    fi
    
    # Check CI configuration
    if [[ -f ".github/workflows/ci.yml" ]]; then
        log_success "GitHub Actions CI configuration found"
    else
        log_error "GitHub Actions CI configuration not found"
    fi
}

validate_shell_scripts() {
    log_info "Validating shell scripts..."
    
    local shell_scripts=(
        "entrypoint.sh"
        "cleanup.sh"
        "tests/test-cleanup.sh"
        "tests/test-docker.sh"
        "validate.sh"
    )
    
    for script in "${shell_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            # Check shebang
            if head -n1 "$script" | grep -q "#!/.*bash"; then
                log_success "$script has correct bash shebang"
            else
                log_error "$script missing or incorrect bash shebang"
            fi
            
            # Check if executable
            if [[ -x "$script" ]]; then
                log_success "$script is executable"
            else
                log_warning "$script is not executable"
            fi
            
            # Basic syntax check
            if bash -n "$script" 2>/dev/null; then
                log_success "$script has valid bash syntax"
            else
                log_error "$script has invalid bash syntax"
            fi
        fi
    done
}

validate_docker_setup() {
    log_info "Validating Docker setup..."
    
    if check_command "docker" "Docker"; then
        if docker info >/dev/null 2>&1; then
            log_success "Docker daemon is running"
            
            # Validate Dockerfile
            if [[ -f "Dockerfile" ]]; then
                log_info "Building Docker image for validation..."
                if docker build -t actions-clean-validation . >/dev/null 2>&1; then
                    log_success "Docker image builds successfully"
                    
                    # Test basic functionality
                    if docker run --rm actions-clean-validation echo "test" >/dev/null 2>&1; then
                        log_success "Docker container runs successfully"
                    else
                        log_error "Docker container fails to run"
                    fi
                    
                    # Cleanup
                    docker rmi actions-clean-validation >/dev/null 2>&1 || true
                else
                    log_error "Docker image failed to build"
                fi
            fi
        else
            log_error "Docker daemon is not running"
        fi
    fi
}

validate_action_yml() {
    log_info "Validating action.yml..."
    
    if [[ -f "action.yml" ]]; then
        # Check required fields
        if grep -q "name:" action.yml; then
            log_success "action.yml has name field"
        else
            log_error "action.yml missing name field"
        fi
        
        if grep -q "description:" action.yml; then
            log_success "action.yml has description field"
        else
            log_error "action.yml missing description field"
        fi
        
        if grep -q "runs:" action.yml; then
            log_success "action.yml has runs section"
        else
            log_error "action.yml missing runs section"
        fi
        
        # Check Docker configuration
        if grep -q 'using: "docker"' action.yml; then
            log_success "action.yml configured for Docker"
        else
            log_error "action.yml not configured for Docker"
        fi
        
        # Check branding
        if grep -q "branding:" action.yml; then
            log_success "action.yml has branding section"
        else
            log_warning "action.yml missing branding section (optional)"
        fi
        
        # Validate inputs
        local expected_inputs=("cleanup_home" "cleanup_workspace" "dry_run")
        for input in "${expected_inputs[@]}"; do
            if grep -q "$input:" action.yml; then
                log_success "action.yml has input: $input"
            else
                log_error "action.yml missing input: $input"
            fi
        done
    else
        log_error "action.yml file not found"
    fi
}

run_linting() {
    log_info "Running linting checks..."
    
    if check_command "shellcheck" "ShellCheck"; then
        local shell_scripts=(
            "entrypoint.sh"
            "cleanup.sh"
            "tests/test-cleanup.sh"
            "tests/test-docker.sh"
            "validate.sh"
        )
        
        for script in "${shell_scripts[@]}"; do
            if [[ -f "$script" ]]; then
                if shellcheck "$script" >/dev/null 2>&1; then
                    log_success "ShellCheck passed for $script"
                else
                    log_error "ShellCheck failed for $script"
                fi
            fi
        done
    else
        log_warning "ShellCheck not available, skipping linting"
    fi
}

run_tests() {
    log_info "Running tests..."
    
    # Run unit tests
    if [[ -x "tests/test-cleanup.sh" ]]; then
        log_info "Running cleanup tests..."
        if ./tests/test-cleanup.sh >/dev/null 2>&1; then
            log_success "Cleanup tests passed"
        else
            log_error "Cleanup tests failed"
        fi
    else
        log_error "Cleanup tests not found or not executable"
    fi
    
    # Run Docker tests (if Docker is available)
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        if [[ -x "tests/test-docker.sh" ]]; then
            log_info "Running Docker tests..."
            if ./tests/test-docker.sh >/dev/null 2>&1; then
                log_success "Docker tests passed"
            else
                log_error "Docker tests failed"
            fi
        else
            log_error "Docker tests not found or not executable"
        fi
    else
        log_warning "Docker not available, skipping Docker tests"
    fi
}

validate_security() {
    log_info "Running security validation..."
    
    # Check for potential security issues in scripts
    local security_patterns=(
        'eval\s+\$'
        '\$\(.*\)\s*\|'
        'rm\s+(-rf\s+)?/'
    )
    
    local all_scripts=(
        "entrypoint.sh"
        "cleanup.sh"
        "tests/test-cleanup.sh"
        "tests/test-docker.sh"
    )
    
    for script in "${all_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            local issues_found=false
            for pattern in "${security_patterns[@]}"; do
                if grep -qE "$pattern" "$script"; then
                    log_warning "Potential security issue in $script: pattern '$pattern'"
                    issues_found=true
                fi
            done
            
            if ! $issues_found; then
                log_success "No obvious security issues in $script"
            fi
        fi
    done
    
    # Check for hardcoded secrets or credentials
    if grep -rE "(password|secret|key|token).*=" . --exclude-dir=.git --include="*.sh" --include="*.yml" >/dev/null 2>&1; then
        log_warning "Found potential hardcoded credentials (review manually)"
    else
        log_success "No obvious hardcoded credentials found"
    fi
}

# Main validation flow
main() {
    echo "Starting build validation for actions-clean..."
    echo "============================================="
    echo
    
    validate_file_structure
    echo
    
    validate_shell_scripts
    echo
    
    validate_action_yml
    echo
    
    validate_docker_setup
    echo
    
    run_linting
    echo
    
    validate_security
    echo
    
    run_tests
    echo
    
    # Final result
    echo "============================================="
    if [[ $VALIDATION_FAILED -eq 0 ]]; then
        log_success "All validations passed! ✨"
        exit 0
    else
        log_error "Some validations failed!"
        echo -e "${RED}Please fix the issues above before proceeding.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"