# Feature: Nivel Tutorial (sala de práctica interactiva) + botón en el menú

## Objective

Un **nivel aparte**, accesible desde un **botón nuevo en el menú principal**
(entre `Jugar` e `Índice`), que **enseñe jugando**: pide una acción a la vez y **no
avanza hasta que el jugador la ejecuta de verdad** contra algo real.

Cubre: **movimiento, disparo, parry (2 variantes) y la pantalla de mejoras.**

## Why

1. Pedido explícito del usuario: *"es un nivel aparte va a estar en los botones
   como jugar etc"*.
2. El panel estático de la v1 fue rechazado: *"el tutorial es una garcha no te
   enseña nada solo te muestra los controles"*.
3. **El parry nerfeado no se enseña con texto**: exige apuntar hacia la bala
   (arco 90°, `player.gd:601-607`), tiene cooldown de 6 s (`player.gd:46`) y la
   ventana dura 0.175 s (`player.gd:44`). Solo se aprende con una bala real.
4. Pedidos de la v3 (usuario): usar **un escenario más chico**, agregar la **parte
   de los poderes** mostrando **una sola** mejora, y que la bala del parry venga
   **primero de costado y después desde arriba**.

## Decisions (cerradas)

- **Escenario: `res://levels/maps/map_02_tres_pisos.tscn`.**
  Medido por las `CollisionShape2D` del `DeadZone`: 1280 px de ancho × 720 de
  alto, contra 3200 × 1800 de la `map_13_arena_abierta` actual — **5× menos
  área**. No tiene partes móviles y tiene tres pisos con huecos, que le sirven al
  paso de saltar. Los otros registrados quedan descartados: `map_03_el_pendulo`
  se autodestruye (`map_03_el_pendulo.gd:56-70`), `map_01_foso_acido` declara el
  piso entero letal (`map_manager.gd:10`), `map_04_repisas_orbes` tiene spawns
  superpuestos.
  - `SpawnP1` del mapa: `(258, 451)` (`map_02_tres_pisos.tscn:18-28`).
  - Herramienta para leer la geometría real del mapa:
    `rounds/tools/_dump_all.gd` (imprime rect, tile_size, filas sólidas, techo y
    suelo; no escribe nada). Correrlo con el binario de Godot.
- **Solo un jugador (Player1).** `player.gd:151` descarta a un jugador si
  `player_number > RunManager.cantidad_jugadores` (default 2). No instanciar P3/P4.
- **Sin `RunController`.** No hay rondas, vidas, banners ni `MatchHUD`.
- **Las teclas SIEMPRE de los bindings vivos** (`Settings.nombre_binding(
  Settings.binding_de(accion))`, `settings.gd:529`/`:429`, igual que
  `options_screen.gd:204`). Hardcodear `A/D/W/V/Q` es INCORRECTO.
- **Leer input por `PlayerInput`**, nunca por `Input.is_action_*`
  (`player_input.gd:151-153` resuelve el modo 2 teclados).
- **Ningún botón depende del foco.** La tecla `W` (`p1_up` **y** `p1_jump`) ya
  auto-confirmó el character select y las mejoras en este proyecto. Botones
  mouse-only.
- **Solo movimiento, disparo, parry y mejoras.** Nada de agarrar, agachar,
  strafe ni lock. (No existe un "crouch mode": el input `down` solo suelta
  plataformas de una cara, trepa y cambia la pose. Se deja intacto.)
- **Nada de balas fantasma.** Prohibido `wall_pierce`: los carriles del drill
  tienen que estar realmente despejados. Eso se prueba en el test.
- **Nada de teletransportes.** El drill ocurre donde el jugador está parado.

## Diseño

### Árbol de `rounds/levels/tutorial_level.tscn`

```
TutorialLevel (Node2D)            -> tutorial_level.gd
├── MapContainer (Node2D)
│   └── MapTresPisos (instancia de map_02_tres_pisos.tscn)      [CAMBIAR]
├── Player1 (instancia de player_1.tscn)  en SpawnP1            [REUBICAR]
├── Camera (Camera2D)                                            [REUBICAR/ajustar]
├── PauseMenu (instancia, oculta)                                [CONSERVAR]
├── Meta (Marker2D)          -> destino visible del paso 1       [REUBICAR]
├── Placement (Node2D)
│   └── Blanco (instancia de training_target.tscn)               [REUBICAR]
├── DrillTimer (Timer, one_shot)                                 [CONSERVAR]
├── UpgradeScreen (instancia de upgrade_screen.tscn, oculta)     [AGREGAR]
└── TutorialHUD (CanvasLayer)                                    [CONSERVAR]
    ├── Arriba/Info/{Paso, Progreso, Aviso}  (Labels)
    └── Abajo/Botones/{Saltear, Volver}      (Button, mouse-only)
```

Todas las posiciones de `Meta`, `Blanco` y los orígenes del drill deben quedar
sobre **piso firme y con carril despejado** en `map_02_tres_pisos`. Verificarlo
antes de fijarlas; no adivinar.

### Pasos (`tutorial_level.gd`) — `TOTAL_PASOS := 6`

| # | Paso | Instrucción (con la tecla REAL) | Condición de avance |
|---|------|----------------------------------|---------------------|
| 1 | MOVER | "Movete hasta la marca (A / D)" | llega a `Meta` |
| 2 | SALTAR | "Saltá (W)" | despega de verdad del suelo |
| 3 | DISPARAR | "Rompé el blanco (V)" | el `Blanco` muere **por una bala real** |
| 4 | PARRY_LATERAL | "Viene una bala de costado: parreala (Q)" | esa bala queda **parreada de verdad** |
| 5 | PARRY_ARRIBA | "Ahora cae una desde arriba: apuntá arriba (W) y parreala (Q)" | esa bala queda **parreada de verdad** |
| 6 | MEJORAS | "Elegí tu mejora" | se abre la pantalla REAL con **una sola** carta, el jugador la confirma y se aplica |
| — | FIN | "¡Listo!" | botón VOLVER AL MENÚ |

El paso 5 existe porque **`W` es `up` y `jump` a la vez**: apuntar hacia arriba
hace saltar. El texto debe avisarlo. Dato clave verificado:
`player_input.gd:44-59` arma el vector de apuntado con las acciones
`left/right/up/down`, y `weapon_component.set_aim` **ignora los vectores en cero**
(`weapon_component.gd:104-105`), así que **el apuntado queda pegado**: sirve
apuntar arriba una vez y después apretar parry. Usarlo en el texto del paso.

### Drill de parry (pasos 4 y 5) — dos balas en secuencia

- Bala 4: **horizontal**, desde el costado, a la altura del jugador.
- Bala 5: **desde arriba**, cayendo en línea recta sobre el jugador.
- Ambas son `res://weapons/bullet.tscn` (la misma que `player.tscn:225` le pasa a
  `WeaponComponent.bullet_scene`), **lentas**, con `bullet_gravity = 0.0` para que
  vuelen recto y predecible.
- El paso se completa cuando el jugador **parrea esa bala**, detectado por la
  señal real `Player.parried_bullet` (`player.gd:6`, emitida desde `on_parry` en
  `player.gd:594`). **Nunca por input.**
- Si falla (la bala lo golpea o pasa de largo): aviso y **reintento inmediato**.
- **Sin `wall_pierce`.** Elegir orígenes con carril realmente libre y probarlo.
- **Sin teletransporte.** El drill arranca donde el jugador está parado.
  Consecuencia: **no se puede usar `player.respawn()`** para reiniciar el cooldown
  de 6 s del parry (porque teleporta a `_spawn_position`). Usar en su lugar
  `_player.set("_parry_cooldown", 0.0)`, **con un comentario** que explique que es
  una concesión del tutorial. No agregar métodos a `player.gd` (tiene trabajo sin
  commitear del usuario).
- Si el jugador cae al vacío (el mapa mata), el respawn blando lo devuelve al
  spawn. Ese teletransporte SÍ es correcto: es una muerte, no un cambio de paso.

### Paso de mejoras (6) — `upgrade_screen.gd` (archivo COMPARTIDO, tocar lo mínimo)

Hoy el número de cartas está hardcodeado (`OPCIONES_POR_JUGADOR := 4`,
`upgrade_screen.gd:8`) y `abrir()` no acepta argumentos (`:42`), así que **no hay
forma de pedir una sola carta**. Cambio mínimo y retrocompatible:

1. `func abrir(cantidad_opciones: int = OPCIONES_POR_JUGADOR) -> void:`
2. Usar `cantidad_opciones` donde hoy usa `OPCIONES_POR_JUGADOR` al armar las
   ofertas (`upgrade_screen.gd:111` → `RunManager.opciones_para(numero, ...)`).

**Nada más en ese archivo.** No refactorizar, no renombrar, no "mejorar".

El tutorial hace `await _upgrade_screen.abrir(1)`. La pantalla se encarga sola:
pausa el árbol (`PauseManager.tomar`, `:47`), muestra la carta, el jugador
confirma con su `fire`/`jump`/Enter (`:493-496`), se aplica vía
`RunManager.elegir` → `_recalcular` → `player.aplicar_mejoras`
(`run_manager.gd:196-201`, `:276-279`) y cierra (`_cerrar` → `PauseManager.soltar`).
La selección **no usa foco de UI** (índice manual, `:548-552`), así que no
reintroduce el bug de `W`.

Requisito: el jugador tiene que estar registrado en `RunManager` (lo hace
`player.gd` en su `_ready`) o la pantalla se cierra sola
(`upgrade_screen.gd:79-82`). Con `ronda == 0` ofrece solo mejoras de nivel 1
(`run_manager.gd:151-153`), que es lo correcto para un tutorial.

### `rounds/levels/training_target.tscn` / `.gd` (ya existe)

Blanco destructible: `class_name TrainingTarget extends Area2D`, **capa 4**,
`HealthComponent` con `max_health = 25`, señal `destroyed`, método `revive()`.
Solo hay que reubicarlo sobre piso firme.

## Tasks

| ID | Task | Route | Status |
|----|------|-------|--------|
| T4 | `training_target` (blanco destructible) | delegated | done |
| T5 | HUD paso a paso + pasos mover/saltar/disparar | delegated | done |
| T6 | Drill de parry con bala real + reintento sin cooldown | delegated | done |
| T7 | Test end-to-end del tutorial | delegated | done |
| T8 | Cambiar el escenario a `map_02_tres_pisos` y reubicar todo sobre piso firme | delegated | done |
| T9 | Paso 5: segunda bala del parry, cayendo desde arriba | delegated | done |
| T10 | Drill sin teletransporte (cooldown por `set`) y sin `wall_pierce` (carriles limpios) | delegated | done |
| T11 | `upgrade_screen.abrir(cantidad_opciones)` + paso 6 de mejoras con una carta | delegated | done |
| T12 | Ampliar el test: carriles limpios, sin teletransporte, paso de mejoras | delegated | done |

## Verificación

Binario: `C:\Users\adria\Downloads\Godot_v4.7-stable_win64_console.exe`

```
& "<bin>" --headless --path "<repo>\rounds" res://tests/test_tutorial_level.tscn
& "<bin>" --headless --path "<repo>\rounds" res://tests/test_spawns_and_hearts.tscn
& "<bin>" --headless --path "<repo>\rounds" --quit-after 120
```

El test NO puede pasar trivialmente. Además de lo ya cubierto, debe probar:

1. El mapa instanciado es `map_02_tres_pisos` y la escena carga con P1, cámara,
   HUD, `PauseMenu` y `UpgradeScreen`.
2. **Ninguna bala del drill tiene `wall_pierce`** y **ambas recorren su carril
   entero sin morir** contra geometría.
3. Al entrar al drill, la posición del jugador **no cambia** (sin teletransporte).
4. El reintento del drill **reinicia el cooldown de 6 s** del parry.
5. Parrear la bala lateral avanza al paso 5, y parrear la que cae avanza al paso 6.
6. Parrear una bala DISTINTA no avanza ningún paso de parry.
7. El paso 6 abre la pantalla real (`UpgradeScreen`) y le pide **una sola** carta.
8. El paso 6 avanza cuando la pantalla se cierra.
9. El blanco sigue muriendo **por una bala real** (sin `apply_damage` directo).
10. Todos los textos de paso usan las teclas reales de `Settings`.

## Riesgos

- **`upgrade_screen.gd` es archivo compartido** y el usuario está en paralelo con
  un refactor de balance que toca el sistema de mejoras. Tocar solo la firma y el
  call site.
- **El sistema de mejoras está en refactor.** `UpgradeDatabase`, los `.tres` de
  upgrades y `stat_sheet.gd` están modificados sin commitear. Si el paso 6 se
  apoya en algo que cambia, puede quedar desfasado: reportarlo, no parchearlo.
- **Geometría de `map_02_tres_pisos`.** Tiene 3 pisos con huecos: hay que elegir
  posiciones sobre piso firme y carriles verticales/horizontales realmente libres.
  La bala que cae necesita que no haya techo en el tramo.
- **`W` es `up` y `jump`.** Apuntar arriba hace saltar. El texto del paso 5 tiene
  que avisarlo o el jugador no entiende qué pasó.
- **Árbol de trabajo sucio.** El usuario tiene ~53 archivos modificados sin
  commitear (refactor de balance). NO tocarlos y NO commitear nada.
- **Modo 2 teclados**: leer por `PlayerInput`.
- **`RunManager` sucio** tras el tutorial (P1 queda registrado). `iniciar_partida()`
  lo resetea en una partida real. Sin verificar headless.

## Historial breve

- **v1** (rechazada): panel estático con la lista de controles. Commiteada por el
  usuario en `cfff258 "tuto y algunos cambiios"` junto con el botón del menú.
- **v2**: tutorial interactivo de 4 pasos (mover, saltar, disparar, parry) con
  práctica real, verificado con 60+ aserciones. Defectos que la v3 corrige:
  teletransporte al entrar al parry y `wall_pierce` en la bala del drill.
- **Parse error ajeno, ya arreglado**: `bullet.gd:524` tenía
  `var aim := new_shooter.get_parry_direction()` sobre una variable tipada `Node`
  → `:=` no podía inferir el tipo → `bullet.gd` no cargaba → no se podía disparar.
  Arreglado con anotación explícita (`var aim: Vector2 = ...`), autorizado por el
  usuario.
- **Pre-existente y ajeno**: `test_spawns_and_hearts.gd:39` asserta ≥8 spawns por
  mapa y los mapas tienen 4.

## v3 verificada (evidencia observada)

Corrida por el writer y **re-corrida por el orquestador** (spot check): todas las
aserciones ✓. Las que importan:

```
✓ El mapa instanciado es map_02_tres_pisos.tscn
✓ El paso NO avanza solo con el tiempo (sigue en 0)
✓ Entrar al drill NO teleporta al jugador (Δ=0.00)
✓ La bala lateral NO tiene wall_pierce (0)
✓ El reintento NO teleporta al jugador
✓ Parrear una bala distinta NO avanza el paso de parry
✓ Parrear la bala lateral avanza a paso 5 (PARRY_ARRIBA)
✓ La bala que cae NO tiene wall_pierce (0)
✓ Parrear la bala que cae avanza a paso 6 (MEJORAS)
✓ El paso 6 abre la pantalla REAL de mejoras
✓ La pantalla pide EXACTAMENTE una carta (pidió 1)
✓ El paso 6 avanza al cerrarse la pantalla (FIN)
✓ El blanco murió por una bala real (sin apply_damage directo)
```

Geometría real de `map_02_tres_pisos` (leída con `rounds/tools/_dump_all.gd`):
`rect (0,0)-(40,23)` tiles de 32 px; filas sólidas completas `gy0` (techo),
`gy21/22` (piso). Plataformas por fila: `gy5` x544-735; `gy8` x320-575 y
x704-959; `gy11` x160-383 y x896-1119; `gy13` x544-735; `gy15` x224-543 y
x736-1055; `gy18` x96-287 y x992-1183. **Las filas `gy1-4, 6, 7, 9, 10, 12, 14,
16, 17, 19, 20` están vacías de pared a pared** — eso es lo que hace que el
carril lateral (que vuela por `gy14`) nunca toque geometría mientras el jugador
esté parado en la plataforma de `gy15`.

Posiciones: `Player1` `(258, 451)` (= `SpawnP1`, se asienta en `(258, 459.5)`),
`Meta` `(410, 451)`, `Blanco` `(475, 419)`, `Camera` `(640, 368)` con
`max_zoom = 0.85`. Orígenes del drill **relativos al jugador**: lateral
`jugador + (-170, 0)` a 130 px/s; caída `jugador + (0, -55)` a 50 px/s.
(La caída es corta en distancia pero lenta, ~1.1 s visible.)

### CORRECCIÓN de un diagnóstico anterior (importante)

En la v2 dije que la bala del drill necesitaba `wall_pierce` porque *"hay
geometría del mapa en el carril (x≈797)"*. **Eso estaba MAL.** La causa real era
un bug de orden en el código: se hacía `add_child(bala)` **antes** de fijarle la
posición, así que el `Area2D` nacía en `(0,0)`, solapaba el tile de la esquina del
mapa y moría en el primer frame. El `wall_pierce = 3` no resolvía nada: **tapaba
el bug**. En la v3 se posiciona **antes** de `add_child` y el `wall_pierce` se fue.

## Riesgo residual conocido (NO corregido)

Los orígenes del drill son relativos al jugador, y **el alto de la caída está
fijo en 55 px**. Si el jugador llegara a pararse **debajo de una plataforma con
menos de 55 px de luz** (por ejemplo sobre `gy18`, x∈[224,287] o x∈[992,1055],
donde la plataforma de `gy15` queda a ~44 px por encima de su posición), la bala
de la caída nacería **dentro de la geometría**, moriría en el frame 1, y el
`tree_exiting` dispararía un reintento inmediato → **bucle apretado creando y
destruyendo balas cada frame** (spam de avisos y stutter). Recuperable con
`SALTAR PASO`, y solo ocurre si el jugador se va de la plataforma guía, pero es un
modo de falla feo.

Mitigación propuesta (no aplicada): retardar el reintento (p. ej. 0,35 s) para que
nunca sea un bucle apretado, y **clampear el alto de la caída con un raycast**
hacia arriba (el proyecto ya usa `direct_space_state` en `bullet.gd:196-205`, no
hace falta ningún nodo ni abstracción nueva).

## Estado

- Rutas autorizadas: `rounds/levels/tutorial_level.*`,
  `rounds/levels/training_target.*`, `rounds/tests/test_tutorial_level.*`, y
  `rounds/ui/upgrade_screen.gd` (solo la firma de `abrir()` y su call site).
- `upgrade_screen.gd` quedó con **4 inserciones y 2 borrados**: un campo
  `_cantidad_opciones`, el parámetro opcional de `abrir()` y su uso en
  `_mostrar_grupo`. Retrocompatible: `run_controller.gd:103` sigue llamando
  `abrir()` sin argumentos. Nada más se tocó en ese archivo.
- Nodo renombrado: `MapArenaAbierta` → `MapTresPisos` (coherente con el escenario
  nuevo; solo lo referenciaba el test del tutorial).
- Dato desactualizado: el cooldown del parry ya **no es 6 s**. El WIP del usuario
  lo bajó a `parry_cooldown_time = 4.0` (`player.gd:47`). El test es agnóstico al
  valor: verifica que el reintento lo deja en 0.
- Modo TDD: sin framework (sin addons); la verificación es el test headless.
- Commits: **NO hacerlos.** El árbol tiene el refactor de balance sin commitear
  (y sigue creciendo: `ammo_display.gd` se sumó después).
- Review nativo (RDD on global): no corrido; el candidato sería el árbol entero
  incluyendo trabajo ajeno en curso.
