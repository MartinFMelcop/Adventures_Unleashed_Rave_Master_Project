# LEGACY (descontinuado)

**Data (UTC):** 2025-12-23T18:50:57Z

Este diretório existia apenas como **backup legado** do pacote anterior (workbooks `.xlsx` e um ZIP histórico).
Após a migração para **DATA/** (CSV value-only) e consolidação do consumo humano em **HUMAN/RM_HUMAN_VIEWS_MAIN.xlsx**,
os arquivos Excel legados foram **removidos** para evitar confusão e reduzir peso.

## Fonte da verdade (não muda)
- **LOG de ajustes:** `DATA/QA/LOG_AJUSTES.csv`
- **Dados versionáveis:** `DATA/**` (CSV + índices)
- **Excel humano (derivado):** `HUMAN/RM_HUMAN_VIEWS_MAIN.xlsx`

## Auditoria / Proveniência
- `origin_hash` do ZIP anterior: `b8b1448910c300de817e8a8e39cd3ddf7e7580a30894aabdcdf051c4e5e1eddd`
- Lista + hashes dos arquivos removidos: `LEGACY/REMOVED_LEGACY_FILES.json`

> Regra: **não há mais `.xlsx` fora do `HUMAN/`**.


## Added (2025-12-25)
- `LEGACY/REF_LIBRARY/livro_dos_100_contos.docx` — internal lore codex used as reference for time/space theme and calamities.


## Removed (2025-12-25)
- `LEGACY/REF_LIBRARY/rgss_reference_manual.pdf` — **removed from snapshot** (duplicate). Use:
  - `DATA/QA/LEGACY_AI_DIGESTS/LEGACY_DOC_0001__RGSS_REFERENCE_MANUAL__AI_DIGEST.md`
  - Source pointer: `EXTERNAL_BUNDLE::RPGMXP_RGSS_NARRATIVE_REFERENCES.zip::RGSS_REFERENCE_MANUAL.pdf`
- `LEGACY/REF_LIBRARY/rpgmxp_main_document.pdf` — **removed from snapshot** (duplicate). Use:
  - `DATA/QA/LEGACY_AI_DIGESTS/LEGACY_DOC_0002__RPGMXP_MAIN_DOCUMENT__AI_DIGEST.md`
  - Source pointer: `EXTERNAL_BUNDLE::RPGMXP_RGSS_NARRATIVE_REFERENCES.zip::RPGMXP_MAIN_DOCUMENT.pdf`

> Motivo: AJ_000202 — após existir AI digest, evitar manter binários duplicados no snapshot (peso + risco de proveniência).

## Política (importante)
- `LEGACY/*` é **referência** (rascunhos antigos, fontes externas, bundles). Não é canon.
- Qualquer migração para `DATA/*` precisa de AJ explícito e deve citar RefIDs em `DATA/CORE/REFERENCIAS_MASTER.csv` quando aplicável.

