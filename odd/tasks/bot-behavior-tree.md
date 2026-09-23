# Feature: Bot Behavior Tree

## Objective

Migrar la IA del bot (`BotBrain`) de la lógica imperativa en `_physics_process`
a un **Behavior Tree nativo de Godot** (sin addons ni dependencias externas),
preservando el comportamiento observable actual.

## Problem

`rounds/player/components/bot_brain.gd` concentra 5 fases en un método lineal
con `return`s ad-hoc y estado disperso en timers sueltos. No hay una estructura
de prioridades explícita que permita, a futuro, que nuevas conductas compitan
por el control (esquivar, retirarse, recargar, elegir target).

## Why

Pedido explícito del usuario: "implementa behavior trees". Se acordó migrar la
estructura ahora y **no** agregar comportamientos nuevos en este cambio
(principio de cambio mínimo del `AGENTS.md`).

## Scope

**In scope**
- Framework BT mínimo: `BTNode`, `BTSequence`, `BTSelector`, `BTLeaf`.
- Refactor de `BotBrain` para construir y tickear el árbol.

**Out of scope**
- Nuevas conductas (dodge, HP-aware, ammo, targeting por amenaza).
- Arreglo de límites hardcodeados / migración a `RayCast2D` (ver memoria de
  evaluación; va en un cambio aparte).

## Constraints

- GDScript idiomático, un `class_name` por archivo (convención del proyecto).
- Sin addons, sin autoloads nuevos, sin Managers.
- **Preservar la API que usa el test** `test_death_loop_and_bot_abyss.gd`:
  `BotBrain._evitar_abismo(delta)` y `BotBrain._move_axis` deben seguir
  existiendo con la misma semántica.
- Sin cambio de comportamiento observable.

## Tasks

| ID | Task | Route | Status |
|----|------|-------|--------|
| T1 | Crear framework BT (4 archivos en `rounds/player/components/bt/`) | delegated (writer trigger: 2+ archivos) | done |
| T2 | Refactorizar `BotBrain` para usar el árbol, preservando métodos | delegated (mismo writer) | done |
| T3 | Verificar: `scripts/godot-check.sh` + test del bot | delegated (writer ejecuta) | done |
| T4 | Commit work-unit | parent | done |

## Tree design (comportamiento preservado)

```
Root = Selector
  ├─ Sequence
  │    1. Condition: _can_act()          # player válido, vivo, can_control
  │    2. Action:    _check_parry()       # corre ANTES de buscar target (igual que hoy)
  │    3. Condition: _has_target()        # cachea _target; FAILURE si no hay
  │    4. Action:    _update_movement()
  │    5. Action:    _update_aim()
  │    6. Action:    _update_shooting()
  └─ Action: _stop()                       # cero move/fire (fallback del Selector)
```

Orden verificado contra el código actual: reset de flags → guardas → cooldown →
prune → parry → find_target → movement → aim → shoot.

## Acceptance criteria

- `scripts/godot-check.sh` en PASS (todos los scripts compilan + smoke test).
- `test_death_loop_and_bot_abyss.tscn` pasa (frena ante el abismo).
- El bot sigue disparando, apuntando y evadiendo igual que antes.

## Checks

```
GODOT_BIN=/home/adriano/Downloads/Godot_v4.7.2-stable_linux.x86_64 bash scripts/godot-check.sh
GODOT_BIN=/home/adriano/Downloads/Godot_v4.7.2-stable_linux.x86_64 \
  /home/adriano/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless \
  --path rounds res://tests/test_death_loop_and_bot_abyss.tscn
```

## Progress / Evidence

- T1/T2 — writer de contexto fresco (delegated). Creados `bt_node.gd`, `bt_sequence.gd`, `bt_selector.gd`, `bt_leaf.gd`; `bot_brain.gd` cablea el árbol. Diff: `+49 / -27` en bot_brain.gd.
- T3 — Verificación observada (writer + spot check del padre, idéntico):
  - `scripts/godot-check.sh` → `VALIDATE: checked 89 scripts, 0 failed` / `RESULT: PASS`
  - `test_death_loop_and_bot_abyss.tscn` (headless) → 2 ✓ + `TODOS LOS TESTS...` , exit 0.
- Gotcha de toolchain: agregar `class_name` nuevos requiere `godot --headless --path rounds --import` una vez, porque el class cache vive en `rounds/.godot/` (gitignored). En el editor se resuelve solo al abrir el proyecto.

## Next step

Comportamiento preservado. Conductas nuevas (dodge, HP-aware, ammo, targeting) quedan para un cambio aparte.
