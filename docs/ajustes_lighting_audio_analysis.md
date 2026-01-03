# Análise detalhada dos AJs de iluminação, tempo e áudio (Ato 1)

## Contexto
- Fonte canon: `RM_CORE/README_RM_MAIN.md` → prioriza leitura de README e governança antes de mexer nos dados.
- Ajustes analisados (todos **P0**):
  - **AJ_000405** – Troca automática de BGM/BGS por contexto.
  - **AJ_000407** – Runtime de tempo (fase do dia e switches).
  - **AJ_000408** – Aplicar Tone dia/noite em mapas externos.
  - **AJ_000409** – Framework "Caverna Escura" (overlay + luzes).
  - **AJ_000410** – Item/estado Tocha/Lanterna integrado ao lighting.

## Informações levantadas
- **Plano de áudio (AJ_000405)**
  - Dados de referência: `ACT1_AUDIO_PLAN` (QA/DIST) precisa ser a fonte única para regras por chunk/evento.
  - Build deve prever ausência de assets: Game.exe legado não garante BGM/BGS completos.
  - Prioridade esperada: cutscene > combate > ambiente do mapa; retomar trilha anterior quando o evento terminar.
- **Tone dia/noite (AJ_000408)**
  - `TIME_PHASES_MASTER` já lista fases; faltam overrides por mapa para exceções (ex.: interiores quentes vs cavernas frias).
  - Transferências de mapa costumam limpar `Screen.tone`; é necessário reaplicar após teleporte e load.
  - Proposta de tabela auxiliar: `TIME_TONE_OVERRIDES` (MapID/Fase → Tone) para evitar poluição na master.
- **Runtime de tempo (AJ_000407)**
  - `TIME_PHASES_MASTER` define ordem/duração, switches de dia/noite e flags de NPC/Workers; precisa de timer único no RGSS.
  - Ausência atual de `CHUNK_TIME_OVERRIDES` deixa brecha para fases especiais (eventos); manter hook previsto no design.
- **Caverna Escura (AJ_000409)**
  - Framework esperado: overlay escuro + fontes de luz em eventos (player, tochas, objetos). Deve respeitar performance em mapas grandes.
  - DIC_DUNGEON precisa apontar quais mapas usam o modo e quais light sources padrão.
- **Tocha/Lanterna (AJ_000410)**
  - Item deve alterar raio de luz do player e prevenir softlock. Falta decisão sobre durabilidade/combustível e craft inicial.
  - Integração com CONSUMIVEIS/ITENS_MASTER e flags do sistema de lighting.

## Dúvidas prioritárias para o time
1) **Fallback de áudio:** podemos mapear um BGM/BGS padrão por MapType para evitar silêncio quando o asset estiver ausente? (depende de ACT1_AUDIO_PLAN)
2) **Overrides de tone:** preferem tabela dedicada `TIME_TONE_OVERRIDES` (mapa/fase → tone) ou embutir no `TIME_PHASES_MASTER`? O split reduz poluição.
3) **Performance do overlay:** há limite de FPS alvo em mapas grandes (ex.: cavernas 100x100)? Precisamos de cache de bitmap por chunk ou reuse global?
4) **Durabilidade da tocha:** tocha infinita ou consumível? Se consumível, qual frequência de loot/craft no Ato 1 para não quebrar progressão?
5) **Tick do tempo:** timer roda por frame ou intervalo em segundos? Em cutscenes o tempo congela ou continua? Precisamos de comando debug para QA acelerar o ciclo?

## Próximos passos sugeridos
- Confirmar respostas das dúvidas acima antes de codificar; documentar decisões nas Notas do AJ.
- Formalizar regras em `SPEC_FUNC_AI`/`SPEC_TEC_AI` (tempo, lighting e áudio) e amarrar `MER_AI` para itens de iluminação.
- Criar entradas QA: fallback de asset (BGM/BGS), benchmark de FPS para mapas escuros e checklist de persistência de tone/switches de tempo.

