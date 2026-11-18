# The semver Skill opens the back-merges

After the operator merges a `release/*` or `hotfix/*` pull request into `main`, `release.yml` makes the tag and publishes the GitHub release ([ADR-0004](0004-public-0x-releases-cut-from-git-flow-branches.md)), and a new Finish run of the semver Skill opens each back-merge (`Tag and back-merge: Skill` in `docs/agents/semver-policy.md`). Finish runs under the operator's login, so the back-merge's required checks run, and the Auto-merge workflow merges a back-merge into `develop`. CI could not do this with its default token: GitHub starts no workflow for a pull request that this token opens, so the checks of the 0.2.0 back-merge stayed `action_required` and it never merged ("release.yml opens a back-merge that never merges by itself", [#74](https://github.com/a1exk-dev/codestyle-home/issues/74)).

## Considered Options

- **CI opens the back-merge with the default token.** Rejected: its pull request starts no checks, and the token cannot turn on auto-merge without `contents: write`.
- **CI opens it with a personal access token secret.** Rejected: each of the 17 repos needs the secret, which `protect.sh` would have to set because a template copies no secrets. The token expires, and a leaked token acts as the operator.
- **CI opens it with a token of a GitHub App.** Rejected: each repo needs the App ID and private key secrets, for the same reason.
- **The semver Skill opens it.** Chosen: no secrets. The operator merges each pull request into `main` by hand (`Production auto-merge: off`), so a Finish run follows each release.

## Consequences

- Finish makes the tag only when `release.yml` has not made it, so the two never make the same tag, and the GitHub release keeps its `CHANGELOG.md` notes.
- Until someone runs Finish, `develop` does not have the release. The summary of each `release.yml` run says to finish the release with the semver Skill.
