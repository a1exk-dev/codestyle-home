# codestyle-home

The workspace for the [codestyle.nvim](https://github.com/a1exk-dev/codestyle.nvim) repos. It holds no plugin code. It lists each codestyle repo in `repos.txt` and clones it into a folder of the same name, which Git ignores.

## Set up the workspace

```sh
git clone https://github.com/a1exk-dev/codestyle-home.git
cd codestyle-home
scripts/clone.sh
```

The script clones each repo that is missing and fast-forwards the current branch of each repo you have. Run it again to update the workspace.

It never changes a clone's branch and never discards work. It skips a clone that has uncommitted changes, a detached HEAD, or a branch that cannot fast-forward, and names it in the summary. It exits non-zero only when a clone or pull fails for another reason.

## Add a repo

Add one line to `repos.txt`: the folder name and the clone URL. The next run of `scripts/clone.sh` clones it. Name the repo `codestyle-<name>.nvim`, so that `.gitignore` already ignores its folder.

## Report boilerplate drift

Before you change the Language Plugin template, run:

```sh
scripts/drift.sh
```

For each Language Plugin clone, it lists the boilerplate files that differ from the template clone: changed, missing, or extra. `boilerplate.txt` lists the boilerplate files. Add `--diff` to show each difference, and name plugins to report only those. Plugins may differ on purpose, so the report changes no file and exits non-zero only when the template is not cloned.

## Agent setup

The home holds the agent setup for every repo: the skills in `.agents/skills/` and `.claude/skills/` (pinned in `skills-lock.json`), the main `AGENTS.md`, and the process policies in `docs/agents/`. Start Claude Code at the home root, so that it loads them. Each repo keeps only a short `AGENTS.md` about itself, and builds and tests without the home.

## Change the home

The home has one branch, `main`, with no versions or changelog. Open a pull request from a feature branch into `main`. CI runs each `tests/*_test.sh` and `typos`.
