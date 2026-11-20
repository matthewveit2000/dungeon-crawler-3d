# GitHub Copilot Instructions

This repository uses `AGENTS.md` as the canonical instruction set for all AI tools.

1. Read `AGENTS.md` and `docs/ROLES_AND_GOVERNANCE.md` before proposing or making changes.
2. Respect all locked-in constraints in `docs/VISION_AND_CONSTRAINTS.md` and `docs/DECISION_LOG.md`.
3. Update `CHANGELOG.md` (and relevant domain changelogs under `docs/changelogs/`) whenever you make meaningful changes.
4. Build with automated testing in mind—anything that can be tested automatically must be tested automatically.
5. For any visual, 3D art, lighting, animation, HUD, or menu change, run `./scripts/run-visual-qa.sh` and visually inspect live player-POV screenshots and motion video (`D-028`).
- Log every User comment in `docs/USER_FEEDBACK_LOG.md` before acting and check it before changing a system (see `AGENTS.md` §4, `D-045`).
