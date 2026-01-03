# MER_AI (AI-friendly Entity-Relationship scaffold)

**Purpose**: Provide a machine-friendly MER baseline to guide the pipeline:
MER AI-friendly → Functional Spec AI-friendly → Technical Spec AI-friendly → RPG Maker XP implementation → local executable tests (Act 1) → Steam publish (Act 4) → post-publish improvements.

**Generated (UTC)**: 2025-12-24T04:36:32Z

## Files
- `DATA/GOV/MER_AI.csv` (canonical table; indexed in `DATA/DATA_INDEX.csv` and mapped in `DATA/sheet_name_map.json`)
- This doc: `DATA/GOV/MER_AI.md` (how to interpret / next steps)

## How MER_AI.csv is derived (v1)
1. **Entities** are derived from every `DIC_*.csv` in `DATA/DEV` and `DATA/CORE`.
   - Each `DIC_*` file becomes an `ENTITY_TABLE`.
   - Each normalized base name becomes an `ENTITY_GROUP`.
2. **Relationships** are derived only when there is explicit evidence:
   - `*_ID` / `*ID` columns (e.g., `TipoPrimarioID`) produce `RELATIONSHIP` records with `RelationType=FK_INFERRED`.
   - `REL_*.csv` files produce `RELATIONSHIP` records with `RelationType=REL_TABLE`.
3. If a relationship points to an entity that **does not exist as `DIC_*` in this snapshot**, we register a **placeholder** `ENTITY_GROUP` (Status = `PENDING`) so future steps can model it explicitly.

## Interpretation guidelines
- `ENTITY_GROUP` = conceptual bucket (what the game *is* about).
- `ENTITY_TABLE` = concrete CSV table currently in the dataset.
- `RELATIONSHIP` = evidence-backed link between groups/tables.
- Status meanings:
  - `CONFIRMED`: entity table exists as `DIC_*`
  - `INFERRED`: relationship inferred from ID naming (needs validation)
  - `PENDING`: placeholder/unmodeled (needs an explicit table)

## Next recommended improvements
- Expand relationship detection beyond `REL_*` and `*ID` columns (e.g., `*_ASSIGNMENTS`, tagging, crossrefs).
- Define cardinalities and optionality for each relationship.
- Normalize naming to strict `snake_case` and remove diacritics (planned: AJ_000126).
- Add constraints (unique keys, required fields) and validation rules for core gameplay entities.

