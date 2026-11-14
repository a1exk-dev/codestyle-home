# codestyle-home

The operator's workspace. Each repo in `repos.txt` is a separate Git repo in a gitignored folder of the same name, filled by `scripts/clone.sh`.

## Scope

- Change only the repo that your task names. Each repo folder has its own branches, `AGENTS.md`, and required checks: read its `AGENTS.md` before you change it, and commit and open pull requests in that repo.
- A change to the home itself (`repos.txt`, `scripts/`, `tests/`, these docs) goes in a feature branch and a pull request into `main`. The home has no versions, tags, or changelog.

## Checks

- When you change a home script, add or change its tests in `tests/`: plain bash on throwaway Git repos that checks only folders, output, and exit code.
- No check is required on the home's `main`. Before you make a check required, ask the operator.
