# AUDIO — Regras canônicas (AJ_000256)

## Princípios
- **Somente assets próprios**: referências (músicas/jogos) servem apenas como inspiração.
- **Compatível com RPG Maker XP**: organização por pastas padrão `Audio/BGM`, `Audio/BGS`, `Audio/ME`, `Audio/SE`.
- **Cue-driven**: o jogo referencia `CueID` (tabela `AUDIO_CUES`) e resolve para arquivo no pacote/instalação.

## Duração e looping
- `Loop=TRUE` para BGM/BGS de exploração e lutas longas (miniboss).
- `Loop=FALSE` para SE (one-shot).

## Temas
- 1 tema por macro-região: Vila, Floresta das Fadas, Ruínas Goblin, Brejo Alagado, Caminho Costeiro, Reino Élfico.
- 1 tema por **miniboss** (MB001/MB002/MB003).
- Dungeons de caverna podem compartilhar o mesmo ambience/BGM base.

## Status de asset
- `AssetStatus=PLANNED`: cue existe no design, **arquivo pode não existir ainda**.
- `AssetStatus=READY`: arquivo existe no bundle/pacote e pode ser validado por QA.

Gerado em: 2025-12-30T01:24:41Z
