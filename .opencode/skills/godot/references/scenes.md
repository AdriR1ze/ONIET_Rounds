# Godot Scenes

## Scene ownership

Keep scene-specific logic close to the scene that owns it.

Preserve an existing scene hierarchy unless the task requires changing it.

## Node paths

Avoid fragile hardcoded paths when a clear existing reference/exported property
can be used.

However, do not replace every `$Node` reference with a more complex dependency
system. Simple paths are perfectly valid when the hierarchy is stable.

## Instancing

Use scene instancing for reusable entities and meaningful composition.

Do not create separate scenes for trivial objects unless reuse or organization
benefits from it.

## Exported references

Use exported node/resource references when a dependency should be configured
from the editor and this improves clarity.

Do not export every possible dependency just because it is possible.

## Scene changes

When modifying a scene, preserve unrelated node properties, hierarchy and
connections.
