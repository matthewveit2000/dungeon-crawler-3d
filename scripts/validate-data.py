#!/usr/bin/env python3
"""Validates all Tier 3 JSON data packs in game/data/ for structure, ranges, and cross-references."""

import json
import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "game" / "data"

REQUIRED_FILES = [
    "world.json",
    "player.json",
    "items.json",
    "affixes.json",
    "rarities.json",
    "themes.json",
    "abilities.json",
    "enemies.json",
    "dungeon_ai.json",
    "progression.json",
    "tutorials.json",
    "setpieces.json",
]


def load_json(path: pathlib.Path) -> dict:
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, dict):
        raise ValueError(f"{path.name} root must be a JSON object")
    return data


def main() -> int:
    errors: list[str] = []
    packs: dict[str, dict] = {}

    for fname in REQUIRED_FILES:
        fpath = DATA_DIR / fname
        if not fpath.exists():
            errors.append(f"Missing required data pack: {fpath}")
            continue
        try:
            packs[fname] = load_json(fpath)
        except Exception as exc:
            errors.append(f"Failed to parse {fname}: {exc}")

    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        return 1

    # 1. Validate world.json
    world = packs["world.json"]
    if world["grid"]["tile_size_meters"] <= 0:
        errors.append("world.json: tile_size_meters must be > 0")
    if world["floor_timer"]["days_per_floor"] != 5:
        errors.append("world.json: D-006 requires days_per_floor == 5")
    if world["floor_timer"]["real_seconds_per_in_game_day"] <= 0:
        errors.append("world.json: real_seconds_per_in_game_day must be > 0")
    if world["stairs"]["show_next_floor_preview"] is not False:
        errors.append("world.json: D-008 requires show_next_floor_preview == false")
    if len(world.get("floors", [])) < 2:
        errors.append("world.json: must define at least 2 floors (Floor 1 + Floor 2 descent)")

    # 2. Validate items.json & affixes.json cross-references
    items_pack = packs["items.json"]
    affixes_pack = packs["affixes.json"]
    valid_slots = set(items_pack.get("slots", [])) | {"consumable"}
    sponsored_ids = {e["id"] for e in affixes_pack.get("sponsored_effects", [])}
    rarity_ids = {r["id"] for r in affixes_pack.get("rarities", [])}

    item_ids: set[str] = set()
    for item in items_pack.get("items", []):
        iid = item.get("id", "")
        if not iid or iid in item_ids:
            errors.append(f"items.json: missing or duplicate item id '{iid}'")
        item_ids.add(iid)
        if item.get("slot") not in valid_slots:
            errors.append(f"items.json: item '{iid}' has invalid slot '{item.get('slot')}'")
        if "sponsored_effect" in item and item["sponsored_effect"] not in sponsored_ids:
            errors.append(f"items.json: item '{iid}' references unknown sponsored_effect '{item['sponsored_effect']}'")
        if "forced_rarity" in item and item["forced_rarity"] not in rarity_ids:
            errors.append(f"items.json: item '{iid}' references unknown forced_rarity '{item['forced_rarity']}'")

    # 3. Validate player.json starting gear & inventory exist in items.json
    player = packs["player.json"]
    if player["camera"]["default_mode"] != "first_person":
        errors.append("player.json: D-012 requires default_mode == 'first_person'")
    for slot, iid in player.get("starting_equipment", {}).items():
        if slot not in valid_slots:
            errors.append(f"player.json: invalid starting_equipment slot '{slot}'")
        if iid not in item_ids:
            errors.append(f"player.json: starting_equipment '{iid}' not found in items.json")
    for iid in player.get("starting_inventory", []):
        if iid not in item_ids:
            errors.append(f"player.json: starting_inventory '{iid}' not found in items.json")

    # 4. Validate enemies.json and floor boss references
    enemies_pack = packs["enemies.json"]
    enemy_ids: set[str] = set()
    boss_ids: set[str] = set()
    regular_count = 0
    for enemy in enemies_pack.get("enemies", []):
        eid = enemy.get("id", "")
        if not eid or eid in enemy_ids:
            errors.append(f"enemies.json: missing or duplicate enemy id '{eid}'")
        enemy_ids.add(eid)
        if enemy.get("is_boss"):
            boss_ids.add(eid)
        else:
            regular_count += 1
        if enemy.get("max_health", 0) <= 0 or enemy.get("damage", 0) <= 0:
            errors.append(f"enemies.json: enemy '{eid}' must have positive max_health and damage")
        if "guaranteed_rarity" in enemy and enemy["guaranteed_rarity"] not in rarity_ids:
            errors.append(f"enemies.json: enemy '{eid}' references unknown rarity '{enemy['guaranteed_rarity']}'")

    if regular_count < 2:
        errors.append("enemies.json: D-027 requires at least 2-3 regular enemy types")
    if not boss_ids:
        errors.append("enemies.json: must define at least 1 floor boss")

    for floor in world.get("floors", []):
        bid = floor.get("boss_id")
        if bid not in boss_ids:
            errors.append(f"world.json: floor {floor.get('floor_number')} boss_id '{bid}' not in boss definitions")

    # 5. Validate dungeon_ai.json required events
    ai_events = packs["dungeon_ai.json"].get("events", {})
    for req_event in [
        "floor_enter",
        "safe_room_discovered",
        "boss_arena_sealed",
        "boss_defeated",
        "sponsored_loot",
        "floor_collapse",
        "player_death",
        "level_up",
        "time_warning",
    ]:
        if not ai_events.get(req_event):
            errors.append(f"dungeon_ai.json: missing non-empty event list '{req_event}'")

    # 6. Validate progression.json
    prog = packs["progression.json"]
    skills = prog.get("proficiencies", {}).get("skills", [])
    xp_per_use = prog.get("proficiencies", {}).get("xp_gain_per_use", {})
    for skill in skills:
        if skill not in xp_per_use or xp_per_use[skill] <= 0:
            errors.append(f"progression.json: skill '{skill}' missing positive xp_gain_per_use")

    # 7. Validate tutorials.json (D-030)
    tut_topics = packs["tutorials.json"].get("topics", [])
    if len(tut_topics) < 6:
        errors.append("tutorials.json: D-030 requires at least 6 contextual tutorial topics")
    tut_ids: set[str] = set()
    for t in tut_topics:
        tid = t.get("id", "")
        if not tid or tid in tut_ids:
            errors.append(f"tutorials.json: missing or duplicate topic id '{tid}'")
        tut_ids.add(tid)
        if not t.get("title") or not t.get("body"):
            errors.append(f"tutorials.json: topic '{tid}' requires title and body")

    # 8. Validate setpieces.json (D-029)
    setpieces = packs["setpieces.json"].get("setpieces", {})
    for req_sp in ["entrance", "safe_room", "boss_arena", "vault", "stairs"]:
        if req_sp not in setpieces or not setpieces[req_sp].get("props"):
            errors.append(f"setpieces.json: D-029 requires handcrafted setpiece props for '{req_sp}'")

    # 9. Validate rarities.json, themes.json, and abilities.json (D-055)
    rarities_pack = packs["rarities.json"]
    unified_r_ids = {r.get("id", "") for r in rarities_pack.get("rarities", [])}
    for req_r in ["common", "uncommon", "rare", "epic", "legendary"]:
        if req_r not in unified_r_ids:
            errors.append(f"rarities.json: missing required rarity tier '{req_r}'")

    themes_pack = packs["themes.json"]
    theme_ids = {t.get("id", "") for t in themes_pack.get("themes", [])}
    if not theme_ids:
        errors.append("themes.json: must define at least 1 floor theme")
    for floor in world.get("floors", []):
        tid = floor.get("theme_id", "")
        if tid and tid not in theme_ids:
            errors.append(f"world.json: floor {floor.get('floor_number')} theme_id '{tid}' not found in themes.json")

    abilities_pack = packs["abilities.json"]
    ability_ids: set[str] = set()
    for ab in abilities_pack.get("abilities", []):
        aid = ab.get("id", "")
        if not aid or aid in ability_ids:
            errors.append(f"abilities.json: missing or duplicate ability id '{aid}'")
        ability_ids.add(aid)
        if not ab.get("kind"):
            errors.append(f"abilities.json: ability '{aid}' missing 'kind'")

    if errors:
        for e in errors:
            print(f"[ERROR] {e}", file=sys.stderr)
        return 1

    print(
        f"[validate-data] OK: {len(REQUIRED_FILES)} packs, "
        f"{len(item_ids)} items, {len(enemy_ids)} enemies ({len(boss_ids)} boss), "
        f"{len(unified_r_ids)} rarities, {len(theme_ids)} themes, {len(ability_ids)} abilities, "
        f"{len(ai_events)} Dungeon AI pools, "
        f"{len(tut_ids)} tutorial topics, {len(setpieces)} handcrafted setpieces."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
