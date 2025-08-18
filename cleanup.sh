#!/usr/bin/env bash
set -o errexit -o nounset -o xtrace -o pipefail
shopt -s inherit_errexit nullglob dotglob

# Read input parameters
CLEANUP_HOME="${INPUT_CLEANUP_HOME:-true}"
CLEANUP_WORKSPACE="${INPUT_CLEANUP_WORKSPACE:-true}"
DRY_RUN="${INPUT_DRY_RUN:-false}"

# Ensure we're running in a GitHub Actions environment
if [[ -z "${GITHUB_WORKSPACE:-}" ]]; then
  echo "ERROR: Not running in GitHub Actions environment"
  exit 1
fi

# Function to perform cleanup with dry-run support
cleanup_directory() {
  local dir="$1"
  local description="$2"
  
  if [[ ! -d "$dir" ]]; then
    echo "WARNING: $description directory not found: $dir"
    return 0
  fi
  
  local items
  items=$(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null || true)
  
  if [[ -z "$items" ]]; then
    echo "INFO: $description directory is already clean: $dir"
    return 0
  fi
  
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN: Would clean $description directory: $dir"
    echo "Items that would be removed:"
    find "$dir" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true
  else
    echo "Cleaning $description directory: $dir"
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  fi
}

# Validate workspace path for security
if [[ -n "${GITHUB_WORKSPACE:-}" ]] && [[ -d "${GITHUB_WORKSPACE}" ]]; then
  # Only clean if we're actually in a reasonable workspace path
  if [[ "$PWD" != "${GITHUB_WORKSPACE}"* ]] && [[ "$DRY_RUN" != "true" ]]; then
    echo "WARNING: Not executing from within GITHUB_WORKSPACE, skipping cleanup for security"
    exit 0
  fi
fi

# Clean home directory contents if enabled
if [[ "$CLEANUP_HOME" == "true" ]] && [[ -n "${HOME:-}" ]]; then
  cleanup_directory "$HOME" "HOME"
fi

# Clean workspace directory contents if enabled
if [[ "$CLEANUP_WORKSPACE" == "true" ]] && [[ -n "${GITHUB_WORKSPACE:-}" ]]; then
  cleanup_directory "$GITHUB_WORKSPACE" "GITHUB_WORKSPACE"
fi

if test "${RUNNER_DEBUG:-0}" != '1'; then
  set +o xtrace
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry run completed - no files were actually deleted"
else
  echo "Cleanup completed successfully"
fi
