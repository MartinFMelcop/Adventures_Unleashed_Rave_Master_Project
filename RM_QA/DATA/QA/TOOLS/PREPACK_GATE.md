# Pre-Packaging Gate (CI/local)

**Goal:** block packaging/builds when integrity or traceability contracts fail.

## What it checks
- `manifest.json` matches file **bytes + sha256**
- `checksums.sha256` matches file **sha256**
- `DATA/DATA_INDEX.csv` matches sheet CSV **sha256/bytes + row/col counts**
- `DATA/sheet_name_map.json` is consistent with `DATA_INDEX`
- If present in the module:
  - `DATA/QA/RPT_TRACEABILITY_VALIDATION.csv` must have **zero FAIL**
  - `DATA/QA/RPT_ACT1_COVERAGE.csv` must have **all required=Y PASS**
  - `DATA/QA/TEST_SCENARIOS_DIALOGUE.csv` (QA) requires `DATA/QA/RPT_DIALOGUE_SCENARIO_RUNNER.csv` with **PASS=TRUE** (unless skipped)

## How to run (local)
```bash
python DATA/QA/TOOLS/prepack_gate_validate.py RM_CORE RM_ACT1 RM_QA RM_ART RM_LEGACY
```

## Output files (optional)
- `--json-out gate.json` writes a structured summary (status + findings)
- `--md-out gate.md` writes a Markdown summary (handy for PR comments)

Example:
```bash
python DATA/QA/TOOLS/prepack_gate_validate.py --md-out gate_RM_QA.md RM_QA
```

## How to integrate in CI
- Call the script before any “publish artifact” step.
- Treat **exit code != 0** as a hard failure.
- Template workflows live in `DATA/QA/CI/`.

## Notes
- This is the **gate** only. Generating the reports (ex.: `RPT_TRACEABILITY_VALIDATION`) happens in earlier pipeline steps.
- Version: **AJ_000243** (2025-12-27)
