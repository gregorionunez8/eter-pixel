# Diseño de juego

Economía jugable local: monstruos dejan oro y objetos según tablas. Clic recoge al acercarse. Iria vende pociones/armadura/accesorios; Daro vende armas/protecciones, repara y mejora. Comprar entrega una unidad; vender entrega la pila completa y requiere desequipar. Se cobra reparación por punto perdido. Impactos desgastan arma/armadura, durabilidad cero elimina bonos. +0..+15 cobra oro, chance y descenso de un nivel al fallar configurables; la primera mejora es garantizada. Oro inicial0, entrenar permite financiar compras; efigies no premian.

Aldea de Éter es un refugio levantado alrededor de una piedra azul que protege a viajeros de la niebla. El Bosque de las Sombras y la Cripta Olvidada contienen los restos del pacto que originó esa protección.

Guerrero: fuerza y defensa; Mago: energía y magia; Elfa: agilidad, arco y apoyo. Cuatro atributos: fuerza, agilidad, vitalidad y energía. Equipamiento y progreso definidos por datos.

Control principal: clic izquierdo para desplazarse, mantener para actualizar destino; clic sobre enemigo para perseguir y autoatacar. Habilidades en barra; I inventario, C personaje, M mapa, Enter chat, Esc menú.

Ciclo previsto: crear personaje, entrar a la aldea, entrenar, obtener experiencia y equipo, vender y mejorar, explorar zonas más difíciles. Se documentará qué segmentos existen efectivamente en PROGRESS.md.

Progresión implementada: nivel inicial1, curva XP=floor(80*nivel^1.7), cinco puntos por nivel y cap100. Atributos a elección mediante C. Subir nivel restaura recursos, morir pierde 5% de XP parcial sin bajar nivel. Efigies sirven para practicar sin XP; sólo monstruos dan su recompensa. Resets preparados pero desactivados en esta slice. Equipo/economía todavía pendientes.

Inventario implementado:8x6, tamaños hasta2x3; ocho slots, equipo inicial de clase, tres pociones, espada mágica inicial en suelo una sola vez. I abre ventana, arrastrar mueve/equipa, doble clic/derecho usa/equipa, seleccionar slot y Desequipar devuelve a bolsa si cabe. Soltar transfiere UID al suelo, clic recoge desde48px o camina hacia objeto. Pila pociones10/materiales20. Rarezas normal/mágico/excelente/legendario; mejoras hasta15, fallo baja un nivel y costo creciente. Mejoras aún requieren API, interfaz de herrero y economía siguientes. Suelo temporal, guardado local de objetos propios.
