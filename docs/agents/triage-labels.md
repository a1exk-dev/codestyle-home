# Triage labels

The skills name triage roles. This file maps each role to its label in the home tracker, `a1exk-dev/codestyle-home`. The tracker of each repo in `repos.gitconfig` uses the same labels for contributors' bug reports.

## State roles

Each triaged issue carries one state label.

| Role | Label | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | The maintainer must evaluate this issue. |
| `needs-info` | `needs-info` | The issue waits on the reporter for more information. |
| `ready-for-agent` | `ready-for-agent` | The issue is fully specified, and an AFK agent can do it. |
| `ready-for-human` | `ready-for-human` | A human must do the issue. |
| `wontfix` | `wontfix` | Nobody will act on the issue. |

## Category roles

Each triaged issue carries one category label.

| Role | Label | Meaning |
| --- | --- | --- |
| `bug` | `bug` | Something is broken. |
| `enhancement` | `enhancement` | A new feature or an improvement. |

## Wayfinder labels

The wayfinder skill labels its own issues. A wayfinder issue carries no state label.

| Label | Meaning |
| --- | --- |
| `wayfinder:map` | A map: the destination, notes, decisions so far, and fog of one effort. |
| `wayfinder:research` | A ticket that a research session answers. |
| `wayfinder:prototype` | A ticket that a prototype answers. |
| `wayfinder:grilling` | A ticket that a grilling session with the operator answers. |
| `wayfinder:task` | A ticket of work that a map carries out itself. |

When a skill names a role, for example "apply the AFK-ready triage label", use the label of that role from these tables. When state labels conflict on one issue, ask the operator before you change a label.
