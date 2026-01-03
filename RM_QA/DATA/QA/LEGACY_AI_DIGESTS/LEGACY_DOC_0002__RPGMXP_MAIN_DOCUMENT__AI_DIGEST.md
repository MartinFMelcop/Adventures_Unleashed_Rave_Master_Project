---
rm_digest_spec: 1
doc_id: LEGACY_DOC_0002
source_relpath: "LEGACY/REF_LIBRARY/RPGMXP_MAIN_DOCUMENT.pdf"
source_type: pdf
created_utc: "2025-12-24T08:39:24Z"
extraction: "human-written digest (no full-text reproduction)"
copyright_mode: "summary_only"
---

# RPG Maker XP — Main Document — AI Digest

## Purpose
Use this manual as the **tooling / editor grounding**: how the RMXP editor organizes maps, events, database records and resources.

## What this source is good for
- Validating **editor constraints** that affect functional specs (events, switches/variables, map layers).
- Aligning data tables with how RMXP expects content to be authored.
- Making sure pipeline steps lead toward a **playable executable** (local tests) before Steam milestones.

## Core editor model
- **Project**: map tree + database + scripts + resource folders.
- **Maps**: tilesets, layers, passability, encounters; map IDs matter.
- **Events**: pages with conditions; commands; self-switches; interpreter executes.
- **Database**: actors, classes, skills, items, weapons, armors, enemies, troops, states, animations, tilesets, common events.
- **Resources**: graphics/audio are referenced by name and must exist in correct folders.

## High-value topics to consult (typical content/system work)
- Eventing patterns: cutscenes, branching, quest logic, triggers
- Switches/variables conventions (naming + ranges + reserved IDs)
- Database record dependencies (skills ↔ states ↔ animations; enemies ↔ troops; items ↔ effects)
- Packaging basics: how the game is built/run locally for testing

## AI usage directives
- DO NOT treat the manual as a canonical data source. Canon is **DATA/** in this bundle.
- Use the manual to translate: **spec → RMXP authoring steps** (events + DB entries + resources).
- Keep outputs machine-checkable: cite table IDs and cross-links in the project data.

## Suggested outputs this digest should enable
- Functional spec sections that explicitly state: **where** (map/event/common event) something is authored.
- Technical spec mapping: which table/entity in DATA corresponds to which RMXP database section.
