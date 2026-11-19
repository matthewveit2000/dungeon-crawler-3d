#!/usr/bin/env python3
"""Repository & multi-AI hygiene checks:
- Verifies all universal AI instruction files exist and reference AGENTS.md
- Verifies no unseeded randf()/randi()/randf_range()/randi_range() calls exist in game/src/
- Verifies internal markdown relative links in root & docs/ resolve to real files
"""

import pathlib
import re
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

AI_ENTRY_FILES = [
    "AGENTS.md",
    "CLAUDE.md",
    ".cursorrules",
    ".github/copilot-instructions.md",
    "CHANGELOG.md",
    "docs/DECISION_LOG.md",
    "docs/ROLES_AND_GOVERNANCE.md",
    "docs/GAME_DESIGN.md",
    "docs/TESTING_STRATEGY.md",
    "docs/ROADMAP.md",
]

UNSEEDED_RNG_RE = re.compile(r"(?<![.\w])(randf|randi|randf_range|randi_range|randomize)\s*\(")
MD_LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")


def main() -> int:
    errors: list[str] = []

    # 1. Required AI & governance files
    for rel in AI_ENTRY_FILES:
        path = REPO_ROOT / rel
        if not path.exists():
            errors.append(f"Missing required governance/AI file: {rel}")
        elif rel in ("CLAUDE.md", ".cursorrules", ".github/copilot-instructions.md"):
            if "AGENTS.md" not in path.read_text(encoding="utf-8"):
                errors.append(f"{rel} must reference AGENTS.md")

    # 2. Seeded randomness guardrail across game/src/
    src_dir = REPO_ROOT / "game" / "src"
    if src_dir.exists():
        for gd_file in sorted(src_dir.rglob("*.gd")):
            if gd_file.name == "seeded_rng.gd":
                continue
            for idx, line in enumerate(gd_file.read_text(encoding="utf-8").splitlines(), start=1):
                stripped = line.strip()
                if stripped.startswith("#"):
                    continue
                m = UNSEEDED_RNG_RE.search(stripped)
                if m:
                    rel = gd_file.relative_to(REPO_ROOT)
                    errors.append(
                        f"{rel}:{idx}: unseeded randomness '{m.group(1)}()' is forbidden; use SeededRng"
                    )

    # 3. Verify local markdown links in root and docs/
    md_files = list(REPO_ROOT.glob("*.md")) + list((REPO_ROOT / "docs").rglob("*.md"))
    for md in md_files:
        text = md.read_text(encoding="utf-8")
        for match in MD_LINK_RE.finditer(text):
            target = match.group(1).strip()
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            clean = target.split("#", 1)[0]
            if not clean:
                continue
            resolved = (md.parent / clean).resolve()
            if not resolved.exists():
                rel = md.relative_to(REPO_ROOT)
                errors.append(f"{rel}: broken relative markdown link -> {target}")

    if errors:
        for e in errors:
            print(f"[HYGIENE ERROR] {e}", file=sys.stderr)
        return 1

    print("[check-repo-hygiene] OK: Multi-AI docs, seeded-RNG guardrail, and markdown links all clean.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
