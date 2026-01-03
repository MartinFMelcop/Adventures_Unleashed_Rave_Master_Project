# RMXP Dialogue Runtime Bindings (AI-only)

purpose:
- Document optional RMXP switches/variables for the deterministic dialogue scoring runtime.
- The runtime **does not require** any specific switch/variable to function.
- Recommended integration uses Script Event Commands calling `RM::DialogueScoring.say(...)`.

## Required (none)

- No mandatory switches/variables.
- No mandatory Common Events.

## Optional (debug)

switches:
- id: 901
  name: RM_DEBUG_DIALOGUE
  effect:
    - if ON, `RM::DialogueScoring.choose_variant(...)` writes a short debug breakdown to `$game_message`.


- id: 902
  name: RM_DEBUG_DIALOGUE_TRACE
  effect:
    - if ON, debug breakdown includes predicate evaluation trace (true/false) for the selected variant ConditionsExpr.
variables:
- none (debug uses message output only).


## ConditionsExpr (runtime contract)

This is a small boolean expression language used by `RM::DialogueScoring.choose_variant(...)` to filter candidate dialogue variants.

### Operators and precedence
- Parentheses: `( ... )`
- AND: `&`
- OR: `|`
- Precedence: `()` > `&` > `|`

### Atoms
Supported atom forms:

1) Comparison  
`<KEY> <OP> <VALUE>` where:
- `OP` is one of: `== != <= >= < >`
- `KEY` is resolved from:
  1) relations (`rel[KEY]`)
  2) state (`state[KEY]`)
  3) fallback: `state[KEY + "_0_100"]`
- Numeric compare happens when both sides are integers; otherwise string compare is used.

Examples:
- `Mood != OUTBURST`
- `Trust_Player >= 60`

2) Tag/Flag predicates  
- `HasTag(TAG)=true|false`
- `HasFlag(FLAG)=true|false`
- `HasRecentEvent(EVENT)=true|false`

Examples:
- `HasTag(FAE_SOCIAL)=true`
- `HasFlag(NPC_HOSTILE)=false`
- `HasRecentEvent(EVT_PLAYER_THREATENED)=true`



### TTL note
- Flags and recent events may have TTL (time-to-live) assigned when added (e.g., `FLAG_X@2`).
- During dialogue, each call to `RM::DialogueScoring.say(...)` ticks TTL by **1** turn before selecting a variant.
### Empty / invalid expressions
- Empty string is treated as **true**.
- If parsing fails, runtime falls back to a legacy evaluator (simple `&` / `|` evaluation) to avoid hard crashes.

### Debug trace (optional)
When `RM_DEBUG_DIALOGUE_TRACE (SW 902)` is ON, the debug overlay prints a per-atom trace (`ATOM => true/false`) for the selected variant.

### QA harness (optional)
Script calls (RMXP “Script...” event command):

- `RM::DialogueScoring.run_tests_dialogue_scoring(true)`  
  Uses `DATA/QA/TEST_DIALOGUE_SCORING_RUNTIME.csv`

- `RM::DialogueScoring.run_scenarios_dialogue(true)`  
  Uses `DATA/QA/TEST_SCENARIOS_DIALOGUE.csv`


## Data deployment contract (build step)

At runtime, CSVs must exist under:

- `Data/RM_CSV/CORE/FACTION_NORMS.csv`
- `Data/RM_CSV/DEV/NPC_PROFILE.csv`
- `Data/RM_CSV/DEV/NPC_STATE.csv`
- `Data/RM_CSV/DEV/NPC_RELATIONS.csv`
- `Data/RM_CSV/DEV/DIALOGUE_VARIANTS.csv`

(These are canonical in the bundle under `DATA/*` and are copied/packed for RMXP by the build pipeline.)

## Variant side-effects (DIALOGUE_VARIANTS)

Fields used by the runtime when a variant is selected:

- `AddFlags`: pipe-separated list (`FLAG_A|FLAG_B|...`). Each token may optionally set an explicit boolean value and/or TTL: `FLAG_A` (true), `FLAG_A=false`, `FLAG_A@3`, `FLAG_A=false@2`.
- `AddFlags_TTL_Turns`: optional integer; default TTL override applied to every `AddFlags` token that does not include `@TTL`.
- `ClearFlags`: pipe-separated list (`FLAG_A|FLAG_B|...`). Clears flags via `RM_Flags.clear(...)` (and updates the local evaluation flag set immediately).
- `AddRecentEvent`: pipe-separated list (`EV_A|EV_B|...`). Each token may optionally carry a TTL override using `@` (e.g. `EV_A@2`).
- `AddRecentEvent_TTL_Turns`: optional integer; default TTL override applied to every `AddRecentEvent` token that does not include `@TTL`.
- `ClearRecentEvent`: pipe-separated list (`EV_A|EV_B|...`). Clears recent events from the persistent recency store (supports the same event IDs used by `AddRecentEvent`).

n that does not include `@TTL`.

Tip: define your flags/events in `MEMORY_FLAGS.csv` / `RECENT_EVENTS.csv` to control `Scope` and base `TTL_Turns` deterministically. TTL only decays if your game loop calls `RM_Flags.tick_turn(...)` / `RM_RecentEvents.tick_turn(...)`.

## Script usage (RMXP event command)

Minimal example (show chosen line):

```
t = RM::DialogueScoring.say("NPC-0007", "SMALLTALK", ["STAKES_LOW"]); $game_message.add(t)
```

Notes:
- `tags` is an Array<String>. Use it to represent scene context, stakes, special quirks, etc.
- **Flags and recent-events are persisted** via `RM_FLAGS_EVENTS_RUNTIME.rb` (stored in `Game_System.rm_flag_store` / `Game_System.rm_event_store`).
  - When a selected variant has `AddFlags`, the runtime calls `RM_Flags.set(...)` (scope/TTL comes from `MEMORY_FLAGS.csv`; if undefined, defaults to **NPC** scope).
  - When a selected variant has `AddRecentEvent`, the runtime calls `RM_RecentEvents.push(...)` (TTL comes from `RECENT_EVENTS.csv` when defined).


## See also
- RMXP_PACKAGING_AND_INPUT_NOTES.md
