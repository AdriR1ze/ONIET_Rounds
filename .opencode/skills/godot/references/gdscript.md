# GDScript

## Style

Follow the project's existing formatting and naming conventions first.

Prefer:

- clear names
- typed variables and return types when useful
- early returns when they simplify control flow
- small functions when the separation is meaningful
- explicit code over clever tricks

Do not split trivial code into many tiny helper functions.

## Types

Use static typing where it improves readability, catches mistakes, or documents
important interfaces.

Examples:

```gdscript
var health: int = 100
var target: Node2D
func take_damage(amount: int) -> void:
    pass
```

Do not add types mechanically to every expression if they make the code harder
to read.

## Functions

A function should have a reasonably clear responsibility.

Do not create a helper solely because a block has several lines.

Avoid functions that silently modify unrelated state.

## Conditionals

Prefer simple control flow.

Instead of deeply nested code, use early returns when appropriate.

Do not turn straightforward conditionals into compressed expressions just to
reduce line count.

## Comments

Comments should explain:

- non-obvious reasoning
- engine limitations
- intentional workarounds
- important invariants

Do not write comments that simply translate the code into English.

## Errors and nullability

Handle genuinely possible failure states.

Do not scatter `if value == null` checks everywhere when project ownership
guarantees the reference exists.

When a null reference indicates a real bug, prefer finding the broken ownership
or initialization rather than hiding it with arbitrary fallback behavior.

## Signals

Use signals for events, not as a replacement for every direct method call.

Keep signal ownership and connection points understandable.

## Performance

Avoid unnecessary work in `_process` and `_physics_process`.

Do not optimize ordinary code prematurely. Measure or identify a concrete
bottleneck first.
