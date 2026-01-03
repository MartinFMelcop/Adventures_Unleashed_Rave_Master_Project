#!/usr/bin/env python3
"""Ingest ART image metadata (sha256/bytes/dimensions) from a binary bundle (.zip).

Usage example (run from repo root):
  python DATA/QA/TOOLS/ingest_art_index_from_bundle_binary.py \
    --bundle_id ART_BUNDLE_0001 \
    --bundle_zip RM_ART/BUNDLES/ART_BUNDLE_0001_LEGACY_GRAPHICS.zip \
    --core_index_csv RM_CORE/DATA/CORE/ART_IMAGE_ASSET_INDEX.csv

Notes:
- The script treats (Bundle, RelativePath) as the natural key.
- It will fill missing Sha256/Bytes/Width/Height/Format, or update them if --force is used.
- It will create new rows if a (Bundle, RelativePath) does not exist.
"""
import argparse
import hashlib
import os
import pathlib
import zipfile
from datetime import datetime, timezone
from io import BytesIO

import pandas as pd
from PIL import Image

IMG_EXT = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"}

def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()

def is_image(path_in_zip: str) -> bool:
    return pathlib.Path(path_in_zip).suffix.lower() in IMG_EXT

def infer_format(path_in_zip: str) -> str:
    return pathlib.Path(path_in_zip).suffix.lower().lstrip(".")

def read_dims(b: bytes):
    im = Image.open(BytesIO(b))
    return im.size  # (w, h)

def next_asset_id(existing_ids, bundle_id: str, seq_start: int = 1) -> str:
    # Example: ART_BUNDLE_0001 -> AB0001
    m = "".join([c for c in bundle_id if c.isalnum()])
    short = m.replace("ARTBUNDLE", "AB").replace("ART_BUNDLE_", "AB").replace("BUNDLE", "BD")
    prefix = f"IMG-{short}-"
    i = seq_start
    while True:
        aid = f"{prefix}{i:04d}"
        if aid not in existing_ids:
            return aid
        i += 1

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bundle_id", required=True)
    ap.add_argument("--bundle_zip", required=True)
    ap.add_argument("--core_index_csv", required=True)
    ap.add_argument("--license", default="INTERNAL")
    ap.add_argument("--source_refid", default="")
    ap.add_argument("--force", action="store_true", help="overwrite existing sha/dims even if present")
    args = ap.parse_args()

    now = utc_now()

    if not os.path.exists(args.bundle_zip):
        raise SystemExit(f"Bundle not found: {args.bundle_zip}")
    if not os.path.exists(args.core_index_csv):
        raise SystemExit(f"Core index not found: {args.core_index_csv}")

    idx = pd.read_csv(args.core_index_csv)
    required_cols = [
        "AssetID","RelativePath","Bundle","Sha256","Bytes","Width","Height","Format",
        "Tags","SourceRefID","License","ExternalPointer","Status","Notes","CriadoUTC","AtualizadoUTC"
    ]
    for c in required_cols:
        if c not in idx.columns:
            raise SystemExit(f"Missing required column in index: {c}")

    existing_ids = set(idx["AssetID"].astype(str))
    key_cols = ["Bundle", "RelativePath"]

    new_rows = []
    with zipfile.ZipFile(args.bundle_zip, "r") as z:
        for name in z.namelist():
            if not is_image(name):
                continue
            b = z.read(name)
            sha = sha256_bytes(b)
            size = len(b)
            w, h = read_dims(b)
            fmt = infer_format(name)

            m = (idx["Bundle"] == args.bundle_id) & (idx["RelativePath"] == name)
            if m.any():
                # fill / update existing
                row_i = idx.index[m][0]
                if args.force or pd.isna(idx.at[row_i, "Sha256"]):
                    idx.at[row_i, "Sha256"] = sha
                if args.force or pd.isna(idx.at[row_i, "Bytes"]):
                    idx.at[row_i, "Bytes"] = size
                if args.force or pd.isna(idx.at[row_i, "Width"]):
                    idx.at[row_i, "Width"] = w
                if args.force or pd.isna(idx.at[row_i, "Height"]):
                    idx.at[row_i, "Height"] = h
                if args.force or pd.isna(idx.at[row_i, "Format"]):
                    idx.at[row_i, "Format"] = fmt
                if args.force or (not isinstance(idx.at[row_i, "License"], str)) or (idx.at[row_i, "License"] == ""):
                    idx.at[row_i, "License"] = args.license
                if args.source_refid and (args.force or (not isinstance(idx.at[row_i, "SourceRefID"], str)) or (idx.at[row_i, "SourceRefID"] == "")):
                    idx.at[row_i, "SourceRefID"] = args.source_refid
                idx.at[row_i, "AtualizadoUTC"] = now
                if (not isinstance(idx.at[row_i, "Status"], str)) or (idx.at[row_i, "Status"] == ""):
                    idx.at[row_i, "Status"] = "ACTIVE"
            else:
                aid = next_asset_id(existing_ids, args.bundle_id, seq_start=len(existing_ids)+1)
                existing_ids.add(aid)
                new_rows.append({
                    "AssetID": aid,
                    "RelativePath": name,
                    "Bundle": args.bundle_id,
                    "Sha256": sha,
                    "Bytes": size,
                    "Width": w,
                    "Height": h,
                    "Format": fmt,
                    "Tags": "",
                    "SourceRefID": args.source_refid,
                    "License": args.license,
                    "ExternalPointer": "",
                    "Status": "ACTIVE",
                    "Notes": "Ingested from RM_ART bundle (binary).",
                    "CriadoUTC": now,
                    "AtualizadoUTC": now,
                })

    if new_rows:
        idx = pd.concat([idx, pd.DataFrame(new_rows)], ignore_index=True)

    idx.to_csv(args.core_index_csv, index=False)
    print(f"OK: updated {args.core_index_csv} (added={len(new_rows)})")

if __name__ == "__main__":
    main()
