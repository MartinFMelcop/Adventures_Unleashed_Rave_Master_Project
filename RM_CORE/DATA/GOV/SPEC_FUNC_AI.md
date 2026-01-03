---
rm_spec: SPEC_FUNC_AI
version: 1
audience: ai_only
language: en-US
timezone: UTC
canonical_csv: "DATA/GOV/SPEC_FUNC_AI.csv"
inputs:
  - "DATA/GOV/MER_AI.csv"
  - "DATA/QA/RMXP_KNOWLEDGE_BASE_CSV.csv"
  - "DATA/CORE/REFERENCIAS_MASTER.csv"
purpose: >
  Functional specification layer that maps canonical data tables into gameplay/governance modules
  with deterministic rules, acceptance criteria, and traceability toward delivery milestones.
---

# SPEC_FUNC_AI (Functional Specification) — v1

This document is **AI-only** and **read-only** inside the bundle snapshot.

## Canonical file
- CSV (machine source of truth for this spec): `DATA/GOV/SPEC_FUNC_AI.csv`

## How to use
1. Load the CSV.
2. For a target feature/module, follow `primary_sources` first, then `related_sources`.
3. Apply `functional_rules` as MUST-level interpretation rules.
4. Use `acceptance_criteria` as the validation checklist for analysis and change proposals.

## Scope
- Defines **what the game and data must do** (functional intent).
- Does **not** define technical implementation steps (that belongs to `SPEC_TEC_AI`, PENDING).

## Columns (CSV schema)
- `spec_id`: stable identifier (`SF-XXXX`).
- `module`: high-level domain (WORLD, COMBAT, CRAFTING, etc.).
- `feature`: concise name.
- `goal`: objective.
- `description`: operational description.
- `primary_sources`: canonical relative paths (semicolon-separated).
- `related_sources`: supporting paths (semicolon-separated).
- `key_entity_groups`: pointers to MER_AI entity groups (if applicable).
- `functional_rules`: MUST-level rules/constraints.
- `acceptance_criteria`: conditions to consider the feature validated.
- `status`: DRAFT / ACTIVE / DEPRECATED.
- `priority`: P0 / P1 / P2.
- `dependencies`: cross-module dependencies (RefIDs, tables, or PENDING notes).
- `future_improvements`: required follow-ups discovered during analysis.
- `notes`: freeform.

## Traceability convention
- Data-model enumeration: `DATA/GOV/MER_AI.csv`
- Functional intent: `DATA/GOV/SPEC_FUNC_AI.csv`
- Technical plan: `DATA/GOV/SPEC_TEC_AI.csv` (**PENDING**)
- Delivery milestones: README pipeline section (Act 1 local build → Act 4 Steam release)

## Mandatory analysis behavior (policy reminder)
- During **analysis** of any adjustment: identify and register **future improvements** (at least one).
- During **homologation** of any adjustment: ensure **at least one log record** is created/updated and **reprioritize open backlog by WSJF**.

