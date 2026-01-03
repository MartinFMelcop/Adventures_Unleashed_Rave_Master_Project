# Fluxo inicial do jogo (Prólogo → Criação de personagem → Spawn)

## Canon (Ato 1)

**Prólogo (não jogável):** na **capital**, o jogador vê o **cartaz da menina perdida** antes da aventura.  
Isso é **apenas uma sequência de imagens** (slideshow/storyboard), sem controle do personagem e sem exploração de mapa.

**Depois do prólogo:**
1. **Tela de criação do personagem** (classe, antecedente, passiva selecionada etc.).
2. **Spawn direto na vila (mapa de origem)** no chunk **24R0_I**.
3. A partir daí, o jogo segue normalmente (ex.: tutorial/quests iniciais em 24R0_I).

## Implicações para dados do projeto

- O **prólogo não precisa** aparecer no **HUMAN_VIEW_CHUNK_GRID** (não consome Chunk/ChaveMapa).
- Se existir referência ao prólogo em dados, ela deve ser marcada como **CUTSCENE/UI**, não como “mapa jogável”.
- Qualquer trigger de quest do Ato 1 deve assumir que o jogador já está na vila quando começa a jogar.

## Sugestão de implementação em RMXP (RGSS)

- Implementar o prólogo como uma **Scene** exibindo imagens com input “avançar/voltar”, antes de entrar na cena de criação.
- Ordem típica:
  - `Scene_Title` → `Scene_PrologueSlides` → `Scene_CharacterCreate` → `Scene_Map` (transfer para 24R0_I).
