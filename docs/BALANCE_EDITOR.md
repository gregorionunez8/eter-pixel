# Balance Editor
GAME > Balance muestra multiplicadores y, debajo, reglas originales de Item Upgrade, Economy y Progression / Reset. Los catálogos originales siguen siendo fuente de verdad.
Monster: hp, damage (incluye min/max configurados), defense, experience, gold, drop_rate, respawn. Skill: damage (base y escalado), mana, cooldown, pve. Economy: buy_multiplier/sell_multiplier. Todos default1; cliente/servidor aplican iguales adapters.
Player: Starting Level, Starting Stat Points, Experience Multiplier. GAME > Classes cambia atributos/ataque/speed y las reglas reales de intervalo/rango/skills de cada clase. GAME > Balance > Player Stat Formulas edita las fórmulas globales existentes de HP/MP/defensa/accuracy/evasion; no se duplican por clase.
Progression: max_level, puntos por nivel, penalidad XP, fórmula base/exponente. Experience Mode permite formula/table; agregar filas a Experience Table en orden de nivel. Tabla Required/Total XP muestra primeras200 filas.
Item Upgrade: max, stat_per_level, costos y chances. La tabla de chances debe cubrir el máximo; Validate lo exige. Economy: sell_fraction/repair_per_point/precios.
Reset: activar en Progression, reset_min_level; Balance/reset fija cost, starting_level, points, bonus, max_resets y políticas. Un NPC tipo reset permite confirmar; servidor valida proximidad y aplica transacción. Inventario/equipment/quests conservados; stats initial/keep y skills keep/initial.
PvP multiplier y durability scaling están preparados pero no se debe afirmar uso runtime sin su prueba específica. No son parte de PvP avanzado.
Guardar, construir y reiniciar juego/servidor. Cambios no modifican retroactivamente todos los personajes guardados; probar saves y límites al reducir valores.
