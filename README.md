# Runner Post Cleanup
A Github Action to clean the runner workspace - mostly copied from https://github.com/TooMuch4U/actions-clean. 

This action will delete all files in the runners working directory at the end of the job. 
This is especially useful for self-hosted runners, where workspace files don't get deleted at the end of workflows.

## Usage
Add a step for the action (at any point in the job) and a post run job will delete any files left in the workspace.
```yaml
# ...

  my-job:
    name: My job
    runs-on: my-self-hosted-runner
    steps:
      - name: Cleanup job
        uses: ducktors/runner-post-cleanup
        if: always()
      - uses: actions/checkout
        name: Checkout
    
# ...
```
