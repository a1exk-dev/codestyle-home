# codestyle-home

The workspace for the [codestyle.nvim](https://github.com/a1exk-dev/codestyle.nvim) repos. It holds no plugin code. It lists each codestyle repo in `repos.gitconfig` and clones it into a folder of the same name, which Git ignores.

## Set up the workspace

```sh
gh repo clone a1exk-dev/codestyle-home
cd codestyle-home
scripts/clone.sh
```

The script clones each repo that is missing and fast-forwards the current branch of each repo you have. Run it again to update the workspace. It clones with `gh repo clone`, so each clone uses your `gh` login and its Git protocol, for example SSH after `gh config set git_protocol ssh`.

It never changes a clone's branch and never discards work. It skips a clone that has uncommitted changes, a detached HEAD, or a branch that cannot fast-forward, and names it in the summary. It exits non-zero only when a clone or pull fails for another reason.

## Add a repo

Add one section to `repos.gitconfig`, in Git config format: the folder name and the repo on GitHub.

```ini
[repo "codestyle-php.nvim"]
	github = a1exk-dev/codestyle-php.nvim
```

 The next run of `scripts/clone.sh` clones it. Name the repo `codestyle-<name>.nvim`, so that `.gitignore` already ignores its folder.

## Report boilerplate drift

Before you change the Language Plugin template, run:

```sh
scripts/drift.sh
```

For each Language Plugin clone, it lists the boilerplate files that differ from the template clone: changed, missing, or extra. `boilerplate.txt` lists the boilerplate files. Add `--diff` to show each difference, and name plugins to report only those. Plugins may differ on purpose, so the report changes no file and does not fail on a difference. It fails only when the template is not cloned, `boilerplate.txt` lists no file, or an argument is wrong.

## Protect the branches and turn on auto-merge

After a repo joins `repos.gitconfig`, run with your `gh` login:

```sh
scripts/protect.sh
```

On each repo in `repos.gitconfig`, `main` and `develop` then require the five checks of Core ADR-0017, from GitHub Actions, also for admins. The script owns every rule of branch protection: it turns off any other rule set by hand, such as required reviews or linear history. It also allows auto-merge and deletes the branch of a merged pull request on each repo. The script changes only a branch or settings that differ, and names each branch, and each repo's settings, `protected`, `set`, `up to date`, or `failed`. It exits non-zero when a branch failed, for example because the repo has no `develop` yet. It needs `jq`.

## Agent setup

The home holds the agent setup for every repo: the skills in `.agents/skills/` and `.claude/skills/` (pinned in `skills-lock.json`), the main `AGENTS.md`, and the process policies in `docs/agents/`. Start Claude Code at the home root, so that it loads them. Each repo keeps a short `AGENTS.md` about itself and a copy of the commit, semver and changelog skills and their policies, and builds and tests without the home. After a change to one of these skills or policies, run `scripts/copy-skills.sh` and open one pull request per repo. `scripts/copy-skills.sh --check` names each stale copy.

## Change the home

The home has one branch, `main`, with no versions or changelog. Open a pull request from a feature branch into `main`. CI runs each `tests/*_test.sh` and `typos`, and `main` requires both checks. The Auto-merge workflow turns on auto-merge for your own pull requests, so each one merges with a merge commit when both checks pass, and its branch is deleted. The pull requests of other people wait for your review.
