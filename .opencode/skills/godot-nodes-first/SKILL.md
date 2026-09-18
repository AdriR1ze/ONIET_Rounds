---
name: godot-nodes-first
description: Use when writing or refactoring Godot GDScript gameplay code in this project (player movement, collisions, detection, timers, audio, animation). Enforces "nodos primero": anything Godot can do with a node (RayCast2D, ShapeCast2D, Area2D, Timer, AudioStreamPlayer, AnimationPlayer, CollisionShape2D, Marker2D...) must be a node in the .tscn, not created with .new()/add_child() or emulated with math or move_and_collide.
---

# Godot: nodos primero

En este proyecto, si Godot ya tiene un nodo que hace el trabajo, **usa ese nodo
en la escena `.tscn`** y referencialo desde el script. No lo crees por código
(`Nodo.new()` + `add_child()`) y no emules su función con matemática propia ni
con llamadas sueltas de física cuando existe un nodo dedicado.

## Qué usar en cada caso

- **Rayos / línea de visión / techo, suelo, paredes** -> `RayCast2D`
  (o `ShapeCast2D` si necesitás un volumen). Van como nodos en la escena con
  su `position`, `target_position` y `collision_mask` configurados.
- **Solapamiento / proximidad / hurtbox / pickups** -> `Area2D` con señales.
- **Temporizadores / cooldowns / llamadas diferidas puntuales** -> nodo `Timer`
  (o `SceneTreeTimer` solo para un caso realmente único). No uses un contador
  manual `_timer -= delta` cuando un `Timer` encaja.
- **Audio** -> `AudioStreamPlayer` / `AudioStreamPlayer2D`.
- **Animación** -> `AnimationPlayer` / `AnimatedSprite2D`.
- **Cuerpo del jugador / física** -> `CharacterBody2D` con `CollisionShape2D`
  hijos y `move_and_slide()`.
- **Marcadores, spawners, triggers** -> `Marker2D`, `Area2D`, nodos en escena.

## Cómo cablearlos

- Adicionalos al `.tscn` (no en `_ready()`).
- Declará la referencia tipada:
  `@onready var _ray: RayCast2D = $CornerRayLeft`
- Exponé lo que deba tocar diseño con `@export`.
- Dejá el nodo activo desde la escena (`enabled = true` en `RayCast2D`,
  `monitoring`/`monitorable` en `Area2D`) en lugar de activarlo en runtime.
- Si necesitás el resultado en el mismo frame, llamá `force_raycast_update()`
  antes de leer `is_colliding()`.

## Evitá

- `RayCast2D.new()` + `add_child()` dentro de `_ready()`.
- `move_and_collide(..., true)` o `test_move()` como reemplazo de un nodo de
  detección.
- Contadores manuales de tiempo donde un `Timer` encaja.

Solo caé en código puro cuando no exista un nodo adecuado, o cuando el nodo
tenga que crearse en una cantidad/scale realmente dinámica (ej. cientos de
balas), y dejalo dicho de forma explícita.
