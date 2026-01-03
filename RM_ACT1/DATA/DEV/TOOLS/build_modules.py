#!/usr/bin/env python3
"""
RM build_modules - deterministic module ZIP builder.

Goal
- Split a monolithic RM_project_files snapshot into deterministic module ZIPs:
  RM_CORE, RM_ACT1, RM_QA, RM_LEGACY
- Generate per-module: manifest.json + checksums.sha256
- Generate root: manifest_modules.json

This script is intentionally stdlib-only.

Usage (example)
  python build_modules.py --root ./RM_project_files --out ./out_modules --version_aj AJ_000219

Notes
- Module layout is loaded from DATA/GOV/BUNDLE_SCALING_PLAN.json
- RM_ACT1 currently depends on allowlists/tags; by default it exports DATA/DEV/*
"""
from __future__ import annotations
import argparse, hashlib, json, os, shutil, zipfile
from pathlib import Path
from datetime import datetime, timezone

VIRTUAL_PREFIX = "RM_project_files/"

def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def list_files(root: Path):
    for p in root.rglob("*"):
        if p.is_file():
            yield p

def write_manifest_and_checksums(module_root: Path):
    files = []
    for p in sorted(list_files(module_root), key=lambda x: x.as_posix()):
        rel = p.relative_to(module_root).as_posix()
        files.append({"path": rel, "bytes": p.stat().st_size, "sha256": sha256_file(p)})
    (module_root / "manifest.json").write_text(json.dumps({"files": files}, indent=2), encoding="utf-8")

    lines = []
    for f in files:
        lines.append(f'{f["sha256"]}  {VIRTUAL_PREFIX}{f["path"]}')
    (module_root / "checksums.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")

def zip_dir(src_dir: Path, zip_path: Path):
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(list_files(src_dir), key=lambda x: x.as_posix()):
            z.write(p, p.relative_to(src_dir).as_posix())

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="Path to monolithic snapshot root (folder containing DATA/, LEGACY/, etc.)")
    ap.add_argument("--out", required=True, help="Output folder for module zips")
    ap.add_argument("--version_aj", required=True, help="Adjustment id used as module version (e.g., AJ_000219)")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    policy_path = root / "DATA" / "GOV" / "BUNDLE_SCALING_PLAN.json"
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    layout = {m["module_id"]: m for m in policy["module_layout"]}

    def copy_scope(dst: Path, scope: list[str]):
        for s in scope:
            # allow simple dir patterns (no glob; keep deterministic)
            src = root / s
            if src.exists():
                if src.is_dir():
                    shutil.copytree(src, dst / s, dirs_exist_ok=True)
                else:
                    (dst / s).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst / s)

    modules = []
    order = ["RM_CORE", "RM_ACT1", "RM_QA", "RM_LEGACY"]
    for module_id in order:
        mdir = out / module_id
        if mdir.exists():
            shutil.rmtree(mdir)
        mdir.mkdir(parents=True, exist_ok=True)

        if module_id == "RM_ACT1":
            # current default export
            copy_scope(mdir, ["DATA/DEV"])
        else:
            copy_scope(mdir, layout[module_id]["scope"])

        write_manifest_and_checksums(mdir)
        zip_path = out / f"{module_id}_{args.version_aj}.zip"
        zip_dir(mdir, zip_path)

        modules.append({
            "module_id": module_id,
            "version_aj": args.version_aj,
            "zip_filename": zip_path.name,
            "zip_sha256": sha256_file(zip_path),
            "size_bytes": zip_path.stat().st_size,
            "required_order": order.index(module_id) + 1
        })

    manifest_modules = {
        "schema_version": 1,
        "generated_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "modules": modules
    }
    (out / "manifest_modules.json").write_text(json.dumps(manifest_modules, indent=2), encoding="utf-8")

if __name__ == "__main__":
    main()
