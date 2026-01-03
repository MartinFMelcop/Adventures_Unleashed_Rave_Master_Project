# Audio (RPG Maker XP) — Estrutura e Regras

Este módulo não contém músicas/sons prontos.

**Regra:** somente assets próprios (originais).

## Pastas
- `RMXP_BASE/Audio/BGM` — músicas de fundo (loop)
- `RMXP_BASE/Audio/BGS` — ambiente (loop)
- `RMXP_BASE/Audio/ME` — efeitos musicais (curtos, ex.: vitória)
- `RMXP_BASE/Audio/SE` — efeitos sonoros (UI, hits, status)

## Como nomear
Usar `FileStem` da tabela `AUDIO_CUES.csv` (sem extensão) + formato final (`ogg`, `wav`, etc.).

## Integração de dados
- `RMXP_BASE/Data/RM_CSV/AUDIO_CUES.csv`
- `RMXP_BASE/Data/RM_CSV/AUDIO_PLAN_ACT1.csv`

Gerado: 2025-12-30T01:30:21Z

## Inspirações (sem cópia)
- Direção musical pode citar RefIDs em `DATA/CORE/REFERENCIAS_MASTER.csv` (ex.: Radiohead, Red Hot Chili Peppers), mas os **arquivos finais são 100% autorais**.
- Se uma track/SE for motivada por referência, registre o RefID no plano de áudio (metadados) para rastreio.

