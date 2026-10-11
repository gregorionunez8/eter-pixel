# Content Validation
TOOLS > Validate o toolbar Validate. ERROR bloquea Save/Build; WARNING permite continuar; INFO confirma resultado sin problemas detectados. Click abre el registro cuando existe.
Comprueba IDs/formato, claves JSON duplicadas, item/skill/NPC/shop/map/drop references, clases, libros, probabilidades0-100, cantidades/upgrades, spawns/portales fuera de mapas, destino inexistente, PNG/audio faltantes y referencias cíclicas de media.
No sustituye pruebas de movimiento/combate ni valida toda la semántica del juego. Campos preparados deben tener advertencias; consultar alcance de cada editor.
Delete confirma y muestra referencias. Borrar instancia de mapa conserva definición. Archivos PNG/audio no se borran automáticamente al quitar metadata.
Save verifica SHA de catálogos frente a edición externa antes de escribir. Si hay conflicto, conservar el archivo externo y usar Reload (descarta draft tras confirmación). Backup acotado anterior: artifacts/studio-backup.
Build Content valida, guarda shared y genera client/data y world legacy desde village. Servidor lee shared; cliente lee copia construida. No mantener otro catálogo paralelo manual.

Además se bloquean hojas equipadas incompatibles con Hframes/Vframes, formatos de media incompatibles, assets referenciados sin archivo y encargos incompletos. Cast Time/VFX externos generan WARNING; modos de skill no soportados generan ERROR. Las tres clases actuales pueden balancearse, pero crear una cuarta requiere ampliar el runtime y no está habilitado.
