# Análise de ajustes prioritários (personas)

## Personas envolvidas
- **Amelia (Build/Infra)**: foca em scripts e automação de build.
- **Rafa (QA/Validação)**: prioriza rastreabilidade e integridade dos relatórios.
- **Lia (Narrativa/Mapa)**: avalia impactos de conteúdo em chunks e UX.

## AJ_000373 — Local Test Assembler (montar pasta jogável)
- **Contexto**: ferramenta `local_test_assembler.py` copia `RMXP_BASE`, sincroniza `ScriptsCustom` e agrega CSVs. Referência direta em `RM_DIST/TOOLS/README_TOOLS.md`.
- **Dúvidas levantadas**:
  - Amelia: faltam checagens de pré-condição (existência de manifest/checagens de bytes) e opção de limpar destino sem apagar saves manuais.
  - Rafa: não há evidência de relatório pós-build (hashes/contagem de arquivos) para anexar a LOG_AJUSTES ou pré-validação do gate.
  - Lia: como sinalizar ausência de assets opcionais (tiles/áudio) para Ato 1 sem quebrar build? Precisa de aviso separado de erro.
- **Restrições/observações**: script atual não valida integridade nem suporta overlays adicionais; ver saída do gate atual para baseline de falhas conhecidas.

## AJ_000248 — Notificação opcional do prepack gate
- **Contexto**: gate existente (`prepack_gate_validate.py`) já falha builds e gera reports, mas backlog pede notificação (Slack/Discord/email) apenas em FAIL.
- **Dúvidas levantadas**:
  - Amelia: canal configurável via env? precisamos de template seguro para não vazar tokens em logs.
  - Rafa: qual payload mínimo? (link para artifact `gate_<MODULE>.md` + resumo das primeiras 5 falhas parece suficiente).
  - Lia: builds locais deveriam pular notificação? Possível flag `--notify` para evitar barulho ao iterar narrativa.
- **Restrições/observações**: evitar dependências externas pesadas; preferir webhooks simples e permitir noop quando variáveis não setadas.

## AJ_000297 — Chunk 18X18 (Serra — Porta da Caverna de Prova)
- **Contexto**: parte da cadeia de canonização de chunks na serra (ver `Mapa_WorldMap_VIEW.csv`). Conecta-se a 18W17/19X19.
- **Dúvidas levantadas**:
  - Lia: confirmação de quem é o guardião narrativo na porta (referência a DGN-FAE ou ao arco dos Mentores?).
  - Rafa: precisamos de critérios de aceite para canonizar (ex.: entradas/saídas recíprocas, loot mínimo conforme AJ_000388).
  - Amelia: faltam templates de evento em RGSS para validar iluminação/tonemap se o chunk herdar regras de cavernas (AJs 000158/409/410).
- **Restrições/observações**: chunk depende de decisões de loot/encontros (AJ_000387/000388) e do DoD formal para canonização (AJ_000370).

## Conclusão
- Os três ajustes continuam **BACKLOG**, mas requerem esclarecimentos de owner antes de execução.
- Próximos passos recomendados: 
  1) definir canal seguro e payload mínimo para notificação do gate; 
  2) adicionar checklist de pré-condição e relatório no assembler; 
  3) registrar DoD claro para canonizar chunks de serra/torre.
- Um novo AJ foi aberto para automatizar a atualização de manifest/checksums/DATA_INDEX e manter o baseline do gate.
