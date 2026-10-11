# Skill Editor
CONTENT > Skills muestra los seis poderes existentes. Create usa ID estable; editar nombre, descripción, Classes, Required Level, Icon, Mana Cost, Cooldown, Range, Base Damage, Damage Multiplier, Scaling Stat e Hits.
Los modos runtime existentes son single, area, multiple y heal. El selector Behavior conecta direct_damage/projectile a single, area_damage/aoe_around_player a area, multi_projectile a multiple y heal a heal. Heal Fraction usa fracción de vida; Max Targets limita multiple.
BUFF/DEBUFF/DIRECTIONAL están preparados en el esquema y bloqueados por Validate hasta tener implementación verificada. Cast Time, Projectile Speed, VFX externos y algunos parámetros de duración todavía requieren integración; no asumir efecto sólo porque se guardan.
Inventory Icon permite dibujar/importar PNG. CREATE SKILL BOOK crea un item compatible y abre Items para editar icono/suelo; el libro no se equipa.
Un poder nuevo con Book Item ID requiere aprendizaje. Libro: clases y nivel deben coincidir; al aprender se consume una vez. Si ya se conoce, no se consume. Habilidades iniciales existentes siguen disponibles.
Audio / Cast Sound se reproduce mediante Audio Manager. Impact/travel/loop se preparan para integración según efecto.
TEST abre sala: elegir clase y skill, TEST CAST. Ver MP used/cooldown y daño del dummy. Restore HP / MP es independiente; repetir respetando cooldown. Guardado desactivado.
