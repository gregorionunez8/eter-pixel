# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones implementadas y smoke headless pasa. Siguiente: captura gráfica `tools/invoke-godot.ps1 -Label menu -Expected 'PASS rendered menu' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-menu')`; luego navegación AStarGrid2D y CharacterBody2D con pruebas de rutas y colisiones. El ejecutable válido es C:\Godot\godot.exe; el wrapper console instalado está roto. No ejecutar el exe GUI directamente en pruebas: usar tools/invoke-godot.ps1.
