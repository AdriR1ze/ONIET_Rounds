---
name: godot
description: >
  Develop, debug, review and modify Godot 4 projects using idiomatic GDScript,
  simple maintainable architecture, Godot-native features, and minimal changes.
  Use for gameplay code, scenes, nodes, signals, Resources, debugging,
  architecture and performance work.
---

# Godot Development Skill

Work with the existing Godot project before designing new systems.

## Core rules

1. Read the relevant existing scripts/scenes before changing them.
2. Understand ownership and data flow before adding architecture.
3. Prefer the simplest correct solution.
4. Prefer Godot-native features when they naturally solve the problem.
5. Reuse existing project systems and conventions.
6. Make the smallest change necessary for the requested task.
7. Do not refactor unrelated code.
8. Do not rename existing identifiers unless necessary.
9. Do not introduce managers, controllers, services, components, autoloads,
   event buses or other abstractions without a concrete reason.
10. Do not optimize without evidence of a performance problem.
11. Preserve working behavior outside the requested change.
12. Never invent APIs, nodes, files, systems or project conventions that have
    not been inspected or established.

## Before coding

Determine:

- Which script/node owns the behavior?
- What existing code already handles part of it?
- Who calls the code being changed?
- What scene hierarchy and dependencies are involved?
- Is the state local, scene-level, reusable data, or genuinely global?
- Can the change be made without creating a new abstraction?

If the requested change conflicts with the existing architecture, prefer the
smallest compatible change. Only redesign architecture when it is necessary.

## Godot-native preference

Prefer, when appropriate:

- Nodes and scene composition
- Signals for event-driven communication
- Groups for semantic membership
- Resources for reusable/configurable data
- Exported properties for intentional dependencies/configuration
- Godot's built-in physics, animation, navigation, timers and containers
- Typed GDScript where it improves clarity

Do not use a feature merely because it exists. The feature must make the code
simpler or clearer.

## Minimal-change policy

When fixing or implementing something:

- Change only what is needed.
- Do not clean up unrelated code.
- Do not reformat unrelated files.
- Do not rename variables/functions/nodes just for style.
- Do not replace working code with a different architecture without need.
- Keep the user's existing approach when it is reasonable.
- If a larger refactor would help, explain it separately instead of silently
  doing it.

## Code quality

Prefer code that is:

- readable
- explicit
- locally understandable
- easy to debug
- consistent with the project
- appropriately typed
- free of unnecessary abstraction

Avoid:

- clever one-liners that reduce readability
- deeply nested control flow
- duplicated complex logic
- comments that merely restate code
- defensive checks for impossible states when the architecture guarantees them
- abstractions created only to make code look "clean"

## Reference files

Read the relevant reference when the task requires deeper guidance:

- `references/architecture.md`
- `references/gdscript.md`
- `references/scenes.md`
- `references/signals.md`
- `references/resources.md`
- `references/performance.md`
- `references/debugging.md`
- `references/project_structure.md`
- `references/anti_patterns.md`

## Final verification

Before finishing:

1. Verify the requested behavior.
2. Check for obvious syntax/type errors.
3. Check that changed references still exist.
4. Check that the change did not modify unrelated behavior.
5. If tests or the Godot project can be run, use them when appropriate.
6. Report important assumptions instead of inventing missing information.
