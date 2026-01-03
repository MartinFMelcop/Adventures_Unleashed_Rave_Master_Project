# Ingest ART bundle (binary)

This document describes how to populate `sha256`, `bytes`, and `width/height` in:

- `RM_CORE/DATA/CORE/ART_IMAGE_ASSET_INDEX.csv`

from a real bundle stored in:

- `RM_ART/BUNDLES/*.zip`

## Command

```bash
python DATA/QA/TOOLS/ingest_art_index_from_bundle_binary.py \
  --bundle_id ART_BUNDLE_0001 \
  --bundle_zip RM_ART/BUNDLES/ART_BUNDLE_0001_LEGACY_GRAPHICS.zip \
  --core_index_csv RM_CORE/DATA/CORE/ART_IMAGE_ASSET_INDEX.csv \
  --license INTERNAL_LEGACY_IMPORT
```

## Notes

- Natural key: `(Bundle, RelativePath)`
- Default behavior: fills missing fields; use `--force` to overwrite existing values.
- Only image files are ingested: png/jpg/jpeg/webp/bmp/gif
