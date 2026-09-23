---
name: godot-nodes-first
description: Use when writing or refactoring Godot GDScript code in this project (player movement, collisions, detection, timers, audio, animation, UI / Control nodes). Enforces "nodos primero": anything Godot can do with a node (RayCast2D, ShapeCast2D, Area2D, Timer, AudioStreamPlayer, AnimationPlayer, CollisionShape2D, Marker2D, Control, Containers, Label, Button...) must be a node in the .tscn, not created with .new()/add_child() or emulated with math, custom position offsets, or move_and_collide.
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
- **Interfaz de usuario / HUD / Menús** -> Nodos `Control` y contenedores en la escena:
  - **Layout y alineación** -> `VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, `CenterContainer`, `PanelContainer`. No posiciones elementos con cálculos matemáticos manuales ni acumuladores de `position`. Usá anclas (`anchors_preset`) y flags de tamaño (`size_flags_horizontal`, `size_flags_vertical`).
  - **Textos e información** -> `Label` o `RichTextLabel` configurados en la escena con sus temas, fuentes y alineaciones.
  - **Botones y entradas interactivas** -> `Button`, `TextureButton`, `CheckButton` conectados mediante señales (`pressed`, etc.).
  - **Barras y valores numéricos** -> `ProgressBar`, `TextureProgressBar`, `SpinBox` o contenedores en escena.
  - **Fondos y paneles** -> `Panel`, `PanelContainer`, `ColorRect`, `TextureRect`.

## Cómo cablearlos

- Adicionalos al `.tscn` (no en `_ready()`).
- Declará la referencia tipada:
  `@onready var _ray: RayCast2D = $CornerRayLeft`
  `@onready var _vidas_box: HBoxContainer = %VidasContainer`
- Exponé lo que deba tocar diseño con `@export`.
- Dejá el nodo activo y configurado desde la escena (`enabled = true` en `RayCast2D`,
  `monitoring`/`monitorable` en `Area2D`, anclas y márgenes en `Control`) en lugar de crearlo o armarlo íntegramente en runtime.
- Si necesitás el resultado en el mismo frame, llamá `force_raycast_update()`
  antes de leer `is_colliding()`.

## Evitá

- `RayCast2D.new()` + `add_child()` dentro de `_ready()`.
- `Control.new()`, `Label.new()`, `VBoxContainer.new()` instanciados masivamente por código para armar interfaces que deberían estar en el `.tscn`.
- `move_and_collide(..., true)` o `test_move()` como reemplazo de un nodo de
  detección.
- Contadores manuales de tiempo donde un `Timer` encaja.
- Posicionamiento absoluto manual (`position = Vector2(...)` o sumas de offsets a mano) para elementos de interfaz en lugar de usar anclas y contenedores (`Container`).

Solo caé en código puro cuando no exista un nodo adecuado, o cuando el nodo
tenga que crearse en una cantidad/scale realmente dinámica (ej. cientos de
balas o pips generados en runtime según datos variables), y dejalo dicho de forma explícita.

