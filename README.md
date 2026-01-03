# RM_Project — Guia rápido

Objetivo
- Padrões mínimos p/ organização, log, debug e qualidade em projetos RGSS (RPG Maker XP).

## Passo a passo inicial
1) Crie as pastas scripts/core, scripts/dev e docs (fora do editor).
2) Cole scripts/core/core_extensions.rb no slot “00 - Core”.
3) Cole scripts/dev/debug_tools.rb no slot “90 - Dev / Debug”.
4) No script Main, envolva a inicialização com DebugTools.wrap_main.
5) Ajuste RMXPCore::Config::DEBUG = true para ligar logs durante o desenvolvimento.

Estrutura sugerida (fora do editor)
- scripts/core: utilidades de núcleo (não dependem de jogo).
- scripts/dev: ferramentas de desenvolvimento (debug, medidores, logs).
- docs: convenções e processos.
- Use este repositório como “fonte da verdade”; copie/cole para o Editor de Scripts.

Ordem no Editor de Scripts (sugestão)
- 00 - Core (cole scripts de scripts/core, ex.: core_extensions.rb)
- 10..80 - Systems/Scenes (seu jogo)
- 90 - Dev / Debug (cole scripts de scripts/dev)
- 99 - Bootstrap (código mínimo de inicialização)

## Checklist de Integração (XP)
- [ ] “00 - Core” acima de todos os sistemas e do “90 - Dev / Debug”.
- [ ] “90 - Dev / Debug” abaixo de Core e acima do “99 - Bootstrap”.
- [ ] Main envolvida com DebugTools.wrap_main conforme exemplo abaixo.
- [ ] Rodar o jogo uma vez e verificar Game.log criado.

Logs e Debug
- Em 00 - Core, ajuste RMXPCore::Config::DEBUG = true para ligar logs.
- O log é salvo em Game.log (na pasta do executável).
- Para capturar exceções da inicialização (sem travar silenciosamente), no script Main envolva a chamada principal:

```ruby
# Envolva a função/método que inicia o jogo:
DebugTools.wrap_main("Boot") do
  # Chame aqui o fluxo normal da Main do seu projeto
  # ex.: main() ou SceneManager.run (conforme seu setup)
  main()
end
```

Dicas de versionamento
- Commits pequenos e frequentes; mensagens curtas e claras.
- Considere Git LFS para Audio/Graphics (arquivos grandes).
- Marque versões jogáveis com tags (v0.1.0, v0.2.0, …).

## Release checklist
- [ ] Definir RMXPCore::Config::DEBUG = false.
- [ ] Remover Game.log antigos do pacote.
- [ ] Fazer smoke test no executável final (boot, mapa, batalha, menu).

Boas práticas rápidas
- Separe “engine” (núcleo) de “conteúdo do jogo”.
- Evite alterar scripts padrão sem camadas/encapsulamento.
- Prefira métodos pequenos e nomes descritivos.
- Comente “porquê”, não “o quê”.

## Troubleshooting
- Game.log não aparece: confirme DEBUG = true e permissões de escrita na pasta do jogo.
- NoMethodError em DebugTools.wrap_main: verifique a ordem (Core acima de Dev) e se os scripts foram colados corretamente.
- Tela preta no boot: cheque Game.log; comente temporariamente o wrap_main para isolar a causa; restaure depois.

## Alinhamento: informações e dúvidas (prioritário)

Notas gerais (RMXP/RGSS)
- RGSS do XP usa Ruby 1.8, frame rate alvo 40 FPS, resolução nativa 640x480.
- Input: módulo Input (teclado) e suporte a gamepad via DirectInput; remapeamento é custom.
- Fontes: Font.default_name pode variar por máquina; defina fallback (ex.: ["Arial","Tahoma"]).
- I/O: save/log na pasta do jogo evita AppData, mas exige não instalar em Program Files.

Projeto e escopo
- Visão em 1–2 frases: qual a proposta central do jogo?
  - Sugestão inicial: defina gênero + “fantasy hook” + loop principal (explorar → batalhar → progredir).
  - Impacto: direciona sistemas prioritários e escopo do MVP.
- Público-alvo e idioma principal? Precisa de PT/EN multilíngue?
  - Sugestão inicial: PT-BR primeiro; estrutura para i18n simples via tabelas de texto.
  - Impacto: organização de textos/strings desde o início.
- Duração desejada (minutos/horas) e escopo do MVP?
  - Sugestão inicial: 20–40 min jogáveis, 1 boss, 1 cidade, 2 mapas de dungeon.
  - Impacto: prioriza Menu/Save, Batalha, Mapa e Cutscenes básicas.

Técnico (RPG Maker XP / RGSS)
- Resolução alvo (padrão 640x480) e modo tela cheia/janela? Precisa de scaling?
  - Sugestão inicial: 640x480 janela; Alt+Enter para fullscreen nativo; sem scaling no MVP.
  - Nota: mudanças reais de resolução exigem scripts/DLL de terceiros; evitá-los no MVP.
- Performance alvo: 40 FPS estável em quais PCs? Mapas grandes/“parallax mapping”?
  - Sugestão inicial: 40 FPS em PCs modestos; evitar parallax extensivo no MVP; limitar eventos paralelos.
  - Dicas: spritesheet leves (PNG), tiles 32x32, viewport e z-order simples.
- Sistema de batalha: padrão do XP, ATB/CTB custom, lateral, ou outro?
  - Sugestão inicial: padrão front-view do XP para MVP; side-view/ATB fica p/ fase 2.
  - Impacto: reduz risco de compatibilidade e escopo de UI.
- Input: teclado apenas ou suporte a gamepad? Precisa de remapeamento?
  - Sugestão inicial: teclado; mapear gamepad depois; remapeamento é fase 2.
  - Nota: remap requer camada sobre Input e tela de opções.

Arquitetura e código
- Padrão de extensão dos scripts padrões: alias + módulos ou subclasses?
  - Sugestão inicial: patch seguro via alias (Ruby 1.8) + módulos; subclasses para cenas novas.
  - Ex.: alias :old_method :method; def method; old_method; end
- Organização de sistemas: quais domínios vêm primeiro (Inventário, Menu, Save, Cutscenes)?
  - Sugestão inicial (ordem): Save/Load → Menu → Cutscenes/Flow → Inventário → Batalha HUD.
- Convenções adicionais além do docs/coding-guidelines.md? Ex.: prefixos de módulos.
  - Sugestão: prefixo RMXPCore/Systems::Nome; cenas como Scene_Algo; módulos utilitários em Core.

Conteúdo e UX
- Estilo de UI (fonte, tamanho, cores). Necessita fallback de fontes?
  - Sugestão: Font.default_name = ["Arial","Tahoma"]; size 22; contraste alto em janelas.
- Fluxo principal de menus (Start → Novo/Carregar/Opções). Terá Opções com áudio/video/controles?
  - Sugestão: Start → Novo/Carregar/Opções (áudio ON/OFF, volume BGM/SE).
  - Nota: vídeo/controles deixam para fase 2.
- Legibilidade: precisa de tema alto contraste ou acessibilidade mínima?
  - Sugestão: bordas e sombras de texto; evitar texto abaixo de 16px.

Saves e dados
- Slots de save, autosave e compatibilidade entre versões?
  - Sugestão: 8–12 slots; autosave ao entrar em mapa seguro; compat quebrada entre versões maiores.
- Onde armazenar saves (pasta do jogo vs AppData)?
  - Sugestão: pasta do jogo (compat XP); orientar instalar fora de Program Files.
  - Alternativa avançada: AppData via ENV["APPDATA"] (fase 2).

Logs, debug e erros
- Política de logs em release: DEBUG=false e logs desativados ou nível reduzido?
  - Sugestão: DEBUG=false em release; manter wrap_main; logs desativados em release.
- Comportamento de exceções em release: mostrar mensagem amigável + encerrar ou tentar continuar?
  - Sugestão: msg amigável + encerramento; instruir usuário a enviar Game.log.

Build, assets e distribuição
- Empacotamento: RGSSAD + encriptação de assets? Tamanho alvo do pacote?
  - Sugestão: RGSSAD ativado em release; sem encriptação em dev; alvo < 200 MB.
- Pipeline de assets (pastas, formatos: OGG/PNG) e controle de versão (Git LFS necessário)?
  - Sugestão: OGG p/ áudio, PNG p/ imagens; Git LFS para Audio/Graphics.

Qualidade e testes
- Checklist de smoke test mínimo por cena/sistema?
  - Sugestão: boot → mapa → menu → batalha curta → save/load → retorno ao mapa sem crash.
- Estratégia de testes manuais: mapas de depuração, teleports e toggles de debug?
  - Sugestão: mapa de dev com teleports e NPCs de teste; toggles via switch global.

Riscos e pendências conhecidas
- Dependências de scripts de terceiros? Compatibilidades a validar?
  - Sugestão: adiar dependências externas até estabilizar Core/Dev; validar ordem de scripts.
- Restrições de prazo/marcos (protótipo jogável, demo pública, etc.)?
  - Sugestão: MVP em 4–6 semanas; demo pública após polimento de 1 sprint.

Como responder
- Copie esta seção e responda em linha (após cada pergunta). Em seguida priorizo os próximos commits.

## Conclusão dos ajustes (provisória para próximo build)
- Resolução/Modo: 640x480 janela; Alt+Enter p/ fullscreen; sem scaling no MVP.
- Performance: alvo 40 FPS; evitar parallax pesado; limitar eventos paralelos.
- Batalha: front-view padrão XP no MVP.
- Input: teclado; gamepad/remap na fase 2.
- Arquitetura: patches via alias + módulos; cenas novas por subclasses; ordem de scripts conforme README.
- UI: Font.default_name = ["Arial","Tahoma"]; size 22; contraste alto; sombras de texto.
- Saves: 8–12 slots; autosave opcional em áreas seguras; saves na pasta do jogo (evitar Program Files).
- Logs/Erros: DEBUG=true em dev; DEBUG=false em release; wrap_main ativo; logs desativados em release.
- Build: RGSSAD em release; OGG/PNG; Git LFS p/ assets; pacote < 200 MB.
- Testes: smoke test mínimo por cena; mapa de dev com teleports e toggles de debug.

## Build v0.1.0 — Plano e tarefas
1) Editor de Scripts
   - 00 - Core: colar core_extensions.rb.
   - 90 - Dev / Debug: colar debug_tools.rb.
   - 99 - Bootstrap (Main): aplicar o snippet abaixo.
2) Configurações
   - Dev: RMXPCore::Config::DEBUG = true.
   - Release: RMXPCore::Config::DEBUG = false.
3) Testes
   - Executar o “Roteiro de smoke test (v0.1.0)”.

## log_ajustes — Itens críticos: informações e dúvidas

Como usar
- Cole abaixo, por domínio, os pontos de maior prioridade do log_ajustes.
- Preencha “Info conhecida” e responda “Dúvidas”. Marque decisões no checklist rápido.

Display (Resolução/Modo)
- Do log_ajustes: [cole linha(s) relevantes]
- Info conhecida: 640x480 janela; Alt+Enter fullscreen; sem scaling no MVP.
- Detalhes técnicos (RMXP):
  - Resolução nativa fixa (640x480). Não há API oficial para redimensionar a viewport em XP.
  - Fullscreen do XP usa DirectDraw/Direct3D com stretching do driver; pode distorcer 4:3 em monitores 16:9.
  - Letterboxing (barras pretas) e pixel-perfect dependem do driver/monitor; sem controle fino no XP vanilla.
- Dúvidas: precisa de letterbox garantido em 16:9? tolera blur em fullscreen?
- Ação/Responsável/Prazo: [definir política fullscreen/letterbox] [owner] [data]

Performance (FPS/Mapas/Parallax)
- Do log_ajustes: [...]
- Info conhecida: alvo 40 FPS; evitar parallax pesado; limitar eventos paralelos.
- Detalhes técnicos (RMXP):
  - Custo alto: muitas Pictures, eventos Paralelos, Bitmap.new/Bitmap#hue_change por frame, blend/tone/zoom contínuos.
  - Boas práticas: reaproveitar Bitmaps/Sprites; evitar alocação por frame; chamar dispose corretamente.
  - Orçamentos sugeridos (MVP): ≤ 3 processos paralelos por mapa; ≤ 20 pictures simultâneas; ≤ 60 eventos visíveis ativos.
- Dúvidas: haverá parallax animado? mapas > 80x80 tiles? partículas em batalha?
- Ação/Responsável/Prazo: [mapear mapas críticos e orçamentos por cena] [owner] [data]

Batalha (Sistema/Compat)
- Do log_ajustes: [...]
- Info conhecida: front-view padrão XP no MVP.
- Detalhes técnicos (RMXP):
  - Manter animações leves (frame count reduzido) e evitar múltiplos SE simultâneos.
  - HUD mínima: usar Window_Base padrão para status e dano sem bitmaps personalizados no MVP.
- Dúvidas: bosses exigem HUD custom (ex.: barras múltiplas)? skills com splash screen?
- Ação/Responsável/Prazo: [definir escopo HUD/skills MVP] [owner] [data]

Input (Teclado/Gamepad/Remap)
- Do log_ajustes: [...]
- Info conhecida: teclado; gamepad/remap fase 2.
- Detalhes técnicos (RMXP):
  - Mapeamentos padrão: Input::C (Confirm: Z/Enter/Space), Input::B (Cancelar: X/Esc), Input::A (Shift), L/R (Q/W).
  - Gamepad via DirectInput funciona out‑of‑the‑box; remap requer camada própria sobre Input.
- Dúvidas: confirmar layout final de teclas exibido na UI? suporte a AZERTY?
- Ação/Responsável/Prazo: [documentar layout e mensagens de ajuda] [owner] [data]

Arquitetura (Patches/Ordem)
- Do log_ajustes: [...]
- Info conhecida: patches via alias + módulos; ordem 00 Core, 10..80 Systems, 90 Dev, 99 Bootstrap.
- Detalhes técnicos (RGSS/Ruby 1.8):
  - Usar alias e wrappers (sem alias_method_chain) para manter compatibilidade.
  - Evitar editar scripts padrão inline; preferir módulos e subclasses.
- Dúvidas: haverá scripts de terceiros no MVP (ex.: título custom)? ordem e compatibilidade?
- Ação/Responsável/Prazo: [listar dependências externas e validar ordem] [owner] [data]

UI (Fontes/Tema/Legibilidade)
- Do log_ajustes: [...]
- Info conhecida: Font.default_name ["Arial","Tahoma"]; size 22; contraste alto; sombras.
- Detalhes técnicos:
  - Anti‑alias padrão ativo; em PCs sem fonte, Windows substitui automaticamente (variação visual).
  - Windowskin padrão do XP evita incompatibilidades de paleta no MVP.
- Dúvidas: títulos/menus precisam de tamanhos diferentes? suporte mínimo a daltônicos?
- Ação/Responsável/Prazo: [tabela de tamanhos por tela e paleta segura] [owner] [data]

Saves (Slots/Autosave/Local)
- Do log_ajustes: [...]
- Info conhecida: 8–12 slots; autosave opcional; saves na pasta do jogo (evitar Program Files).
- Detalhes técnicos:
  - XP salva .rxdata na pasta do executável; privilégios de escrita exigidos.
  - Autosave: recomendado em transições de mapa seguras (após transfer_player), nunca durante batalha.
- Dúvidas: política de compatibilidade entre versões (semântica)? avisar ao carregar save antigo?
- Ação/Responsável/Prazo: [definir número de slots e pontos de autosave] [owner] [data]

Logs e Erros (DEBUG/Release/Wrap)
- Do log_ajustes: [...]
- Info conhecida: DEBUG=true dev / false release; wrap_main ativo; logs desativados em release.
- Detalhes técnicos:
  - wrap_main registra exceções e re‑lança em dev; em release, usar print amigável + exit.
  - Rotação de log simples por tamanho (Config::LOG_MAX) quando DEBUG=true.
- Dúvidas: mensagens de erro devem incluir instruções para suporte? idioma PT‑BR apenas?
- Ação/Responsável/Prazo: [aprovar texto padrão de erro] [owner] [data]

Build (RGSSAD/Assets/Tamanho)
- Do log_ajustes: [...]
- Info conhecida: RGSSAD em release; OGG/PNG; alvo < 200 MB; Git LFS p/ assets.
- Detalhes técnicos:
  - Empacotador do XP gera Game.rgssad; criptografia básica, impede edição trivial.
  - OGG (128–192 kbps) para BGM/ME/BGS/SE; PNG 8/24‑bit com compressão lossless.
- Dúvidas: incluir créditos/licenças no pacote? política para fontes externas?
- Ação/Responsável/Prazo: [definir checklist legal de assets] [owner] [data]

Testes (Smoke/Mapa Dev)
- Do log_ajustes: [...]
- Info conhecida: roteiro de smoke test no README; mapa de dev com teleports e NPCs.
- Detalhes técnicos:
  - Casos adicionais: Alt+Tab durante BGM; sessão > 30 min (detectar vazamento de Bitmaps); load após game over.
  - Verificar dispose de bitmaps/sprites ao trocar de cena (evitar leaks).
- Dúvidas: plataformas alvo de teste (Win 7/10/11)? resolução do monitor referência?
- Ação/Responsável/Prazo: [matriz de testes e artefatos a coletar] [owner] [data]

Checklist de decisão rápida
- [ ] Manter 640x480 sem scaling no MVP.
- [ ] Evitar parallax pesado no MVP.
- [ ] Sistema de batalha front-view padrão.
- [ ] Somente teclado no MVP.
- [ ] Autosave habilitado em áreas seguras.
- [ ] DEBUG=false em release e wrap_main ativo.
- [ ] Empacotar com RGSSAD em release.

## Conclusão aprofundada dos ajustes (provisória)
- Display: manter 640x480; fullscreen via Alt+Enter, aceitar barras pretas/blur conforme driver; sem scaling custom no MVP.
- Performance: budgets por cena definidos (paralelos ≤ 3, pictures ≤ 20); reuso de Bitmaps/Sprites obrigatório; evitar alocação por frame.
- Batalha: front‑view padrão; HUD mínima usando Windows padrão; animações leves.
- Input: teclado com mapeamento padrão do XP; documentar teclas na UI; remap/gamepad pós‑MVP.
- Arquitetura: alias + módulos; sem alterar scripts padrão diretamente; ordem de slots conforme README.
- UI: fontes ["Arial","Tahoma"], size 22 padrão; manter windowskin padrão; contraste/sombra ativados.
- Saves: 10 slots (default do projeto); autosave somente em transições seguras; salvar na pasta do jogo.
- Logs/Erros: DEBUG=true em dev (log com rotação); DEBUG=false em release (mensagem amigável + encerrar).
- Build: RGSSAD no release; assets OGG/PNG otimizados; pacote alvo < 200 MB; revisar licenças/creditos.
- Testes: smoke test + sessão longa (30 min) + Alt+Tab + save/load pós‑batalha; checagem de dispose em troca de cenas.

## LOG_AJUSTES — Execução prática (XP)

Abrir um AJ (antes de codar)
- Escolha o próximo AJ no DATA/QA/LOG_AJUSTES.csv (ordem WSJF).
- Mude Status para ANALISE/ DESENVOLVIMENTO; preencha Owner/ETID se aplicável.
- Aponte impactos previstos (MER/SPEC_FUNC/SPEC_TEC/TRACE) — se mudar gameplay/UI/save/build, esses artefatos devem ser atualizados.

Fechar/Homologar um AJ (após testar no XP)
- Status → HOMOLOGAÇÃO → CONCLUIDO.
- Registre evidências mínimas: arquivos alterados (paths), snippet de teste/smoke, resultado esperado/obtido.
- Crie ≥1 novo AJ (BACKLOG) de melhoria futura relacionado ao item (governança exige).
- Repriorize WSJF (atualize WSJF_RANK/relatório quando aplicável).

Dicas rápidas no XP
- Core/Debug: 00 - Core e 90 - Dev / Debug (ordem definida acima).
- Bootstrap: manter wrap_main e fontes padrão do trecho deste README.
- Smoke: use o roteiro v0.1.0 já listado.

Links úteis
- Processo/Canon (snapshot, leitura): RM_CORE/README_RM_MAIN.md
- LOG_AJUSTES (fonte da verdade): RM_QA/DATA/QA/LOG_AJUSTES.csv