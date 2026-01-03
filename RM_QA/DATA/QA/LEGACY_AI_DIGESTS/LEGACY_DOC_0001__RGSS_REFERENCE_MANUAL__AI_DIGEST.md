---
rm_digest_spec: 1
doc_id: LEGACY_DOC_0001
source_relpath: "LEGACY/REF_LIBRARY/RGSS_REFERENCE_MANUAL.pdf"
source_type: pdf
created_utc: "2025-12-24T08:39:24Z"
extraction: "human-written digest (no full-text reproduction)"
copyright_mode: "summary_only"
---

# RGSS Reference Manual — AI Digest (RPG Maker XP)

## Purpose
Use this manual as the **technical grounding** for implementing game systems in **RGSS (Ruby for RPG Maker XP)**.

## What this source is good for
- Confirming **RGSS terminology** and the **runtime model** (graphics loop, scenes, windows, sprites, audio, input).
- Understanding what is feasible in **RMXP scripting** without engine mods.
- Guiding **technical specs** (classes/modules to touch; constraints; performance considerations).

## Core mental model (RGSS runtime)
- **Main loop / frame updates**: visuals and input are frame-driven.
- **Scene management**: gameplay flow is orchestrated via scene objects.
- **Rendering**: sprites + windows layered; map and UI are rendered differently.
- **Data**: RPG Maker database objects are exposed through Ruby objects (RPG module + Game_* runtime state).

## High-value topics to consult (typical system work)
- **Graphics / timing** (frame count, transitions, waits)
- **Input handling** (keyboard state, triggers vs repeats)
- **Audio** (BGM/BGS/SE control)
- **Sprites, Viewports, Bitmaps** (render pipeline + memory)
- **Window / UI widgets** (message windows, menu windows, custom HUD)
- **Map and events runtime** (game state updates; interpreter usage)
- **Save data considerations** (what is serialized; how to version changes safely)

## AI usage directives
- DO NOT copy/paste large excerpts from the PDF into the project.
- Prefer: identify the relevant concept, then express it as **an implementation constraint or pattern** inside the project specs.
- When a detail matters (API naming / edge cases), cite **page numbers internally** during analysis (do not reproduce text).

## Suggested outputs this digest should enable
- **MER (AI-friendly)**: entities for Scripts/Systems, constraints, and integration points.
- **Functional spec**: player-facing behavior for each system.
- **Technical spec**: RGSS classes/modules to implement, plus data persistence plan.
