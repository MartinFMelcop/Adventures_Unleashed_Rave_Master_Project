# RMXP — Packaging & Input Notes (AJ_000366)

This doc is a **practical reference** for the project runtime on **RPG Maker XP (RGSS1)**, focused on:
- *Packaging/release conventions* (what is safe to change and when),
- *Input mapping* (run/dash, confirm/cancel/menu),
- *Common pitfalls* (Game.ini, executable name, self-referential checksums),
- *How to register decisions* in GOV artifacts (SPEC_TEC_AI / README rules).

## 1) Packaging basics (RMXP)

Minimal distributable set (typical):
- `Game.exe` (or renamed, e.g. `RaveMasters.exe` for release)
- `Game.ini`
- `RGSS104E.dll` (name depends on install/language)
- `Data/` (rxdata)
- `Graphics/`, `Audio/` (assets)

### Game.ini essentials
`Game.ini` normally contains:
- `Title=...` (window title)
- `RTP1=Standard` (optional)
- `Library=RGSS104E.dll` (DLL to load RGSS)

**Project rule (recommended):**
- Keep dev project stable (`Game.exe`) so the editor can open it safely.
- Rename **only in release packaging** (AJ_000166 / AJ_000259), and keep the mapping consistent (EXE + Title).

## 2) Input mapping (RGSS1)

Common conventions used by RMXP scripts:
- Confirm: `Input::C`
- Cancel/Menu: `Input::B`
- Dash/Run: typically `Input::A` or Shift key (depending on input layer)

### Run/Dash strategy for this project
- Prefer a **single switch** in settings (`SETTINGS_MOVEMENT.csv`) to enable/disable run.
- Implement run by temporarily increasing `$game_player.move_speed`.
- Optional: sprite swap (`_run`) if available; otherwise keep default sprite.

**Do not** hardcode constants in multiple scripts; route through a settings table whenever possible.

## 3) Safe aliasing pattern (RGSS)

When extending core classes (e.g., `Game_Player`, `Scene_Map`):
- Use `alias` with a unique prefix (`rm_...`) to avoid collisions with other scripts.
- Keep the extension minimal and gated by settings.
- Never do heavy file IO in `update` loops.

## 4) Integrity artifacts (manifest / checksums)

The project uses:
- `manifest.json`: file inventory with sha256/size; **does not list itself**.
- `checksums.sha256`: sha256 list; **must not include itself**.

Self-referential checksums create unavoidable mismatches; the gate validator should tolerate older bundles, but new bundles should not include the self-line.

## 5) Where to record decisions
- Behavior/user-facing: `SPEC_FUNC_AI` and related docs
- Implementation constraints/hooks: `SPEC_TEC_AI`
- Short operational rules: README (AI-only) + QA tools notes
- Data source-of-truth: DATA/CORE + ACT1 tables (never README)

## See also
- `RMXP_DIALOGUE_RUNTIME_BINDINGS.md`
- `RMXP_FLAGS_EVENTS_RUNTIME_BINDINGS.md`
- `RMXP_PLAYER_LEVEL_RUNTIME_BINDINGS.md`
