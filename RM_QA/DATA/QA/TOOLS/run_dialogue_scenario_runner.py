#!/usr/bin/env python3
"""
Dialogue Scenario Runner (machine-friendly)

Reads QA scenarios (DATA/QA/TEST_SCENARIOS_DIALOGUE.csv), selects dialogue variants from
ACT1 (DATA/DEV/DIALOGUE_VARIANTS.csv), applies deltas, and emits a report:
DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv

This runner is intentionally lightweight: it covers the subset of ConditionsExpr currently used
in the project (HasTag/HasFlag/HasRecentEvent, numeric comparisons, &, |, parentheses).

Enhancements (AJ_000247):
- Report is step-level (ScenarioID + StepIndex) and includes diffs
- Supports flag TTL and recent-event TTL via "@<turns>" tokens and/or *_TTL_Turns columns
- Supports "FLAG=false" / "EVT=false" tokens (clear semantics)
- Gate-friendly: any step PASS=FALSE implies scenario failure
"""

from __future__ import annotations

import argparse
import csv
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple


# -----------------------------
# Helpers
# -----------------------------

def _utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _read_csv(path: str) -> List[Dict[str, str]]:
    with open(path, "r", encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def _write_csv(path: str, fieldnames: List[str], rows: List[Dict[str, Any]]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def _parse_list(s: str) -> List[str]:
    s = (s or "").strip()
    if not s:
        return []
    # allow "a|b|c" or "a;b;c"
    parts = []
    for chunk in re.split(r"[|;]", s):
        chunk = chunk.strip()
        if chunk:
            parts.append(chunk)
    return parts


def _parse_setup_state(s: str) -> Dict[str, str]:
    s = (s or "").strip()
    if not s:
        return {}
    out: Dict[str, str] = {}
    for token in [t.strip() for t in s.split(";") if t.strip()]:
        if "=" in token:
            k, v = token.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def _to_int(v: Any, default: int = 0) -> int:
    if v is None:
        return default
    try:
        return int(v)
    except Exception:
        try:
            return int(float(str(v)))
        except Exception:
            return default


# -----------------------------
# TTL containers
# -----------------------------

@dataclass
class TTLSet:
    perm: set[str]
    ttl: Dict[str, int]  # name -> remaining turns (>=1)

    def present(self, name: str) -> bool:
        return name in self.perm or (name in self.ttl and self.ttl[name] > 0)

    def all_names(self) -> List[str]:
        return sorted(set(self.perm) | set(self.ttl.keys()))

    def add_perm(self, name: str) -> None:
        if not name:
            return
        self.perm.add(name)
        if name in self.ttl:
            self.ttl.pop(name, None)

    def add_ttl(self, name: str, turns: int) -> None:
        if not name:
            return
        if turns <= 0:
            self.add_perm(name)
            return
        # TTL overrides permanent
        if name in self.perm:
            self.perm.remove(name)
        self.ttl[name] = turns

    def clear(self, name: str) -> None:
        if not name:
            return
        self.perm.discard(name)
        self.ttl.pop(name, None)

    def tick(self) -> None:
        """Decrement TTL by 1 turn. Remove entries at 0."""
        dead = []
        for k, v in self.ttl.items():
            nv = v - 1
            if nv <= 0:
                dead.append(k)
            else:
                self.ttl[k] = nv
        for k in dead:
            self.ttl.pop(k, None)


# -----------------------------
# ConditionsExpr
# -----------------------------

def _expr_to_py(expr: str) -> str:
    """
    Transform minimal DSL into a safe-ish python expression.

    Supported:
      - HasTag(X)=true/false
      - HasFlag(X)=true/false
      - HasRecentEvent(X)=true/false
      - &, |, parentheses
      - Numeric comparisons (e.g., Stress_0_100 >= 80)
      - Mood comparisons
    """
    e = (expr or "").strip()
    if not e:
        return ""

    # Normalize operators (keep single-char forms too)
    e = e.replace("&", " and ").replace("|", " or ")

    # Function calls: HasTag(X) -> has_tag("X")
    e = re.sub(r"\bHasTag\(\s*([A-Za-z0-9_@.\-]+)\s*\)", r'has_tag("\1")', e)
    e = re.sub(r"\bHasFlag\(\s*([A-Za-z0-9_@.\-]+)\s*\)", r'has_flag("\1")', e)
    e = re.sub(r"\bHasRecentEvent\(\s*([A-Za-z0-9_@.\-]+)\s*\)", r'has_recent_event("\1")', e)

    # equality to python
    e = re.sub(r"=\s*true\b", "== True", e, flags=re.IGNORECASE)
    e = re.sub(r"=\s*false\b", "== False", e, flags=re.IGNORECASE)

    # Mood comparisons: wrap RHS token in quotes when unquoted
    def _wrap_mood(m: re.Match) -> str:
        op = m.group(2)
        rhs = m.group(3)
        return f'Mood {op} "{rhs}"'
    e = re.sub(r"\b(Mood)\s*([!=]=)\s*([A-Za-z0-9_]+)\b", _wrap_mood, e)

    return e


def _eval_expr(expr: str, state: Dict[str, str], tags: set[str], flags: TTLSet, events: TTLSet) -> bool:
    py = _expr_to_py(expr)
    if not py:
        return True

    def has_tag(t: str) -> bool:
        return t in tags

    def has_flag(f: str) -> bool:
        return flags.present(f)

    def has_recent_event(ev: str) -> bool:
        return events.present(ev)

    env: Dict[str, Any] = {
        "has_tag": has_tag,
        "has_flag": has_flag,
        "has_recent_event": has_recent_event,
        "True": True,
        "False": False,
    }

    # expose state fields
    Mood = state.get("Mood", "NEUTRAL")
    env["Mood"] = Mood
    for k, v in state.items():
        if k == "Mood":
            continue
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k or ""):
            try:
                env[k] = float(v) if ("." in str(v)) else int(str(v))
            except Exception:
                env[k] = v

    try:
        return bool(eval(py, {"__builtins__": {}}, env))
    except Exception:
        # If malformed, fail-safe to False so it doesn't match variants unexpectedly.
        return False


# -----------------------------
# DV selection + application
# -----------------------------

@dataclass
class SelectionResult:
    variant_id: str
    delta_stress: int
    delta_fear: int
    set_mood: str
    add_flags: List[str]
    clear_flags: List[str]
    add_recent_events: List[str]
    clear_recent_events: List[str]


def _select_variant(dv_rows: List[Dict[str, str]], npc_id: str, intent: str, state: Dict[str, str],
                    tags: set[str], flags: TTLSet, events: TTLSet) -> Optional[Dict[str, str]]:
    candidates = []
    for r in dv_rows:
        if (r.get("IntentID") or "").strip() != intent:
            continue
        scope_type = (r.get("ScopeType") or "").strip().upper()
        scope_id = (r.get("ScopeID") or "").strip()
        if scope_type == "GLOBAL":
            pass
        elif scope_type == "NPC":
            if scope_id != npc_id:
                continue
        else:
            # Unknown scope types are ignored
            continue

        expr = (r.get("ConditionsExpr") or "").strip()
        if expr and not _eval_expr(expr, state, tags, flags, events):
            continue

        prio = _to_int(r.get("Priority", 0), 0)
        base = _to_int(r.get("BaseScore", 0), 0)
        # For now we keep the prior behavior: pick highest (Priority, BaseScore).
        candidates.append((prio, base, r))

    if not candidates:
        return None
    candidates.sort(key=lambda x: (x[0], x[1]), reverse=True)
    return candidates[0][2]


def _parse_ops_with_ttl(raw: str, default_ttl_turns_raw: Any = None) -> Tuple[List[str], Dict[str, int], List[str]]:
    """
    Parse tokens for AddFlags/AddRecentEvent.

    Tokens supported:
      - NAME              => add perm
      - NAME@2            => add ttl=2
      - NAME=false        => clear NAME (returns in clear list)
    If default_ttl_turns_raw is an int and token has no @, applies as TTL to those adds.
    """
    default_ttl = _to_int(default_ttl_turns_raw, 0)
    adds_perm: List[str] = []
    adds_ttl: Dict[str, int] = {}
    clears: List[str] = []

    for tok in _parse_list(raw):
        if not tok:
            continue
        # clear semantics: X=false
        if re.search(r"=\s*false\s*$", tok, flags=re.IGNORECASE):
            name = tok.split("=", 1)[0].strip()
            if name:
                clears.append(name)
            continue

        # TTL in token: X@2
        m = re.match(r"^(.+?)@(\d+)$", tok.strip())
        if m:
            name = m.group(1).strip()
            ttl = _to_int(m.group(2), 0)
            if name:
                adds_ttl[name] = max(1, ttl)
            continue

        name = tok.strip()
        if not name:
            continue
        if default_ttl > 0:
            adds_ttl[name] = max(1, default_ttl)
        else:
            adds_perm.append(name)

    return adds_perm, adds_ttl, clears


def _apply_variant(row: Dict[str, str], state: Dict[str, str], tags: set[str], flags: TTLSet, events: TTLSet) -> SelectionResult:
    # numeric deltas
    delta_stress = _to_int(row.get("DeltaStress", 0), 0)
    delta_fear = _to_int(row.get("DeltaFear", 0), 0)

    # apply to state with clamp 0..100
    stress = _to_int(state.get("Stress_0_100", state.get("Stress", "0")), 0)
    fear = _to_int(state.get("Fear_0_100", state.get("Fear", "0")), 0)

    stress2 = max(0, min(100, stress + delta_stress))
    fear2 = max(0, min(100, fear + delta_fear))

    state["Stress_0_100"] = str(stress2)
    state["Stress"] = str(stress2)
    state["Fear_0_100"] = str(fear2)
    state["Fear"] = str(fear2)

    set_mood = (row.get("SetMood") or "").strip()
    if set_mood:
        state["Mood"] = set_mood

    # Flags
    add_flags_perm, add_flags_ttl, clear_from_false = _parse_ops_with_ttl(row.get("AddFlags", ""), row.get("AddFlags_TTL_Turns"))
    clear_flags = _parse_list(row.get("ClearFlags", ""))
    clear_flags_all = clear_flags + clear_from_false

    for f in add_flags_perm:
        flags.add_perm(f)
    for f, ttl in add_flags_ttl.items():
        flags.add_ttl(f, ttl)
    for f in clear_flags_all:
        flags.clear(f)

    # Recent events
    add_ev_perm, add_ev_ttl, clear_ev_from_false = _parse_ops_with_ttl(row.get("AddRecentEvent", ""), row.get("AddRecentEvent_TTL_Turns"))
    clear_ev = _parse_list(row.get("ClearRecentEvent", ""))
    clear_ev_all = clear_ev + clear_ev_from_false

    for ev in add_ev_perm:
        events.add_perm(ev)
    for ev, ttl in add_ev_ttl.items():
        events.add_ttl(ev, ttl)
    for ev in clear_ev_all:
        events.clear(ev)

    return SelectionResult(
        variant_id=(row.get("VariantID") or ""),
        delta_stress=delta_stress,
        delta_fear=delta_fear,
        set_mood=(state.get("Mood") or ""),
        add_flags=sorted(add_flags_perm + list(add_flags_ttl.keys())),
        clear_flags=sorted(clear_flags_all),
        add_recent_events=sorted(add_ev_perm + list(add_ev_ttl.keys())),
        clear_recent_events=sorted(clear_ev_all),
    )


# -----------------------------
# Scenario parsing
# -----------------------------

def _parse_steps(steps_text: str) -> List[Dict[str, str]]:
    steps_text = (steps_text or "").strip()
    if not steps_text:
        return []
    parts = [p.strip() for p in steps_text.split("||") if p.strip()]
    out: List[Dict[str, str]] = []
    for p in parts:
        tokens = [t.strip() for t in p.split(";") if t.strip()]
        d: Dict[str, str] = {}
        extra_tags: List[str] = []
        for t in tokens:
            if "=" in t:
                k, v = t.split("=", 1)
                d[k.strip()] = v.strip()
            else:
                extra_tags.append(t.strip())
        if extra_tags:
            base = d.get("Tags", "")
            merged = [x for x in _parse_list(base)] + extra_tags
            d["Tags"] = "|".join(merged)
        out.append(d)
    return out


def _expect_set(step: Dict[str, str], key: str) -> set[str]:
    return set(_parse_list(step.get(key, "")))


def run(qa_root: str, act1_root: str, output_rel: str = "DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv") -> Tuple[str, List[Dict[str, Any]]]:
    qa_root = os.path.abspath(qa_root)
    act1_root = os.path.abspath(act1_root)

    scenarios_path = os.path.join(qa_root, "DATA/QA/TEST_SCENARIOS_DIALOGUE.csv")
    dv_path = os.path.join(act1_root, "DATA/DEV/DIALOGUE_VARIANTS.csv")

    scenarios = _read_csv(scenarios_path)
    dv_rows = _read_csv(dv_path)

    report_rows: List[Dict[str, Any]] = []
    gen_utc = _utc_now()

    for sc in scenarios:
        sid = (sc.get("ScenarioID") or "").strip()
        npc_id = (sc.get("NPCID") or "").strip()
        setup_state = _parse_setup_state(sc.get("SetupState", ""))

        # Ensure required defaults
        state = {
            "Stress_0_100": setup_state.get("Stress_0_100", setup_state.get("Stress", "0") or "0"),
            "Fear_0_100": setup_state.get("Fear_0_100", setup_state.get("Fear", "0") or "0"),
            "Mood": setup_state.get("Mood", "NEUTRAL") or "NEUTRAL",
            "OutburstCooldown": setup_state.get("OutburstCooldown", "0") or "0",
            "Trust_Player": setup_state.get("Trust_Player", "50") or "50",
        }
        # keep aliases
        state["Stress"] = state["Stress_0_100"]
        state["Fear"] = state["Fear_0_100"]

        flags = TTLSet(perm=set(_parse_list(sc.get("SetupFlagsTrue", ""))), ttl={})
        events = TTLSet(perm=set(), ttl={})

        steps = _parse_steps(sc.get("Steps", ""))
        scenario_pass = True

        for i, st in enumerate(steps, start=1):
            # Turn tick happens at the start of each step except the first
            if i > 1:
                flags.tick()
                events.tick()

            intent = (st.get("Intent") or st.get("IntentID") or "").strip()
            tags = set(_parse_list(st.get("Tags", "")))

            expected_var = (st.get("ExpectedVariantID") or st.get("ExpectVariant") or st.get("ExpectVariantID") or "").strip()
            expect_mood = (st.get("ExpectMood") or "").strip()
            expect_ds = st.get("ExpectDeltaStress", None)
            expect_df = st.get("ExpectDeltaFear", None)

            exp_flags_present = _expect_set(st, "ExpectFlagsPresent")
            exp_flags_absent = _expect_set(st, "ExpectFlagsAbsent")
            exp_ev_present = _expect_set(st, "ExpectRecentEventsPresent")
            exp_ev_absent = _expect_set(st, "ExpectRecentEventsAbsent")

            chosen = _select_variant(dv_rows, npc_id, intent, state, tags, flags, events)
            step_pass = True
            diffs: List[str] = []

            if chosen is None:
                step_pass = False
                diffs.append(f"no variant matched (intent={intent})")
                actual_var = ""
                res = SelectionResult("", 0, 0, state.get("Mood",""), [], [], [], [])
            else:
                res = _apply_variant(chosen, state, tags, flags, events)
                actual_var = res.variant_id

            # Validate expected variant
            if expected_var and actual_var != expected_var:
                step_pass = False
                diffs.append(f"ExpectedVariantID {expected_var} != {actual_var}")

            # Validate mood / deltas (if declared)
            if expect_mood and state.get("Mood","") != expect_mood:
                step_pass = False
                diffs.append(f"ExpectMood {expect_mood} != {state.get('Mood','')}")

            if expect_ds is not None and str(expect_ds).strip() != "":
                exp_ds_i = _to_int(expect_ds, 0)
                if res.delta_stress != exp_ds_i:
                    step_pass = False
                    diffs.append(f"ExpectDeltaStress {exp_ds_i} != {res.delta_stress}")

            if expect_df is not None and str(expect_df).strip() != "":
                exp_df_i = _to_int(expect_df, 0)
                if res.delta_fear != exp_df_i:
                    step_pass = False
                    diffs.append(f"ExpectDeltaFear {exp_df_i} != {res.delta_fear}")

            # Validate flags / events state AFTER applying the variant (turn tick was already done at step start)
            flags_after = set(flags.all_names())
            ev_after = set(events.all_names())

            if exp_flags_present and not exp_flags_present.issubset(flags_after):
                step_pass = False
                diffs.append(f"MissingFlags {sorted(exp_flags_present - flags_after)}")

            if exp_flags_absent and (exp_flags_absent & flags_after):
                step_pass = False
                diffs.append(f"UnexpectedFlagsPresent {sorted(exp_flags_absent & flags_after)}")

            if exp_ev_present and not exp_ev_present.issubset(ev_after):
                step_pass = False
                diffs.append(f"MissingRecentEvents {sorted(exp_ev_present - ev_after)}")

            if exp_ev_absent and (exp_ev_absent & ev_after):
                step_pass = False
                diffs.append(f"UnexpectedRecentEventsPresent {sorted(exp_ev_absent & ev_after)}")

            if not step_pass:
                scenario_pass = False

            report_rows.append({
                "ScenarioID": sid,
                "StepIndex": i,
                "NPCID": npc_id,
                "PASS": "TRUE" if step_pass else "FALSE",
                "ExpectedVariantID": expected_var,
                "ActualVariantID": actual_var,
                "ExpectedMood": expect_mood,
                "ActualMood": state.get("Mood", ""),
                "ExpectedDeltaStress": "" if expect_ds is None else str(expect_ds),
                "ActualDeltaStress": str(res.delta_stress),
                "ExpectedDeltaFear": "" if expect_df is None else str(expect_df),
                "ActualDeltaFear": str(res.delta_fear),
                "FlagsAfter": "|".join(sorted(flags_after)),
                "RecentEventsAfter": "|".join(sorted(ev_after)),
                "Diffs": "; ".join(diffs),
                "GeneratedUTC": gen_utc,
            })

        # If no steps, still emit a row so the gate can see it
        if not steps:
            report_rows.append({
                "ScenarioID": sid,
                "StepIndex": 0,
                "NPCID": npc_id,
                "PASS": "TRUE",
                "ExpectedVariantID": "",
                "ActualVariantID": "",
                "ExpectedMood": "",
                "ActualMood": state.get("Mood", ""),
                "ExpectedDeltaStress": "",
                "ActualDeltaStress": "0",
                "ExpectedDeltaFear": "",
                "ActualDeltaFear": "0",
                "FlagsAfter": "|".join(sorted(flags.all_names())),
                "RecentEventsAfter": "|".join(sorted(events.all_names())),
                "Diffs": "",
                "GeneratedUTC": gen_utc,
            })

    out_path = os.path.join(qa_root, output_rel)
    _write_csv(out_path, [
        "ScenarioID", "StepIndex", "NPCID", "PASS",
        "ExpectedVariantID", "ActualVariantID",
        "ExpectedMood", "ActualMood",
        "ExpectedDeltaStress", "ActualDeltaStress",
        "ExpectedDeltaFear", "ActualDeltaFear",
        "FlagsAfter", "RecentEventsAfter", "Diffs", "GeneratedUTC",
    ], report_rows)
    return out_path, report_rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--qa-root", default=".", help="Path to RM_QA module root (contains DATA/QA/...)")
    ap.add_argument("--act1-root", required=True, help="Path to RM_ACT1 module root (contains DATA/DEV/...)")
    ap.add_argument("--out-rel", default="DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv", help="Output relpath inside qa-root")
    args = ap.parse_args()

    out_path, rows = run(args.qa_root, args.act1_root, args.out_rel)
    fails = [r for r in rows if str(r.get("PASS", "")).upper() != "TRUE"]
    # Scenario-level: a scenario fails if any of its steps fails
    bad_scenarios = sorted({r.get("ScenarioID") for r in fails if r.get("ScenarioID")})
    print(f"Wrote {out_path} ({len(rows)} step-rows; failing_scenarios={len(bad_scenarios)})")
    return 1 if bad_scenarios else 0


if __name__ == "__main__":
    raise SystemExit(main())
