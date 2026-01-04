# TOOLS (Build/RGSS)

Ferramentas para **empacotar** e **validar** scripts customizados (plain `.rb`) dentro do `Scripts.rxdata` do RPG Maker XP (RGSS1).

## Fonte de verdade
- Autorias de scripts ficam em: `RM_ACT1/DATA/DEV/RGSS/`
- Ordem + assinatura (sha256) ficam em: `RM_ACT1/DATA/DEV/RGSS/RGSS_PACK_MANIFEST.json`

## Como usar (exemplo)
Assumindo que você extraiu `RM_DIST` e `RM_ACT1` no mesmo diretório:

```bash
ruby RM_DIST/TOOLS/rgss_pack.rb --scripts_dir RM_ACT1/DATA/DEV/RGSS --project_dir RM_DIST/RMXP_BASE
ruby RM_DIST/TOOLS/rgss_verify.rb --scripts_dir RM_ACT1/DATA/DEV/RGSS --project_dir RM_DIST/RMXP_BASE
```

## Saídas
- `RM_DIST/TOOLS/rgss_pack_report.json`
- `RM_DIST/TOOLS/rgss_verify_report.json`

## Notas de projeto
- Siga o runbook do `README_RM_MAIN.md` (referências + RMXP grounding).
- Empacotamento deve manter rastreio: scripts ↔ CSVs ↔ eventos.
- Assets: somente próprios (inspiração via `REFERENCIAS_MASTER`).



## Local Test Assembler (Build)

Ferramenta para montar uma pasta jogável de teste local a partir dos módulos.

Uso (na raiz do repositório):

```bash
python RM_DIST/TOOLS/local_test_assembler.py --out ./_local_test
python RM_DIST/TOOLS/local_test_assembler.py --out ./_local_test --preserve-saves
```

O assembler:
- copia `RM_DIST/RMXP_BASE` para `--out`
- sincroniza `ScriptsCustom` a partir de `RM_ACT1/DATA/DEV/RGSS`
- agrega CSVs em `Data/RM_CSV` a partir de `RM_CORE/DATA/CORE`, `RM_ACT1/DATA/CORE` e `RM_ACT1/DATA/DEV`
- gera `local_test_report.json` no destino com contagem de scripts/CSVs e eventuais faltas de `manifest.json/checksums.sha256`
- `--preserve-saves` mantém `Save*.lsd` existentes na pasta de saída
