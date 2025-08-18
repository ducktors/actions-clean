# Self-Hosted Runner Job Cleaner

**Runner Post Cleanup** is a GitHub Action designed to automatically clean up the runner's workspace at the end of a job. This is especially useful for **self-hosted runners**, where leftover files can accumulate between workflow runs, potentially causing issues or consuming unnecessary disk space.

## Why use this action?

- **Prevents disk space issues** on persistent/self-hosted runners.
- **Removes all files** left in the working directory after your workflow completes.
- **Easy to use:** simply add a step—cleanup runs automatically after your job.

## Usage

Add a step for this action at any point in your job.
A post-run step will automatically delete any files left in the workspace when the job completes.

```yaml
jobs:
  my-job:
    name: My job
    runs-on: my-self-hosted-runner
    steps:
      - uses: actions/checkout
        name: Checkout

      # Add your workflow steps here

      - name: Cleanup job
        uses: ducktors/runner-post-cleanup
        if: always()
```

### Notes

- The `if: always()` condition ensures the cleanup runs even if previous steps fail.
- You can place the cleanup step anywhere in your job steps; the action will perform cleanup as a post-job hook.
- For GitHub-hosted runners, cleanup is usually handled automatically. This action is primarily beneficial for self-hosted runners.

## License

MIT

---

Inspired by [TooMuch4U/actions-clean](https://github.com/TooMuch4U/actions-clean).
