# Traceability Contract (MER → Functional → Technical)

This bundle uses an explicit, machine-friendly traceability chain:

- **MER layer**: `DATA/GOV/MER_AI.csv`  
  - Key columns added by **AJ_000203**: `MER_ID`, `STAGE_ID`, `ACT_GATE`
- **Functional layer**: `DATA/GOV/SPEC_FUNC_AI.csv`  
  - Key columns added by **AJ_000203**: `func_id`, `trace_mer`, `stage_id`, `act_gate`
- **Technical layer**: `DATA/GOV/SPEC_TEC_AI.csv`  
  - Key columns reinforced by **AJ_000203**: `trace_mer`, `trace_func`, plus `stage_id`, `act_gate`

## Canonical formats

### MER references
- Technical specs reference MER items using: `MER_AI:<MER_ID>`
- `MER_ID` must exist in `MER_AI.MER_ID`.

### Functional references
- Technical specs reference functional items using: `SPEC_FUNC_AI:<FUNC_ID>`
- `FUNC_ID` must exist in `SPEC_FUNC_AI.func_id`.

### Derived map (single-source join)
- `DATA/GOV/TRACEABILITY_MAP.csv` is **derived** from `SPEC_TEC_AI.trace_*` and provides one row per technical spec.

## Acts and stages
- Stages are defined in `DATA/GOV/RM_DELIVERY_ROADMAP_AI.json`.
- `DATA/GOV/ACT_STAGE_MAP.csv` provides a stable mapping between **Stage IDs** and **Act gates**.

Generated UTC: 2025-12-25T21:15:13Z
