#!/usr/bin/env python3
"""Automated unit tests for scripts/sync-game-sheet.py (D-061 / FB-026)."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parent / "sync-game-sheet.py"
spec = importlib.util.spec_from_file_location("sync_game_sheet", SCRIPT_PATH)
assert spec and spec.loader
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestSyncGameSheet(unittest.TestCase):
    def setUp(self) -> None:
        self.packs = mod.load_all_packs()

    def test_builds_all_13_tabs_with_complete_game_coverage(self) -> None:
        tabs = mod.build_all_tabs(self.packs, synced_utc="2026-11-22 12:00 UTC")
        self.assertEqual(list(tabs.keys()), mod.TAB_ORDER)
        self.assertEqual(len(tabs), 13)

        # Total items across the 4 item tabs equals all 46 items in items.json
        item_tabs = ["Weapons & Shields", "Spells", "Armor & Accessories", "Consumables & Ingredients"]
        total_item_rows = sum(len(tabs[t]) - 1 for t in item_tabs)
        self.assertEqual(total_item_rows, len(self.packs["items"]["items"]))

        # All 11 enemies represented
        self.assertEqual(len(tabs["Enemies & Bosses"]) - 1, len(self.packs["enemies"]["enemies"]))

        # Every data tab ends with a Change Request column
        for t in mod.TAB_ORDER:
            if t in ("Overview & Requests", "Completed Log"):
                continue
            self.assertEqual(tabs[t][0][-1], "Change Request", f"{t} must end with Change Request")

    def test_preserves_unread_change_requests_and_completed_log_across_sync(self) -> None:
        initial = mod.build_all_tabs(self.packs)
        # Simulate user adding Change Request comments on multiple tabs
        w_rows = [list(r) for r in initial["Weapons & Shields"]]
        req_col = w_rows[0].index("Change Request")
        for r in w_rows[1:]:
            if r[0] == "iron_longsword":
                r[req_col] = "Bump base damage from 18 to 20"

        e_rows = [list(r) for r in initial["Enemies & Bosses"]]
        e_req_col = e_rows[0].index("Change Request")
        for r in e_rows[1:]:
            if r[0] == "draugr_raider":
                r[e_req_col] = "Make aggro radius 20 instead of 22"

        ov_rows = [list(r) for r in initial["Overview & Requests"]]
        for r in ov_rows:
            if r and r[0] == "GEN-01":
                r[1] = "Combat"
                r[2] = "High"
                r[3] = "Add a frost-themed dagger"
                r[4] = "Uncommon rarity"

        extracted = {
            "Weapons & Shields": mod.extract_change_requests_from_rows("Weapons & Shields", w_rows),
            "Enemies & Bosses": mod.extract_change_requests_from_rows("Enemies & Bosses", e_rows),
            "Overview & Requests": mod.extract_change_requests_from_rows("Overview & Requests", ov_rows),
        }
        self.assertEqual(extracted["Weapons & Shields"], {"iron_longsword": "Bump base damage from 18 to 20"})
        self.assertEqual(extracted["Enemies & Bosses"], {"draugr_raider": "Make aggro radius 20 instead of 22"})
        self.assertEqual(extracted["Overview & Requests"], {"GEN-01": "Add a frost-themed dagger"})

        gen_rows = mod.extract_general_rows(ov_rows)
        completed_history = [
            mod.COMPLETED_LOG_HEADERS,
            ["2026-11-22 12:00 UTC", "Spells", "firebolt_tome", "Lower mana cost", "Reduced to 12", "abc1234"],
        ]

        rebuilt = mod.build_all_tabs(self.packs, extracted, gen_rows, completed_history)
        # Verify preserved comments survived rebuild
        w_map = {r[0]: r[-1] for r in rebuilt["Weapons & Shields"][1:]}
        self.assertEqual(w_map["iron_longsword"], "Bump base damage from 18 to 20")
        e_map = {r[0]: r[-1] for r in rebuilt["Enemies & Bosses"][1:]}
        self.assertEqual(e_map["draugr_raider"], "Make aggro radius 20 instead of 22")
        gen_map = {r[0]: r for r in rebuilt["Overview & Requests"] if r and str(r[0]).startswith("GEN-")}
        self.assertEqual(gen_map["GEN-01"][3], "Add a frost-themed dagger")
        self.assertEqual(gen_map["GEN-01"][1], "Combat")
        # Verify Completed Log survived rebuild
        self.assertEqual(len(rebuilt["Completed Log"]), 2)
        self.assertEqual(rebuilt["Completed Log"][1][2], "firebolt_tome")

    def test_formatting_requests_cover_all_tabs(self) -> None:
        tabs = mod.build_all_tabs(self.packs)
        sheet_ids = {name: idx for idx, name in enumerate(mod.TAB_ORDER)}
        reqs = mod.build_formatting_requests(tabs, sheet_ids)
        self.assertGreater(len(reqs), 40)
        # Ensure column letter helper handles single and double letters
        self.assertEqual(mod.col_letter(0), "A")
        self.assertEqual(mod.col_letter(25), "Z")
        self.assertEqual(mod.col_letter(26), "AA")


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(TestSyncGameSheet)
    res = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if res.wasSuccessful() else 1)
