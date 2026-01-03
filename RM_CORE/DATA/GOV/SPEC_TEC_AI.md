# SPEC_TEC_AI (AI-first Technical Specification)

This document is the **technical layer** in the delivery chain:

**MER_AI → SPEC_FUNC_AI → SPEC_TEC_AI → Game Development → Local Executable (Act 1) → Steam Publication (Act 4) → Post-release Improvements**

## Purpose
- Provide **modular, traceable** technical guidance for implementation in **RPG Maker XP (RGSS/Ruby)**.
- Keep it **AI-friendly**: deterministic, explicit inputs/outputs, clear file targets, and trace links.

## Rules (MUST)
- MUST keep **canonical truth** in `DATA/*`. README is directive/mirror only.
- MUST record **future improvements** during analysis of any AJ.
- MUST, during homologation of any AJ, add **at least one** new AJ entry to `DATA/QA/LOG_AJUSTES.csv` and **reprioritize open demand pool** (WSJF_RANK).
- MUST avoid embedding large binary legacy assets inside the main snapshot bundle; register external bundles by **pointer + sha256**.

## How to use
- Primary table: `DATA/GOV/SPEC_TEC_AI.csv`
- Each row represents a **module/component** with:
  - Purpose, Inputs, Outputs
  - File targets (what will be touched upstream)
  - Acceptance criteria and non-functional constraints
  - Trace links back to MER and Functional spec

## Next step
- Expand TSPEC items into implementable tasks in `DATA/QA/LOG_AJUSTES.csv` as AJs or ETIDs.
