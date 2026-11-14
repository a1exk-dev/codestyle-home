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

## Change the home

The home has one branch, `main`, with no versions or changelog. Open a pull request from a feature branch into `main`. CI runs `tests/clone_test.sh` and `typos`.
