#!/usr/bin/env python3
"""Ingest ART image index from an external bundle inventory CSV.

Purpose
- Convert an external bundle inventory (like EXTERNAL_BUNDLE_INVENTORY__LEGACY_BUNDLE_0002.csv)
  into rows for DATA/CORE/ART_IMAGE_ASSET_INDEX.csv.

This tool does NOT require the binary images; it can emit inventory-only rows with Status=EXTERNAL_PENDING.

Usage
  python ingest_art_index_from_bundle_inventory.py \
    --inventory_csv DATA/QA/EXTERNAL_BUNDLE_INVENTORY__LEGACY_BUNDLE_0002.csv \
    --out_csv DATA/CORE/ART_IMAGE_ASSET_INDEX.csv \
    --bundle_id LEGACY_BUNDLE_0002 \
    --asset_prefix IMG-LB0002-

Notes
- If you later have the binary bundle available (RM_ART/BUNDLES), run a "binary enrich" step
  to compute sha256 + width/height.
"""

import argparse
import csv
import datetime
from pathlib import Path

IMG_EXTS = {'.jpg', '.jpeg', '.png', '.webp'}

def utc_now():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--inventory_csv', required=True)
    ap.add_argument('--out_csv', required=True)
    ap.add_argument('--bundle_id', default='LEGACY_BUNDLE_0002')
    ap.add_argument('--asset_prefix', default='IMG-LB0002-')
    args = ap.parse_args()

    inv_path = Path(args.inventory_csv)
    out_path = Path(args.out_csv)

    if not inv_path.exists():
        raise SystemExit(f"Inventory CSV not found: {inv_path}")

    rows = []
    with inv_path.open('r', encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f)
        for r in reader:
            ext = (r.get('FileExt') or '').lower()
            if ext not in IMG_EXTS:
                continue
            rows.append(r)

    rows.sort(key=lambda r: r.get('PathInArchive',''))

    now = utc_now()
    out_fields = [
        'AssetID','RelativePath','Bundle','Sha256','Bytes','Width','Height','Format','Tags',
        'SourceRefID','License','ExternalPointer','Status','Notes','CriadoUTC','AtualizadoUTC'
    ]

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('w', encoding='utf-8', newline='') as f:
        w = csv.DictWriter(f, fieldnames=out_fields)
        w.writeheader()
        for i, r in enumerate(rows, start=1):
            asset_id = f"{args.asset_prefix}{i:04d}"
            rel = r.get('PathInArchive','')
            archive = r.get('ArchiveFilename','')
            size = int(float(r.get('FileSizeBytes') or 0))
            ext_clean = ext.lstrip('.')
            w.writerow({
                'AssetID': asset_id,
                'RelativePath': rel,
                'Bundle': args.bundle_id,
                'Sha256': '',
                'Bytes': size,
                'Width': '',
                'Height': '',
                'Format': ext_clean,
                'Tags': '',
                'SourceRefID': archive,
                'License': '',
                'ExternalPointer': f"{args.bundle_id}::{archive}::{rel}",
                'Status': 'EXTERNAL_PENDING',
                'Notes': 'Inventory-only row from external bundle; sha256/dimensions pending ingest.',
                'CriadoUTC': now,
                'AtualizadoUTC': now
            })

    print(f"Wrote {len(rows)} inventory-only asset rows -> {out_path}")

if __name__ == '__main__':
    main()
