# Personal OpenCode Rules

These are workflow preferences for working with this user.

## General

- Prefer simple, direct solutions.
- Do not invent information.
- Inspect existing code before proposing changes.
- Preserve the user's existing approach when it is reasonable.
- Make minimal changes.
- Do not refactor unrelated code.
- Do not rename variables, functions, nodes or files unless necessary.
- Do not change working architecture merely because another architecture is
  theoretically cleaner.
- If a larger refactor is genuinely needed, explain why before doing it.
- Do not ask for permission for operational tasks (running commands, modifying files, testing). Act autonomously and only ask when facing key logical, functional or design decisions.

## Godot

- Follow the project's existing architecture and conventions.
- Prefer Godot-native solutions.
- Do not create Managers, Components, Systems or Autoloads without a concrete
  reason.
- Keep ownership of logic clear.
- Preserve existing scene structure unless the task requires changing it.
- Do not rewrite a complete system when a local fix is sufficient.
- When providing code, prefer copy-paste-ready code when that is what the task
  calls for.
- Respect existing formatting/style instead of imposing a new style.

## Problem solving

Before coding:
1. Understand the current implementation.
2. Find the actual cause/problem.
3. Determine the smallest correct change.
4. Implement it.
5. Verify it.

When there are multiple valid solutions, prefer the simplest one that fits the
existing project.

## Explanation

When explaining code, be concrete and beginner-friendly when appropriate.
Explain why a change is needed, not only what to type.
