# Progreso

Fase actual: movimiento y primera Aldea de Éter verificados; personajes siguientes.

Repositorio inicialmente vacío. Entorno: Windows, Godot 4.7.2 estable, Node 24.19.0, npm 11.17.0 y Git. Docker y psql no detectados en PATH. Sin instalaciones globales.

Terminadas: estructura, configuración persistida, autoload con registro, menú Jugar/Configuración/Salir y transición. Aldea con plaza, caminos, seis edificios, tienda/herrero identificables, árboles, muros, iluminación ambiental y abertura señalizada hacia bosque. Movimiento mouse/continuo, A*, ocho orientaciones y animaciones idle/caminar, cámara y Y-sort.
Pruebas realizadas: importación headless y smoke; 544 comprobaciones de movimiento incluyendo física real, desvío de obstáculos, clic sobre sólido, llegada/parada, destino repetido, colisiones sin navegación y bloqueo de diagonales. Capturas gráficas reales menú y mundo en artifacts/, revisadas visualmente con renderer OpenGL NVIDIA. Sin errores de motor.
Errores corregidos: wrapper console instalado apunta a un ejecutable ausente; se usa godot.exe. PowerShell lanzaba el exe GUI sin esperar: runner ahora espera, captura logs, verifica exit code y detecta errores semánticos.
Errores corregidos de movimiento: recálculo repetido del mismo destino podía regresar al centro de la celda; se conserva ruta al mismo destino. Soltar sobre UI cancela clic sostenido. Se acercaron edificios a la plaza tras revisar captura.
Limitaciones actuales: destino ajustado al centro de tile; arte procedural reconocible pero provisional, fuente del motor; salida aún sin cambio de mapa. No hay personajes/clases, combate, economía, persistencia ni red implementados.
Decisiones: renderer Compatibility, resolución interna 640x360 y recursos originales procedurales locales.
Próxima tarea: selección y creación de tres clases, atributos y estadísticas derivados por datos, sprites diferenciados y pruebas.
