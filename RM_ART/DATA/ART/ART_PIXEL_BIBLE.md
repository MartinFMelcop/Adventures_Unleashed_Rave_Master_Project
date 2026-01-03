# ART — Pixel Art Bible (Act 1 baseline)

> **Status:** Draft baseline for Act 1 art production (AJ_000254)  
> **Updated (UTC):** 2025-12-27T19:02:39Z  
> **Purpose:** Standardize pixel art so maps/characters/UI stay coherent in RPG Maker XP and remain easy to package/version.

## Non-negotiables (MUST)
- **Tile grid:** 32×32, snapped.
- **Charset standard:** 32×48 per frame; 128×192 sheet (4×4).
- **Single global light direction** for Act 1 (recommendation: top-left).
- **Deterministic naming & versioning:** no spaces; semantic tokens; v## increments.

## Recommended defaults (Act 1)
### Scale
- Player/NPC: 32×48 frame.  
- “Big” NPCs/bosses can be larger, **but** must keep consistent map footprint and readability.

### Palette
- Constrain palettes per biome (Forest/Fae/Goblin Ruins/Mage Tower) while maintaining one shared neutral set.
- Avoid pillow shading; use 2–3 value steps and selective highlights.

### Tilesets & Autotiles (RMXP specifics)
- Autotiles recombine patterns: you must test **all corners/transitions** in-engine.
- Visual passability must match tile flags (X/O/★) to avoid “I can’t walk there?” frustration.

### Animation
- Prioritize readability over realism—small frames need stronger motion cues.
- Optional: provide `*_run.png` variants (same dimensions) for sprint visuals.

## Act 1 coverage checklist
Must have:
- Player charset (walk), optional run charset (`*_run.png`)
- Visuals for miniboss milestones: **MB001 / MB002 / MB003**
- Tilesets covering key biomes used by Act 1
- UI icons for quests/perícias (minimum viable set)

Should have:
- Faction NPC variants (palette accents)
- Basic combat VFX (hit/spark), ambience props

## Structured rules table
See: `DATA/ART/ART_PIXEL_BIBLE.csv` (same sections + RuleIDs).
