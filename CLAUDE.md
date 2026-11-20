# CLAUDE.md

This repository uses [`AGENTS.md`](AGENTS.md) as the canonical, tool-agnostic handbook for all AI assistants.

## Required Reading Before Acting
1. Read [`AGENTS.md`](AGENTS.md) in full.
2. Read [`docs/ROLES_AND_GOVERNANCE.md`](docs/ROLES_AND_GOVERNANCE.md) to confirm what you may do autonomously vs. what requires user approval.
3. Read [`docs/VISION_AND_CONSTRAINTS.md`](docs/VISION_AND_CONSTRAINTS.md) and [`docs/DECISION_LOG.md`](docs/DECISION_LOG.md) for locked-in rules and constraints.
4. Check [`docs/ALIGNMENT_LOG.md`](docs/ALIGNMENT_LOG.md) and [`CHANGELOG.md`](CHANGELOG.md) for the latest project state.

## Key Reminders
- Keep `AGENTS.md` and `docs/` as the single source of truth; do not diverge rules in this file.
- Log every User comment in [`docs/USER_FEEDBACK_LOG.md`](docs/USER_FEEDBACK_LOG.md) before acting, and check it before changing a system so no earlier request regresses (`AGENTS.md` §4, `D-045`).
- Update [`CHANGELOG.md`](CHANGELOG.md) (and relevant domain changelogs in `docs/changelogs/`) for every meaningful change.
- Prioritize automated tests for anything that can be tested automatically.
- For any visual, 3D art, lighting, animation, HUD, or menu change, **always** run `./scripts/run-visual-qa.sh` and visually inspect the live screenshots and motion video from the player's POV (`D-028`).
