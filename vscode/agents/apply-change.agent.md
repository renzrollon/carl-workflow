---
name: Apply Change
description: Implement tasks from an OpenSpec change spec, working through them sequentially with verification.
tools: ['search/codebase', 'search/usages', 'runCommand', 'createFile', 'editFiles', 'problems', 'terminalLastCommand']
user-invocable: true
handoffs:
  - label: "Review the implementation"
    agent: "Review: Code"
    prompt: "Review the code changes I just implemented for"
    send: false
---

Implement tasks from an OpenSpec change.

## Steps

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` and ask the user to select

   Announce: "Using change: <name>"

2. **Check status to understand the schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `planningHome`, `changeRoot`, and `actionContext`: scope constraints

3. **Get apply instructions**
   ```bash
   openspec instructions apply --change "<name>" --json
   ```
   This returns:
   - `contextFiles`: artifact paths to read for context
   - Progress (total, complete, remaining)
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**
   - If `state: "blocked"` (missing artifacts): inform user, suggest using Propose Change
   - If `state: "all_done"`: congratulate, suggest review

4. **Read context files** — Read every file listed under `contextFiles`.

5. **Show progress** — Display schema, progress (N/M tasks), remaining tasks.

6. **Implement tasks (loop)**

   For each pending task:
   - Show which task is being worked on
   - Make code changes (minimal and focused)
   - Mark task complete: `- [ ]` -> `- [x]`
   - Continue to next task

   **Pause if:** Task is unclear, design issue surfaces, error encountered.

7. **On completion** — Show tasks completed, overall progress, suggest review via handoff.

## Output During Implementation

```
## Implementing: <change-name>

Working on task 3/7: <task description>
[...implementation...]
Task complete

Working on task 4/7: <task description>
[...implementation...]
Task complete
```

## Guardrails

- Keep going through tasks until done or blocked
- Always read context files before starting
- If task is ambiguous, pause and ask
- Keep changes minimal and scoped to the task
- Update task checkbox immediately after each task
- When moving files, ALWAYS update all import paths
- Do NOT guess API names or config keys — search first
