---
rm_spec: SF-0310
layer: FUNCTIONAL_SPEC
module: NPC
audience: ai_only
lang: en-US
version: 1
created_utc: 2025-12-25T06:01:24Z
generated_by_adjustment: AJ_000144
---

# SF-0310 — Deterministic NPC Personality + Dialogue Intent System

## Purpose
Provide an **alive but consistent** behavior layer for NPCs (and speaking monsters) that is **implementable in RPG Maker XP (RGSS)** and avoids heavy psychological theory.

Canonical data lives in `DATA/*` tables; this doc is explanatory only.

## Core concepts

### Stable-ish traits (10 axes, 0–100)
Source: `DATA/CORE/PERSONALITY_AXIS_DEF.csv`

NPCs store **effective values** per axis in `DATA/DEV/NPC_PROFILE.csv` (can be derived from archetypes + deltas in future).

### Fast-changing state
Source: `DATA/DEV/NPC_STATE.csv`

- Stress, Fear: 0–100
- Mood: categorical (string)

**Mood values (initial set used by pilot):** `NEUTRAL`, `WARY`, `PRESSURIZED`, `OUTBURST`, `AVOIDANT`, `OBSESSED`.
- Authoring rule: setting `SetMood=OUTBURST` in a dialogue variant implies starting `OutburstCooldown` using `NPC_PROFILE.OutburstCooldownTurns`.
- While `OutburstCooldown>0`, outburst variants may still be selected; when the scene ends, authoring can gate leave/avoid via `FLAG_NPC0007_AVOID_PLAYER_TEMP`.
- OutburstCooldown: integer (turns)

### Social relations (per target)
Source: `DATA/DEV/NPC_RELATIONS.csv`

- Trust, Respect: 0–100
- Debt: integer (can be used as points / favors)

### Faction norms (culture)
Source: `DATA/CORE/FACTION_NORMS.csv`

Norms are **not** individual traits. They represent cultural expectations (law, violence tolerance, etc.) and influence scoring.

### Dialogue intents + variants catalog
Sources:
- `DATA/CORE/DIALOGUE_INTENTS.csv`
- `DATA/DEV/DIALOGUE_VARIANTS.csv`

Intents define the scene goal (e.g., BLAME, APOLOGY, THREAT). Variants are **prewritten** responses tagged with conditions and effects.

## Deterministic scoring contract

For a given IntentID, candidate variants are filtered by:
- Scope: GLOBAL / ARCHETYPE / NPC
- Optional `ConditionsExpr` gates (simple expression language; future improvement)

Then score each candidate:
```
score = BaseScore
      + Σ(axis_value * AxisWeights)
      + Σ(state_value * StateWeights)
      + Σ(relation_value * RelationWeights)
      + Σ(norm_value * NormWeights)
```

Pick max score, then apply **effects**:
- Update NPC state (stress/mood/fear/cooldown)
- Update relations (trust/respect/debt)
- Add flags and recent events

## "Absorb → explode" pattern (pilot encoding)
Pilot NPC: NPC-0007 (Mago Louco)

Encoding uses:
- High Patience (delays escalation)
- High Volatility (strong spikes when triggered)
- OutburstThreshold (stress threshold)
- Gate tags (only on high stakes / confirmed manipulation / obsession topic)
- Cooldown turns after outburst

Source fields:
- `NPC_PROFILE.OutburstThreshold`
- `NPC_PROFILE.OutburstGateTags`
- `NPC_PROFILE.OutburstCooldownTurns`
- `NPC_STATE.OutburstCooldown`

## Speaking monsters
Monsters that have speech should be treated as **SPEAKER entities**, reusing the same intent/variant system.
Non-speaking monsters skip personality/dialogue selection and rely on combat AI only.