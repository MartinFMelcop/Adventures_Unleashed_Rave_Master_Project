# Guias de código (RGSS / Ruby 1.8)

Estilo
- Snake_case para métodos/variáveis; CamelCase para Classes/Módulos.
- Linhas curtas; métodos curtos; nomes claros.
- Sem sintaxe moderna (compatível com Ruby 1.8 / RGSS).

Arquitetura
- Núcleo (Core): utilidades genéricas; sem dependência de jogo.
- Sistemas: módulos por domínio (Inventário, Batalha, UI).
- Cenas: uma classe por tela; responsabilidades únicas.
- Evite “monólitos” em eventos; extraia lógica recorrente para scripts.

Boas práticas
- Não modificar scripts padrão diretamente: prefira:
  - Subclasses,
  - Módulos com refinamentos via alias_method_chain (compatível 1.8),
  - Padrões de composição (delegar responsabilidades).
- Proteja I/O: tratar exceções ao ler/escrever arquivos.
- Logue entradas/saídas críticas e erros (veja 00 - Core).

Testabilidade manual
- Isolar regras de negócio em métodos puros.
- Adicionar chaves de debug para simular estados.
- Use DebugTools.log_section para cercar cenários.

Nomenclatura no Editor de Scripts
- 00 - Core
- 10..80 - Systems/Scenes (prefixos por domínio, ex.: 20 - System - Inventory)
- 90 - Dev / Debug
- 99 - Bootstrap

Commits
- Mensagem: tipo(módulo): resumo curto
  - ex.: feat(inventory): adiciona pilhas e limite
