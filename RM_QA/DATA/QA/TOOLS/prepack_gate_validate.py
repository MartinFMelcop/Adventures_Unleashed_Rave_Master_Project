#!/usr/bin/env python3
"""
RM Pre-Packaging Gate (Traceability + Integrity)

This gate is meant to run in CI (or locally) before publishing module artifacts.
It FAILS the build when any enforced integrity/traceability contract fails.

Validated (per module)
A) Always:
   - manifest.json: listed files exist and match sha256 + bytes
   - checksums.sha256: listed files match sha256 (paths use RM_project_files/<relpath>)
B) When the module contains workbook exports (i.e., DATA/DATA_INDEX.csv exists):
   - DATA/DATA_INDEX.csv: every indexed CSV exists and matches sha256/bytes + row/col counts
   - DATA/sheet_name_map.json (if present): bijection with DATA_INDEX (wb+sheet -> csv_relpath)
C) Optional enforcement reports (if present):
   - DATA/QA/RPT_TRACEABILITY_VALIDATION.csv: zero FAIL
   - DATA/QA/RPT_ACT1_COVERAGE.csv: all required=Y must be PASS

Exit codes
- 0: PASS
- 1: FAIL

Usage
  python DATA/QA/TOOLS/prepack_gate_validate.py RM_QA_AJ_XXXXX.zip RM_CORE_AJ_XXXXX.zip
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import sys
import zipfile
import subprocess
import tempfile
import shutil
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

RM_PREFIX = "RM_project_files/"

@dataclass
class Finding:
    level: str   # "FAIL" or "WARN"
    module: str
    code: str
    message: str

def sha256_bytes(data: bytes) -> str:
    h = hashlib.sha256()
    h.update(data)
    return h.hexdigest()

class ModuleReader:
    """Reads either a zip or a directory with the same relative paths."""
    def __init__(self, module_path: str):
        self.module_path = module_path
        self.is_zip = module_path.lower().endswith(".zip")
        self._zip: Optional[zipfile.ZipFile] = None
        if self.is_zip:
            self._zip = zipfile.ZipFile(module_path, "r")

    def close(self):
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

    def read_bytes(self, relpath: str) -> bytes:
        if self.is_zip:
            return self._zip.read(relpath)
        with open(os.path.join(self.module_path, relpath), "rb") as f:
            return f.read()

def load_json(reader: ModuleReader, relpath: str) -> dict:
    return json.loads(reader.read_bytes(relpath).decode("utf-8"))

def parse_checksums(text: str) -> Dict[str, str]:
    """
    Returns {relpath_without_prefix: sha256}
    Lines format: "<sha>  RM_project_files/<path>"
    """
    out: Dict[str, str] = {}
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw or raw.startswith("#"):
            continue
        parts = raw.split(None, 1)
        if len(parts) < 2:
            continue
        sha = parts[0]
        path = parts[1].strip()
        if path.startswith(RM_PREFIX):
            path = path[len(RM_PREFIX):]
        out[path] = sha
    return out

def read_csv_shape(reader: ModuleReader, relpath: str) -> Tuple[int, int]:
    data = reader.read_bytes(relpath)
    s = data.decode("utf-8")
    r = list(csv.reader(io.StringIO(s)))
    if not r:
        return (0, 0)
    cols = len(r[0])
    rows = max(0, len(r) - 1)  # excluding header
    return rows, cols

def _to_int(v: str) -> int:
    # Many sheets export numeric columns as "123.0"
    try:
        return int(v)
    except Exception:
        return int(float(v))

def validate_module(module_path: str, skip_dialogue_scenarios: bool = False, skip_combat_vectors: bool = False) -> List[Finding]:
    findings: List[Finding] = []
    module_name = os.path.basename(module_path)

    r = ModuleReader(module_path)
    try:
        # Always required
        for req in ("manifest.json", "checksums.sha256", "MODULE_INFO.json"):
            if not r.exists(req):
                findings.append(Finding("FAIL", module_name, "REQ_MISSING", f"Missing required file: {req}"))
                return findings

        manifest = load_json(r, "manifest.json")
        if "files" not in manifest or not isinstance(manifest["files"], list):
            findings.append(Finding("FAIL", module_name, "MANIFEST_BAD", "manifest.json missing 'files' list"))
            return findings

        # A) manifest.json integrity
        for f in manifest["files"]:
            rel = f.get("relpath") or f.get("path")
            exp_bytes = f.get("bytes")
            exp_sha = f.get("sha256")
            if not isinstance(rel, str) or not isinstance(exp_bytes, int) or not isinstance(exp_sha, str):
                findings.append(Finding("FAIL", module_name, "MANIFEST_ENTRY_BAD", f"Bad manifest entry: {f!r}"))
                continue
            if not r.exists(rel):
                findings.append(Finding("FAIL", module_name, "MANIFEST_MISSING_FILE", f"Manifest lists missing file: {rel}"))
                continue
            data = r.read_bytes(rel)
            if len(data) != exp_bytes:
                findings.append(Finding("FAIL", module_name, "MANIFEST_BYTES_MISMATCH", f"{rel}: bytes {len(data)} != manifest {exp_bytes}"))
            got_sha = sha256_bytes(data)
            if got_sha != exp_sha:
                findings.append(Finding("FAIL", module_name, "MANIFEST_SHA_MISMATCH", f"{rel}: sha256 mismatch"))

        # A) checksums.sha256 integrity
        checks_txt = r.read_bytes("checksums.sha256").decode("utf-8")
        checks = parse_checksums(checks_txt)
        if not checks:
            findings.append(Finding("FAIL", module_name, "CHECKSUMS_EMPTY", "checksums.sha256 parsed empty"))
        else:
            for rel, exp_sha in checks.items():
                # checksums file does not list itself
                if rel == "checksums.sha256":
                    continue
                if not r.exists(rel):
                    findings.append(Finding("FAIL", module_name, "CHECKSUMS_MISSING_FILE", f"checksums has missing file: {rel}"))
                    continue
                got_sha = sha256_bytes(r.read_bytes(rel))
                if got_sha != exp_sha:
                    findings.append(Finding("FAIL", module_name, "CHECKSUMS_SHA_MISMATCH", f"{rel}: sha256 mismatch vs checksums.sha256"))

        # B) workbook/export traceability (only if DATA_INDEX exists)
        has_data_index = r.exists("DATA/DATA_INDEX.csv")
        has_sheet_map = r.exists("DATA/sheet_name_map.json")

        idx_rows: List[dict] = []
        if has_data_index:
            idx_text = r.read_bytes("DATA/DATA_INDEX.csv").decode("utf-8")
            idx_r = csv.DictReader(io.StringIO(idx_text))
            idx_rows = list(idx_r)
            required_cols = {"workbook_file", "sheet_name", "csv_relpath", "rows", "cols", "sha256", "size_bytes", "bytes", "sha256_of_csv"}
            if not required_cols.issubset(set(idx_r.fieldnames or [])):
                findings.append(Finding("FAIL", module_name, "DATA_INDEX_BAD", f"DATA_INDEX missing columns: {sorted(required_cols - set(idx_r.fieldnames or []))}"))
            else:
                for row in idx_rows:
                    rel = row["csv_relpath"]
                    if not r.exists(rel):
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_MISSING_FILE", f"DATA_INDEX row points to missing file: {rel}"))
                        continue
                    data = r.read_bytes(rel)
                    got_sha = sha256_bytes(data)
                    exp_sha = row["sha256"]
                    exp_sha2 = row.get("sha256_of_csv", "")
                    if got_sha != exp_sha or (exp_sha2 and got_sha != exp_sha2):
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_SHA_MISMATCH", f"{rel}: sha256 mismatch vs DATA_INDEX"))
                    try:
                        exp_b = _to_int(row["bytes"])
                        exp_sb = _to_int(row["size_bytes"])
                    except Exception:
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_BYTES_BAD", f"{rel}: bytes fields not numeric"))
                        continue
                    if len(data) != exp_b or len(data) != exp_sb:
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_BYTES_MISMATCH", f"{rel}: size {len(data)} != DATA_INDEX bytes({exp_b})/size_bytes({exp_sb})"))
                    # row/col counts
                    try:
                        exp_rows = _to_int(row["rows"])
                        exp_cols = _to_int(row["cols"])
                    except Exception:
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_DIM_BAD", f"{rel}: rows/cols not numeric"))
                        continue
                    got_rows, got_cols = read_csv_shape(r, rel)
                    if got_rows != exp_rows or got_cols != exp_cols:
                        findings.append(Finding("FAIL", module_name, "DATA_INDEX_DIM_MISMATCH", f"{rel}: ({got_rows}x{got_cols}) != DATA_INDEX ({exp_rows}x{exp_cols})"))

        if has_data_index and has_sheet_map:
            sm = load_json(r, "DATA/sheet_name_map.json")
            if not isinstance(sm, dict) or not sm:
                findings.append(Finding("FAIL", module_name, "SHEET_MAP_BAD", "sheet_name_map.json missing or not dict"))
            else:
                # Map -> ensure exists and is in DATA_INDEX
                for wb, mapping in sm.items():
                    if not isinstance(mapping, dict):
                        continue
                    for sheet, rel in mapping.items():
                        if not r.exists(rel):
                            findings.append(Finding("FAIL", module_name, "SHEET_MAP_MISSING_FILE", f"{wb}:{sheet} -> missing file: {rel}"))
                        if not any((rw.get("workbook_file") == wb and rw.get("sheet_name") == sheet and rw.get("csv_relpath") == rel) for rw in idx_rows):
                            findings.append(Finding("FAIL", module_name, "SHEET_MAP_NOT_IN_INDEX", f"{wb}:{sheet} -> {rel} not found in DATA_INDEX"))

                # DATA_INDEX -> ensure represented in map
                for row in idx_rows:
                    wb = row.get("workbook_file")
                    sheet = row.get("sheet_name")
                    rel = row.get("csv_relpath")
                    if not isinstance(wb, str) or not isinstance(sheet, str) or not isinstance(rel, str):
                        continue
                    mapped = sm.get(wb, {})
                    if not isinstance(mapped, dict) or mapped.get(sheet) != rel:
                        findings.append(Finding("FAIL", module_name, "INDEX_NOT_IN_SHEET_MAP", f"{wb}:{sheet} missing or mismatched in sheet_name_map"))

        # C) Optional enforcement reports
        if r.exists("DATA/QA/RPT_TRACEABILITY_VALIDATION.csv"):
            tv_text = r.read_bytes("DATA/QA/RPT_TRACEABILITY_VALIDATION.csv").decode("utf-8")
            tv = list(csv.DictReader(io.StringIO(tv_text)))
            fails = [rw for rw in tv if str(rw.get("status", "")).strip().upper() == "FAIL"]
            if fails:
                findings.append(Finding("FAIL", module_name, "TRACE_REPORT_FAIL", f"RPT_TRACEABILITY_VALIDATION has {len(fails)} FAIL row(s)"))

        if r.exists("DATA/QA/RPT_ACT1_COVERAGE.csv"):
            cov_text = r.read_bytes("DATA/QA/RPT_ACT1_COVERAGE.csv").decode("utf-8")
            cov = list(csv.DictReader(io.StringIO(cov_text)))
            required_fails = [
                rw for rw in cov
                if str(rw.get("required", "")).strip().upper() == "Y"
                and str(rw.get("status", "")).strip().upper() != "PASS"
            ]
            if required_fails:
                findings.append(Finding("FAIL", module_name, "ACT1_COVERAGE_FAIL", f"RPT_ACT1_COVERAGE has {len(required_fails)} required check(s) not PASS"))



        # D) Dialogue scenario runner (enforced when scenarios exist)
        if not skip_dialogue_scenarios and r.exists("DATA/QA/TEST_SCENARIOS_DIALOGUE.csv"):
            if not r.exists("DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv"):
                findings.append(Finding("FAIL", module_name, "DIALOGUE_SCENARIO_REPORT_MISSING",
                                        "QA has TEST_SCENARIOS_DIALOGUE but is missing RPT_DIALOGUE_SCENARIO_RUNNER"))
            else:
                rpt_text = r.read_bytes("DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv").decode("utf-8")
                rpt_rows = list(csv.DictReader(io.StringIO(rpt_text)))
                bad_rows = [rw for rw in rpt_rows if str(rw.get("PASS", "")).strip().upper() != "TRUE"]
                if bad_rows:
                    is_step_level = bool(rpt_rows) and ("StepIndex" in rpt_rows[0])
                    if is_step_level:
                        bad_scen = sorted({(rw.get("ScenarioID") or "") for rw in bad_rows if (rw.get("ScenarioID") or "").strip()})
                        findings.append(Finding("FAIL", module_name, "DIALOGUE_SCENARIO_FAIL",
                                                f"RPT_DIALOGUE_SCENARIO_RUNNER has {len(bad_scen)} scenario(s) with failing step(s)"))
                    else:
                        findings.append(Finding("FAIL", module_name, "DIALOGUE_SCENARIO_FAIL",
                                                f"RPT_DIALOGUE_SCENARIO_RUNNER has {len(bad_rows)} scenario(s) PASS=FALSE"))
        

        # Combat deterministic vectors (QA) — enforce runner report if tests exist
        if not skip_combat_vectors:
            combat_tests = [
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
            any_combat_tests = any(r.exists(p) for p in combat_tests)
            if any_combat_tests:
                if not r.exists("DATA/QA/RPT_COMBAT_VECTOR_RUNNER.csv"):
                    findings.append(Finding("FAIL", module_name, "COMBAT_VECTOR_REPORT_MISSING",
                                            "QA has TEST_COMBAT_* but is missing RPT_COMBAT_VECTOR_RUNNER"))
                else:
                    rpt_text = r.read_bytes("DATA/QA/RPT_COMBAT_VECTOR_RUNNER.csv").decode("utf-8")
                    rpt_rows = list(csv.DictReader(io.StringIO(rpt_text)))
                    bad = [rw for rw in rpt_rows if str(rw.get("PASS", "")).strip().upper() != "TRUE"]
                    if bad:
                        findings.append(Finding("FAIL", module_name, "COMBAT_VECTOR_FAIL",
                                                f"RPT_COMBAT_VECTOR_RUNNER has {len(bad)} failing check(s)"))

        # C) LOG_AJUSTES discipline (when present): AjusteID must be unique
        if r.exists("DATA/QA/LOG_AJUSTES.csv"):
            try:
                log_txt = r.read_bytes("DATA/QA/LOG_AJUSTES.csv").decode("utf-8")
                log_r = csv.DictReader(io.StringIO(log_txt))
                seen: set = set()
                dup: set = set()
                for row in log_r:
                    aid = (row.get("AjusteID") or "").strip()
                    if not aid:
                        continue
                    if aid in seen:
                        dup.add(aid)
                    seen.add(aid)
                if dup:
                    findings.append(Finding("FAIL", module_name, "LOG_AJUSTES_DUP_ID",
                                            f"LOG_AJUSTES has duplicated AjusteID(s): {sorted(dup)}"))
            except Exception as e:
                findings.append(Finding("WARN", module_name, "LOG_AJUSTES_READ_FAIL",
                                        f"Could not validate LOG_AJUSTES uniqueness: {e}"))
        return findings
    finally:
        r.close()

def _findings_to_json(all_findings: List[Finding]) -> Dict:
    fails = [f for f in all_findings if f.level == "FAIL"]
    warns = [f for f in all_findings if f.level == "WARN"]
    status = "FAIL" if fails else "PASS"
    return {
        "status": status,
        "fail_count": len(fails),
        "warn_count": len(warns),
        "findings": [
            {"level": f.level, "module": f.module, "code": f.code, "message": f.message}
            for f in all_findings
        ],
    }

def _render_markdown_summary(all_findings: List[Finding]) -> str:
    data = _findings_to_json(all_findings)
    status = data["status"]
    lines: List[str] = []
    lines.append(f"**PREPACK_GATE: {status}**")
    lines.append("")
    lines.append(f"- FAIL: **{data['fail_count']}**")
    lines.append(f"- WARN: **{data['warn_count']}**")
    lines.append("")
    # Group by module for readability
    by_module: Dict[str, List[Finding]] = {}
    for f in all_findings:
        by_module.setdefault(f.module, []).append(f)
    for module in sorted(by_module.keys()):
        lines.append(f"### {module}")
        items = by_module[module]
        if not items:
            lines.append("_No findings._")
            lines.append("")
            continue
        for f in items:
            emoji = "❌" if f.level == "FAIL" else "⚠️"
            lines.append(f"- {emoji} `{f.code}` — {f.message}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _read_module_id(module_path: str) -> str:
    try:
        r = ModuleReader(module_path)
        try:
            if not r.exists("MODULE_INFO.json"):
                return ""
            info = json.loads(r.read_bytes("MODULE_INFO.json").decode("utf-8"))
            return str(info.get("module_id") or "").strip()
        finally:
            r.close()
    except Exception:
        return ""


def _autorun_dialogue_runner_if_possible(modules: List[str]) -> None:
    """Best-effort: if QA is a directory and ACT1 is provided, generate the dialogue scenario report."""
    qa_paths = [m for m in modules if _read_module_id(m) == "RM_QA" and os.path.isdir(m)]
    act1_paths = [m for m in modules if _read_module_id(m) == "RM_ACT1"]
    if not qa_paths or not act1_paths:
        return
    act1_path = act1_paths[0]
    act1_is_zip = os.path.isfile(act1_path) and act1_path.lower().endswith(".zip")

    temp_dir = None
    act1_root = act1_path
    try:
        if act1_is_zip:
            temp_dir = tempfile.mkdtemp(prefix="rm_act1_extract_")
            with zipfile.ZipFile(act1_path, "r") as zf:
                zf.extractall(temp_dir)
            act1_root = temp_dir

        dv_path = os.path.join(act1_root, "DATA/DEV/DIALOGUE_VARIANTS.csv")
        for qa_path in qa_paths:
            scenarios_path = os.path.join(qa_path, "DATA/QA/TEST_SCENARIOS_DIALOGUE.csv")
            report_path = os.path.join(qa_path, "DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv")
            runner_path = os.path.join(qa_path, "DATA/QA/TOOLS/run_dialogue_scenario_runner.py")
            if not os.path.exists(scenarios_path) or not os.path.exists(runner_path) or not os.path.exists(dv_path):
                continue

            # Cache heuristic: rerun if report missing or older than inputs (only reliable for directories).
            force = act1_is_zip
            if not os.path.exists(report_path):
                force = True
            else:
                try:
                    rpt_m = os.path.getmtime(report_path)
                    src_m = max(os.path.getmtime(scenarios_path), os.path.getmtime(runner_path), os.path.getmtime(dv_path))
                    if rpt_m < src_m:
                        force = True
                except Exception:
                    force = True

            if not force:
                continue

            try:
                proc = subprocess.run([sys.executable, runner_path, "--qa-root", qa_path, "--act1-root", act1_root],
                                      capture_output=True, text=True)
                if proc.returncode != 0:
                    print("PREPACK_GATE: WARN (dialogue autorun): runner returned nonzero", file=sys.stderr)
                    if proc.stdout:
                        print(proc.stdout.strip(), file=sys.stderr)
                    if proc.stderr:
                        print(proc.stderr.strip(), file=sys.stderr)
            except Exception as e:
                print(f"PREPACK_GATE: WARN (dialogue autorun): {e}", file=sys.stderr)
    finally:
        if temp_dir:
            try:
                shutil.rmtree(temp_dir)
            except Exception:
                pass


def _autorun_combat_vector_runner_if_possible(modules: List[str]) -> None:
    """If possible (QA module is a folder), run combat vector runner to generate the report."""
    for m in modules:
        try:
            module_name = os.path.basename(m).replace(".zip", "")
            if "RM_QA" not in module_name:
                continue
            if m.lower().endswith(".zip"):
                continue
            qa_path = m
            tests_any = False
            for p in [
                "DATA/QA/TEST_COMBAT_HIT.csv",
                "DATA/QA/TEST_COMBAT_CRIT.csv",
                "DATA/QA/TEST_COMBAT_RAW.csv",
                "DATA/QA/TEST_COMBAT_MIT.csv",
                "DATA/QA/TEST_COMBAT_APPLY.csv",
                "DATA/QA/TEST_COMBAT_DUR.csv",
                "DATA/QA/TEST_COMBAT_DOT.csv",
                "DATA/QA/TEST_COMBAT_REAPPLY.csv",
                "DATA/QA/TEST_COMBAT_FINAL_DAMAGE.csv",
            ]:
                if os.path.exists(os.path.join(qa_path, p)):
                    tests_any = True
                    break
            if not tests_any:
                continue

            report_path = os.path.join(qa_path, "DATA/QA/RPT_COMBAT_VECTOR_RUNNER.csv")
            if os.path.exists(report_path):
                continue

            runner = os.path.join(qa_path, "DATA/QA/TOOLS/run_combat_vector_runner.py")
            if not os.path.exists(runner):
                continue

            import subprocess
            try:
                proc = subprocess.run([sys.executable, runner, qa_path], capture_output=True, text=True)
                if proc.returncode != 0:
                    print("PREPACK_GATE: WARN (combat autorun): runner returned nonzero", file=sys.stderr)
                    if proc.stdout:
                        print(proc.stdout.strip(), file=sys.stderr)
                    if proc.stderr:
                        print(proc.stderr.strip(), file=sys.stderr)
            except Exception as e:
                print(f"PREPACK_GATE: WARN (combat autorun): {e}", file=sys.stderr)
        except Exception:
            continue

def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-dialogue-scenarios", action="store_true",
                    help="Skip enforcement of dialogue scenario runner report (QA only).")
    ap.add_argument("--auto-run-dialogue-scenarios", action="store_true",
                    help="If possible (QA module is a folder), auto-run dialogue scenario runner to generate the report before enforcing it.")
    ap.add_argument("--skip-combat-vectors", action="store_true",
                    help="Skip enforcement of combat vector runner report (QA only).")
    ap.add_argument("--auto-run-combat-vectors", action="store_true",
                    help="If possible (QA module is a folder), auto-run combat vector runner to generate the report before enforcing it.")
    ap.add_argument("--json-out", default=None,
                    help="Write a JSON summary of findings to this path.")
    ap.add_argument("--md-out", default=None,
                    help="Write a Markdown summary of findings to this path (useful for PR comments).")
    ap.add_argument("modules", nargs="+", help="One or more module ZIPs (or extracted module folders).")
    args = ap.parse_args(argv)

    if args.auto_run_dialogue_scenarios:
        _autorun_dialogue_runner_if_possible(args.modules)

    if args.auto_run_combat_vectors:
        _autorun_combat_vector_runner_if_possible(args.modules)


    all_findings: List[Finding] = []
    for m in args.modules:
        all_findings.extend(validate_module(m, skip_dialogue_scenarios=args.skip_dialogue_scenarios, skip_combat_vectors=args.skip_combat_vectors))

    # Optional outputs
    try:
        if args.json_out:
            with open(args.json_out, "w", encoding="utf-8") as fh:
                json.dump(_findings_to_json(all_findings), fh, ensure_ascii=False, indent=2)
        if args.md_out:
            with open(args.md_out, "w", encoding="utf-8") as fh:
                fh.write(_render_markdown_summary(all_findings))
    except Exception as e:
        print(f"PREPACK_GATE: WARN (output write failed): {e}")

    fails = [f for f in all_findings if f.level == "FAIL"]
    warns = [f for f in all_findings if f.level == "WARN"]

    if fails:
        print("PREPACK_GATE: FAIL")
        for f in fails:
            print(f"[{f.module}] {f.code}: {f.message}")
        if warns:
            for f in warns:
                print(f"[{f.module}] {f.code}: {f.message}")
        return 1

    print("PREPACK_GATE: PASS")
    if warns:
        for f in warns:
            print(f"[{f.module}] {f.code}: {f.message}")
    return 0

if __name__ == "__main__":

    raise SystemExit(main())