# Guideline: densidade de POIs por mapa (benchmark do legado)

Este guideline serve para manter mapas **“incríveis”** (detalhados) sem virar ruído.

## Definição prática (POI)

No legado, usei esta definição para “POI significativo”:
- **Evento** que possui **comandos** (não apenas um sprite decorativo), ex.: diálogo, trigger, puzzle, cutscene, teleporte, loot, etc.

Eventos só decorativos (sem comandos relevantes) contam como **decorativo**.

## Benchmark (projeto legado)

- Mapas analisados: **47**
- POIs significativos: mediana **2**, P75 **5**, máximo **14**

Top 10 (POIs significativos):

|   MapID | MapName   |   POI_Significant |   EventsDecorative |
|--------:|:----------|------------------:|-------------------:|
|       4 | X18       |                14 |                  0 |
|      14 | W21       |                 9 |                  0 |
|       7 | W19       |                 8 |                  1 |
|       8 | V19       |                 8 |                  0 |
|       9 | X20       |                 8 |                  0 |
|      11 | X21       |                 8 |                  0 |
|      17 | X22       |                 8 |                  0 |
|      25 | W17       |                 5 |                153 |
|       5 | W18       |                 5 |                  0 |
|       6 | X19       |                 5 |                  9 |

Arquivo de apoio: `QA/DATA/QA/LEGACY_POI_BENCHMARK.csv`

## Faixas recomendadas (padrão novo)

- **Mapas principais (história / hubs / áreas com quests):** **8–12 POIs significativos**
- **Mapas de transição (corredores / trilhas curtas):** **3–6 POIs significativos**
- **Arenas/boss e mapas de evento único:** **4–8 POIs significativos** (foco em ritmo)

Decorativos:
- Até **2×** o número de POIs significativos (ex.: 8 POIs → até ~16 decorativos), **preferindo menos**.

## Regra de ouro

Cada POI precisa ter um “porquê” claro:
- informar (lore), recompensar, criar escolha, criar risco, ensinar mecânica, ou reforçar atmosfera.
