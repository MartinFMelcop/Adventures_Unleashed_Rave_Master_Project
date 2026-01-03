# RMXP Player Level Runtime Bindings (AI-only)

rm_spec: 1  
module: player_level_runtime  
version: AJ_000226  
generated_utc: 2025-12-25T20:59:16Z

## Files (DEV/RGSS)
- `Data/Scripts` should include (in this order):
  1) `RM_PLAYER_LEVEL_RUNTIME.rb`
  2) `RM_PLAYER_LEVEL_HOOKS.rb`

## CSV exports required in game build
Copy from authoring snapshot to build folder `Data/RM_CSV/`:
- `DATA/CORE/PLAYER_LEVEL_XP_TABLE.csv` -> `Data/RM_CSV/PLAYER_LEVEL_XP_TABLE.csv`
- `DATA/CORE/PLAYER_LEVEL_STAT_BUDGET.csv` -> `Data/RM_CSV/PLAYER_LEVEL_STAT_BUDGET.csv`
- `DATA/CORE/PLAYER_XP_SOURCES.csv` -> `Data/RM_CSV/PLAYER_XP_SOURCES.csv`

## Script Calls (Event Commands)
Grant XP from a configured SourceKey (optionally per-context):
- `RM_PlayerXP.grant("QUEST_SIDE_COMPLETE", "QST-ROSE-01")`
- `RM_PlayerXP.grant("BOOK_PAGE_FOUND", "PAGE-0007")`
- `RM_PlayerXP.grant("COMBAT_BOSS_CALAMITY", "CAL-0003")`

Set world counters used for caps/cooldowns:
- `RM_WorldTime.set_day(12)`
- `RM_WorldTime.set_chapter(1)`

Open minimal stat allocation UI (stub; stores allocations in save state):
- `RM_StatAlloc.open_scene`

Respec allocations (returns allocated points to unspent pool):
- `RM_StatAlloc.respec_all` (or `RM_StatAlloc.respec`)
- `RM_StatAlloc.respec_stat("STR", 5)` (partial)

### Respec Cost + Audit (AJ_000231)
- Objetivo: permitir respec na UI de alocação com **custo** e gerar trilha narrativa/auditável.
- Moeda padrão: **Silver (S)** (converter para Bronze (B) se necessário via ECON_MOEDAS).
- Modelo de custo (default; pode ser balanceado):
  - `base_s = 5`
  - `per_level_s = ceil(Level / 5)`
  - `mult = 1.25 ** respec_count` (contador salvo no save)
  - `total_s = (base_s + per_level_s) * mult`
- UI/Scene_RM_StatAlloc:
  - adicionar comando **Respec** com confirmação mostrando `total_s`.
  - se pagamento falhar: não altera pontos.
- Pós-sucesso (atomizar):
  - debitar `total_s`.
  - `respec_count += 1`.
  - registrar RecentEvent: `EVT_PLAYER_RESPEC_STATALLOC` (ver `DATA/DEV/RECENT_EVENTS.csv`).



## Debug overlay
- Switch **902** toggles the on-map overlay:
  - `ON` shows LV / TotalXP / Points / Bonus HP+SP / Day+Chapter
  - `OFF` disables and disposes overlay sprites

## Notes
- Stat allocation now applies to RMXP parameter plus fields (STR/DEX/AGI/INT) via `rm_sync_player_level_state`.
- Level budgets apply to `@maxhp_plus`/`@maxsp_plus` (Bonus HP/SP).
- VIT/WIS allocation mapping now applies: `VIT_TO_HP=4` and `WIS_TO_SP=2` (constants in `RM_PLAYER_LEVEL_HOOKS.rb`).


## See also
- RMXP_PACKAGING_AND_INPUT_NOTES.md
