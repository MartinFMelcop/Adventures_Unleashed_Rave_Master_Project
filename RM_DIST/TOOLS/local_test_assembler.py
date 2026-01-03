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

import argparse, os, shutil, hashlib
from pathlib import Path

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

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="Output folder for local test project")
    ap.add_argument("--dist", default="RM_DIST", help="Path to RM_DIST module root")
    ap.add_argument("--core", default="RM_CORE", help="Path to RM_CORE module root")
    ap.add_argument("--act1", default="RM_ACT1", help="Path to RM_ACT1 module root")
    args = ap.parse_args()

    dist = Path(args.dist)
    core = Path(args.core)
    act1 = Path(args.act1)
    out = Path(args.out)

    base = dist / "RMXP_BASE"
    if not base.exists():
        raise SystemExit(f"RMXP_BASE not found: {base}")

    print(f"[1/4] Copy RMXP_BASE -> {out}")
    copy_tree(base, out)

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

if __name__ == "__main__":
    main()
