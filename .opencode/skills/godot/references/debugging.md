# Godot Debugging

Debug the actual cause instead of hiding the symptom.

## Process

1. Read the error message carefully.
2. Locate the failing line.
3. Trace the value/reference that caused it.
4. Inspect initialization and ownership.
5. Fix the root cause.
6. Verify nearby behavior.

## Null references

When a node/reference is null:

- determine why it was never assigned,
- determine whether the node exists,
- determine whether the lifecycle/order is correct,
- determine whether the reference became invalid.

Do not blindly add null checks.

## State bugs

For state machines, inspect:

- current state
- transitions
- transition conditions
- entry/exit behavior
- state-specific movement/animation/input
- whether another system overwrites the state

Do not patch one symptom by adding another unrelated state.

## Physics bugs

Distinguish between:

- velocity
- position
- acceleration
- collision response
- movement API
- frame/physics-frame timing

Prefer the appropriate Godot physics API rather than manually fighting the
physics engine.

## Debug code

Temporary debug prints are acceptable while investigating.

Remove noisy temporary debugging unless it is intentionally useful to the
project.
