# Feature: Bot Combat Navigation (flujo de disparo + pathfinding con salto)

## Objective

Reescribir el flujo de decisión del bot:
1. Disparar solo si el objetivo está **al alcance balístico** y el **arco de la bala
   llega sin chocar** terreno.
2. Si no, **navegar el mejor camino** hacia el enemigo más cercano usando un
   **grafo AStar2D procedural** que contempla **saltos y caídas**.

El parry, el apuntado/spread/cadencia por dificultad, el targeting y las guardas
se mantienen.

## Problem

Hoy el bot kitea a 160–280 px, dispara por ángulo sin mirar distancia ni
obstáculos, y no tiene navegación. Además arrastra límites hardcodeados que lo
rompen en mapas grandes.

## Why

Pedido explícito del usuario. La bala tiene caída (`bullet_gravity`), así que la
viabilidad de disparo debe resolverse con **balística**, no con un rayo recto.

## Decisions (cerradas)

- Pathfinding: **AStar2D procedural** desde el `TileMapLayer` (nodos por física).
- Línea de fuego: **solución balística exacta** (ángulo de proyectil) + trazado
  del arco con `direct_space_state` contra capas `1|16`.
- Factibilidad = arco **ideal** (desacoplada del error de apuntado por dificultad).
- Rango emerge de la solución balística (+ cap configurable).
- Reemplaza kiteo/strafe/saltos sueltos de `bot_brain.gd`.

## Modelo físico (datos reales del proyecto)

- Salto: `jump_velocity = -830`, `gravity = 1800` → altura ≈ 191 px (~5–6 tiles),
  aire ≈ 0.92 s, alcance horizontal ≈ 210 px (~6 tiles). Sin doble salto.
- Bala: `bullet_speed ≈ 1050`, `bullet_gravity ≈ 1000–1200`, `lifetime ≈ 1.5 s`.
- Tile: 32 px.

## Flujo

```
guardas (válido/vivo/can_control)
  → check parry
  → ¿disparo factible? (solución balística + arco libre)
        sí → apuntar (por dificultad) + disparar
        no → navegar (AStar) hacia el enemigo más cercano
                 · arista de salto → saltar
                 · si no → avanzar
             (re-path continuo mientras el target se mueve)
```

## Tasks

| ID | Task | Route | Status |
|----|------|-------|--------|
| T1 | `Ballistics` (resolver ángulo + trazar arco) + test | delegated | pending |
| T2 | `NavGraph` AStar2D procedural + test | delegated | pending |
| T3 | Follower + integración en `bot_brain.gd` | delegated | pending |
| T4 | Verificación integrada + `godot-check.sh` | delegated | pending |
| T5 | Commits + RDD | parent | pending |

## Acceptance criteria

- Existe camino en el grafo entre dos puntos del mapa y arista de salto en un hueco.
- Balística: target alcanzable → factible; con pared en el medio → tapado; lejos → sin solución.
- En `map_13` el bot navega A→B sin trabarse ni saltar en loop.
- `scripts/godot-check.sh` PASS.

## Checks

```
GODOT_BIN=/home/adriano/Downloads/Godot_v4.7.2-stable_linux.x86_64 bash scripts/godot-check.sh
# nuevo class_name => import previo
/home/adriano/Downloads/Godot_v4.7.2-stable_linux.x86_64 --headless --path rounds --import
```

## Notas

- El test viejo `test_death_loop_and_bot_abyss.gd` llama a `_evitar_abismo()`
  directo. Con el nuevo flujo se adapta/reemplaza (el abismo lo cubre el grafo).
- Cache del grafo por clave de mapa (estático) para compartir entre bots; no es un
  Manager.

## Progress / Evidence

- (pending)
