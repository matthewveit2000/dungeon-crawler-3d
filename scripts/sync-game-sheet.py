#!/usr/bin/env python3
"""
Dungeon Crawler 3D — Live Google Sheet Maintainer (D-061 / FB-026)

Source of truth: game/data/*.json
Maintains a comprehensive 13-tab Google Sheet with a `Change Request` column on
every data tab, a `General Requests` table on `Overview & Requests`, and an
append-only `Completed Log` tab.

Modes:
  --dry-run            Build all 13 tabs offline and print row/column counts (no API calls).
  --create             Create a brand-new Google Sheet, save its ID to docs/GAME_SHEET.json,
                       and populate + format all 13 tabs.
  --push               Sync game/data/*.json to the configured Sheet while PRESERVING
                       all unread `Change Request` cells (matched by stable Row ID) and
                       all `Completed Log` history.
  --pull-requests      Read every tab and print all non-empty `Change Request` cells.
  --complete TAB ID    Clear a specific `Change Request` cell and append a receipt to
                       `Completed Log` (requires --resolution and optional --commit).
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = REPO_ROOT / "game" / "data"
CONFIG_PATH = REPO_ROOT / "docs" / "GAME_SHEET.json"

SHEET_TITLE = "Dungeon Crawler 3D — Live Game Data & Change Requests"
RARITY_ORDER = ["common", "uncommon", "rare", "epic", "legendary"]
RARITY_BG_HEX = {
    "common": "#eef1f5",
    "uncommon": "#dcfce7",
    "rare": "#dbeafe",
    "epic": "#f3e8ff",
    "legendary": "#fef3c7",
}

TAB_ORDER = [
    "Overview & Requests",
    "Weapons & Shields",
    "Spells",
    "Armor & Accessories",
    "Consumables & Ingredients",
    "Item Mastery Tracks",
    "Enemies & Bosses",
    "Rooms, Chests & Props",
    "Rarities & Loot Odds",
    "Player & Progression",
    "Balance & Knobs",
    "World & Floors",
    "Completed Log",
]

COMPLETED_LOG_HEADERS = ["Date (UTC)", "Tab", "Row ID", "Request", "Resolution", "Commit SHA"]


def load_json(name: str) -> dict[str, Any]:
    with (DATA_DIR / name).open("r", encoding="utf-8") as f:
        return json.load(f)


def load_all_packs() -> dict[str, dict[str, Any]]:
    packs: dict[str, dict[str, Any]] = {}
    for p in sorted(DATA_DIR.glob("*.json")):
        with p.open("r", encoding="utf-8") as f:
            packs[p.stem] = json.load(f)
    return packs


def fmt_num(val: Any) -> Any:
    if val is None or val == "":
        return ""
    if isinstance(val, bool):
        return "Yes" if val else "No"
    if isinstance(val, float):
        if val.is_integer():
            return int(val)
        return round(val, 4)
    return val


def fmt_pct(val: Any) -> str:
    if val is None or val == "":
        return ""
    return f"{round(float(val) * 100.0, 1):g}%"


def rarity_rank(r: str) -> int:
    try:
        return RARITY_ORDER.index(str(r).lower())
    except ValueError:
        return 99


def rarity_caps(rarities_pack: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {str(r["id"]): r for r in rarities_pack.get("rarities", [])}


def summarize_mastery_track(item: dict[str, Any], mastery_abilities: dict[str, Any]) -> str:
    entries = item.get("mastery", [])
    if not entries:
        return ""
    parts = []
    for e in entries:
        ab_id = str(e.get("ability", ""))
        ab_name = str(mastery_abilities.get(ab_id, {}).get("name", ab_id))
        parts.append(f"Lv{e.get('level', '?')} {ab_name}")
    return "; ".join(parts)


def summarize_traits(traits: list[dict[str, Any]]) -> str:
    if not traits:
        return ""
    out = []
    for t in traits:
        tid = str(t.get("id", ""))
        extras = [f"{k}={v}" for k, v in t.items() if k != "id"]
        out.append(f"{tid} ({', '.join(extras)})" if extras else tid)
    return "; ".join(out)


def compute_rarity_shares(rarities_pack: dict[str, Any], floor_num: int) -> dict[str, float]:
    weights: dict[str, float] = {}
    total = 0.0
    for r in rarities_pack.get("rarities", []):
        rid = str(r["id"])
        w = float(r.get("weight", 1.0)) * (1.0 + float(r.get("floor_weight_growth", 0.0)) * max(0, floor_num - 1))
        weights[rid] = w
        total += w
    return {rid: (w / total * 100.0 if total > 0 else 0.0) for rid, w in weights.items()}


def build_all_tabs(
    packs: dict[str, dict[str, Any]],
    existing_requests: dict[str, dict[str, str]] | None = None,
    existing_general: list[list[str]] | None = None,
    existing_completed_log: list[list[str]] | None = None,
    synced_utc: str | None = None,
) -> dict[str, list[list[Any]]]:
    """Build all 13 tab matrices from game/data/*.json, merging preserved Change Request cells."""
    existing_requests = existing_requests or {}
    synced_utc = synced_utc or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    items_pack = packs["items"]
    enemies_pack = packs["enemies"]
    rarities_pack = packs["rarities"]
    themes_pack = packs["themes"]
    balance_pack = packs["balance"]
    player_pack = packs["player"]
    prog_pack = packs["progression"]
    mastery_pack = packs["mastery"]
    world_pack = packs["world"]
    setpieces_pack = packs.get("setpieces", {})

    r_caps = rarity_caps(rarities_pack)
    mastery_abs = mastery_pack.get("abilities", {})
    leg_effects = items_pack.get("legendary_effects", {})
    all_items: list[dict[str, Any]] = items_pack.get("items", [])

    def req_for(tab: str, row_id: str) -> str:
        return existing_requests.get(tab, {}).get(str(row_id), "")

    tabs: dict[str, list[list[Any]]] = {}

    # --- 1. Weapons & Shields ---
    w_tab = "Weapons & Shields"
    w_rows: list[list[Any]] = [[
        "ID", "Name", "Rarity", "Category", "Slot", "Style",
        "Damage", "Armor", "Block %", "Attack Speed", "Stamina Cost", "Range",
        "Base Value (g)", "Power Scale", "Mastery Cap Lv", "Mastery Track",
        "Legendary Effect", "Description", "Change Request",
    ]]
    weapons = [it for it in all_items if it.get("category") in ("weapon", "shield")]
    weapons.sort(key=lambda x: (rarity_rank(x.get("rarity", "common")), str(x.get("category", "")), str(x.get("name", ""))))
    for it in weapons:
        rid = str(it.get("rarity", "common"))
        leg_id = str(it.get("legendary_effect", ""))
        leg_txt = f"{leg_effects[leg_id].get('name', leg_id)}: {leg_effects[leg_id].get('description', '')}" if leg_id in leg_effects else leg_id
        w_rows.append([
            it["id"], it.get("name", ""), rid, it.get("category", ""), it.get("slot", ""),
            it.get("weapon_style", it.get("subtype", "")),
            fmt_num(it.get("damage", "")), fmt_num(it.get("armor", "")),
            fmt_pct(it["block_reduction"]) if "block_reduction" in it else "",
            fmt_num(it.get("attack_speed", "")), fmt_num(it.get("stamina_cost", "")),
            fmt_num(it.get("range", "")), fmt_num(it.get("base_value", "")),
            fmt_num(it.get("power_scale", 1.0)),
            r_caps.get(rid, {}).get("mastery_max_level", ""),
            summarize_mastery_track(it, mastery_abs),
            leg_txt, it.get("description", ""), req_for(w_tab, it["id"]),
        ])
    tabs[w_tab] = w_rows

    # --- 2. Spells ---
    s_tab = "Spells"
    s_rows: list[list[Any]] = [[
        "ID", "Name", "Rarity", "Slot", "School", "Spell Kind",
        "Damage", "Heal", "Magicka Cost", "Cast Time", "Cooldown", "Projectile Speed",
        "Base Value (g)", "Power Scale", "Mastery Cap Lv", "Mastery Track",
        "Description", "Change Request",
    ]]
    spells = [it for it in all_items if it.get("category") == "spell"]
    spells.sort(key=lambda x: (rarity_rank(x.get("rarity", "common")), str(x.get("name", ""))))
    for it in spells:
        rid = str(it.get("rarity", "common"))
        s_rows.append([
            it["id"], it.get("name", ""), rid, it.get("slot", ""),
            it.get("school", ""), it.get("spell_kind", ""),
            fmt_num(it.get("damage", "")), fmt_num(it.get("heal_amount", it.get("heal_health", ""))),
            fmt_num(it.get("magicka_cost", "")), fmt_num(it.get("cast_time", "")),
            fmt_num(it.get("cooldown", "")), fmt_num(it.get("projectile_speed", "")),
            fmt_num(it.get("base_value", "")), fmt_num(it.get("power_scale", 1.0)),
            r_caps.get(rid, {}).get("mastery_max_level", ""),
            summarize_mastery_track(it, mastery_abs),
            it.get("description", ""), req_for(s_tab, it["id"]),
        ])
    tabs[s_tab] = s_rows

    # --- 3. Armor & Accessories ---
    a_tab = "Armor & Accessories"
    a_rows: list[list[Any]] = [[
        "ID", "Name", "Rarity", "Category", "Slot", "Armor",
        "Bonus Health", "Bonus Magicka", "Bonus Stamina", "Bonus Damage", "Bonus Crit %",
        "Base Value (g)", "Power Scale", "Mastery Cap Lv", "Mastery Track",
        "Legendary Effect", "Description", "Change Request",
    ]]
    armors = [it for it in all_items if it.get("category") in ("armor", "accessory")]
    armors.sort(key=lambda x: (rarity_rank(x.get("rarity", "common")), str(x.get("slot", "")), str(x.get("name", ""))))
    for it in armors:
        rid = str(it.get("rarity", "common"))
        leg_id = str(it.get("legendary_effect", ""))
        leg_txt = f"{leg_effects[leg_id].get('name', leg_id)}: {leg_effects[leg_id].get('description', '')}" if leg_id in leg_effects else leg_id
        a_rows.append([
            it["id"], it.get("name", ""), rid, it.get("category", ""), it.get("slot", ""),
            fmt_num(it.get("armor", "")), fmt_num(it.get("bonus_health", "")),
            fmt_num(it.get("bonus_magicka", "")), fmt_num(it.get("bonus_stamina", "")),
            fmt_num(it.get("bonus_damage", "")),
            fmt_pct(it["bonus_crit_chance"]) if "bonus_crit_chance" in it else "",
            fmt_num(it.get("base_value", "")), fmt_num(it.get("power_scale", 1.0)),
            r_caps.get(rid, {}).get("mastery_max_level", ""),
            summarize_mastery_track(it, mastery_abs),
            leg_txt, it.get("description", ""), req_for(a_tab, it["id"]),
        ])
    tabs[a_tab] = a_rows

    # --- 4. Consumables & Ingredients ---
    c_tab = "Consumables & Ingredients"
    c_rows: list[list[Any]] = [[
        "ID", "Name", "Rarity", "Category", "Heal Health", "Restore Magicka",
        "Restore Stamina", "Buff / Effect", "Base Value (g)", "Power Scale",
        "Description", "Change Request",
    ]]
    consumables = [it for it in all_items if it.get("category") in ("consumable", "ingredient")]
    consumables.sort(key=lambda x: (str(x.get("category", "")), rarity_rank(x.get("rarity", "common")), str(x.get("name", ""))))
    for it in consumables:
        buffs = []
        for k in ("buff_speed", "buff_armor", "buff_damage", "buff_duration", "duration"):
            if k in it:
                buffs.append(f"{k}={it[k]}")
        c_rows.append([
            it["id"], it.get("name", ""), str(it.get("rarity", "common")), it.get("category", ""),
            fmt_num(it.get("heal_health", "")), fmt_num(it.get("restore_magicka", "")),
            fmt_num(it.get("restore_stamina", "")), ", ".join(buffs),
            fmt_num(it.get("base_value", "")), fmt_num(it.get("power_scale", 1.0)),
            it.get("description", ""), req_for(c_tab, it["id"]),
        ])
    tabs[c_tab] = c_rows

    # --- 5. Item Mastery Tracks ---
    m_tab = "Item Mastery Tracks"
    m_rows: list[list[Any]] = [[
        "Row Key", "Item ID", "Item Name", "Item Rarity", "Cap Lv",
        "Unlock Lv", "Ability ID", "Ability Name", "Parameters", "Ability Description",
        "Change Request",
    ]]
    masterable = [it for it in all_items if it.get("mastery")]
    masterable.sort(key=lambda x: (rarity_rank(x.get("rarity", "common")), str(x.get("category", "")), str(x.get("name", ""))))
    for it in masterable:
        rid = str(it.get("rarity", "common"))
        cap_lv = r_caps.get(rid, {}).get("mastery_max_level", 10)
        for entry in it.get("mastery", []):
            lv = entry.get("level", "")
            ab_id = str(entry.get("ability", ""))
            ab_def = mastery_abs.get(ab_id, {})
            params = ", ".join(f"{k}={v}" for k, v in entry.items() if k not in ("level", "ability"))
            rkey = f"{it['id']}@Lv{lv}"
            m_rows.append([
                rkey, it["id"], it.get("name", ""), rid, cap_lv,
                lv, ab_id, ab_def.get("name", ab_id), params, ab_def.get("description", ""),
                req_for(m_tab, rkey),
            ])
    tabs[m_tab] = m_rows

    # --- 6. Enemies & Bosses ---
    e_tab = "Enemies & Bosses"
    e_rows: list[list[Any]] = [[
        "ID", "Name", "Rarity", "Role", "Archetype", "Level Range",
        "Max HP", "Damage", "Armor", "Move Speed", "Aggro Radius", "Attack Range",
        "Attack CD", "XP", "Gold", "Loot Drop %", "Power Scale",
        "Traits", "Weakness", "Lore", "Change Request",
    ]]
    enemies = list(enemies_pack.get("enemies", []))
    enemies.sort(key=lambda x: (1 if x.get("is_boss") else 0, rarity_rank(x.get("rarity", "common")), int(x.get("level_min", 1))))
    for e in enemies:
        role = "Floor Boss" if e.get("is_boss") else "Regular"
        gold_rng = f"{e.get('gold_min', 0)}-{e.get('gold_max', 0)}"
        lvl_rng = f"{e.get('level_min', 1)}-{e.get('level_max', 1)}"
        e_rows.append([
            e["id"], e.get("name", ""), str(e.get("rarity", "common")), role, e.get("archetype", ""),
            lvl_rng, fmt_num(e.get("max_health", "")), fmt_num(e.get("damage", "")),
            fmt_num(e.get("armor", "")), fmt_num(e.get("move_speed", "")),
            fmt_num(e.get("aggro_radius", "")), fmt_num(e.get("attack_range", "")),
            fmt_num(e.get("attack_cooldown_sec", "")), fmt_num(e.get("xp_reward", "")),
            gold_rng, fmt_pct(e.get("loot_drop_chance", 0)), fmt_num(e.get("power_scale", 1.0)),
            summarize_traits(e.get("traits", [])), e.get("weakness", ""), e.get("lore", ""),
            req_for(e_tab, e["id"]),
        ])
    tabs[e_tab] = e_rows

    # --- 7. Rooms, Chests & Props ---
    r_tab = "Rooms, Chests & Props"
    r_rows: list[list[Any]] = [[
        "Row Key", "Theme", "Pool", "ID", "Name / Label", "Rarity", "Details", "Change Request",
    ]]
    pool_order = [
        "room_variants", "chest_tiers", "trap_types", "container_types",
        "dressing_props", "wall_variants", "floor_variants", "ceiling_variants",
    ]
    for theme in themes_pack.get("themes", []):
        tid = str(theme["id"])
        for pool in pool_order:
            for entry in theme.get(pool, []):
                eid = str(entry.get("id", ""))
                rkey = f"{tid}:{pool}:{eid}"
                label = str(entry.get("name", entry.get("label", eid)))
                extras = []
                for k, v in entry.items():
                    if k in ("id", "name", "label", "rarity"):
                        continue
                    extras.append(f"{k}={v}")
                r_rows.append([
                    rkey, tid, pool, eid, label, str(entry.get("rarity", "common")),
                    "; ".join(extras), req_for(r_tab, rkey),
                ])
    raw_setpieces = setpieces_pack.get("setpieces", {})
    sp_items = (
        [(k, v) for k, v in raw_setpieces.items()]
        if isinstance(raw_setpieces, dict)
        else [(str(v.get("id", "")), v) for v in raw_setpieces]
    )
    for sid, sp in sp_items:
        rkey = f"setpiece:{sid}"
        r_rows.append([
            rkey, "all", "handcrafted_setpiece", sid, sp.get("name", sid),
            str(sp.get("rarity", "rare")),
            f"role={sp.get('role', '')}; theme={sp.get('theme', '')}; props={len(sp.get('props', []))}",
            req_for(r_tab, rkey),
        ])
    tabs[r_tab] = r_rows

    # --- 8. Rarities & Loot Odds ---
    rar_tab = "Rarities & Loot Odds"
    f1 = compute_rarity_shares(rarities_pack, 1)
    f3 = compute_rarity_shares(rarities_pack, 3)
    f5 = compute_rarity_shares(rarities_pack, 5)
    rar_rows: list[list[Any]] = [[
        "Row Key", "Type", "Label", "Color", "Base Weight", "Floor Growth",
        "Floor 1 %", "Floor 3 %", "Floor 5 %", "Mastery Cap Lv", "Max Abilities",
        "Value Mult / Boost", "Enemy Reward Mult / Min Rarity", "Change Request",
    ]]
    for r in rarities_pack.get("rarities", []):
        rid = str(r["id"])
        rar_rows.append([
            f"tier:{rid}", "Rarity Tier", r.get("label", rid), r.get("color", ""),
            fmt_num(r.get("weight", "")), fmt_num(r.get("floor_weight_growth", 0)),
            f"{f1.get(rid, 0):.1f}%", f"{f3.get(rid, 0):.1f}%", f"{f5.get(rid, 0):.1f}%",
            r.get("mastery_max_level", ""), r.get("max_abilities", ""),
            fmt_num(r.get("value_multiplier", 1.0)), fmt_num(r.get("enemy_reward_mult", 1.0)),
            req_for(rar_tab, f"tier:{rid}"),
        ])
    for prof_id, prof in (rarities_pack.get("source_profiles", {}) or {}).items():
        rkey = f"source:{prof_id}"
        rar_rows.append([
            rkey, "Source Profile", prof_id, "", "", "", "", "", "", "", "",
            f"boost={prof.get('rarity_boost', 1.0)}",
            f"min_rarity={prof.get('min_rarity', 'common')}",
            req_for(rar_tab, rkey),
        ])
    tabs[rar_tab] = rar_rows

    # --- 9. Player & Progression ---
    p_tab = "Player & Progression"
    p_rows: list[list[Any]] = [["Row Key", "Section", "Setting / Perk", "Value", "Details", "Change Request"]]
    for sec in ("stats", "movement", "camera", "interaction", "combat"):
        for k, v in (player_pack.get(sec, {}) or {}).items():
            rkey = f"player.{sec}.{k}"
            p_rows.append([rkey, f"Player — {sec}", k, str(v), "", req_for(p_tab, rkey)])
    p_rows.append(["player.starting_gold", "Player — starting", "starting_gold", player_pack.get("starting_gold", 0), "", req_for(p_tab, "player.starting_gold")])
    p_rows.append(["player.starting_equipment", "Player — starting", "starting_equipment", json.dumps(player_pack.get("starting_equipment", {})), "", req_for(p_tab, "player.starting_equipment")])
    p_rows.append(["player.starting_inventory", "Player — starting", "starting_inventory", ", ".join(str(x) for x in player_pack.get("starting_inventory", [])), "", req_for(p_tab, "player.starting_inventory")])
    for sec in ("xp_curve", "level_up_rewards"):
        for k, v in (prog_pack.get(sec, {}) or {}).items():
            rkey = f"progression.{sec}.{k}"
            p_rows.append([rkey, f"Progression — {sec}", k, fmt_num(v), "", req_for(p_tab, rkey)])
    for k, v in (prog_pack.get("proficiencies", {}) or {}).items():
        rkey = f"progression.proficiencies.{k}"
        val_str = json.dumps(v) if isinstance(v, (dict, list)) else fmt_num(v)
        p_rows.append([rkey, "Progression — proficiencies", k, val_str, "", req_for(p_tab, rkey)])
    for perk in prog_pack.get("perks", []):
        rkey = f"perk:{perk['id']}"
        bonuses = ", ".join(f"{k}={v}" for k, v in perk.items() if k not in ("id", "name", "branch", "description"))
        p_rows.append([rkey, f"Perk ({perk.get('branch', '')})", perk.get("name", perk["id"]), bonuses, perk.get("description", ""), req_for(p_tab, rkey)])
    tabs[p_tab] = p_rows

    # --- 10. Balance & Knobs ---
    b_tab = "Balance & Knobs"
    b_rows: list[list[Any]] = [["Row Key", "Section", "Knob", "Value", "Notes", "Change Request"]]
    for k, v in (balance_pack.get("global", {}) or {}).items():
        rkey = f"global.{k}"
        b_rows.append([rkey, "Global Multiplier", k, fmt_num(v), "1.0 = tuned default", req_for(b_tab, rkey)])
    for k, v in (balance_pack.get("champions", {}) or {}).items():
        if k == "_doc":
            continue
        rkey = f"champions.{k}"
        val_str = ", ".join(str(x) for x in v) if isinstance(v, list) else fmt_num(v)
        b_rows.append([rkey, "Champion Lairs", k, val_str, "", req_for(b_tab, rkey)])
    for k, v in (balance_pack.get("vendor", {}) or {}).items():
        rkey = f"vendor.{k}"
        val_str = ", ".join(str(x) for x in v) if isinstance(v, list) else fmt_num(v)
        b_rows.append([rkey, "Vendor Economy", k, val_str, "", req_for(b_tab, rkey)])
    for sec in ("level_scaling", "floor_level_band", "floor_scaling"):
        for k, v in (enemies_pack.get(sec, {}) or {}).items():
            rkey = f"enemies.{sec}.{k}"
            b_rows.append([rkey, f"Enemy Scaling — {sec}", k, fmt_num(v), "", req_for(b_tab, rkey)])
    for k in ("max_level", "xp_base", "xp_growth", "stat_growth_per_level"):
        if k in mastery_pack:
            rkey = f"mastery.{k}"
            b_rows.append([rkey, "Item Mastery Curve", k, fmt_num(mastery_pack[k]), "", req_for(b_tab, rkey)])
    tabs[b_tab] = b_rows

    # --- 11. World & Floors ---
    wf_tab = "World & Floors"
    wf_rows: list[list[Any]] = [["Row Key", "Section", "Setting / Floor", "Value", "Details", "Change Request"]]
    for sec in ("grid", "labyrinth", "floor_timer", "compass", "stairs", "safe_room_map"):
        for k, v in (world_pack.get(sec, {}) or {}).items():
            rkey = f"world.{sec}.{k}"
            wf_rows.append([rkey, f"World — {sec}", k, str(v), "", req_for(wf_tab, rkey)])
    for fl in world_pack.get("floors", []):
        fnum = fl.get("floor_number", "?")
        rkey = f"floor:{fnum}"
        details = (
            f"theme={fl.get('theme_id', '')}; boss={fl.get('boss_id', '')}; "
            f"enemy_budget={fl.get('enemy_budget', '')}; power_scale={fl.get('power_scale', 1.0)}; "
            f"ambient={fl.get('ambient_color', '')}; fog={fl.get('fog_color', '')}"
        )
        wf_rows.append([rkey, "Floor Definition", f"Floor {fnum} — {fl.get('name', '')}", fl.get("theme_id", ""), details, req_for(wf_tab, rkey)])
    tabs[wf_tab] = wf_rows

    # --- 12. Overview & Requests ---
    ov_tab = "Overview & Requests"
    rarity_counts = {r: 0 for r in RARITY_ORDER}
    for it in all_items:
        rarity_counts[str(it.get("rarity", "common"))] = rarity_counts.get(str(it.get("rarity", "common")), 0) + 1
    ov_rows: list[list[Any]] = [
        ["Dungeon Crawler 3D — Live Game Data & Change Requests", "", "", "", ""],
        ["Last Synced (UTC)", synced_utc, "Source of Truth", "game/data/*.json (auto-synced via scripts/sync-game-sheet.py)", ""],
        ["How to Request Changes", "Write in any row's yellow `Change Request` column (or in General Requests below). Tell Antigravity to implement sheet requests; implemented cells are cleared & logged in Completed Log.", "", "", ""],
        ["", "", "", "", ""],
        ["Metric", "Count / Value", "Breakdown", "", ""],
        ["Total Items", len(all_items), f"Weapons/Shields: {len(weapons)} | Spells: {len(spells)} | Armor/Acc: {len(armors)} | Cons/Ingr: {len(consumables)}", "", ""],
        ["Items by Rarity", len(all_items), " | ".join(f"{r.title()}: {rarity_counts.get(r, 0)}" for r in RARITY_ORDER), "", ""],
        ["Total Enemies", len(enemies), f"Regular: {sum(1 for e in enemies if not e.get('is_boss'))} | Floor Bosses: {sum(1 for e in enemies if e.get('is_boss'))}", "", ""],
        ["Mastery Abilities", len(mastery_abs), f"Item Mastery Entries: {len(m_rows) - 1}", "", ""],
        ["Themes & Floors", f"{len(themes_pack.get('themes', []))} themes / {len(world_pack.get('floors', []))} floors", ", ".join(t["id"] for t in themes_pack.get("themes", [])), "", ""],
        ["", "", "", "", ""],
        ["Request ID", "Area / System", "Priority", "Change Request", "Notes"],
    ]
    gen_map: dict[str, list[str]] = {}
    for row in (existing_general or []):
        if row and str(row[0]).startswith("GEN-"):
            padded = (list(row) + ["", "", "", "", ""])[:5]
            gen_map[str(padded[0])] = padded
    for i in range(1, 21):
        gid = f"GEN-{i:02d}"
        if gid in gen_map:
            ov_rows.append(gen_map[gid])
        else:
            ov_rows.append([gid, "", "", req_for(ov_tab, gid), ""])
    tabs[ov_tab] = ov_rows

    # --- 13. Completed Log ---
    log_rows: list[list[Any]] = [COMPLETED_LOG_HEADERS]
    for row in (existing_completed_log or []):
        if row and row != COMPLETED_LOG_HEADERS and any(str(c).strip() for c in row):
            log_rows.append((list(row) + ["", "", "", "", "", ""])[:6])
    tabs["Completed Log"] = log_rows

    return {t: tabs[t] for t in TAB_ORDER}


def extract_change_requests_from_rows(tab_name: str, rows: list[list[Any]]) -> dict[str, str]:
    """Extract {row_id: request_text} from a 2D sheet grid by locating the `Change Request` header."""
    if not rows:
        return {}
    header_idx = -1
    req_col = -1
    for i, r in enumerate(rows):
        for j, cell in enumerate(r):
            if str(cell).strip() == "Change Request":
                header_idx = i
                req_col = j
                break
        if header_idx >= 0:
            break
    if header_idx < 0 or req_col < 0:
        return {}
    out: dict[str, str] = {}
    for r in rows[header_idx + 1 :]:
        if not r:
            continue
        row_id = str(r[0]).strip()
        if not row_id:
            continue
        val = str(r[req_col]).strip() if req_col < len(r) else ""
        if val:
            out[row_id] = val
    return out


def extract_general_rows(rows: list[list[Any]]) -> list[list[str]]:
    out: list[list[str]] = []
    for r in rows:
        if r and str(r[0]).strip().startswith("GEN-"):
            padded = [str(c) for c in (list(r) + ["", "", "", "", ""])[:5]]
            if any(c.strip() for c in padded[1:]):
                out.append(padded)
    return out


def col_letter(n_zero_based: int) -> str:
    n = n_zero_based + 1
    res = ""
    while n > 0:
        n, rem = divmod(n - 1, 26)
        res = chr(65 + rem) + res
    return res


def hex_to_rgb(h: str) -> dict[str, float]:
    h = h.lstrip("#")
    return {
        "red": int(h[0:2], 16) / 255.0,
        "green": int(h[2:4], 16) / 255.0,
        "blue": int(h[4:6], 16) / 255.0,
    }


def run_gsheets(args: list[str], expect_json: bool = False) -> Any:
    cmd = ["gsheets"] + args + (["--json"] if expect_json else [])
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"gsheets failed ({proc.returncode}): {' '.join(cmd)}\n{proc.stderr or proc.stdout}")
    if expect_json:
        out = proc.stdout.strip()
        return json.loads(out) if out else None
    return proc.stdout.strip()


def read_tab_values(sheet_id: str, tab_name: str) -> list[list[str]]:
    rng = f"'{tab_name}'!A1:Z500"
    try:
        data = run_gsheets(["readonly", "read", sheet_id, rng], expect_json=True)
    except RuntimeError:
        return []
    if isinstance(data, dict):
        return data.get("values", data.get("rows", data.get("data", []))) or []
    if isinstance(data, list):
        return data
    return []


def get_sheet_ids(sheet_id: str) -> dict[str, int]:
    info = run_gsheets(["readonly", "list-sheets", sheet_id], expect_json=True)
    mapping: dict[str, int] = {}
    sheets = info if isinstance(info, list) else info.get("sheets", info.get("tabs", []))
    for s in sheets:
        if isinstance(s, dict):
            props = s.get("properties", s)
            title = props.get("title") or props.get("name")
            sid = props.get("sheetId", props.get("sheet_id", props.get("id")))
            if title is not None and sid is not None:
                mapping[str(title)] = int(sid)
    return mapping


def ensure_tabs(sheet_id: str) -> dict[str, int]:
    mapping = get_sheet_ids(sheet_id)
    # Rename default Sheet1 to Overview & Requests if needed
    if "Overview & Requests" not in mapping and "Sheet1" in mapping:
        run_gsheets(["mutate", "rename-sheet", sheet_id, "--sheet-id", str(mapping["Sheet1"]), "--title", "Overview & Requests"])
        mapping = get_sheet_ids(sheet_id)
    for tab in TAB_ORDER:
        if tab not in mapping:
            run_gsheets(["mutate", "add-sheet", sheet_id, "--title", tab])
    return get_sheet_ids(sheet_id)


def build_formatting_requests(tabs: dict[str, list[list[Any]]], sheet_ids: dict[str, int]) -> list[dict[str, Any]]:
    reqs: list[dict[str, Any]] = []
    header_bg = hex_to_rgb("#1f2937")
    header_fg = hex_to_rgb("#f9fafb")
    req_bg = hex_to_rgb("#fef9c3")
    req_header_bg = hex_to_rgb("#854d0e")

    for tab_name in TAB_ORDER:
        sid = sheet_ids.get(tab_name)
        rows = tabs.get(tab_name, [])
        if sid is None or not rows:
            continue
        ncols = max(len(r) for r in rows)
        nrows = len(rows)

        # Locate header row and special columns
        header_row = 0
        req_col = -1
        rarity_col = -1
        for i, r in enumerate(rows):
            if any(str(c) == "Change Request" for c in r):
                header_row = i
                for j, c in enumerate(r):
                    if str(c) == "Change Request":
                        req_col = j
                    if str(c) in ("Rarity", "Item Rarity"):
                        rarity_col = j
                break

        # Freeze header row + ID column (except Overview)
        freeze_rows = 1 if tab_name != "Overview & Requests" else 0
        freeze_cols = 1 if tab_name not in ("Overview & Requests", "Completed Log") else 0
        reqs.append({
            "updateSheetProperties": {
                "properties": {
                    "sheetId": sid,
                    "gridProperties": {"frozenRowCount": freeze_rows, "frozenColumnCount": freeze_cols},
                },
                "fields": "gridProperties.frozenRowCount,gridProperties.frozenColumnCount",
            }
        })

        # Header row style
        reqs.append({
            "repeatCell": {
                "range": {"sheetId": sid, "startRowIndex": header_row, "endRowIndex": header_row + 1, "startColumnIndex": 0, "endColumnIndex": ncols},
                "cell": {
                    "userEnteredFormat": {
                        "backgroundColor": header_bg,
                        "textFormat": {"bold": True, "foregroundColor": header_fg},
                        "wrapStrategy": "WRAP",
                    }
                },
                "fields": "userEnteredFormat(backgroundColor,textFormat,wrapStrategy)",
            }
        })

        # Wrap all body cells
        if nrows > header_row + 1:
            reqs.append({
                "repeatCell": {
                    "range": {"sheetId": sid, "startRowIndex": header_row + 1, "endRowIndex": nrows, "startColumnIndex": 0, "endColumnIndex": ncols},
                    "cell": {"userEnteredFormat": {"wrapStrategy": "WRAP", "verticalAlignment": "TOP"}},
                    "fields": "userEnteredFormat(wrapStrategy,verticalAlignment)",
                }
            })

        # Highlight Change Request column
        if req_col >= 0:
            reqs.append({
                "repeatCell": {
                    "range": {"sheetId": sid, "startRowIndex": header_row, "endRowIndex": header_row + 1, "startColumnIndex": req_col, "endColumnIndex": req_col + 1},
                    "cell": {"userEnteredFormat": {"backgroundColor": req_header_bg, "textFormat": {"bold": True, "foregroundColor": header_fg}}},
                    "fields": "userEnteredFormat(backgroundColor,textFormat)",
                }
            })
            if nrows > header_row + 1:
                reqs.append({
                    "repeatCell": {
                        "range": {"sheetId": sid, "startRowIndex": header_row + 1, "endRowIndex": nrows, "startColumnIndex": req_col, "endColumnIndex": req_col + 1},
                        "cell": {"userEnteredFormat": {"backgroundColor": req_bg}},
                        "fields": "userEnteredFormat.backgroundColor",
                    }
                })
            # Wide Change Request column (280px)
            reqs.append({
                "updateDimensionProperties": {
                    "range": {"sheetId": sid, "dimension": "COLUMNS", "startIndex": req_col, "endIndex": req_col + 1},
                    "properties": {"pixelSize": 280},
                    "fields": "pixelSize",
                }
            })

        # Rarity color fills
        if rarity_col >= 0:
            for r_idx in range(header_row + 1, nrows):
                rval = str(rows[r_idx][rarity_col]).lower() if rarity_col < len(rows[r_idx]) else ""
                if rval in RARITY_BG_HEX:
                    reqs.append({
                        "repeatCell": {
                            "range": {"sheetId": sid, "startRowIndex": r_idx, "endRowIndex": r_idx + 1, "startColumnIndex": rarity_col, "endColumnIndex": rarity_col + 1},
                            "cell": {"userEnteredFormat": {"backgroundColor": hex_to_rgb(RARITY_BG_HEX[rval]), "textFormat": {"bold": True}}},
                            "fields": "userEnteredFormat(backgroundColor,textFormat)",
                        }
                    })

        # Auto-resize non-Change-Request columns
        reqs.append({
            "autoResizeDimensions": {
                "dimensions": {"sheetId": sid, "dimension": "COLUMNS", "startIndex": 0, "endIndex": max(1, req_col if req_col > 0 else ncols)}
            }
        })

    return reqs


def push_to_sheet(sheet_id: str, apply_formatting: bool = True) -> dict[str, Any]:
    sheet_ids = ensure_tabs(sheet_id)

    # 1. Read existing unread Change Request cells & Completed Log before overwriting
    existing_requests: dict[str, dict[str, str]] = {}
    existing_general: list[list[str]] = []
    existing_completed: list[list[str]] = []
    for tab_name in TAB_ORDER:
        rows = read_tab_values(sheet_id, tab_name)
        if tab_name == "Completed Log":
            existing_completed = rows
        else:
            existing_requests[tab_name] = extract_change_requests_from_rows(tab_name, rows)
            if tab_name == "Overview & Requests":
                existing_general = extract_general_rows(rows)

    packs = load_all_packs()
    synced_utc = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    tabs = build_all_tabs(packs, existing_requests, existing_general, existing_completed, synced_utc)

    # 2. Batch write all 13 tabs (clear stale trailing rows cleanly via pad or exact range)
    batch_ops: list[dict[str, Any]] = []
    for tab_name in TAB_ORDER:
        rows = tabs[tab_name]
        if not rows:
            continue
        ncols = max(len(r) for r in rows)
        # Pad 5 trailing blank rows to erase any removed items without running destructive clear
        padded = [list(r) + [""] * (ncols - len(r)) for r in rows] + [[""] * ncols for _ in range(5)]
        end_col = col_letter(ncols - 1)
        rng = f"'{tab_name}'!A1:{end_col}{len(padded)}"
        batch_ops.append({"op": "write", "range": rng, "data": padded})

    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        json.dump(batch_ops, tf)
        batch_path = tf.name
    try:
        run_gsheets(["mutate", "batch", sheet_id, "-f", batch_path])
    finally:
        os.unlink(batch_path)

    # 3. Apply formatting in one raw-batch call
    if apply_formatting:
        fmt_reqs = build_formatting_requests(tabs, sheet_ids)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
            json.dump({"requests": fmt_reqs}, tf)
            fmt_path = tf.name
        try:
            run_gsheets(["mutate", "raw-batch", sheet_id, "-f", fmt_path])
        finally:
            os.unlink(fmt_path)

    # 4. Update docs/GAME_SHEET.json
    cfg = {
        "spreadsheet_id": sheet_id,
        "spreadsheet_url": f"https://docs.google.com/spreadsheets/d/{sheet_id}/edit",
        "title": SHEET_TITLE,
        "last_synced_utc": synced_utc,
        "tabs": TAB_ORDER,
    }
    with CONFIG_PATH.open("w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    return cfg


def pull_requests(sheet_id: str) -> list[dict[str, str]]:
    found: list[dict[str, str]] = []
    for tab_name in TAB_ORDER:
        if tab_name == "Completed Log":
            continue
        rows = read_tab_values(sheet_id, tab_name)
        reqs = extract_change_requests_from_rows(tab_name, rows)
        for row_id, text in reqs.items():
            found.append({"tab": tab_name, "row_id": row_id, "request": text})
    return found


def complete_request(sheet_id: str, tab_name: str, row_id: str, resolution: str, commit_sha: str) -> bool:
    rows = read_tab_values(sheet_id, tab_name)
    header_idx = -1
    req_col = -1
    for i, r in enumerate(rows):
        for j, c in enumerate(r):
            if str(c).strip() == "Change Request":
                header_idx = i
                req_col = j
                break
        if header_idx >= 0:
            break
    if header_idx < 0 or req_col < 0:
        raise RuntimeError(f"Could not find 'Change Request' column in tab '{tab_name}'")

    target_row_1based = -1
    orig_request = ""
    for i in range(header_idx + 1, len(rows)):
        if rows[i] and str(rows[i][0]).strip() == row_id:
            target_row_1based = i + 1
            orig_request = str(rows[i][req_col]).strip() if req_col < len(rows[i]) else ""
            break
    if target_row_1based < 0:
        raise RuntimeError(f"Row ID '{row_id}' not found in tab '{tab_name}'")

    cell_ref = f"'{tab_name}'!{col_letter(req_col)}{target_row_1based}"
    now_utc = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    ops = [
        {"op": "write", "range": cell_ref, "data": [[""]]},
        {"op": "append", "range": "'Completed Log'!A1", "data": [[now_utc, tab_name, row_id, orig_request, resolution, commit_sha]]},
    ]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
        json.dump(ops, tf)
        path = tf.name
    try:
        run_gsheets(["mutate", "batch", sheet_id, "-f", path])
    finally:
        os.unlink(path)
    return True


def load_sheet_id(cli_id: str | None) -> str:
    if cli_id:
        return cli_id
    if CONFIG_PATH.exists():
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        if cfg.get("spreadsheet_id"):
            return str(cfg["spreadsheet_id"])
    raise SystemExit("No spreadsheet_id found. Run with --create or pass --sheet-id.")


def main() -> int:
    ap = argparse.ArgumentParser(description="Maintain the Dungeon Crawler 3D Google Sheet (D-061).")
    ap.add_argument("--dry-run", action="store_true", help="Build all 13 tabs offline and print summary")
    ap.add_argument("--create", action="store_true", help="Create a new Google Sheet and populate all tabs")
    ap.add_argument("--push", action="store_true", help="Push game/data/*.json to the Sheet (preserving Change Requests)")
    ap.add_argument("--pull-requests", action="store_true", help="List all non-empty Change Request cells across tabs")
    ap.add_argument("--complete", nargs=2, metavar=("TAB", "ROW_ID"), help="Clear a Change Request and log receipt")
    ap.add_argument("--resolution", default="", help="Resolution note for --complete")
    ap.add_argument("--commit", default="", help="Commit SHA for --complete")
    ap.add_argument("--sheet-id", default=None, help="Override spreadsheet ID from docs/GAME_SHEET.json")
    ap.add_argument("--no-format", action="store_true", help="Skip formatting batch on --push")
    args = ap.parse_args()

    if args.dry_run:
        tabs = build_all_tabs(load_all_packs())
        print(f"[sync-game-sheet] DRY-RUN OK: {len(tabs)} tabs built.")
        for t in TAB_ORDER:
            rows = tabs[t]
            print(f"  - {t}: {len(rows)} rows x {max(len(r) for r in rows)} cols")
        return 0

    if args.create:
        res = run_gsheets(["mutate", "create", "--title", SHEET_TITLE], expect_json=True)
        sid = res.get("spreadsheetId") or res.get("spreadsheet_id") or res.get("id")
        if not sid:
            raise RuntimeError(f"Unexpected create response: {res}")
        cfg = push_to_sheet(str(sid), apply_formatting=not args.no_format)
        print(json.dumps(cfg, indent=2))
        return 0

    if args.push:
        sid = load_sheet_id(args.sheet_id)
        cfg = push_to_sheet(sid, apply_formatting=not args.no_format)
        print(f"[sync-game-sheet] PUSH OK: {cfg['spreadsheet_url']} (synced {cfg['last_synced_utc']})")
        return 0

    if args.pull_requests:
        sid = load_sheet_id(args.sheet_id)
        reqs = pull_requests(sid)
        print(json.dumps(reqs, indent=2))
        return 0

    if args.complete:
        sid = load_sheet_id(args.sheet_id)
        tab_name, row_id = args.complete
        complete_request(sid, tab_name, row_id, args.resolution, args.commit)
        print(f"[sync-game-sheet] COMPLETED: cleared ({tab_name}, {row_id}) and logged receipt.")
        return 0

    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
