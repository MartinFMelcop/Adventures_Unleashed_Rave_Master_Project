#!/usr/bin/env python3
"""Combat Vector Runner (deterministic)

Reads TEST_COMBAT_*.csv files and produces RPT_COMBAT_VECTOR_RUNNER.csv with PASS/FAIL.
Goal: regression protection for AJ_000271 combat formulas (Opção C).

Supports module root as:
- folder (preferred)
- .zip (read-only)

Notes:
- Implements Ruby 1.8 style rounding (half away from zero) to avoid Python bankers rounding.
"""

from __future__ import annotations

import argparse
import csv
import io
import math
import os
import sys
import zipfile
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple, Union

# ----------------
# Ruby-compatible helpers
# ----------------

def ruby_round(x: float) -> int:
    # Ruby 1.8 round: half away from zero
    if x >= 0.0:
        return int(math.floor(x + 0.5))
    return int(math.ceil(x - 0.5))

def clamp(x: float, a: float, b: float) -> float:
    return max(a, min(b, x))

def safe_ratio(n: float, d: float) -> float:
    return 0.0 if d == 0.0 else (n / d)

DEFAULTS = {
    "base_hit": 0.90,
    "lvl_coef": 0.02,
    "lvl_min": 0.85,
    "lvl_max": 1.15,
    "hit_min": 0.05,
    "hit_max": 0.95,
    "crit_base": 1.0,
    "crit_cap": 0.50,
    "k_base": 100,
    "k_lvl": 10,
    "apply_min": 0.05,
    "apply_max": 0.95,
}

# ----------------
# Formula implementations (aligned with RM_COMBAT_RUNTIME.rb)
# ----------------

def hit_chance(acc: float, eva: float, lvl_atk: int, lvl_def: int, base_hit_skill: Optional[float]) -> float:
    base = DEFAULTS["base_hit"] if base_hit_skill is None else float(base_hit_skill)
    ratio = safe_ratio(float(acc), float(acc) + float(eva))
    lvl_factor = 1.0 + DEFAULTS["lvl_coef"] * (int(lvl_atk) - int(lvl_def))
    lvl_factor = clamp(lvl_factor, DEFAULTS["lvl_min"], DEFAULTS["lvl_max"])
    p = base * ratio * lvl_factor
    return clamp(p, DEFAULTS["hit_min"], DEFAULTS["hit_max"])

def crit_chance(crit_percent: float, crit_base_skill: Optional[float]) -> float:
    base = DEFAULTS["crit_base"] if crit_base_skill is None else float(crit_base_skill)
    p = base * (float(crit_percent) / 100.0)
    return clamp(p, 0.0, DEFAULTS["crit_cap"])

def raw_damage(atk_or_matk: float, escala_coef: float, letalidade: float) -> float:
    return (float(atk_or_matk) * float(escala_coef)) * (1.0 + float(letalidade))

def mitigate(raw: float, def_or_mdef: float, lvl_def: int) -> int:
    k = DEFAULTS["k_base"] + DEFAULTS["k_lvl"] * int(lvl_def)
    mit = safe_ratio(float(k), float(k) + float(def_or_mdef))
    return ruby_round(float(raw) * mit)

def apply_chance(eff: float, res: float, base_apply_skill: Optional[float]) -> float:
    base = 1.0 if base_apply_skill is None else float(base_apply_skill)
    ratio = safe_ratio(float(eff), float(eff) + float(res))
    p = base * ratio
    return clamp(p, DEFAULTS["apply_min"], DEFAULTS["apply_max"])

def final_duration(base_dur: float, dur_apply_percent: float, ten_percent: float) -> int:
    mult = 1.0 + float(dur_apply_percent) / 100.0 - float(ten_percent) / 100.0
    dur = ruby_round(float(base_dur) * mult)
    return 1 if dur < 1 else dur

def dot_tick(status_id: str, hp_max: int) -> int:
    sid = (status_id or "").strip().upper()
    hp = int(hp_max)
    if sid == "POISON":
        return ruby_round(hp * 0.06)
    if sid == "BLEED":
        return ruby_round(hp * 0.03)
    if sid == "BURN":
        return ruby_round(hp * 0.03)
    return 0

def reapply_duration(remaining: int, add: int) -> int:
    r = int(remaining) + int(add)
    return 1 if r < 1 else r

def final_damage(atk_or_matk: float, escala_coef: float, letalidade: float,
                 def_or_mdef: float, lvl_def: int, defender_flag: int) -> int:
    raw = raw_damage(atk_or_matk, escala_coef, letalidade)
    dmg = mitigate(raw, def_or_mdef, lvl_def)
    if int(defender_flag) == 1:
        dmg = ruby_round(dmg * 0.5)
    return dmg

# ----------------
# IO abstraction
# ----------------

class ModuleReader:
    def __init__(self, module_path: str):
        self.module_path = module_path
        self.is_zip = module_path.lower().endswith(".zip")
        self._zip = zipfile.ZipFile(module_path, "r") if self.is_zip else None

    def close(self) -> None:
        if self._zip is not None:
            self._zip.close()

    def exists(self, relpath: str) -> bool:
        if self.is_zip:
            try:
                self._zip.getinfo(relpath)
                return True
            except KeyError:
                return False
        return os.path.exists(os.path.join(self.module_path, relpath))

    def read_text(self, relpath: str) -> str:
        if self.is_zip:
            b = self._zip.read(relpath)
            return b.decode("utf-8")
        with open(os.path.join(self.module_path, relpath), "r", encoding="utf-8") as f:
            return f.read()

    def write_text(self, relpath: str, text: str) -> None:
        if self.is_zip:
            raise RuntimeError("Cannot write into zip. Extract module to a folder and run again.")
        full = os.path.join(self.module_path, relpath)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

# ----------------
# Runner
# ----------------

@dataclass
class RowResult:
    test_file: str
    component: str
    test_id: str
    passed: bool
    expected: str
    got: str
    delta: str
    notes: str

def _to_float_or_none(s: str) -> Optional[float]:
    s = (s or "").strip()
    if s == "":
        return None
    return float(s)

def _to_int(s: str) -> int:
    return int(float((s or "0").strip()))

def run_component(test_file: str, rows: List[Dict[str, str]]) -> List[RowResult]:
    comp = test_file.replace("TEST_COMBAT_", "").replace(".csv", "").upper()
    out: List[RowResult] = []
    tol = 1e-6

    for r in rows:
        tid = r.get("TestID", "").strip()
        try:
            if comp == "HIT":
                got = hit_chance(
                    float(r["ACC"]), float(r["EVA"]),
                    int(float(r["LvlAtk"])), int(float(r["LvlDef"])),
                    _to_float_or_none(r.get("BaseHitSkill", "")),
                )
                exp = float(r["Expected_HitChance"])
                passed = abs(got - exp) <= tol
                out.append(RowResult(test_file, comp, tid, passed,
                                    f"{exp:.6f}", f"{got:.6f}", f"{(got-exp):.6f}", ""))
            elif comp == "CRIT":
                got = crit_chance(
                    float(r["CRIT_percent"]),
                    _to_float_or_none(r.get("CritBaseSkill", "")),
                )
                exp = float(r["Expected_CritChance"])
                passed = abs(got - exp) <= tol
                out.append(RowResult(test_file, comp, tid, passed,
                                    f"{exp:.6f}", f"{got:.6f}", f"{(got-exp):.6f}", ""))
            elif comp == "RAW":
                got = raw_damage(float(r["ATK_or_MATK"]), float(r["EscalaCoef"]), float(r["Letalidade"]))
                exp = float(r["Expected_RawDamage"])
                passed = abs(got - exp) <= 1e-5
                out.append(RowResult(test_file, comp, tid, passed,
                                    f"{exp:.6f}", f"{got:.6f}", f"{(got-exp):.6f}", ""))
            elif comp == "MIT":
                got = mitigate(float(r["RawDamage"]), float(r["DEF_or_MDEF"]), int(float(r["LvlDef"])))
                exp = int(float(r["Expected_MitigatedDamage"]))
                passed = (got == exp)
                out.append(RowResult(test_file, comp, tid, passed,
                                    str(exp), str(got), str(got-exp), ""))
            elif comp == "APPLY":
                got = apply_chance(float(r["EFF"]), float(r["RES"]), _to_float_or_none(r.get("BaseApplySkill", "")))
                exp = float(r["Expected_ApplyChance"])
                passed = abs(got - exp) <= tol
                out.append(RowResult(test_file, comp, tid, passed,
                                    f"{exp:.6f}", f"{got:.6f}", f"{(got-exp):.6f}", ""))
            elif comp == "DUR":
                got = final_duration(float(r["BaseDur"]), float(r["DurApply_percent"]), float(r["Ten_percent"]))
                exp = int(float(r["Expected_Duration"]))
                passed = (got == exp)
                out.append(RowResult(test_file, comp, tid, passed,
                                    str(exp), str(got), str(got-exp), ""))
            elif comp == "DOT":
                got = dot_tick(r.get("StatusID",""), int(float(r["HPmax"])))
                exp = int(float(r["Expected_DOT_Tick"]))
                passed = (got == exp)
                out.append(RowResult(test_file, comp, tid, passed,
                                    str(exp), str(got), str(got-exp), ""))
            elif comp == "REAPPLY":
                got = reapply_duration(int(float(r["Remaining"])), int(float(r["Add"])))
                exp = int(float(r["Expected_NewRemaining"]))
                passed = (got == exp)
                out.append(RowResult(test_file, comp, tid, passed,
                                    str(exp), str(got), str(got-exp), ""))
            elif comp == "FINAL_DAMAGE":
                got = final_damage(
                    float(r["ATK_or_MATK"]), float(r["EscalaCoef"]), float(r["Letalidade"]),
                    float(r["DEF_or_MDEF"]), int(float(r["LvlDef"])), int(float(r["DefenderFlag"])),
                )
                exp = int(float(r["Expected_FinalDamage"]))
                passed = (got == exp)
                out.append(RowResult(test_file, comp, tid, passed,
                                    str(exp), str(got), str(got-exp), ""))
            else:
                out.append(RowResult(test_file, comp, tid, False, "", "", "", f"Unknown component: {comp}"))
        except Exception as e:
            out.append(RowResult(test_file, comp, tid, False, "", "", "", f"EXCEPTION: {e}"))

    return out

def read_csv_rows(text: str) -> List[Dict[str, str]]:
    f = io.StringIO(text)
    reader = csv.DictReader(f)
    return [dict(r) for r in reader]

def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("module", help="Module root folder (preferred) or module ZIP.")
    ap.add_argument("--out", default="DATA/QA/RPT_COMBAT_VECTOR_RUNNER.csv",
                    help="Output report relpath (folder mode only).")
    args = ap.parse_args(argv)

    r = ModuleReader(args.module)
    try:
        test_files = [
            "DATA/QA/TEST_COMBAT_HIT.csv",
            "DATA/QA/TEST_COMBAT_CRIT.csv",
            "DATA/QA/TEST_COMBAT_RAW.csv",
            "DATA/QA/TEST_COMBAT_MIT.csv",
            "DATA/QA/TEST_COMBAT_APPLY.csv",
            "DATA/QA/TEST_COMBAT_DUR.csv",
            "DATA/QA/TEST_COMBAT_DOT.csv",
            "DATA/QA/TEST_COMBAT_REAPPLY.csv",
            "DATA/QA/TEST_COMBAT_FINAL_DAMAGE.csv",
        ]
        all_results: List[RowResult] = []
        present = 0
        for rel in test_files:
            if not r.exists(rel):
                continue
            present += 1
            rows = read_csv_rows(r.read_text(rel))
            all_results.extend(run_component(os.path.basename(rel), rows))

        if present == 0:
            print("COMBAT_VECTOR_RUNNER: no TEST_COMBAT_*.csv files found; nothing to do.")
            return 0

        # Write report (folder only)
        if r.is_zip:
            # Just print summary for zip mode
            fails = [x for x in all_results if not x.passed]
            print(f"COMBAT_VECTOR_RUNNER: {len(all_results)} checks, FAIL={len(fails)}")
            return 1 if fails else 0

        header = ["TestFile","Component","TestID","PASS","Expected","Got","Delta","Notes"]
        lines = [",".join(header)]
        for rr in all_results:
            lines.append(",".join([
                rr.test_file,
                rr.component,
                rr.test_id,
                "TRUE" if rr.passed else "FALSE",
                rr.expected,
                rr.got,
                rr.delta,
                rr.notes.replace("\n"," ").replace(",",";"),
            ]))
        r.write_text(args.out, "\n".join(lines) + "\n")

        fails = [x for x in all_results if not x.passed]
        print(f"COMBAT_VECTOR_RUNNER: wrote {args.out} — checks={len(all_results)} FAIL={len(fails)}")
        return 1 if fails else 0

    finally:
        r.close()

if __name__ == "__main__":
    raise SystemExit(main())
