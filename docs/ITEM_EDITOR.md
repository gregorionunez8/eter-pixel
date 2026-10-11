# Item Editor
Abrir ÉTER Studio > CONTENT > Items. Los 13 items actuales aparecen sin migración destructiva.
1. Create: ID blade_001. ID estable; Name es el nombre visible.
2. Type: weapon, helmet, armor (Chest), gloves, pants, boots, ring, pendant (Necklace), wings, pet, shield, potion, consumable, skill_book, quest_item, material o misc.
3. Elegir Required Level, clases reales mediante casillas o ALL, Size, Max Stack y durabilidad.
4. Bonuses edita daño/defensa/vida/maná base. Options > + Agregar campo ofrece únicamente opciones permitidas por el tipo. Weapon permite Skill; Boots permite Speed. Los porcentajes de opciones usan unidades legibles: 4.5 significa 4.5%.
5. Inventory Icon, Ground / Drop Sprite y Equipped Visual / Path tienen selección y Dibujar / Importar independientes. El atlas original se conserva como fallback de icono/suelo. Offset, Scale, Layer, Hframes y Vframes configuran la capa equipada.
6. Buy Price / Sell Price controlan economía; un Sell Price de 0 impide vender. Las tiendas pueden sobrescribir su Buy Price.
7. Save All; Build Content; TEST da el item al personaje de prueba. Abrir inventario y Equipar/usar.
Duplicate exige otro ID. Delete muestra referencias y pide confirmación. Búsqueda por ID/nombre, filtro Type y orden ID/nombre.
Upgrade Preview muestra attack/defense por nivel con las reglas actuales. Cambiar el máximo y probabilidades en GAME > Balance > Item Upgrade.
Luck y Excellent son estadísticas preparadas; no generan golpes o recompensas nuevos. Storable prepara una política para almacenamiento futuro: no existe baúl en este incremento. Las capas equipadas del jugador local funcionan; verificar visuales remotos separadamente.
