# MODULE_WORKFLOW (multi-bundle delivery)

## Purpose
Enable deterministic delivery of the RM dataset/game pipeline as multiple ZIP modules when the snapshot becomes too large for reliable upload/download or tool processing.

**Canonical truth remains `DATA/*`.** Human artifacts remain read-only.

## Module set (current policy)
Modules are defined by `DATA/GOV/BUNDLE_SCALING_PLAN.json`.

- `RM_CORE`: `DATA/CORE` + `DATA/GOV` (+ `README_RM_MAIN.md`)
- `RM_ACT1`: Act 1 working set (initially `DATA/DEV/*`; later filtered by `ACT_1` tags/allowlist)
- `RM_QA`: `DATA/QA/*` (logs + reports)
- `RM_LEGACY`: `LEGACY/*` + `HUMAN/*` (reference docs/media + digests)

## Root contract
When operating in multi-bundle mode, the root bundle MUST include:
- `manifest_modules.json` (root module registry: sha256/size/version/order)
- `DATA/GOV/BUNDLE_SCALING_PLAN.json` (policy)
- `DATA/QA/LOG_AJUSTES.csv` and `DATA/QA/CHANGE_LOG.csv` (audit trail)

## Determinism rules
For each module ZIP:
- Include `manifest.json` listing every file in the module with `bytes` + `sha256`.
- Include `checksums.sha256` for every file in the module (one line per file).
- Paths inside `checksums.sha256` use the virtual prefix `RM_project_files/` to match historical convention.
- Rebuild only the modules touched by an adjustment ("minimal change rule"), then update `manifest_modules.json`.

## How to execute an adjustment in module-only mode
1) Identify affected module(s) by file paths in `LOG_AJUSTES.WorkbooksImpactados / SheetsImpactadas`.
2) Apply the change ONLY inside the affected module working directory.
3) Rebuild that module ZIP (`manifest.json` + `checksums.sha256` + zip file).
4) Update root `manifest_modules.json` with new sha256/size/version for the module.
5) Append `CHANGE_LOG` and update `LOG_AJUSTES` (status, evidence, future improvements).
6) Run QA validation:
   - `RPT_MODULES_VALIDATION.csv` shows sha256/size and basic consistency checks.

## RM_ACT1 allowlist (implemented)

Act 1 isolation is governed by **two layers**:

1) **File-level allowlist** (module packaging):
- `DATA/GOV/ACT_ALLOWLIST_ACT1.csv`

2) **Entity-level tags** (subset selection inside tables):
- `RM_ACT1/DATA/DEV/ACT_ENTITY_TAGS.csv`
- `RM_ACT1/DATA/DEV/EXPORT_TAGS.csv` now points to `ACT_ENTITY_TAGS` via `ENTITY_MAP` rules (the previous `FILE_PATTERN` bootstrap rules are **DEPRECATED**).

The allowlist defines which files can ship in the `RM_ACT1` bundle.  
The entity tags define which **IDs** (chunks/quests/npcs/etc.) are considered part of Act 1 for exporters/consumers.

**Current policy (bootstrap stage):**
- `RM_ACT1` still ships the DEV working set, but **selection must move to entity-level** as tooling is updated.
- `RM_CORE` remains the canonical source for shared dictionaries; Act 1 should reference `RM_CORE` at runtime unless explicitly exporting a minimal subset.

**Tooling expectation:**
- Module export scripts read `ACT_ALLOWLIST_ACT1.csv` to produce a stable file list.
- Export/consumer scripts should read `ACT_ENTITY_TAGS.csv` to filter entity rows by ID (pending full implementation; tracked in `AJ_000238`).
- Any missing required rules or missing entity-tag artifacts must be reported in QA (`RPT_ACT1_COVERAGE`).


## Assembly order (recommended)
1. RM_CORE
2. RM_ACT1 (overrides/additions)
3. RM_QA (logs/reports; optional at runtime)
4. RM_LEGACY (optional)

## Backward compatibility
Single-snapshot mode remains valid: all modules may be embedded as a full monolithic ZIP.
Multi-bundle mode is preferred when size/transfer reliability triggers are hit.
