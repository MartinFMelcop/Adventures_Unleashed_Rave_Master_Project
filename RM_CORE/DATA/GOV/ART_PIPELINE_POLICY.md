# ART pipeline policy (image-only)

**Status:** DRAFT  
**Scope:** Pixel art / UI sprites / icons / portraits.  
**Applies to:** any image file used by the project, whether stored inside a bundle or referenced externally.

## Source of truth

The source of truth for image assets is the **index**:

- `DATA/CORE/ART_IMAGE_ASSET_INDEX.csv`

The project may store actual image binaries in:
- a future `RM_ART` bundle (recommended), **or**
- external bundles referenced via `ExternalPointer`, **or**
- (temporarily) a module folder, if size limits allow.

Regardless of storage, the index is mandatory.

## Index columns (minimum contract)

- `AssetID` (unique)
- `RelativePath` (path inside bundle, e.g. `ART/portraits/NPC-0001.png`)
- `PathNormalized` (lowercase + spaces→"_"; used for lint/dedupe without changing the source path)
- `Bundle` (e.g. `RM_ART`, `RM_ACT1`, `RM_CORE`, `EXTERNAL`)
- `Sha256` (sha256 of the image bytes)
- `Bytes`, `Width`, `Height`, `Format`
- `Tags` (semicolon-separated, e.g. `portrait;npc;rose_arc`)
- `SourceRefID` (optional link to `REFERENCIAS_MASTER.RefID`)
- `License` (e.g. `INTERNAL`, `CC0`, `CC-BY-4.0`)
- `ExternalPointer` (optional; if image is not shipped inside bundles)
- `Status` (`ACTIVE`, `REMOVED`, `EXTERNAL_PENDING`)
- `Notes`, `CriadoUTC`, `AtualizadoUTC`

## ExternalPointer conventions

Use one of:

- `LEGACY_BUNDLE:<bundle_id>::<inner_path>`  
  where `<bundle_id>` exists in `DATA/QA/LEGACY_BUNDLES.csv`

- `FILE:<relative_path_or_uri>`  
  for a local path outside the bundle system (temporary only)

## QA validation

QA generates:

- `DATA/QA/RPT_ART_ASSET_INDEX_VALIDATION.csv`

Rules (minimum):
- PASS if the index file exists and has the required columns.
- FAIL if `AssetID` duplicates exist.
- FAIL if a row with `Bundle != EXTERNAL` references a missing file (when that bundle includes binaries).

> Note: current bundles do not ship image binaries yet; validation is structural only.

### Auto-tag rules (AJ_000246)

During ingest/maintenance we auto-fill `Tags` and `PathNormalized` using deterministic prefixes:

- `RPG_ExperimentalIAAPP_LEGADO/Graphics/Icons` → `ui_icon;legacy_import`
- `RPG_ExperimentalIAAPP_LEGADO/Graphics/Titles` → `title_screen;legacy_import`
- `RPG_ExperimentalIAAPP_LEGADO/Graphics/Windowskins` → `ui_skin;legacy_import`
- `OVERLORD_LIGHTNOVELS/Light Novels/Illustrations` → `reference_illustration;legacy_bundle`

Do **not** edit these tags manually unless a follow-up AJ updates the rules; use `PathNormalized` for dedupe/lint.

