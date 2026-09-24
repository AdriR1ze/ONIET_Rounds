# Feature: Nivel Tutorial (sala de práctica) + botón en el menú

## Objective

Un **nivel aparte** de práctica, accesible desde un **botón nuevo en el menú
principal** (al lado de `Jugar`, `Índice`, `Opciones`, `Salir`), donde el jugador
puede probar los controles sin rondas, sin vidas y sin presión.

El nivel muestra un panel con los controles reales del jugador 1 y libera la
práctica cuando el jugador lo confirma.

## Problem

Hoy no existe NADA de tutorial, onboarding, ni detección de primera vez
(verificado: no hay archivos `tutorial*`, sin flags en `Settings`). Un jugador
nuevo entra directo a `character_select` → `test_level` y tiene que adivinar los
controles en medio de una pelea real.

## Why

Pedido explícito del usuario: *"es un nivel aparte va a estar en los botones como
jugar etc"*. Un nivel separado no ensucia la partida real ni el flow de rondas.

## Decisions (cerradas)

- **Nivel aparte, no overlay.** Se entra desde el menú, no desde la partida.
- **Sin `RunController`.** No hay rondas, vidas, banners ni `MatchHUD`. El nivel
  es un sandbox. `player.gd` funciona suelto: `player.gd:151` solo descarta al
  jugador si `player_number > RunManager.cantidad_jugadores` (default `2`).
- **Un solo jugador (`Player1`).** El tutorial se entra desde el menú, ANTES de
  `character_select`, así que todavía no hay cantidad de jugadores. Mantenerlo en
  P1 es lo que lo hace "mini". **No instanciar `Player3`/`Player4`**: serían
  descartados por `player.gd:151-154`.
- **Reusar un mapa existente ya registrado**, no autorar tiles nuevos. Se instancia
  la escena del mapa como hijo del nivel. Cero arte nuevo, look consistente.
- **La muerte es un reset blando, no un callejón sin salida.** El mapa reusado
  trae su `DeadZone` (`hazard_zone.gd`), así que caerse mata. En el tutorial eso
  se resuelve reconectando la señal `died` del `HealthComponent` a
  `health_component.reset()` (`health_component.gd:43`) + `player.respawn()`
  (`player.gd:753`). Ambas son API existente y autocontenida: `respawn()` resetea
  posición, velocidad, estados, timers y buffs sin depender de `RunManager`.
  **No inventar lógica de revive nueva.**
- **Los textos de controles se generan en runtime desde los bindings reales.**
  Los controles son remapeables (`Settings`, `user://settings.cfg`) y hay un modo
  de 2 teclados (`KeyboardSetup.raw_input_activo()`). Hardcodear `A/D/W/V/Q/C`
  sería INCORRECTO para cualquiera que haya remapeado. Reusar el helper de
  "binding → etiqueta legible" que ya usa `rounds/ui/options_screen.gd` y las
  mismas etiquetas de sufijo, para que el tutorial diga lo mismo que Opciones.
- **El panel no bloquea la práctica.** Es semi-transparente, se ve la arena
  detrás, y se descarta con la acción de disparo REAL del jugador (leída de sus
  bindings, no hardcodeada).
- **Cuidado con el foco de botones (bug ya visto).** Hubo un bug real en este
  proyecto: la tecla `W` (que es `p1_up` Y `p1_jump`) auto-confirmaba el
  character select y la pantalla de mejoras, porque el foco de UI escuchaba las
  teclas de gameplay. En el tutorial el panel NO debe depender de un `Button` con
  foco para descartarse. Descartar por la acción `fire` del jugador.

## Diseño

### `rounds/levels/tutorial_level.tscn` (NUEVO)

```
TutorialLevel (Node2D)            -> tutorial_level.gd
├── MapContainer (Node2D)
│   └── <instancia de un mapa registrado>   (reuso, elegir uno de MapManager)
├── Player1 (instancia de player_1.tscn)    -> ubicado en un Marker2D "Spawn*" del mapa
├── Camera (Camera2D)                        -> mismo setup que test_level.tscn:77-80
├── PauseMenu (instancia, oculta)            -> ESC funciona tal cual
└── TutorialHUD (CanvasLayer)
    └── Fondo (ColorRect oscuro semi-transparente)
        └── Panel (VBoxContainer centrado)
            ├── Titulo (Label)
            ├── Controles (Label)          -> texto armado en runtime
            └── Volver (Button)            -> "VOLVER AL MENÚ"
```

### `rounds/levels/tutorial_level.gd` (NUEVO)

- `_ready()`:
  - conectar la señal `died` del `HealthComponent` de `Player1` a
    `_on_player_died()` → `health.reset()` + `player.respawn()`.
  - armar el texto de `Controles` con los bindings reales de P1 (mover, saltar,
    agacharse, disparar, parry/ragdoll, agarrar), reusando el helper y las
    etiquetas de `options_screen.gd`.
  - el texto debe decir explícitamente con qué tecla se cierra el panel.
- `_unhandled_input`: si el panel está visible y el jugador presiona su acción
  `fire` → ocultar el panel.
- `Volver` presionado → `Transition.cambiar_escena("res://ui/main_menu.tscn")`.
- Acción `restart` (R) → `health.reset()` + `player.respawn()` (coherente con
  `test_level.gd:4-9`).

### `rounds/ui/main_menu.tscn` + `main_menu.gd` (EDITAR)

- Botón `Tutorial` en `Centro/Menu` (VBoxContainer), mismo patrón que los otros:
  `layout_mode = 2`, `custom_minimum_size = Vector2(260, 0)`, texto "Tutorial".
  Ubicarlo justo después de `Jugar` (antes de `Índice`).
- `main_menu.gd`: `@onready var _boton_tutorial: Button = $Centro/Menu/Tutorial`
  + `_boton_tutorial.pressed.connect(_abrir_tutorial)` dentro de `_ready()`
  (mismo patrón que `main_menu.gd:35-43`).
- `_abrir_tutorial()` → `Transition.cambiar_escena("res://levels/tutorial_level.tscn")`
  (mismo patrón que `main_menu.gd:116`).

### `rounds/tests/test_tutorial_level.tscn` / `.gd` (NUEVO)

Sigue la convención del proyecto (`extends Node`, `_ready()`, `assert`,
`print("✓ ...")`, `get_tree().quit(0)`).

Verifica, sin depender de render:
1. `tutorial_level.tscn` carga, instancia y tiene `Player1`, `Camera`,
   `TutorialHUD` y `PauseMenu`.
2. `Player1` tiene `player_number == 1` y NO fue descartado.
3. El texto de `Controles` NO está vacío y contiene al menos una tecla que
   proviene de un binding real (comparar contra `InputMap`), es decir: no es un
   string hardcodeado.
4. `main_menu.tscn` tiene el nodo `Centro/Menu/Tutorial` y su texto es "Tutorial".
5. Matar a `Player1` (`health.apply_damage(999)` → señal `died`) lo deja vivo y
   de vuelta en su spawn: `is_alive()` y `global_position == _spawn_position`.

## Tasks

| ID | Task | Route | Status |
|----|------|-------|--------|
| T1 | Crear `tutorial_level.tscn` + `tutorial_level.gd` (mapa reusado, P1, cámara, HUD, respawn blando) | delegated | done |
| T2 | Botón `Tutorial` en `main_menu.tscn` + wiring en `main_menu.gd` | delegated | done |
| T3 | Test `test_tutorial_level.tscn/.gd` + correrlo headless con Godot | delegated | done |

## Verificación

Binario: `C:\Users\adria\Downloads\Godot_v4.7-stable_win64_console.exe`

```
& "C:\Users\adria\Downloads\Godot_v4.7-stable_win64_console.exe" --headless --path "C:\Users\adria\Documents\GitHub\ONIET_Rounds\rounds" res://tests/test_tutorial_level.tscn
```

Y que no rompa los tests existentes, por ejemplo:

```
& "C:\Users\adria\Downloads\Godot_v4.7-stable_win64_console.exe" --headless --path "C:\Users\adria\Documents\GitHub\ONIET_Rounds\rounds" res://tests/test_spawns_and_hearts.tscn
```

## Riesgos

- **`RunManager` sucio tras el tutorial.** Al registrarse `Player1`
  (`player.gd:157` → `run_manager.gd:114-121`), queda estado en el autoload. Una
  partida real llama `RunManager.iniciar_partida()` que lo resetea. Verificar que
  volver al menú y arrancar una partida normal sigue andando.
- **Mapa reusado con `DeadZone`.** Cubierto por el respawn blando.
- **Modo 2 teclados.** Si `KeyboardSetup.raw_input_activo()` es true, P1 lee
  eventos crudos y no las acciones `p1_*` (`player_input.gd:151-153`). El texto de
  controles debe reflejar los bindings vigentes, no un modo asumido.
- **Árbol de trabajo sucio.** Hay cambios sin commitear del nerfeo de parry
  (`player.gd`, `hurtbox_component.gd`, `bullet.gd`, `project.godot`,
  `keyboard_setup.gd`). NO tocarlos y NO commitear. Al commitear (si el usuario lo
  pide) stagear SOLO los archivos del tutorial.

## Verificación (evidencia observada)

Corrido por el writer y re-corrido por el orquestador (spot check) con:

`& "<bin>" --headless --path "...\ONIET_Rounds\rounds" res://tests/test_tutorial_level.tscn`

```
--- TEST NIVEL TUTORIAL (SALA DE PRÁCTICA) ---
✓ Menú principal: botón 'Tutorial' presente en Centro/Menu
✓ Escena carga con Player1, Camera, TutorialHUD, PauseMenu y mapa reusado
✓ Player1 activo y no descartado (player_number == 1)
✓ Controles generados desde bindings reales (disparar = 'V', no hardcodeado)
✓ Muerte = respawn blando: Player1 vivo y de vuelta en (480.0, 1400.0)
--- TODOS LOS TESTS DEL TUTORIAL PASARON EXITOSAMENTE ---
```

Implementación final (decisiones reales del writer):

- Mapa reusado: `res://levels/maps/map_13_arena_abierta.tscn` (registrado en
  `map_manager.gd:44-51`). `Player1` ubicado en `SpawnP1` = `Vector2(480, 1400)`.
- Helper de bindings reusado: `Settings.nombre_binding(Settings.binding_de(accion))`
  (`settings.gd:529` y `:429`), el mismo par que usa `options_screen.gd:204`.
  Etiquetas de `Settings.ETIQUETAS` (`settings.gd:7-19`).
- Desvío respecto al plan: `player.respawn()` YA llama a `_health.reset()` en
  `player.gd:817`, así que el `reset()` extra era redundante y no se agregó.
- `Panel` centrado con `anchors_preset=8` (sin nodo contenedor extra).

## Hallazgo BLOQUEANTE (ajeno a este cambio)

El árbol de trabajo del usuario tiene un **error de parseo que deja el sistema de
armas sin cargar**:

```
SCRIPT ERROR: Parse Error: Cannot infer the type of "aim" variable because the
value doesn't have a set type.  at: GDScript::reload (res://weapons/bullet.gd:524)
ERROR: Failed to load script "res://weapons/bullet.gd" with error "Parse error".
```

- Causa: `rounds/weapons/bullet.gd:524` (dentro del nerfeo de parry SIN COMMITEAR)
  hace `var aim := new_shooter.get_parry_direction()`. `new_shooter` está tipado
  como `Node`, y `Node` no declara ese método, así que `:=` no puede inferir el
  tipo. `get_parry_direction()` SÍ está bien tipado (`-> Vector2`,
  `player.gd:597`); el problema es el tipado del receptor, no el método.
- No fue causado por este cambio: es parte del diff sin commitear de `bullet.gd`
  (líneas agregadas en `@@ -518,6 +518,12 @@`).
- Consecuencia: en el árbol de trabajo NO se podía disparar.
- **ARREGLADO** con autorización explícita del usuario, una sola línea:
  `var aim: Vector2 = new_shooter.get_parry_direction()`. Es una anotación de tipo
  explícita, el mismo patrón que ya usa el propio `bullet.gd:561`
  (`var parent: Node = ...`) y `player.gd:600` (`var b_vel: Vector2 = ...`).
  No cambia comportamiento en runtime, solo satisface al compilador.
- Verificado tras el arreglo: el parse error desapareció, el test del tutorial
  sigue pasando 5/5, el test de spawns conserva solo su fallo pre-existente, y el
  menú principal arranca sin errores de script.

## Estado

- Rutas de edición autorizadas: `rounds/levels/tutorial_level.*`,
  `rounds/ui/main_menu.*`, `rounds/tests/test_tutorial_level.*`.
- Modo TDD: no hay framework de tests (sin addons); la verificación es el test
  headless de la sección anterior.
- Archivos nuevos/borrados que Godot generó al importar: `tutorial_level.gd.uid` y
  `test_tutorial_level.gd.uid` (el proyecto versiona los `.uid` de los tests
  existentes, así que van con los scripts).
- Commits: **NO hechos.** El árbol de trabajo tiene el WIP de parry sin commitear;
  no se tocó ni se stageó nada. Commits pendientes de decisión del usuario.
- Verificación NO hecha: el riesgo de estado sucio de `RunManager` al volver del
  tutorial a una partida real (requiere juego interactivo).

