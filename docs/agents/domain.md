# Domain Docs

How the engineering skills should consume the domain documentation of the home and its repos when exploring the codebase.

## Before exploring, read these

Read the glossary and ADRs of the repo that your task names, and the home ADRs:

| Context | Glossary | ADRs |
| --- | --- | --- |
| The home (cross-repo decisions) | none | `docs/adr/` |
| The Core | `codestyle.nvim/GLOSSARY.md` | `codestyle.nvim/docs/adr/` |

Read only the ADRs that touch the area you're about to work in. A Language Plugin or the template has no domain glossary of its own: it uses the Core's `GLOSSARY.md`. When a repo joins `repos.txt` with its own glossary or ADRs, add its row here.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## Where a new doc goes

- A term or decision about one repo goes in that repo's `GLOSSARY.md` or `docs/adr/`.
- A decision that covers more than one repo goes in the home's `docs/adr/`.
- A Core ADR number is never reused. A Core ADR that moved to the home keeps a "Moved to" stub under its old number.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the glossary. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (some decision), but worth reopening because…_

Name the repo with the number when it is not clear, for example "Core ADR-0007" or "home ADR-0003".
