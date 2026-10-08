# Dirección artística

Fantasía medieval oscura original. Piedra azul espectral como acento; ciudad en pizarra, tierra húmeda, tejados rojizos y madera vieja. Siluetas reconocibles, texturas en grupos de píxeles y luces cálidas de herrería.

Paleta: tinta #111522, sombra #202838, piedra #424e5a, piedra clara #75828b, musgo #304638, hierba #46634b, madera #49352e, cobre #9f6044, oro #d5aa64, éter #64c8cf, piel #c59a79.

Tiles 32x32; personajes 32x48; props anclados al suelo y ordenados por Y. Base 640x360, nearest, escalado entero y sin suavizado.

Se evaluó ImageGen disponible. Para la primera iteración se elige generación procedural determinista de sprites raster originales: permite mantener paleta, escala, bordes y reproducibilidad exactas. No se emplean recursos remotos ni de terceros. No es aún arte comercial final.

Licencias: código y arte creados en este repositorio para ÉTER; sin dependencias gráficas externas. La fuente predeterminada del motor es provisional.

Recursos presentes: assets/terrain.png (atlas 32x32), traveler.png (32 frames 32x48, 8 direcciones), tree.png, house.png, shop.png, smith.png, shrine.png y wall.png. Generador local tools/generate-art.mjs, determinista y sin dependencias npm. Sombras raster transparentes, edificios con tejados y mampostería; no bloques planos como escenario final.

Clases: warrior.png, mage.png y elf.png son hojas 128x384 con cuatro frames en ocho direcciones. Siluetas con acero/espada, túnica violeta/bastón de éter y cuero verde/arco. Previews a escala entera 3x, sin filtro. El equipo visual inicial forma parte de la hoja; cambios de equipo dinámicos quedan para inventario.

Enemigos originales: spider.png y wolf.png (64x48 por frame), goblin.png/skeleton.png/orc.png (48x64), guardian.png (64x80), cuatro frames horizontales cada uno. Ocho patas y ojos rojos, lobo gris de ojos de éter, goblin de orejas largas, huesos con costillas, orco blindado y guardián de armadura oscura con cuernos y hacha. Orientación lateral mediante flip; no hay aún ocho vistas distintas por especie. Captura de la zona revisada con barras compactas que no cubren siluetas.
