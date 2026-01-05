# Análise de ajustes em aberto (personas)

## Persona 1 — Helena (QA de governança)
- **Dúvida:** o recalculo de `LinhasCopiadas/ColunasCopiadas` do 00_INDEX foi aplicado em todas as abas com CSV real? Como evitar regressão em views?
- **Info levantada:** o AJ_000184 foi concluído recalculando os valores com base na última célula não vazia para cada CSV disponível em `RM_QA/DATA/QA`, preservando as views e registrando evidências no próprio LOG_AJUSTES.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L188-L193】【F:RM_QA/DATA/QA/00_INDEX.csv†L1-L18】
- **Próximos passos sugeridos:** validar amostras comparando `max_row` vs. intervalo usado e manter documentação de execução segmentada (evitando sobrecarga de CI).【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L188-L193】

## Persona 2 — Mateus (Engenharia de dados/CI)
- **Dúvida:** como garantir que futuros deltas do 00_INDEX não dependam de scripts manuais e que alertas sejam emitidos quando o used range mudar inesperadamente?
- **Info levantada:** o backlog AJ_000416 abre a automação de CI para recalcular o used range, registrar diffs e emitir alertas de drift com WSJF configurado (P1).【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L574-L577】【F:RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv†L45-L54】
- **Próximos passos sugeridos:** implementar job de staging que roda sobre subconjuntos de abas e grava evidências em LOG_AJUSTES/CI logs antes de promover para produção.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L574-L577】

## Persona 3 — Bruna (Design de itens)
- **Dúvida:** ainda há risco de colisão de nomes de itens entre raridades? Qual política definitiva de display/ID deverá ser aplicada?
- **Info levantada:** o AJ_000121 segue em BACKLOG propondo separar NomeBase/NomeDisplay para resolver duplicidades de leitura humana, com escopo em ITENS_MASTER e relatórios de nomes duplicados.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L125-L133】【F:RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv†L60-L63】
- **Próximos passos sugeridos:** alinhar geração automática de `NomeDisplay` (raridade/sufixo) com os relatórios de duplicados e atualizar validações/UI conforme o plano do ajuste.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L125-L133】

## Conclusão geral
- Os recalculos do 00_INDEX reduziram linhas/colunas fantasma e fecharam o AJ_000184 com evidência rastreável.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L188-L193】【F:RM_QA/DATA/QA/00_INDEX.csv†L1-L24】
- Foi criado o follow-up AJ_000416 para automatizar essa checagem em CI, mantendo a fila WSJF atualizada com o novo item de governança.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L574-L577】【F:RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv†L45-L54】
- Itens de maior impacto em design (ex.: nomeação de itens no AJ_000121) continuam exigindo decisão de modelo de exibição e integração com relatórios de duplicidade.【F:RM_QA/DATA/QA/LOG_AJUSTES.csv†L125-L133】【F:RM_QA/DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv†L60-L63】
