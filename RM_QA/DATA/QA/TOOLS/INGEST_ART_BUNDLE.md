# Ingest ART bundle inventory -> ART_IMAGE_ASSET_INDEX

This module uses *index-first* art governance: binaries may live in `RM_ART`, but the canonical list is the CSV index.

## Input
- `DATA/QA/EXTERNAL_BUNDLE_INVENTORY__LEGACY_BUNDLE_0002.csv` (example)

## Output
- `DATA/CORE/ART_IMAGE_ASSET_INDEX.csv`

## Command
```bash
python DATA/QA/TOOLS/ingest_art_index_from_bundle_inventory.py \
  --inventory_csv DATA/QA/EXTERNAL_BUNDLE_INVENTORY__LEGACY_BUNDLE_0002.csv \
  --out_csv DATA/CORE/ART_IMAGE_ASSET_INDEX.csv \
  --bundle_id LEGACY_BUNDLE_0002 \
  --asset_prefix IMG-LB0002-
```

## Next step (future AJ)
When binary bundles are available, enrich the index with:
- `Sha256`
- `Width`, `Height`
- optional auto-tags (folder-based)
