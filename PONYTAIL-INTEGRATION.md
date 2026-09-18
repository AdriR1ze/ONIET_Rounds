# Integración con Ponytail

Esta skill (`godot`) se complementa con **Ponytail**, el modo "senior dev
vago" que empuja siempre a la solución más simple que realmente funcione.

## Qué es Ponytail

Ponytail obliga a subir una escalera antes de escribir código:

1. ¿Esto necesita existir? (YAGNI)
2. ¿Ya existe en el proyecto? Reutilizalo.
3. ¿Lo hace la stdlib?
4. ¿Lo cubre una feature nativa de la plataforma/Godot?
5. ¿Lo resuelve una dependencia ya instalada?
6. ¿Se puede en una línea?
7. Recién ahí: el mínimo código que funcione.

Niveles: `lite`, `full` (por defecto), `ultra`.

## Cómo está instalado en este proyecto

- Plugin vendorizado en `.opencode/ponytail/` y activado en `opencode.json`
  (`plugin`). Inyecta las reglas de Ponytail en cada turno y registra sus
  comandos y skills.
- Skills propias de Ponytail: `ponytail`, `ponytail-review`, `ponytail-audit`,
  `ponytail-debt`, `ponytail-gain`, `ponytail-help`.

## Uso

- `/ponytail` -> modo full.
- `/ponytail lite|full|ultra|off` -> cambia el nivel.
- `/ponytail-review` -> revisa los cambios actuales buscando sobre-ingeniería.
- `/ponytail-audit` -> audita todo el repo.
- `/ponytail-debt` -> recolecta comentarios `ponytail:` diferidos.
- `/ponytail-help` -> referencia rápida.
- "stop ponytail" / "normal mode" -> desactiva.

## Prioridad cuando Ponytail y la skill Godot se superponen

Si las dos reglas chocan, **gana la regla más específica de Godot/proyecto**,
pero el espíritu es el mismo en ambas. Orden de trabajo:

1. Entender el proyecto existente.
2. Reutilizar código/sistemas existentes.
3. Preferir features nativas de Godot.
4. Usar la solución más simple que cumpla la tarea.
5. Evitar abstracciones innecesarias.
6. Hacer el cambio mínimo necesario.
7. Verificar el resultado.

## Nota

El paquete original (`godot-opencode-skill`) no incluía implementación de
Ponytail, solo este documento. Ahora Ponytail está instalado de verdad y esta
guía describe la integración real.
