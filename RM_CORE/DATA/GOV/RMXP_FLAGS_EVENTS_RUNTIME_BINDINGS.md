# RMXP Flags + Recent Events Runtime Bindings (AI-only)

Purpose: make **flags** (MEMORY_FLAGS) and **recent events** (RECENT_EVENTS) persist in save/load, so dialogue ConditionsExpr and social mechanics can rely on stable state.

## Files
- Script: `DATA/DEV/RGSS/RM_FLAGS_EVENTS_RUNTIME.rb`
- Data tables (copied into game build):  
  - `MEMORY_FLAGS.csv`  
  - `RECENT_EVENTS.csv`

## RMXP Script order (recommended)
Place `RM_FLAGS_EVENTS_RUNTIME` **above** systems that read flags/events, e.g.:
1) `RM_FLAGS_EVENTS_RUNTIME`
2) `RM_DIALOGUE_SCORING_RUNTIME`
3) Other gameplay systems (quests, combat, crafting)

## Persistence model
- Stored inside `Game_System`:
  - `rm_flag_store` (global + per-npc + relation flags)
  - `rm_event_store` (recent events with TTL)
- Works automatically because `Game_System` is serialized by RMXP.

## Script Calls (Event Commands)
### Flags
- Set (auto-scope via MEMORY_FLAGS.csv; optional overrides):
  - `RM_Flags.set("FLAG_PLAYER_HELPED", true, "NPC-0007")`
  - `RM_Flags.set("FLAG_AVOID_PLAYER", true, "NPC-0007", "NPC", 10)`  # TTL 10 turns
- Clear:
  - `RM_Flags.clear("FLAG_AVOID_PLAYER", "NPC-0007")`
- Query:
  - `RM_Flags.has?("FLAG_PLAYER_LIED", "NPC-0007")`

### Recent Events
- Push:
  - `RM_RecentEvents.push("EVT_PLAYER_LIED", "NPC-0007")`
- Query:
  - `RM_RecentEvents.has?("EVT_NPC_OUTBURST", "NPC-0007")`

- Clear:
  - `RM_RecentEvents.clear("EVT_PLAYER_LIED", "NPC-0007")`

### Turn ticking (optional, deterministic TTL)
If you want TTL to decay, call once per interaction/turn:
- `RM_Flags.tick_turn(1)`
- `RM_RecentEvents.tick_turn(1)`

(Integration choice: tick on dialogue close, battle end, or step counter.)

## Data roots
Runtime reads from `Data/RM_CSV/`. Build pipeline must copy:
- `DATA/DEV/MEMORY_FLAGS.csv`  -> `Data/RM_CSV/MEMORY_FLAGS.csv`
- `DATA/DEV/RECENT_EVENTS.csv` -> `Data/RM_CSV/RECENT_EVENTS.csv`


## See also
- RMXP_PACKAGING_AND_INPUT_NOTES.md
