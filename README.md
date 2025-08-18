# Self-Hosted Runner Job Cleaner

A GitHub Action to clean the runner workspace and home directory at the end of jobs.
This is especially useful for self-hosted runners, where workspace files don't get deleted automatically at the end of workflows.

## Features

- ✅ Safely cleans `GITHUB_WORKSPACE` and `HOME` directory contents
- ✅ Configurable cleanup options (workspace, home, or both)
- ✅ Dry-run mode to preview what would be deleted
- ✅ Enhanced security checks to prevent accidental deletions
- ✅ Detailed logging and error handling
- ✅ Runs as a post-action cleanup step

## Usage

### Basic Usage

Add a step for the action at any point in your job. The cleanup will run automatically after all other steps complete:

```yaml
jobs:
  my-job:
    name: My job
    runs-on: my-self-hosted-runner
    steps:
      - name: Cleanup job
        uses: ducktors/runner-post-cleanup@v1
        if: always()
      - uses: actions/checkout@v4
        name: Checkout
      # ... your other steps
```

### Advanced Configuration

```yaml
- name: Cleanup job
  uses: ducktors/runner-post-cleanup@v1
  with:
    cleanup_home: true          # Clean HOME directory (default: true)
    cleanup_workspace: true     # Clean GITHUB_WORKSPACE (default: true)
    dry_run: false             # Preview mode only (default: false)
  if: always()
```

### Dry Run Mode

To see what would be cleaned without actually deleting files:

```yaml
- name: Preview cleanup
  uses: ducktors/runner-post-cleanup@v1
  with:
    dry_run: true
  if: always()
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cleanup_home` | Whether to cleanup HOME directory contents | No | `true` |
| `cleanup_workspace` | Whether to cleanup GITHUB_WORKSPACE contents | No | `true` |
| `dry_run` | Show what would be cleaned without deleting | No | `false` |

## Security Features

- Only runs in GitHub Actions environments
- Validates directory paths exist before attempting cleanup
- Checks that execution happens within expected workspace boundaries
- Uses `find` with depth limits to prevent recursive disasters
- Graceful error handling with detailed logging

## Requirements

- Self-hosted runners (GitHub-hosted runners clean up automatically)
- Linux/Unix-based runners (uses bash and find commands)

## License

MIT License
