# RM_DIST (RMXP Base Skeleton)

Este módulo contém um *skeleton* de projeto RPG Maker XP extraído do LEGACY_BUNDLE_0001
(`LEGACY/EXTERNAL/RM_Project_IMPORTAR_DOCUMENTOS_LEGADO.zip`), pasta de origem:
`RPG_ExperimentalIAAPP_LEGADO/`.

## O que tem aqui
- `RMXP_BASE/Game.exe` + `Game.ini`
- `RMXP_BASE/Data/*.rxdata` (inclui Maps e base do banco)
- `RMXP_BASE/Graphics/` (parcial; muitos recursos ainda dependem de RTP/placeholder)
- `RMXP_BASE/Audio/` (estrutura criada; atualmente sem BGM/SE reais)

## Ajuste aplicado (AJ_000252)
- `RMXP_BASE/Data/Scripts.rxdata` foi restaurado a partir do backup mais recente encontrado
  no bundle legado (para evitar `Scripts.rxdata` "stub" de ~2KB).

## Próximos passos
- AJ_000253: integrar loader/packer para consumir nossos scripts em `DATA/DEV/RGSS/*.rb`
- AJ_000254/255/256: produzir assets de Ato 1 (pixel art + áudio) e reduzir dependência de RTP
- AJ_000258: smoke test automatizado do executável

## Ajuste aplicado (AJ_000261)
- Walk/Run no mapa: inserido script `RM_MOVEMENT_RUN_RUNTIME` em `RMXP_BASE/Data/Scripts.rxdata` (antes de `Main`).
- Behavior: segurar SHIFT (fallback Input::A) para correr (+1 move_speed). Sprite-run e passos são opcionais (fallback seguro).
## Ajuste aplicado (AJ_000253)
Integração **Build/RGSS**: scripts customizados do repositório passam a ser consumidos de forma determinística.

### Fonte de verdade (scripts)
- Autorias: `RM_ACT1/DATA/DEV/RGSS/*.rb`
- Ordem + assinatura: `RM_ACT1/DATA/DEV/RGSS/RGSS_PACK_MANIFEST.json`

### O que foi feito neste módulo
- Os scripts listados no manifest foram **empacotados** dentro de `RMXP_BASE/Data/Scripts.rxdata` **antes de `Main`**, na mesma ordem do manifest.
- Cópia dos fontes ficou em `RMXP_BASE/ScriptsCustom/` (para inspeção/diff).

### Ferramentas incluídas
- `TOOLS/rgss_pack.rb`: empacota (enforce order + valida sha256).
- `TOOLS/rgss_verify.rb`: valida presença + sha dos scripts empacotados.

Exemplo:

```bash
ruby RM_DIST/TOOLS/rgss_pack.rb --scripts_dir RM_ACT1/DATA/DEV/RGSS --project_dir RM_DIST/RMXP_BASE
ruby RM_DIST/TOOLS/rgss_verify.rb --scripts_dir RM_ACT1/DATA/DEV/RGSS --project_dir RM_DIST/RMXP_BASE
```

## Configuração rápida: Walk/Run (Acessibilidade)

O sistema de corrida (Run) pode ser ajustado **sem editar scripts** via:

- `RMXP_BASE/Data/RM_CSV/SETTINGS_MOVEMENT.csv`

Você pode remapear:
- `run_key` (tecla para correr)
- `run_mode` (`HOLD` ou `TOGGLE`)
- `run_speed_delta` (delta sobre a velocidade base)

Observação: `run_key=SHIFT` faz fallback para `Input::A` caso `Input::SHIFT` não exista no RGSS1.


## Grounding RMXP (como isso conversa com nossos CSVs)
- **RMXP é event-driven**: a maior parte do “mundo vivo” (rotina/NPC/portas) deve ser modelada via **Eventos de Mapa** com **páginas condicionais** (Switches/Variables).
- **Flags canônicas** vivem em `DATA/CORE/FLAGS_MASTER.csv` e devem mapear para switches/vars do RMXP (via camada RGSS).
- **Âncora de Respawn (Lareira/Acampamento)**: quando esse ponto é ativado, o jogo entra em *modo sandbox* (o jogador fica livre para seguir Rose / Vila / Mago Louco / Ruínas). O retorno ao morrer deve apontar para essa âncora.

## Como usar REFERENCIAS_MASTER sem “copiar”
- Referências (OSRS, GW2, Dark Souls, Overlord etc.) servem para **padrões de design** (loop, pacing, UI), não para copiar arte/áudio.
- Antes de integrar assets em `RMXP_BASE/Audio` ou `Graphics`, verifique `DATA/CORE/REFERENCIAS_MASTER.csv` e a política “assets próprios”.

## Checklist rápido (antes de rodar build)
1) `RMXP_BASE/Data/Scripts.rxdata` contém o loader do pack (`RGSS_PACK_MANIFEST`).
2) Switches/Variables usados por eventos têm definição rastreável em CSV (FLAGS/STATE).
3) Audio/Graphics não dependem de RTP (ou estão claramente marcados como placeholder/backlog).


- (AJ_000258) Checklist smoke test em RM_QA/DATA/QA/RELEASE_SMOKE_TEST_CHECKLIST.csv.
