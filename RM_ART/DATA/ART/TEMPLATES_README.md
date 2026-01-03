# ART Templates (RMXP)

Este diretório contém **templates** (imagens vazias) e **overlays** (grades/guias) para padronizar produção de pixel art para RPG Maker XP.

## Como usar

- Use o arquivo em `TEMPLATES/` como canvas base (transparente).
- Ative o guia correspondente em `OVERLAYS/` (a grade bate com o tamanho de tile/frame).
- Consulte `ART_TEMPLATE_REGISTRY.csv` para dimensões e propósito.

## Padrões RMXP (referência)

- Tiles: 32x32 px
- Characters: 4 direções x 4 frames (16 frames); o bitmap é dividido por 4 (largura/altura)
- Windowskin: 192x128 px
- Title: 640x480 px
- Battleback: 640x320 px
- Icons: 24x24 px

## Observações
- Tilesets: largura padrão 8 tiles (=256 px), altura variável; fornecemos 256x256 e 256x1024 como ponto de partida.
- Autotiles: usamos o formato base 3x4 tiles (96x128) e versão animada com 4 frames horizontais (384x128) como template prático para água/lava etc.
