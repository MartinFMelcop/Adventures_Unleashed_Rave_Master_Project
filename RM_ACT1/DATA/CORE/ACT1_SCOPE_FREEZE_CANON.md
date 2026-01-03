# Act 1 Scope Freeze (Canon)

Effective UTC: **2025-12-27T22:34:12Z**

This document freezes **Act 1 content scope** (story + world entities) while allowing **implementation/system** work to continue.

## What is frozen (content)

The following DEV entity sets are frozen at the snapshot shown in `ACT1_SCOPE_FREEZE_CANON.csv`:

- Chapters / Main Quests / Sidequests
- Chunks / Inners / MiniDungeons / Dungeons / Puzzles
- NPCs / Monsters

Allowed: edit fields inside existing rows (text, links, gates, DoR/DoD, balancing, tags).  
Not allowed: add new IDs/rows for those entity sets **without a dedicated AJ** and traceability updates (MER/SPEC/TRACE).

## Known issues / exceptions

- `QST-0028` and `SDQ-0028` reference **`CAP-0028`** but the canon chapter list currently ends at **`CAP-0027`**.
  - This is tracked as a **WARN** in `RM_QA/DATA/QA/RPT_ACT1_SCOPE_FREEZE_STATUS.csv` and must be resolved by a dedicated AJ (re-map or move out-of-scope).

## What is allowed to expand (systems)

Systems and implementation may expand freely as long as they **do not introduce new story scope**. Examples:
- New RGSS scripts, UI windows, combat calculations, quest tracker UI, data validators, performance fixes.

## QA gate

A scope-freeze compliance report is generated in QA:
- `RM_QA/DATA/QA/RPT_ACT1_SCOPE_FREEZE_STATUS.csv`

Acceptance: **0 ERROR**.
