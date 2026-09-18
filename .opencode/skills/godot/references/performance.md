# Godot Performance

## Rule

Do not optimize without a reason.

Before optimizing:

1. Identify the expensive operation.
2. Determine how frequently it executes.
3. Measure/profile when possible.
4. Change the bottleneck.
5. Verify the result.

## Common areas

Pay attention to:

- unnecessary per-frame work
- repeated node lookups in hot loops
- excessive allocations
- spawning/despawning large numbers of objects
- physics workload
- expensive pathfinding
- unnecessary scene tree searches

## Pooling

Object pooling can help when repeated creation/destruction is a demonstrated
bottleneck.

Do not introduce pooling simply because "games should use pooling."

## Caching

Cache values when they are repeatedly obtained and the cache makes the code
meaningfully faster without making correctness harder.

Do not cache everything.

## Complexity

Prefer the algorithm with appropriate complexity when the scale requires it,
but do not replace simple readable code with complicated data structures for
small inputs.

## Rendering

Do not make rendering changes or visual optimizations without understanding
the actual bottleneck.
