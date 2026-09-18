# Godot Anti-Patterns

Avoid these unless there is a concrete reason.

## Architecture astronautics

Do not introduce:
- ManagerManager
- Service layers
- factories
- dependency injection containers
- event buses
- elaborate interfaces
- ECS-like systems

just because they sound scalable.

## God object avoidance taken too far

Do not respond to one large script by automatically splitting it into ten
components.

First determine whether the responsibilities are actually independent.

## Global-state abuse

Do not use Autoloads as a shortcut for references.

## Premature optimization

Do not add:
- pooling
- caching
- multithreading
- custom data structures

without a real need.

## Over-defensive programming

Do not hide architectural bugs behind endless null checks and fallback values.

## Unrequested refactoring

Do not clean up, rename, reformat or redesign unrelated code while implementing
a feature or fixing a bug.

## AI-specific anti-pattern

Never invent a project API.

If unsure whether a function, property, node, signal or class exists, inspect
the project or state the uncertainty.
