# CLAUDE.md

This repository uses [`AGENTS.md`](AGENTS.md) as the canonical, tool-agnostic handbook for all AI assistants.

## Required Reading Before Acting
1. Read [`AGENTS.md`](AGENTS.md) in full.
2. Read [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md) to confirm what you may do autonomously vs. what requires user approval.
3. Read [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) for locked-in rules and constraints.
4. Check [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) and [`CHANGELOG.md`](CHANGELOG.md) for the latest project state.

## Key Reminders
- Keep `AGENTS.md` and `docs/` as the single source of truth; do not diverge rules in this file.
- Update [`CHANGELOG.md`](CHANGELOG.md) (and relevant domain changelogs in `docs/changelogs/`) for every meaningful change.
- Prioritize automated tests for anything that can be tested automatically.
