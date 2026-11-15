# Each repo keeps a copy of the commit, semver and changelog skills and their policies

Amends [ADR-0001](0001-codestyle-home-holds-every-codestyle-repo-and-replaces-the-sync.md), whose repos kept no copies of the skills or policies. The Core, the template and each `codestyle-<id>.nvim` repo now keep a copy of the three process skills, `git-commit`, `semver` and `common-changelog`, and of the policies they read: `docs/agents/commit-policy.md`, `semver-policy.md` and `changelog-policy.md`. An agent session that starts in one repo alone, or in the cloud, then commits, branches, versions and writes the changelog by the same rules as a session in the home (operator).

## Decision

- **What is copied:** `.agents/skills/<skill>/` for the three skills, a Claude Code link `.claude/skills/<skill>` to each, and the three policies in `docs/agents/`. The other skills and policies stay only in the home.
- **Source:** the home. A skill or policy changes only in the home, by a pull request into `main`.
- **Copy:** `scripts/copy-skills.sh` writes the home's copies into each clone in `repos.txt` and commits nothing. The agent that changed the home opens one pull request per repo with the result, as for a template change (ADR-0001). No bot or App runs.
- **Drift:** `scripts/copy-skills.sh --check` names each stale copy and exits non-zero.

## Considered Options

- **Policies only**, or **skills only.** Rejected: a skill without its policy sets up a new policy from the operator's answers, and a policy without its skill has nothing that reads it.
- **Copies by hand.** Rejected: nothing would show a stale copy.
- **Each repo owns its copies.** Rejected: the rules of the repos would drift apart.

## Consequences

- A change to one of the three skills or policies takes one home pull request, then one pull request per repo.
- A repo's copies are what its contributors and its agents follow. In a session in the home, the home's files and the repo's copies are the same once each copy is up to date.
