# AI Readability & Log Visibility (Operational Linter)

## Objetivo
Centralizar o contrato **AI-only** descrito no README e oferecer um checklist de linter para evitar deriva (dados escondidos em texto, contagens hardcoded, falta de rastreabilidade). Complementa `DATA/GOV/AI_READABILITY_POLICY.json`.

## Escopo e fontes canônicas
- Canon mínimo (sempre carregar nesta ordem): `DATA/GOV/MANIFESTO_8_ARTEFATOS.json` → `DATA/DATA_INDEX.csv` → `DATA/*/00_INDEX.csv` → `DATA/QA/LOG_AJUSTES.csv` → `DATA/QA/CHANGE_LOG.csv` → `DATA/CORE/REFERENCIAS_MASTER.csv`.
- **Nunca** canonizar conteúdo que viva apenas no README; sempre refletir em `DATA/*` primeiro.
- HUMAN/* permanece somente leitura; LEGACY/* é referência.

## Contrato AI-only
- Leia/execute sempre via artefatos em `DATA/*`; README apenas espelha decisões.
- Toda homologação de AJ cria **≥1 novo AJ BACKLOG** e atualiza WSJF em `RPT_WSJF_OPEN_AJUSTES.csv`.
- Toda análise registra ao menos 1 "FuturasMelhorias" em `LOG_AJUSTES`.
- MER/SPEC_FUNC/SPEC_TEC/TRACEABILITY são obrigatórios para qualquer mudança de gameplay/runtime/save/UI.

## Checklist de Linter (aplicar antes de fechar qualquer AJ)
1) **Ponteiros e logs**
   - README aponta para as fontes canônicas corretas (sem caminhos órfãos).
   - `LOG_AJUSTES` e `CHANGE_LOG` registram o AJ e a data mais recente.
2) **Determinismo**
   - Não há contagens hardcoded (ex.: número de tabelas/linhas) — derive a partir de CSV/manifest.
   - Novos arquivos estão no `manifest.json` + `checksums.sha256` do módulo.
3) **Governança**
   - `LOG_AJUSTES`: Status/WSJF/FuturasMelhorias atualizados; follow-up backlog criado.
   - `RPT_WSJF_OPEN_AJUSTES`: pool aberto repriorizado; itens concluídos removidos.
4) **Rastreabilidade**
   - Se um AJ toca feature/sistema: ids em MER/SPEC_FUNC/SPEC_TEC/TRACEABILITY citados ou justificativa clara em `LOG_AJUSTES.Notas`.
   - Evidências listam arquivos/relatórios gerados.
5) **Qualidade de arquivo**
   - CSVs sem células completamente vazias em colunas críticas; cabeçalhos preservados.
   - Timestamps UTC normalizados (ISO 8601 com sufixo `Z`).

## Como reportar violações
- Registrar na coluna `Notas` do AJ afetado + criar AJ BACKLOG para automação/ajuste.
- Incluir referência ao passo da checklist que falhou.
