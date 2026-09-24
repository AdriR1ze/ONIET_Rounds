# Feature: Balance de poderes y habilidades (borrar 6 + rebalancear 20)

## Objective

Borrar 6 poderes completos y rebalancear un lote de habilidades, ajustando los
valores en `upgrades/definitions/*.tres` (fuente de verdad en runtime) y en su
generador `tools/generar_upgrades.gd` (para que sigan sincronizados).

## Problem

Pedido explícito del usuario: varios poderes son demasiado fuertes o molestos, y
varias habilidades tienen nerfeos que quiere quitar o suavizar.

## Scope

- Backend de mejoras: `rounds/upgrades/**`, `rounds/tools/generar_upgrades.gd`.
- Integración de efectos en `rounds/player/player.gd`,
  `rounds/player/components/weapon_component.gd`, `rounds/weapons/bullet.gd`.
- La escena `card_theme_window.gd` NO se toca: los temas (`armadura`, `sangre`,
  `barrera`, `demolicion`) los comparten otras mejoras.

## Decisions

- **.tres = runtime.** `UpgradeDatabase` (autoload) carga todos los `.tres` al
  arrancar. Borrar un poder = borrar su `.tres` (más su efecto). Editar valores =
  editar el `.tres`.
- **Generador sincronizado.** `generar_upgrades.gd` es la fuente documental; se
  edita a mano junto con el `.tres`. **NO se corre el generador** (regeneraría
  los 41 archivos con IDs nuevos y ensuciaría todo el diff).
- **Borrado completo, no dead code.** Al borrar un poder se elimina su `.tres`,
  su `.gd` + `.uid` y su integración en `player.gd`/generador.
- **`Piel Armadura` = Piel Adaptativa** (confirmado por el usuario).
- **Bullet Time** suma `+1%` de daño por cada segundo que la bala está en el aire.
- **Propulsión**: se quita `-10% daño`, se sube el empuje y se permite acumular al
  spamear, con tope para no salir volando.
- **Golpe Titánico**: cooldown mínimo de ataque `0.2 s`.
- **Ruleta Rusa**: crítico de `x4` ( +300% ) a `x3` ( +200% ), nerfeo a `-15%`.

## Tasks

### T1 — Borrar 6 poderes
- [x] T1.1 Borrar `definitions/{corazon_titanio,ira_sangre,sepultador,muro_vivo,cosecha_balas,carga_blindada}.tres`
- [x] T1.2 Borrar `effects/{corazon_titanio_effect,ira_sangre_effect,sepultador_effect,muro_vivo_effect,cosecha_balas_effect,carga_blindada_effect}.gd` (+ `.uid`)
- [x] T1.3 Quitar los `preload` y los bloques `_crear(...)` de esos 6 en `tools/generar_upgrades.gd`
- [x] T1.4 Quitar su integración en `player.gd` (ver detalle abajo)

### T2 — Quitar nerfeos de daño
- [x] T2.1 Bala Anclante: quitar `damage MULT 0.90` + desventaja
- [x] T2.2 Perforadora Vital: quitar `damage MULT 0.90` + desventaja
- [x] T2.3 Piel Adaptativa: quitar `damage MULT 0.90` + desventaja
- [x] T2.4 Deuda de Sangre: quitar `damage MULT 0.90` + desventaja
- [x] T2.5 Nexo de Vida: quitar `damage MULT 0.85` + desventaja

### T3 — Quitar nerfeos de cadencia / salud máxima
- [x] T3.1 Magnetismo: quitar `fire_rate MULT 0.90` + desventaja
- [x] T3.2 Sanguijuela Vampírica: quitar `max_health MULT 0.85` + desventaja + frase de descripción
- [x] T3.3 Segunda Piel: quitar `max_health MULT 0.85` + desventaja

### T4 — Ajustes numéricos
- [x] T4.1 Bala Pesada: `fire_rate 0.65 → 0.80` (texto `-35% → -20% cadencia`)
- [x] T4.2 Gatillo Eléctrico: `damage 0.65 → 0.75` (texto `-35% → -25% daño`)
- [x] T4.3 Vitalidad Sólida: `max_health ADD 40 → 30` (textos)
- [x] T4.4 Bala de Plomo: `bullet_gravity 1.60 → 1.50` (texto `+60% → +50% caída`)
- [x] T4.5 Balas Fantasma: `damage 0.90 → 0.85` (texto `-10% → -15% daño`)
- [x] T4.6 Impacto Sísmico: `damage 0.80 → 0.90` (texto `-20% → -10% daño`)
- [x] T4.7 Maestro del Rebote: `damage 0.85 → 0.80` (texto `-15% → -20%`)
- [x] T4.8 Glitch: `spread 8.0 → 20.0` (texto `+8° → +20°`)

### T5 — Ruleta Rusa
- [x] T5.1 `russian_roulette.tres` + generador: `damage 0.88 → 0.85`, textos `+300%/x4 → +200%/x3` y `-12% → -15%`
- [x] T5.2 `weapon_component.gd`: crítico de bala `* 4.0 → * 3.0` (línea ~142) y melee `*= 4 → *= 3` (línea ~401)

### T6 — Bullet Time (+1%/s en el aire)
- [x] T6.1 `bullet_time_effect.gd`: agregar `@export var damage_growth_per_sec: float = 0.01`
- [x] T6.2 `bullet.gd` `_on_area_entered`: aplicar el crecimiento sobre el daño final usando `_time_alive`
- [x] T6.3 Textos del `.tres`/generador: documentar `+1% daño por segundo en el aire`

### T7 — Propulsión
- [x] T7.1 `.tres` + generador: quitar `damage MULT 0.90` y su desventaja
- [x] T7.2 `propulsion_effect.gd`: subir `recoil_force` (220 → 300)
- [x] T7.3 `player.gd` `apply_recoil`: tope de velocidad para permitir acumulación sin salir disparado

### T8 — Golpe Titánico
- [x] T8.1 `weapon_component.gd`: cooldown mínimo `0.2 s` cuando el ataque es melee

### T9 — Verificación
- [x] T9.1 `bash scripts/godot-check.sh` → `RESULT: PASS`
- [x] T9.2 Contar definiciones cargadas (41 − 6 = 35) sin `.tres` rotos

## Detalle de T1.4 — Cirugía de `player.gd`

Borrar SOLO lo de los 6 poderes; conservar Deuda de Sangre, Segunda Piel,
Piel Adaptativa, etc.

**Variables a borrar:**
- `_harvest_armor_stacks`, `_harvest_armor_timer` (Cosecha de Balas)
- `_charge_armor`, `_running_time`, `_charge_hit_cooldown` (Carga Blindada)
- `has_titanium_heart`, `_titanium_heart_ready`, `_titanium_heart_cooldown` (Corazón de Titanio)
- `_sepultador_timer`, `_sepultador_damage`, `_last_sepultador_source` (Sepultador)
- `active_barrier`, `_still_timer` (Muro Vivo)

**Lógica a borrar:**
- `_check_sepultador_collision()` y sus 2 llamadas en `_physics_process`
- `mark_sepultador()` y `_check_sepultador_collision()`
- En `hurt()`: la intercepción de barrera y el bloque de Corazón de Titanio
- En `get_armor_reduction()`: los aportes de Cosecha y Carga (dejar Piel Adaptativa)
- En `get_speed_multiplier()` / `get_damage_multiplier()` / `_update_dots()`: los `has_effect_id("ira_sangre")`
- En `respawn()`: los resets de cosecha/carga/titanio/sepultador/barrera (dejar los de Deuda de Sangre)
- En `aplicar_mejoras()`: `has_titanium_heart` y la barrera (dejar `has_blood_debt`)
- En `_update_buffs()`: bloques de Cosecha, Corazón de Titanio, Sepultador y Cooldown de Carga

## Verification

```bash
GODOT_BIN="$USERPROFILE/Downloads/Godot_v4.7-stable_win64_console.exe" bash scripts/godot-check.sh
```

Baseline antes de tocar: `VALIDATE: checked 106 scripts, 0 failed` + `RESULT: PASS`.

## Progress

- [x] Implementación completa (T1–T8) en el working tree (sin commit).
- [x] Evidencia de verificación:
  - `VALIDATE: checked 100 scripts, 0 failed` (106 baseline − 6 efectos borrados).
  - Smoke test de `test_level.tscn` sin `SCRIPT ERROR|Parse Error|Compile Error|Failed to load`.
  - 35/35 definiciones cargan (`bad=0`; 41 − 6 borrados), con los valores objetivo
    confirmados por script (`heavy_bullet fire_rate=0.80`, `gatillo damage=0.75`,
    `vitalidad max_health=30`, `lead_slug bullet_gravity=1.50`,
    `phantom damage=0.85`, `impacto damage=0.90`, `ricochet damage=0.80`,
    `glitch spread=20`, `russian damage=0.85`, y `stats=[]` en
    bala_anclante/perforadora/piel_adaptativa/deuda_sangre/nexo/magnetismo/
    vampiric_leech/segunda_piel).
  - Sin referencias colgadas a los 6 poderes borrados (única excepción: string
    placeholder inerte en `tests/test_dynamic_keyboard.gd`).
- [!] Review nativo (RDD on): **detenido a propósito**. El candidato del worktree
  incluye trabajo concurrente del usuario sin relación (`training_target.*`
  sin trackear; `tutorial_level.*`, `stat_sheet.gd`, `demolition_effect.gd`
  modificados), así que no es un work-unit limpio de este cambio. Se preservó el
  estado; pendiente decidir/commitear y reintentar el preflight si se quiere review.
- [x] Nota: `weapon_component.gd` también traía cambios concurrentes del usuario
  (auto-recarga tras 1 s) que NO son parte de este cambio y se dejaron intactos.
