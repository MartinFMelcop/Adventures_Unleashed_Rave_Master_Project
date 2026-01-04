#!/usr/bin/env python3
"""
local_test_assembler.py
Build local-test folder from RM modules.

Goal:
- Create a runnable RPG Maker XP folder (RMXP_BASE) with up-to-date:
  - ScriptsCustom (from RM_ACT1/DATA/DEV/RGSS)
  - Data/RM_CSV (from RM_CORE/DATA/CORE + RM_ACT1/DATA/CORE + RM_ACT1/DATA/DEV)
  - Optional assets overlays if present

Usage (from repo root):
  python RM_DIST/TOOLS/local_test_assembler.py --out ./_local_test

Assumes folders at repo root:
  RM_DIST/  RM_CORE/  RM_ACT1/

This tool is "best effort": it won't crash the build on missing optional files.
"""

import argparse, os, shutil, hashlib, json
from pathlib import Path
from datetime import datetime, timezone

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def copy_tree(src: Path, dst: Path):
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)

def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)

def copy_csvs(src_dir: Path, out_csv_dir: Path):
    if not src_dir.exists():
        return
    for csvp in src_dir.rglob("*.csv"):
        rel = csvp.name
        shutil.copy2(csvp, out_csv_dir / rel)


def capture_saves(out_dir: Path):
    saved = []
    if not out_dir.exists():
        return saved
    for save in out_dir.glob("Save*.lsd"):
        saved.append((save.name, save.read_bytes()))
    return saved


def restore_saves(out_dir: Path, saves):
    for name, data in saves:
        (out_dir / name).write_bytes(data)


def check_integrity(module_dir: Path):
    missing = []
    for fname in ("manifest.json", "checksums.sha256"):
        if not (module_dir / fname).exists():
            missing.append(fname)
    return missing


def write_report(out_dir: Path, payload: dict):
    ensure_dir(out_dir)
    report_path = out_dir / "local_test_report.json"
    payload["generated_utc"] = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    report_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return report_path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Output folder for local test project")
    ap.add_argument("--dist", default="RM_DIST", help="Path to RM_DIST module root")
    ap.add_argument("--core", default="RM_CORE", help="Path to RM_CORE module root")
    ap.add_argument("--act1", default="RM_ACT1", help="Path to RM_ACT1 module root")
    ap.add_argument("--preserve-saves", action="store_true", help="Keep existing Save*.lsd from previous build")
    args = ap.parse_args()

    dist = Path(args.dist)
    core = Path(args.core)
    act1 = Path(args.act1)
    out = Path(args.out)

    base = dist / "RMXP_BASE"
    if not base.exists():
        raise SystemExit(f"RMXP_BASE not found: {base}")

    preflight = {}
    for module in (dist, core, act1):
        missing = check_integrity(module)
        if missing:
            preflight[module.name] = {"missing": missing}

    preserved_saves = capture_saves(out) if args.preserve_saves else []

    print(f"[1/4] Copy RMXP_BASE -> {out}")
    copy_tree(base, out)
    if preserved_saves:
        restore_saves(out, preserved_saves)

    print("[2/4] Sync ScriptsCustom from ACT1/DATA/DEV/RGSS")
    scripts_src = act1 / "DATA" / "DEV" / "RGSS"
    scripts_dst = out / "ScriptsCustom"
    ensure_dir(scripts_dst)
    for rb in scripts_src.glob("*.rb"):
        shutil.copy2(rb, scripts_dst / rb.name)
    for fn in ["RGSS_PACK_MANIFEST.json", "RGSS_PACK_ORDER.csv"]:
        p = scripts_src / fn
        if p.exists():
            shutil.copy2(p, scripts_dst / fn)

    print("[3/4] Build Data/RM_CSV from CORE+ACT1")
    csv_dst = out / "Data" / "RM_CSV"
    ensure_dir(csv_dst)

    copy_csvs(core / "DATA" / "CORE", csv_dst)
    copy_csvs(act1 / "DATA" / "CORE", csv_dst)
    copy_csvs(act1 / "DATA" / "DEV", csv_dst)

    print("[4/4] Done.")
    print(f"ScriptsCustom: {len(list((out/'ScriptsCustom').glob('*.rb')))} scripts")
    print(f"RM_CSV: {len(list(csv_dst.glob('*.csv')))} csvs")
    print("Tip: run rgss_pack.rb (in RM_DIST/TOOLS) to embed scripts into Scripts.rxdata if needed.")

    report = {
        "preflight": preflight,
        "output": {
            "scripts": len(list((out / "ScriptsCustom").glob("*.rb"))),
            "csvs": len(list(csv_dst.glob("*.csv"))),
            "preserved_saves": [name for name, _ in preserved_saves],
        },
        "sources": {
            "dist": str(dist),
            "core": str(core),
            "act1": str(act1),
        },
    }
    report_path = write_report(out, report)
    print(f"Report: {report_path}")

if __name__ == "__main__":
    main()
