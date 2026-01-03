# REPUTATION_RULES (canon)

Este arquivo define **efeitos determinísticos** de Reputação por região (*RepZona*) e nível (*RepValor*).

## Escala de reputação
A escala canônica é discreta: `-3, -2, -1, +1, +2, +3` (não usamos `0`; o “neutro” fica em `-1/+1`).

Fonte:
- `DATA/CORE/DIC_REPUTACAO_NIVEIS.csv`
- `DATA/CORE/DIC_REPUTACAO_REGIOES.csv`

## Como interpretar a tabela
Cada linha representa um “efeito” aplicável quando a reputação atual da região (`RepZona`) é exatamente (`RepValor`).

Campos principais:
- `EffectType`: categoria (`SHOP`, `SPAWN`, `AGGRO`, `DIALOGUE`, `ACCESS`)
- `EffectKey`: chave do efeito (ex.: `shop_buy_mult`)
- `EffectValue`: valor (string; interpretar conforme `ValueType`)
- `StackRule`: regra de composição caso existam múltiplas fontes (padrão para runtime/QA)

## Chaves (EffectKey) incluídas
### SHOP
- `shop_buy_mult` (float, override): multiplicador de preço de compra
- `shop_sell_mult` (float, override): multiplicador de preço de venda
- `shop_inventory_tier` (enum, override): `NONE|POOR|BASIC|STANDARD|GOOD|VIP`

### SPAWN
- `spawn_enemy_density_mult` (float, multiply): densidade de spawn de hostis
- `spawn_rare_bonus` (float, add): bônus de chance para spawns raros

### AGGRO
- `aggro_on_sight` (bool, override): 1 = hostil imediato (guardas/patrulhas)
- `aggro_range_mult` (float, multiply): multiplicador do raio de aggro
- `ambush_chance_bonus` (float, add): bônus/penalidade em chance de emboscada

### DIALOGUE
- `dialogue_tone` (enum, override): `HOSTILE|THREATENING|GUARDED|NEUTRAL|FRIENDLY|ADMIRING`
- `dialogue_persuasion_dc_delta` (int, add): ajuste em DC de persuasão/suborno
- `dialogue_options_tier` (int, max): nível de opções de diálogo liberadas

### ACCESS
- `access_services_tier` (int, max): 0..4, acesso a serviços (curandeiro, loja, estalagem, etc.)
- `quest_tier_max` (int, max): 0..4, teto de “tier” de quests liberadas
- `fast_travel` (bool, override): 1 = fast travel/atalhos habilitados

## Não-expansão de história
Este canon **não cria** quests novas nem altera capítulos; só define parâmetros de gameplay para runtime/UI.

Gerado em: 2025-12-27T20:55:32Z
