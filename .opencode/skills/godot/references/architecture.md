# Godot Architecture

## Ownership first

Every piece of gameplay logic should have a clear owner.

Ask:

- Which node owns this state?
- Which node owns this behavior?
- Is another existing system already responsible?
- Does this need to be shared?

Prefer local ownership when possible.

## Managers

Do not create a Manager just because multiple objects exist.

A manager is justified when there is a real coordination responsibility that
cannot reasonably belong to one existing node.

Bad pattern:
`EnemyManager` only because there are enemies.

Potentially justified:
A system that coordinates spawning, wave progression and global enemy limits
when those responsibilities genuinely belong together.

## Components

Do not split every behavior into a component.

Create a component when:

- the behavior is meaningfully reusable,
- it has a coherent responsibility,
- multiple entities need the same behavior,
- composition is actually simpler than inheritance or local logic.

Avoid components that contain only one trivial function.

## Autoloads

Autoloads are global state. Treat them as expensive architectural decisions.

Use them for genuinely global systems/state, not as a convenient way to avoid
passing references.

Prefer local references, scene ownership, Resources or signals when appropriate.

## Communication

Prefer the least coupled mechanism that remains clear:

1. Direct reference for clear ownership/dependency.
2. Signal for an event.
3. Group for semantic discovery/membership.
4. Autoload/global state only when genuinely global.

Avoid building custom event buses unless the project has a concrete need.

## Inheritance

Use inheritance when the objects really share an "is-a" relationship and the
base behavior is useful.

Do not create deep inheritance trees for minor code reuse.

## Data vs behavior

Use Resources for reusable/configurable data when appropriate.

Keep runtime state and behavior in the object/system that owns them.

Do not turn every variable into a Resource or every behavior into a component.

## Architecture changes

If existing architecture is imperfect but sufficient for the task, preserve it.

Architecture should solve actual problems, not theoretical ones.
