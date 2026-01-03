#!/usr/bin/env python3
"""Generate lightweight coverage metrics by ACT and ETID from LOG_AJUSTES.

Output:
- DATA/QA/RPT_COVERAGE_ACT_ET.csv (inside the QA module folder)

This is intentionally heuristic: ACT buckets are inferred from Title/Descricao text.
"""

import argparse
import csv
import io
import os
import re
from datetime import datetime, timezone
from typing import Dict, List


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def read_csv(path: str) -> List[Dict[str, str]]:
    with open(path, "r", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def write_csv(path: str, rows: List[Dict[str, str]], fieldnames: List[str]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def act_bucket(title: str, desc: str) -> str:
    t = (title or "") + " " + (desc or "")
    t = t.upper()
    # Common patterns
    if re.search(r"\bACT\s*1\b|\bACT1\b|ATO\s*1", t):
        return "ACT_1"
    if re.search(r"\bACT\s*4\b|\bACT4\b|ATO\s*4", t):
        return "ACT_4"
    if "RM_ACT1" in t or "ACT_ALLOWLIST_ACT1" in t:
        return "ACT_1"
    return "ACT_UNKNOWN"


def summarize(group_key: str, items: List[Dict[str, str]]) -> Dict[str, str]:
    total = len(items)
    concluido = sum(1 for x in items if (x.get("Status", "").strip().upper() == "CONCLUIDO"))
    backlog = sum(1 for x in items if (x.get("Status", "").strip().upper() == "BACKLOG"))
    done_pct = (concluido / total * 100.0) if total else 0.0
    return {
        "key": group_key,
        "total": str(total),
        "concluido": str(concluido),
        "backlog": str(backlog),
        "done_pct": f"{done_pct:.1f}",
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--qa", required=True, help="Path to extracted RM_QA module folder.")
    args = ap.parse_args(argv)

    qa_root = args.qa
    log_path = os.path.join(qa_root, "DATA", "QA", "LOG_AJUSTES.csv")
    act1_cov_path = os.path.join(qa_root, "DATA", "QA", "RPT_ACT1_COVERAGE.csv")
    trace_path = os.path.join(qa_root, "DATA", "QA", "RPT_TRACEABILITY_VALIDATION.csv")

    if not os.path.exists(log_path):
        raise SystemExit(f"Missing LOG_AJUSTES.csv at {log_path}")

    log = read_csv(log_path)
    gen = utc_now()

    rows: List[Dict[str, str]] = []
    fieldnames = ["dimension", "key", "total", "concluido", "backlog", "done_pct", "notes", "generated_utc"]

    # ETID grouping
    et_groups: Dict[str, List[Dict[str, str]]] = {}
    for r in log:
        k = (r.get("ETID", "") or "").strip() or "(none)"
        et_groups.setdefault(k, []).append(r)
    for k, items in sorted(et_groups.items(), key=lambda kv: kv[0]):
        s = summarize(k, items)
        rows.append({
            "dimension": "ETID",
            **s,
            "notes": "",
            "generated_utc": gen,
        })

    # ACT grouping (heuristic)
    act_groups: Dict[str, List[Dict[str, str]]] = {}
    for r in log:
        k = act_bucket(r.get("Titulo", ""), r.get("Descricao", ""))
        act_groups.setdefault(k, []).append(r)
    for k, items in sorted(act_groups.items(), key=lambda kv: kv[0]):
        s = summarize(k, items)
        rows.append({
            "dimension": "ACT",
            **s,
            "notes": "heuristic",
            "generated_utc": gen,
        })

    # ACT1 required checks (if present)
    if os.path.exists(act1_cov_path):
        cov = read_csv(act1_cov_path)
        required = [x for x in cov if (x.get("required", "").strip().upper() == "Y")]
        required_total = len(required)
        required_pass = sum(1 for x in required if (x.get("status", "").strip().upper() == "PASS"))
        pct = (required_pass / required_total * 100.0) if required_total else 0.0
        rows.append({
            "dimension": "ACT_REPORT",
            "key": "ACT_1_REQUIRED_CHECKS",
            "total": str(required_total),
            "concluido": str(required_pass),
            "backlog": str(required_total - required_pass),
            "done_pct": f"{pct:.1f}",
            "notes": "from RPT_ACT1_COVERAGE required=Y (PASS count)",
            "generated_utc": gen,
        })

    # Traceability FAIL count (if present)
    if os.path.exists(trace_path):
        tv = read_csv(trace_path)
        fails = [x for x in tv if (x.get("status", "").strip().upper() == "FAIL")]
        total = len(tv)
        failc = len(fails)
        pct = ((total - failc) / total * 100.0) if total else 0.0
        rows.append({
            "dimension": "ACT_REPORT",
            "key": "TRACEABILITY_NON_FAIL_ROWS",
            "total": str(total),
            "concluido": str(total - failc),
            "backlog": str(failc),
            "done_pct": f"{pct:.1f}",
            "notes": "from RPT_TRACEABILITY_VALIDATION (non-FAIL row ratio)",
            "generated_utc": gen,
        })

    out_path = os.path.join(qa_root, "DATA", "QA", "RPT_COVERAGE_ACT_ET.csv")
    write_csv(out_path, rows, fieldnames)
    print(f"Wrote {out_path} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
