---
description: Ejecuta el flujo agéntico de Godot (plan -> code -> test -> evaluate) sobre una tarea.
agent: godot-orchestrator
---

Ejecutá el flujo agéntico completo sobre esta tarea del proyecto Godot `rounds/`:

$ARGUMENTS

Seguí el flujo del orquestador: descomponer con `godot-planner`, implementar
con `godot-coder`, verificar con `godot-tester` y aprobar/rechazar con
`godot-evaluator`, iterando hasta `APPROVED` (máximo 5 intentos por subtarea).
