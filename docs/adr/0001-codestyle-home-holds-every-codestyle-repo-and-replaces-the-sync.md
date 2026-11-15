# codestyle-home holds every codestyle repo and replaces the sync

Amended by [ADR-0006](0006-each-repo-keeps-a-copy-of-the-process-skills-and-policies.md): each repo keeps a copy of the commit, semver and changelog skills and their policies.

The project adopts `codestyle-home`, a public workspace repo that holds every codestyle repo, the shared agent setup and the docs that cover more than one repo. It supersedes [ADR-0005](0005-language-plugins-keep-own-repos-and-get-shared-files-through-the-template.md): no Core-to-template-to-plugin sync runs, and no GitHub App opens pull requests ("Does a home repo that holds every codestyle repo replace the ADR-0020 sync?", [codestyle.nvim#108](https://github.com/a1exk-dev/codestyle.nvim/issues/108)). The facts on agent context come from "Do coding agents load a parent folder's AGENTS.md, CLAUDE.md and skills from inside a nested Git repo?" ([codestyle.nvim#109](https://github.com/a1exk-dev/codestyle.nvim/issues/109)).

## Decision

- **Purpose:** the home is the operator's local workspace. Every repo stands alone: it builds, tests and runs CI without the home. Contributors are not required to use the home or its skills.
- **Names:** `codestyle-home`, `codestyle.nvim` (the Core, unchanged), `codestyle-<id>.nvim`, `codestyle-language-template.nvim`. The `.nvim` suffix stays, so the Core's install name stays short and lazy.nvim's main-module guess still works.
- **Sub-repos:** gitignored clones. The home commits a manifest, `repos.gitconfig`, and a script that clones the missing repos and pulls the rest. The manifest is in Git config format, one `[repo "<folder>"]` section with `github = <owner>/<name>` per repo, so Git parses it and it can take more keys later. It holds no clone URL: the script clones with `gh repo clone`, which follows the operator's `gh` login and protocol. No submodules, so the home never needs pointer-bump commits.
- **The home holds:** the skills, the main `AGENTS.md`/`CLAUDE.md`, the process policies (`docs/agents/`), and the docs and ADRs that cover more than one repo.
- **Each repo holds:** only what is about that repo: README, its own ADRs, its own glossary, and a short `AGENTS.md`. The domain `GLOSSARY.md` and the ADRs about Core code stay in the Core. Plugins link to them and keep no copies.
- **Boilerplate:** no automatic sync and no GitHub App. A template change may not fit every plugin, so the agent that makes it in the home opens one pull request per plugin and adapts it where needed. Plugins may differ from the template. A home command reports, per plugin, the boilerplate files that differ.
- **Home process:** the home has one protected `main`, and its changes arrive by pull request, with no versions, tags or changelog. The process policies in its `docs/agents/` cover every repo, and the repos keep no copies. The Semver policy covers the Core, the template and the Language Plugins, but not the home.
- **Visibility:** `codestyle-home` is public, so links from repo docs to cross-repo ADRs work.
- **Issues:** all agent work (wayfinder maps, specs, `ready-for-agent` and `ready-for-human` issues) lives in the home tracker. Each repo's tracker is only for contributors and release discussions.
- **ADRs:** the cross-repo ADRs move to the home and are numbered from 0001, with this decision first: Core ADR-0009, ADR-0013, ADR-0019 and ADR-0020 become ADR-0002 to ADR-0005. Each Core original becomes a "Moved to" stub, and Core ADR numbers are never reused.
- **Sessions:** the operator always starts agents in the home. Walls between repos are kept by instructions only. Claude Code started at the home root loads every skill, and loads a repo's `CLAUDE.md` when it reads files there. Codex and opencode are not part of the setup. Cloud agents never see the home.

What the Language Plugin template contains is out of scope and goes to a separate map.

## Considered Options

- **The sync of ADR-0005**, through the template with a GitHub App and self-merging pull requests. Rejected: every plugin would carry copies of the skills, policies and Core docs, a template change would land in plugins it does not fit, and the App and a check against hand edits add moving parts.
- **Submodules in the home.** Rejected: each change in a repo would need a pointer-bump commit in the home.
- **A plain-text manifest** (`repos.txt`, one folder and clone URL per line). Replaced by the operator: a custom format that each script parsed itself, and its HTTPS URLs made clones that could not push over the operator's SSH setup.
- **Repos found by a GitHub topic**, with no manifest. Rejected: every script would need the network, and the list would change outside a reviewed pull request.
- **A private home.** Rejected: links from the public repos' docs to the cross-repo ADRs would not work for readers.

## Consequences

- A change to a skill or policy reaches every repo in one home pull request.
- An agent session that starts inside one repo, or in the cloud, sees only that repo's short `AGENTS.md`, not the home's skills and policies.
- Links to the moved ADRs from Core docs resolve through the stubs.
- A skill that reads `docs/agents/<file>` finds it at the home root, not in the repo folder that the task changes. The home's `AGENTS.md` says so.
