# codestyle-home

The operator's workspace. Each repo in `repos.txt` is a separate Git repo in a gitignored folder of the same name, filled by `scripts/clone.sh`.

## Scope

- Change only the repo that your task names. Each repo folder has its own branches, `AGENTS.md`, and required checks: read its `AGENTS.md` before you change it, and commit and open pull requests in that repo.
- A change to the home itself (`repos.txt`, `scripts/`, `tests/`, the skills, these docs) goes in a feature branch and a pull request into `main`. The home has no versions, tags, or changelog.

## Policies

- The policies in the home's `docs/agents/` cover every repo. When a skill names `docs/agents/<file>`, read that file in the home root, also while you work in a repo folder. The repos keep no copies.
- The Semver policy, `docs/agents/semver-policy.md`, covers the Core, the template, and the Language Plugins. It does not cover the home, which works on `main` only, through pull requests.

## Questions

- When you must ask the operator a question, use the question tool. Ask one question, then wait for the answer before you ask the next question. Give concrete answer options, with the recommended option first. This rule replaces the question format of each Skill that asks questions in batches.

## Knowledge

- Before you examine or change a repo, read the glossary and the ADRs that `docs/agents/domain.md` names for it, and `MEMORY.md` for the applicable entries. Obey these ADRs, because each ADR records a decision that the code does not show.

## Workflow

- Changelog: In each pull request into a repo's `develop` with a change that users can see, add its item under `## Unreleased` of that repo's `CHANGELOG.md` with the common-changelog Skill. On each `release/*` or `hotfix/*` branch, release the changelog as its version before you open the pull request into `main` ([ADR-0004](docs/adr/0004-public-0x-releases-cut-from-git-flow-branches.md)).
- Merge messages: Start the message of each merge commit into `develop` with the line `<type>[(<scope>)]: merge <branch> into develop (#<n>)`, and of each merge commit into the home's `main` with `<type>[(<scope>)]: merge <branch> into main (#<n>)`. When you write this message, obey each Setting of the Commit policy, `docs/agents/commit-policy.md`, that controls the message.

## Checks

- When you change a home script, add or change its tests in `tests/`: plain bash on throwaway Git repos that checks only folders, output, and exit code.
- No check is required on the home's `main`. Before you make a check required, ask the operator.

## Agent skills

### Triage labels

The default labels are needs-triage, needs-info, ready-for-agent, ready-for-human, and wontfix. Before you add or change a triage label, read `docs/agents/triage-labels.md`.

### Issue tracker

Agent issues are tracked in GitHub Issues (`a1exk-dev/codestyle-home`) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Before you write or edit an `AGENTS.md`, a `GLOSSARY.md`, `MEMORY.md`, or an ADR, and when you complete a task, obey `docs/agents/domain.md`.
