---
rm_readme_spec: 1
audience: ai_only
human_mode: read_only
bundle_role: read_only_snapshot
language: en-US
timezone: UTC
authoring_rule: "README mirrors canonical DATA and defines directives; never becomes a source of truth."
build_utc: "2025-12-27T21:28:49Z"
---

# RM — AI Operational README (Read-Only Snapshot)

## Fluxo inicial e qualidade de mapas (canon)

- Fluxo do prólogo (slideshow na capital) → criação de personagem → spawn na vila: `DATA/GOV/INTRO_FLOW.md`
- Densidade recomendada de POIs por mapa (benchmark do legado): `DATA/GOV/POI_DENSITY_GUIDE.md`
- Se o grid humano de chunks tiver erro humano, consulte: `QA/DATA/QA/VIEW_HUMANA_FIX_LIST.csv` (não edita a view; só indica onde ajustar)


## 0) Canonical sources (SOURCE OF TRUTH)
The README is **not** authoritative. These files are.

```yaml
canonical:
  data_index: "DATA/DATA_INDEX.csv"
  sheet_name_map: "DATA/sheet_name_map.json"
  table_index_core: "DATA/CORE/00_INDEX.csv"
  table_index_dev: "DATA/DEV/00_INDEX.csv"
  table_index_qa: "DATA/QA/00_INDEX.csv"
  table_index_gov: "DATA/GOV/00_INDEX.csv"
  column_meta_master: "DATA/GOV/COL_META_MASTER.csv"  # derived column dictionary
  mer_ai: "DATA/GOV/MER_AI.csv"
  spec_func_ai: "DATA/GOV/SPEC_FUNC_AI.csv"
  spec_tec_ai: "DATA/GOV/SPEC_TEC_AI.csv"
  delivery_roadmap_ai: "DATA/GOV/RM_DELIVERY_ROADMAP_AI.json"
  log_ajustes: "DATA/QA/LOG_AJUSTES.csv"
  change_log: "DATA/QA/CHANGE_LOG.csv"
  rmxp_base: "DATA/QA/RMXP_KNOWLEDGE_BASE_CSV.csv"
  legacy_bundles: "DATA/QA/LEGACY_BUNDLES.csv"
  legacy_bundle_contents: "DATA/QA/LEGACY_BUNDLE_CONTENTS.csv"
  reference_master_media: "DATA/CORE/REFERENCIAS_MASTER.csv"

governance:
  ai_readability_policy: "DATA/GOV/AI_READABILITY_POLICY.json"
  legacy_bundle_policy: "DATA/GOV/LEGACY_BUNDLE_POLICY.json"
  bundle_minimal_manifest: "DATA/GOV/MANIFESTO_8_ARTEFATOS.json"
  mer_ai: "DATA/GOV/MER_AI.csv"
  spec_func_ai: "DATA/GOV/SPEC_FUNC_AI.csv"
  spec_func_ai_doc: "DATA/GOV/SPEC_FUNC_AI.md"
integrity:
  manifest: "manifest.json"
  checksums: "checksums.sha256"
```

## Mandatory process rules (analysis & homologation)

**During analysis of any AJ (LOG_AJUSTES item)**  
- **MUST** register at least one *future improvement* in `LOG_AJUSTES.FuturasMelhorias` (even if the AJ is small).
- **MUST** keep changes incremental and AI-friendly (prefer adding small, well-scoped artifacts over large refactors).

**During homologation of any AJ**  
- **MUST** create **at least one** new AJ record in `LOG_AJUSTES` (usually as BACKLOG) capturing a next improvement.
- **MUST** reprioritize the open pool using **WSJF** (update `WSJF_RANK`) and refresh `DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv`.


**MER / Functional Spec / Technical Spec are living artifacts (NOT optional)**  
For any AJ that changes **gameplay**, **UI**, **save data**, **runtime scripts**, **data schemas**, or **build/packaging**:
- **MUST** update `DATA/GOV/MER_AI.csv` when there is any new/changed entity group, relationship, table, column, or concept (including new save keys or persistence variables).
- **MUST** update `DATA/GOV/SPEC_FUNC_AI.csv` (add or amend an entry) describing player-facing behavior + acceptance criteria.
- **MUST** update `DATA/GOV/SPEC_TEC_AI.csv` (add or amend an entry) describing components, target files, and non-functional constraints.
- **MUST** keep traceability consistent and refreshed:
  - `SPEC_FUNC_AI.func_id` must be referenced by `SPEC_TEC_AI.trace_func`
  - `MER_AI.MER_ID` must be referenced by `SPEC_FUNC_AI.trace_mer` / `SPEC_TEC_AI.trace_mer`
  - `DATA/GOV/TRACEABILITY_MAP.csv` must be updated accordingly.
If an AJ intentionally does **not** update these artifacts, it must (1) explain why in `LOG_AJUSTES.Notas`, and (2) create a follow-up AJ (BACKLOG) to update them. No AJ may be marked **CONCLUIDO** without either updating these artifacts or recording a follow-up AJ.

---

## Como MER / SPEC_FUNC / SPEC_TEC / TRACEABILITY me ajudam a criar o jogo (e como usar melhor)

Esses 4 artefatos existem para **evitar drift**, **reduzir retrabalho** e **transformar “ideia” em implementação verificável**.

### 1) MER_AI (modelo conceitual / “o que existe no mundo de dados”)
Usos práticos:
- Evita duplicar conceitos (ex.: “Classe”, “Antecedente”, “Reputação”, “Gate”) com nomes diferentes.
- Define **IDs**, **campos**, **relacionamentos** e **cardinalidades** → guia o desenho dos CSVs e o schema de save.
- Ajuda a identificar impacto: quando um conceito muda, quais tabelas/relacionamentos precisam mudar.

Como eu devo usar em cada AJ:
- Antes de codar, eu confiro se o conceito já existe no MER.
- Se for novo/alterado: **atualizo/registro no MER** (ou crio follow-up AJ).
- Eu cito no fechamento do AJ quais `MER_ID`s foram consultados/alterados.

### 2) SPEC_FUNC_AI (especificação funcional / “o que o jogador percebe”)
Usos práticos:
- Congela o comportamento do jogo em termos observáveis (fluxos, UX, regras).
- Define **critérios de aceite** → permite QA/Smoke tests consistentes.
- Impede que scripts “corram soltos” sem descrição oficial.

Como eu devo usar em cada AJ:
- Eu crio/atualizo um item `func_id` descrevendo o comportamento + aceite.
- Eu garanto que o AJ tem um “como testar” alinhado à spec.

### 3) SPEC_TEC_AI (especificação técnica / “como vamos implementar”)
Usos práticos:
- Lista componentes, arquivos-alvo (RGSS/RMXP/CSV), restrições de performance e compatibilidade.
- Serve como plano de execução e como documentação pós-entrega.

Como eu devo usar em cada AJ:
- Eu crio/atualizo um `tspec_id` com: módulos impactados, arquivos, pontos de hook/alias, e riscos.
- Eu registro decisões técnicas (ex.: fallback quando asset não existir).

### 4) TRACEABILITY_MAP (costura MER ↔ Func ↔ Tec ↔ AJ)
Usos práticos:
- Permite “impact analysis” (o que quebra se eu mexer em X?).
- Ajuda a detectar drift (feature implementada sem spec; spec sem implementação; etc.).
- Facilita priorização (qual spec está bloqueando build?).

Como eu devo usar em cada AJ:
- Eu atualizo os vínculos: `MER_ID` ↔ `func_id` ↔ `tspec_id` ↔ `AJ_######`.

---

## Template obrigatório na execução de qualquer AJ (para manter os artefatos vivos)

Ao fechar um AJ eu **sempre** incluo na resposta:

1) **Como usei MER/SPEC/TRACEABILITY**
- MER consultado/alterado: `MER_ID`s
- Funcional consultado/alterado: `func_id`s
- Técnico consultado/alterado: `tspec_id`s
- Trace atualizado: linhas/IDs adicionadas

2) **Por que isso ajudou**
- 1–3 bullets dizendo como os artefatos reduziram risco/dúvida (ex.: evitou duplicação; definiu aceite; evitou drift de save).

3) **Checklist de consistência**
- Scripts/CSV entregues estão referenciados por `func_id/tspec_id`
- QA (LOG_AJUSTES/CHANGE_LOG) atualizado
- Manifest/checksums atualizados



**Guiding goal**  
These AJs must move us along the delivery pipeline:  
MER AI-friendly → Functional Spec AI-friendly → Technical Spec AI-friendly → Game Dev → Local executable tests (Act 1) → Steam publish (Act 4) → Post-publish improvements.




## 0) Disciplina de decisões (sem suposições) + Canon-first

- **Canon-first:** trate **CORE** como canon. Tudo em **DEV/EM_CONSTRUCAO** é rascunho e **não deve ser assumido como história final**.
- **Sem suposições:** se uma decisão necessária **não** estiver explícita nos arquivos do projeto, registre como **BACKLOG** (ou PENDING_REVIEW quando existir) e **peça confirmação ao usuário** antes de “cravar” como canon.
- **Evite extrapolar escopo:** quando o usuário trouxer novas expectativas (ex.: mais mini bosses, novas UIs, sistemas), **atualize o backlog e o WSJF** ao invés de “presumir” que já está resolvido.
- **Canonização explícita:** qualquer item DEV→CANON precisa de (1) decisão/critério de aprovação e (2) rastreabilidade no LOG_AJUSTES.

## 0.1) Disciplina de IDs de Ajustes (AJ)

- **NUNCA** conflitar/duplicar `AjusteID`.
- Antes de criar novos AJs: **leia `DATA/QA/LOG_AJUSTES.csv`**, extraia o maior `AJ_######` e gere o próximo (`max + 1`).
- Não “preencha buracos” (ex.: pular para um número antigo) sem motivo — prefira sequência crescente.
- Gate recomendado: o prepack/validador deve falhar se houver IDs duplicados no LOG.





## 0.2) Leitura ativa (anti-“seguir ordens friamente”)

> Objetivo: **interpretar** os dados (intenção + impacto + coerência) — não apenas “ler” tabelas.

**Em qualquer análise (principalmente Chunks/Quests/NPCs/Itens/Craft):**
1) **Pergunte “por que isso existe?”**  
   - Qual loop do jogador isso atende? (exploração, combate, economia, social, mistério)  
   - Em qual **arco/capítulo** isso entra?  
   - Em qual **faixa de level/ato** isso é permitido?

2) **Cheque coerência cruzada (sempre):**
   - Chunk ↔ Conexões ↔ POIs/WorldMap ↔ Quests/Sidequests ↔ NPCs ↔ Recursos ↔ Crafting ↔ Inners/Dungeons
   - Se algo aparece “só no texto” e não existe em dicionários/IDs → **marcar como PENDENTE_DE_MATERIALIZAR**.

3) **Gatilhos de “suspeita” (não canonizar):**
   - Nome próprio inventado (“Vila Rose” sem decisão do usuário)  
   - Mecânicas fora do escopo do Ato (ex.: *calamidades/agenda semanal* em Ato 1)  
   - Perícia/ação incoerente (ex.: madeira via “Colheita” ao invés de Corte/Lenhador)  
   - Conteúdo que conflita com decisões recentes do usuário (ex.: prólogo, level cap, ordem de tutorial)

4) **Classifique sempre (para revisão humana):**
   - **Provável verdade**: estruturado, referenciado por múltiplas tabelas/IDs e consistente com decisões do usuário  
   - **Pode se tornar verdade**: aparece como intenção (texto/nota), mas falta amarração/ID/implementação  
   - **Parece alucinação**: vazamento de sistema, placeholder tratado como oficial, ou conflito com decisões do usuário

5) **Referências são “lentes”, não ornamentação:**
   - Para cada decisão relevante, declarar **qual referência** influenciou (ou declarar “sem referência”).  
   - Converter referência em **regras de design testáveis** (do’s/don’ts) e mapear quais tabelas/arquivos isso afeta.

**Anti-travamento / continuidade do chat:**
- Ao final de cada chunk revisado, gerar um bloco “STATE SNAPSHOT” curto (copy/paste) com:
  - Chunk atual + direção escolhida + decisões canonizadas + pendências/perguntas
- Se possível, registrar o mesmo snapshot em um arquivo dentro do projeto (ex.: `DATA/GOV/AI_HANDOFF.md`) para retomar em novos chats.

## 0) Runbook de atuação do GPT (OBRIGATÓRIO)

Sempre que eu for **planejar ou executar** qualquer ajuste (AJ), sigo **esta ordem** (e em modo sessão posso executar múltiplos AJs):

1) **README_RM_MAIN.md** (este arquivo)
2) **Referências & Licenças**: `DATA/CORE/REFERENCIAS_MASTER.csv` + políticas (legacy/licensing).  
   Regra: *nada vira canon* vindo de legacy sem AJ explícito.
3) **Backlog/Ajustes**: `DATA/QA/LOG_AJUSTES.csv` + priorização (ex.: `DATA/QA/RPT_WSJF_OPEN_AJUSTES.csv`)
4) **MER/SPEC/TRACE** (sempre que o AJ cria/ajusta feature, regra, dado ou contrato):
   - `DATA/GOV/MER_AI.csv` (conceitos/entidades: **o “mapa mental” do jogo**)
   - `DATA/GOV/SPEC_FUNC_AI.csv` (o **o quê** do sistema: comportamento esperado)
   - `DATA/GOV/SPEC_TEC_AI.csv` (o **como**: implementação/arquivos alvo)
   - `DATA/GOV/TRACEABILITY_MAP.csv` (rastreio MER ↔ FUNC ↔ TEC para impacto/QA)
5) **Aplicar mudança** nos artefatos corretos (respeitando allowlists + ACT gates).
6) **Fechar governança/QA**: atualizar `CHANGE_LOG`, `DATA_INDEX`, `sheet_name_map`, `manifest.json`, `checksums.sha256`
   e evidências/relatórios em `DATA/QA/`.

**Obrigatório em toda entrega de AJ:**
- Declarar quais IDs foram usados (MER_ID / func_id / tec_spec_id) e **como** eles guiaram as decisões.
- Se o AJ mexe com regra/feature, garantir que os rastreios em `TRACEABILITY_MAP` permaneçam consistentes.

## 1) AI deterministic read order
0. `DATA/GOV/MANIFESTO_8_ARTEFATOS.json` (minimal bundle entrypoints: 8 artifacts contract)
1. `DATA/DATA_INDEX.csv` (what exists, hashes, dimensions)
2. `DATA/sheet_name_map.json` (sheet → csv lookup shortcut)
3. `DATA/*/00_INDEX.csv` (table metadata indexes: descriptions, key fields, table types)
4. `DATA/QA/LOG_AJUSTES.csv` (decisions + planned work)
5. `DATA/QA/CHANGE_LOG.csv` (build history)
6. `DATA/QA/RMXP_KNOWLEDGE_BASE_CSV.csv` (RMXP terminology grounding)
7. `DATA/CORE/REFERENCIAS_MASTER.csv` (media/reference canon)

### AJ_000122 / AJ_000123 — tabelas machine-friendly (canon operacional)

- `DATA/CORE/CHUNK_CONEXOES.csv` agora tem **campos estruturados** (além da coluna `Conexao`):
  - `ConexaoRaw` (token cru vindo do grid humano)
  - `ConexaoTipo` (`CHUNK|BLOCKED|MINIDUNGEON|FUTURE_SCOPE|SPECIAL`)
  - `TargetType`, `TargetID`
  - `BlockReason` (`TERRAIN|WATER|ATO2|INSTANCIA|ORIGEM`)
  - `GateFlag` (placeholder para gating por flags/vars)
  - `InstanciaID` (quando `ConexaoTipo=MINIDUNGEON`)
- `DATA/CORE/REL_REQUIREMENTS.csv` centraliza **requisitos** (pre-req, reputação mínima, unlock keys) no schema:
  - `EntidadeTipo`, `EntidadeID`, `CampoContexto`, `Key`, `Operador`, `Valor`, `Ordem`, `Notas`
- `DATA/CORE/REL_TRIGGERS.csv` centraliza **gatilhos** (quests/sidequests/steps) para consumo por evento/RGSS.

Regra prática: **UI/humano lê `Conexao` e `Texto_UI`; o runtime/validador lê `*Raw`, `*Tipo`, `REL_*`.**


8. NPC personality & dialogue scaffolding (SF-0310):
   - CORE: `DATA/CORE/PERSONALITY_AXIS_DEF.csv`, `DATA/CORE/PERSONALITY_ARCHETYPE.csv`, `DATA/CORE/FACTION_NORMS.csv`, `DATA/CORE/DIALOGUE_INTENTS.csv`
   - DEV: `DATA/DEV/NPC_PROFILE.csv`, `DATA/DEV/NPC_STATE.csv`, `DATA/DEV/NPC_RELATIONS.csv`, `DATA/DEV/DIALOGUE_VARIANTS.csv`, `DATA/DEV/MEMORY_FLAGS.csv`, `DATA/DEV/RECENT_EVENTS.csv`


## 2) Directives (MUST rules)
- MUST treat `DATA/*` as **current working drafts** (design notes + implementation scaffolding). **Conflicts are expected**.
  - NEVER assume a table is “correct” just because it exists or says CANON.
  - When data contradicts the agreed canon (user decisions), record the conflict and open/adjust an AJ to reconcile.
- MUST load `DATA/GOV/MANIFESTO_8_ARTEFATOS.json` first when operating under constrained context; treat its 8 artifacts list as the **minimum required set**.
- MUST NOT invent IDs (RefIDs, token policies, etc.). If something required is missing, mark **PENDING** and request canonical insertion.
- MUST NOT **assumir** ou **afirmar como decidido** o escopo de entrega (ex.: *Ato 1*, lista de features, marcos/bosses) sem:
  1) verificar o canon nos CSVs (ex.: `ACT_ENTITY_TAGS.csv`, `DIC_CAPITULOS_*`, `DIC_MONSTROS_*`, etc.) e
  2) registrar a decisão no `LOG_AJUSTES` (ou marcar **PENDING** + abrir AJ de decisão para o usuário aprovar).
- Se houver lacuna de informação, **não inventar**: registrar como **PENDING** e/ou criar AJ em BACKLOG para decisão (com perguntas objetivas).
- MUST keep `HUMAN/*` unchanged unless an explicit HUMAN_VIEW AJ requests edits.
- MUST treat `LEGACY/*` as reference-only. Any migration into `DATA/*` must be explicit and logged (include a doubts ledger + mapping plan before migration).
- MUST, during **AJ analysis**, include at least one "Future improvements" candidate (or explicitly state none), aligned to the delivery roadmap (Section 7).
- MUST, during **AJ homologation**, (1) create ≥1 new record in `DATA/QA/LOG_AJUSTES.csv` and (2) reprioritize the open demand pool by WSJF (update `WSJF_RANK` for open items).
- MUST keep outputs oriented toward shipping the game (RMXP best practices → local executable tests → Steam release), not only maintaining datasets.
- If README is edited manually, integrity artifacts may become stale. This is expected and resolved by a **mechanical rebuild** (separate from content decisions).



## 2.1) Canon vs Draft (como lidar com contradições)

Este repositório **é um banco vivo de design**. Tabelas podem conter:
- **Ideias/rascunhos** (texto), placeholders e escopos parcialmente escritos;
- **Variações antigas** (“mortos” vs “ausentes”), que precisam de refatoração;
- **Dados técnicos** já prontos para RMXP/RGSS (flags, eventos, integração).

Regras de operação:
- **Canon = decisões do usuário registradas em LOG_AJUSTES + artefatos atualizados**.
- Se um arquivo contradiz o canon, ele vira **PENDING_CONSISTENCY**: não “corrijo na cabeça”; eu **abro AJ** e proponho a correção mínima.
- A fonte de verdade *para execução* é o **conjunto consistente após o AJ**, não uma tabela isolada.

## 2.2) Termos canônicos (glossário mínimo)

- **Âncora de Respawn** (*sinônimos aceitos em texto: “lareira”, “acampamento”*): ponto de retorno ao morrer + checkpoint que marca a transição para o modo sandbox.
  - Padrão de escrita recomendado: “Âncora de Respawn (Lareira/Acampamento)”.
- **Chunk (ChaveMapa)**: `(linha)(coluna)(id)` ex.: `23R1` = linha 23, coluna R, id 1.
  - Cada chunk tem **1 origem (parent)** e pode originar **até 3 filhos**.
  - Entre chunks podem existir **Minidungeons** (entrada num chunk, saída em outro).
  - Dentro de um chunk podem existir **Inners/Dungeons** (entrada/saída no mesmo chunk).

## 2.3) Estrutura de história (4 linhas paralelas — sandbox)

### Gatilhos oficiais (fonte de verdade)
- **Fim do prólogo / sandbox liberado:** ao setar a **Âncora de Respawn** em `23T3`.
- **ROSE_ARC:** disponível após o prólogo; missão principal detalhada ao falar com a líder (`NPC-0001` em `24S1`).
- **VILA_ROSE_LIFE:** inicia ao falar com a líder (`NPC-0001` em `24S1`) — serviços/reputação.
- **MAD_MAGE_ARC:** inicia ao entrar em `23U4` (auto-start) ou, garantido, ao entrar em `23V5` (batalha forçada da Cockatrice).
- **GOBLIN_RUINS_ARC:** inicia ao encontrar os 3 mentores em `23P7` (batalha tutorial estilo Wally).
- **Nota (machine-friendly):** ver `DATA/CORE/REL_TRIGGERS.csv` para os gatilhos normalizados (quests/sidequests/steps).

## 2.4) Modo de execução por sessão (batch)

Quando o usuário disser “execute”, isso define uma **sessão**.
- Numa sessão eu posso executar **múltiplos AJs** (o máximo seguro) mantendo governança e integridade.
- Eu devo sempre atualizar: `LOG_AJUSTES` + `CHANGE_LOG` + `manifest/checksums` e devolver os módulos ZIP atualizados.

## 2.5) Uso obrigatório de Referências (REFERENCIAS_MASTER) + RMXP grounding

Para cada AJ (análise e execução):
- **Citar RefIDs relevantes** (ex.: OSRS, GW2, Dark Souls, Overlord) e declarar “como influencia” (sem copiar assets).
- Consultar `DATA/QA/RMXP_KNOWLEDGE_BASE_CSV.csv` quando a mudança toca implementação RMXP/RGSS.
- Se uma regra/cena depende de RMXP (eventos/páginas/switches/variables), registrar no `SPEC_TEC_AI.csv` ou no plano do AJ.



## 3) AI_QUERY_PLAYBOOK (minimal routines)
- LOAD_CANONICAL → verify canonical files exist and parse cleanly.
- ACT1_SCOPE_DIGEST → extrair marcos do Ato 1 (capítulos e minibosses) direto das tabelas canon; nunca assumir escopo sem esse digest.
- LOG_PENDING_NEXT → select the single next AJ by WSJF/priority/rank.
- MEDIA_COUNTS_BY_CATEGORY → derive counts from `REFERENCIAS_MASTER.csv` (no hardcoding in README).
- INTEGRITY_STALENESS_CHECK → detect stale manifest/checksums/DATA_INDEX without treating it as semantic corruption.
- DIALOGUE_CONDITIONSEXPR_VALIDATE → validate `DATA/DEV/DIALOGUE_VARIANTS.csv.ConditionsExpr` using `DATA/CORE/DIALOGUE_TAGS.csv` + `DATA/DEV/MEMORY_FLAGS.csv` and write QA report `DATA/QA/RPT_DIALOGUE_CONDITIONSEXPR_VALIDATION.csv`.
- WSJF_REPRIORITIZE_OPEN_POOL → recompute `WSJF_RANK` for open items (required during homologation).
- FUTURE_IMPROVEMENTS_CAPTURE → during analysis, output ≥1 future improvement candidate aligned to the delivery roadmap (or state none).

(Full QA outputs should be written as structured files under `DATA/QA/*`.)

## 4) Legacy analysis protocol (before any migration)
Legacy artifacts are **kept for consultation** until their AJ is complete, then can be discarded.

**Before migrating anything from legacy:**
1. Identify the legacy bundle in `DATA/QA/LEGACY_BUNDLES.csv`.
2. Inspect bundle contents via `DATA/QA/LEGACY_BUNDLE_CONTENTS.csv`.
3. Answer/record questions in `DATA/QA/LEGACY_ANALYSIS_QUESTIONS.csv` (do not guess).
4. Create a migration map (what maps to which canonical tables) and mark **PENDING_REVIEW** until approved.

## 5) Biblioteca de referência (RPG Maker XP / RGSS / Narrativa)

**Objetivo:** dar suporte técnico (RPGMXP/RGSS) e narrativo (Overlord) para evoluir de **MER ai-friendly → Especificação Funcional ai-friendly → Especificação Técnica ai-friendly → Desenvolvimento → Executável local (Ato 1) → Publicação Steam (Ato 4)**.

### Artefatos adicionados (dentro do projeto)

- `LEGACY/REF_LIBRARY/rpgmxp_main_document.pdf` — manual/guia RPG Maker XP (uso e padrões).
- `LEGACY/REF_LIBRARY/rgss_reference_manual.pdf` — manual RGSS (Ruby no RPGMXP).


### Leitura ativa das referências (como virar regra de design)

As referências (`DATA/CORE/REFERENCIAS_MASTER.csv`) **não são “lista de inspirações”**. Elas são **lentes de design**.

**Procedimento obrigatório quando uma referência for relevante:**
1) Extrair 3–7 padrões úteis (ex.: loop, ritmo, UI, telegraphing, risco/recompensa).
2) Converter em **regras testáveis** (do/don’ts) — ex.:  
   - “Evitar time-gating semanal no early game”  
   - “Tutorial travado deve durar pouco e terminar em um marco claro (ex.: borda da floresta)”
3) Mapear a aplicação em dados: quais tabelas/colunas/IDs serão afetados.
4) Registrar a aplicação em `REFERENCIAS_APLICADAS_*` (ou no AJ) para evitar “inspiração esquecida”.

**Anti-vazamento de escopo:**
- Não importar mecânicas de atos/níveis altos (ex.: calamidades lvl 60+) para o Ato 1.
- Se um dado em DEV sugerir isso, classificar como **Parece alucinação** e empurrar para backlog do ato correto.


### External bundles (size-based storage policy)

Canonical records:
- `DATA/QA/LEGACY_BUNDLES.csv` (bundle pointer registry: BundleID, SHA256, size, retention)
- `DATA/QA/LEGACY_BUNDLE_CONTENTS.csv` (optional per-file inventory for audit/search)
- `DATA/GOV/LEGACY_BUNDLE_POLICY.json` (machine-readable policy: thresholds, versioning, retention)

Policy summary:
- Large bundles MAY be stored **externally** (outside this snapshot) to keep the core bundle small and deterministic.
- This snapshot stores **pointers only** (BundleID + SHA256 + metadata). Do not embed multi-hundred-MB sources unless explicitly required.


### Bundle growth & size limits (scaling plan)

This project can outgrow a single snapshot ZIP (upload/download reliability, tooling timeouts, very large legacy references).
When thresholds are hit, **split delivery into deterministic modules** (multiple ZIPs) while preserving the rule that **`DATA/*` is canonical truth**.

Canonical policy file:
- `DATA/GOV/BUNDLE_SCALING_PLAN.json`

**Triggers (any one):**
- Snapshot ZIP exceeds **40 MB** OR file count exceeds **1,000**
- Any single legacy reference exceeds **10 MB**
- Upload/download failures or instability in the chat environment
- Act isolation is required (e.g., to ship/validate Act 1 without bundling future acts)

**Module layout (recommended):**
- `RM_CORE.zip` → `DATA/CORE` + `DATA/GOV` (excluding heavy legacy assets) + README pointers
- `RM_ACT1.zip` → Act 1 content only (chunks, quests, dialogues, RMXP exports)
- `RM_QA.zip` → QA reports + `LOG_AJUSTES` + `CHANGE_LOG` (append-only) to avoid bloating CORE
- `RM_LEGACY.zip` → reference docs/media + AI digests; large refs may use the `LEGACY_BUNDLES` registry (external pointers)

**Assembly rules:**
- Each module has its own `manifest.json` + `checksums.sha256`.
- Root `manifest_modules.json` lists `{module_id, version_aj, zip_sha256, size_bytes, required_order}`.
- Adjustments must target the **minimal** module(s); do not repack unrelated modules.
- Removing legacy assets is allowed **only** inside legacy bundles and must keep a pointer + hash for auditability.

**Chris Sawyer mode (when near limits):**
- Keep IDs short and stable; avoid repeated prose in CSVs.
- Move long-form narrative/reference text to legacy digests; keep `DATA/*` entries as pointers/tags.
- Periodically dedupe/prune deprecated legacy assets; never delete canonical DATA history.

### AI-only digests for legacy references (metadata-first)

Canonical index (machine-readable):
- `DATA/QA/LEGACY_AI_DIGEST_INDEX.csv` — list of legacy reference documents + usage mode + digest links.

Digests (AI-friendly summaries; no full-text reproduction):
- `DATA/QA/LEGACY_AI_DIGESTS/LEGACY_DOC_0001__RGSS_REFERENCE_MANUAL__AI_DIGEST.md`
- `DATA/QA/LEGACY_AI_DIGESTS/LEGACY_DOC_0002__RPGMXP_MAIN_DOCUMENT__AI_DIGEST.md`
- `DATA/QA/LEGACY_AI_DIGESTS/LEGACY_DOC_0003__OVERLORD_LIGHTNOVELS__AI_GUIDE.md` (metadata-only + original guidance)

Indexes (metadata-only navigation aids):
- `DATA/QA/RGSS_API_SYMBOLS.csv` — RGSS modules/classes/data structures + source page pointers (no quotes).
- `DATA/QA/RGSS_AUTHORING_MAP.csv` — implementation tasks → RGSS symbols map (UI/input/audio/etc.).
- `DATA/QA/RMXP_MANUAL_SECTIONS.csv` — section/page ranges for RPG Maker XP main document.


External bundle inventory (metadata-only):
- `DATA/QA/EXTERNAL_BUNDLE_INVENTORY__LEGACY_BUNDLE_0002.csv` — file list + sizes from `RPGMXP_RGSS_NARRATIVE_REFERENCES.zip` (not embedded).

Rules:
- DO NOT embed large external archives > policy threshold inside the snapshot; register via legacy bundle pointers + inventory.
- DO NOT copy novel text or large manual excerpts into this repository. Use **summary-only** digests + original patterns.
- Convert learnings into: MER (AI-friendly) → Functional Spec (AI-friendly) → Technical Spec (AI-friendly) → RMXP dev → Local executable tests → Steam pipeline.
Human retrieval + verification (external to this bundle):
1) Obtain the external ZIP from your own storage.
2) Verify `sha256(zip)` matches `LEGACY_BUNDLES.SHA256`.
3) Store locally under `LOCAL_EXTERNAL_BUNDLES/<BundleFilename>` (NOT inside `RM_project_files/`).
4) When you create AI-only extracts, commit only the **derived lightweight artifacts** into `DATA/QA/` (never the full source bundle).

Versioning rules:
- Bundles are immutable. Any change to contents = new `BundleID` + new `SHA256`.
- Never overwrite an existing bundle record; mark older ones as `SUPERSEDED` (or keep status and use Notes).

Retention / discard rules:
- Keep an external bundle until all IDs listed in `LEGACY_BUNDLES.RetainUntilAjustes` are **CONCLUIDO** and the necessary AI-only extracts exist in-bundle.
- **Planned deprecation:** PDFs/EPUBs are **temporary** once AI digests are complete; phase them out from the snapshot bundle. Keep **image assets** (or an image-only bundle) for future game art generation.
- After that, mark as `DISCARD_CANDIDATE` (deletion happens outside this snapshot policy).

Registered external bundle (current):
- `LEGACY_BUNDLE_0002` → `LEGACY/RPGMXP_RGSS_NARRATIVE_REFERENCES.zip` (external pointer; see registry CSV for hash/size)

### Publication safety (copyright)

- Treat novels/manuals as **reference only**.
- For AI workflows: prefer *summaries, glossaries, topic maps, and indices*.
- Do not include verbatim copyrighted text in game content or in any public artifact.

## 6) GDD legacy migration (AJ_000145)
This AJ converts the legacy GDD into **AI-usable structured artifacts** and a **migration plan**, without silently changing canonical gameplay tables.

**Primary legacy source (baseline):**
- `LEGACY/EXTERNAL/RM_Project_IMPORTAR_DOCUMENTOS_LEGADO.zip`
- Primary doc (for extraction): `GDD_Rave_Masters_v0_2_ptBR_LEGADO.md`

**Artifacts produced (machine-readable):**
- `DATA/QA/GDD_LEGACY_DOCS.csv` (legacy GDD doc index + hashes)
- `DATA/QA/GDD_LEGACY_SECTIONS.jsonl` (sectionized content for retrieval/grounding)
- `DATA/QA/GDD_MIGRATION_MAP.csv` (section → suggested canonical sheets; **PENDING_REVIEW**)
- `DATA/QA/GDD_LEGACY_FACTS.csv` (bullet/rule lines extracted; **PENDING** migration)
- `DATA/QA/RPT_GDD_DIFF_SUMMARY.csv` (high-level heading differences between legacy versions)
- `DATA/QA/RPT_AI_READINESS.csv` (bundle-wide AI friendliness scan; HUMAN is an exception)

**Rule:**
- Nothing from legacy becomes canonical unless it is explicitly migrated into `DATA/*` by a tracked AJ.

## 7) AI readability policy
See `DATA/GOV/AI_READABILITY_POLICY.json` for bundle rules and QA reports.


## 8) Delivery roadmap (outcome chain)
This bundle exists to ship a high-quality RPG (RPG Maker XP) to Steam. Data governance is a means to that end.

**Chain (target):**
1) MER (AI-friendly) → stable naming + ER model for the game's domain (entities, relations, constraints).
2) Functional specification (AI-friendly) → gameplay loops, UX flows, feature rules, acceptance criteria.
3) Technical specification (AI-friendly) → RMXP implementation mapping (tables ↔ scripts/events/maps), performance constraints, build rules.
4) Game development (RMXP) → implement features, integrate data, iterate on content and balance.
5) Local executable + playtest gate (**Act 1**) → generate a runnable local build for tests *before* public release; log findings and prioritize fixes.
6) Steam publication gate (**Act 4**) → ship the full game to Steam (packaging, compliance, marketing assets).
7) Post-publication improvements → new content, QoL, balancing, and expansions; keep WSJF-driven backlog.

**Guiding constraint:** every AJ should move at least one step forward in this chain (or unblock it) and should record future improvement candidates during analysis.
6.8 Routine: COLUMN_META_LOOKUP (schema grounding)
Source: `DATA/GOV/COL_META_MASTER.csv`

Use:
- Given a normalized column name (or raw/original variant), return:
  - `col_meta_id`
  - `column_normalized`
  - `predominant_type`
  - `original_variants`
  - `reason_flags_union`
  - usage counts (files/sheets)

Notes:
- This file is a derived governance artifact (built from canonical CSV headers + naming maps).
- If missing/stale, schedule a mechanical rebuild of `COL_META_MASTER` (separate from content decisions).

## Operator bridge (RPG Maker XP project README)

- Where to perform RGSS/XP integration and playtests:
  - c:\Users\marti\OneDrive\Documentos\RPGXP\RM_Project\README.md (operational, XP-focused)
- AJ workflow (short):
  - Pick the next AJ in DATA/QA/LOG_AJUSTES.csv (WSJF-driven).
  - While executing: update Status (ANALISE→DESENVOLVIMENTO→TESTES→HOMOLOGAÇÃO).
  - If gameplay/UI/save/build changed: update MER_AI / SPEC_FUNC_AI / SPEC_TEC_AI and refresh TRACEABILITY_MAP.
  - On homologation: mark CONCLUIDO, add ≥1 follow-up AJ (BACKLOG), and refresh WSJF rank/report.

Note: This README remains a read-only snapshot of the canon/process. The project-level README contains XP editor snippets, debug tips, and quick smoke steps.
