# Progreso

Fase actual: personajes verificados; combate siguiente.

Repositorio inicialmente vacío. Entorno: Windows, Godot 4.7.2 estable, Node 24.19.0, npm 11.17.0 y Git. Docker y psql no detectados en PATH. Sin instalaciones globales.

Terminadas: estructura, configuración persistida, autoload con registro, menú Jugar/Configuración/Salir y transición. Aldea con plaza, caminos, seis edificios, tienda/herrero identificables, árboles, muros, iluminación ambiental y abertura señalizada hacia bosque. Movimiento mouse/continuo, A*, ocho orientaciones y animaciones idle/caminar, cámara y Y-sort.
Pruebas realizadas: importación headless y smoke; 544 comprobaciones de movimiento incluyendo física real, desvío de obstáculos, clic sobre sólido, llegada/parada, destino repetido, colisiones sin navegación y bloqueo de diagonales. Capturas gráficas reales menú y mundo en artifacts/, revisadas visualmente con renderer OpenGL NVIDIA. Sin errores de motor.
Errores corregidos: wrapper console instalado apunta a un ejecutable ausente; se usa godot.exe. PowerShell lanzaba el exe GUI sin esperar: runner ahora espera, captura logs, verifica exit code y detecta errores semánticos.
Errores corregidos de movimiento: recálculo repetido del mismo destino podía regresar al centro de la celda; se conserva ruta al mismo destino. Soltar sobre UI cancela clic sostenido. Se acercaron edificios a la plaza tras revisar captura.
Personajes terminados: creación con nombre validado y selección Guerrero/Mago/Elfa, cuatro atributos, siete estadísticas derivadas por datos, nivel/experiencia/puntos iniciales, animación en ocho direcciones y equipo inicial visual distinto. Datos compartidos en shared/classes.json, sincronizados al cliente por tools/sync-data.mjs; fórmulas centralizadas en EterCharacter.
Pruebas de personajes: 33 comprobaciones, nombres válidos/inválidos, rechazo de clase desconocida, cálculos de referencia, aislamiento de datos, formulario y creación/movimiento real de las tres clases. Capturas gráficas de las tres pantallas inspeccionadas sin recortes.
Limitaciones actuales: destino ajustado al centro de tile; arte procedural reconocible pero provisional, fuente del motor; salida aún sin cambio de mapa. El equipo es apariencia inicial, no inventario/equipamiento intercambiable aún. No hay combate, economía, persistencia ni red implementados.
Decisiones: renderer Compatibility, resolución interna 640x360 y recursos originales procedurales locales.
Próxima tarea: combate en tiempo real y habilidades por clase; usar primero objetivo de entrenamiento comprobable, después seis especies e IA. No declarar implementado lo que sólo figura en datos de diseño.
