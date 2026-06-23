---
name: openspec-apply-change
description: Implement tasks from an OpenSpec change. Use when the user wants to start implementing, continue implementation, or work through tasks.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.4.0"
---

Implement tasks from an OpenSpec change.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce: "Using change: <name>" and how to override (e.g., `/opsx:apply <other>`).

2. **Check status to understand the schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - `planningHome`, `changeRoot`, and `actionContext`: planning scope and edit constraints
   - Which artifact contains the tasks (typically "tasks" for spec-driven, check status for others)

3. **Get apply instructions**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   This returns:
   - `contextFiles`: artifact ID -> array of concrete file paths (varies by schema - could be proposal/specs/design/tasks or spec/tests/implementation/docs)
   - Progress (total, complete, remaining)
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**
   - If `state: "blocked"` (missing artifacts): show message, suggest using openspec-continue-change
   - If `state: "all_done"`: congratulate, suggest archive
   - Otherwise: proceed to implementation

   **Workspace guard:** If status JSON reports `actionContext.mode: "workspace-planning"` and `allowedEditRoots` is empty, explain that full workspace apply is not supported in this slice. Treat linked repos and folders as read-only context, ask the user to select an affected area through an explicit implementation workflow, and STOP before editing files.

4. **Read context files**

   Read every file path listed under `contextFiles` from the apply instructions output.
   The files depend on the schema being used:
   - **spec-driven**: proposal, specs, design, tasks
   - Other schemas: follow the contextFiles from CLI output

5. **Show current progress**

   Display:
   - Schema being used
   - Progress: "N/M tasks complete"
   - Remaining tasks overview
   - Dynamic instruction from CLI

6. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on
   - Make the code changes required
   - Keep changes minimal and focused
   - Mark task complete in the tasks file: `- [ ]` → `- [x]`
   - Continue to next task

   **Pause if:**
   - Task is unclear → ask for clarification
   - Implementation reveals a design issue → suggest updating artifacts
   - Error or blocker encountered → report and wait for guidance
   - User interrupts

7. **On completion or pause, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - If all done: suggest archive
   - If paused: explain why and wait for guidance

**Output During Implementation**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**Output On Completion**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

All tasks complete! Ready to archive this change.
```

**Output On Pause (Issue Encountered)**

```
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

**Handling Test/Verification Tasks (Cross-Failure Analysis)**

When the task list contains a test or verification group (typically the last numbered section — tasks starting with "Verify", "Write tests", "Test that", or "Final verification"):

1. **Write all test files first** — implement all "Write tests" tasks before running any of them.

2. **Discovery pass** — run the full verification set in one pass and collect ALL failures:
   ```bash
   # Run all new tests + verification checks + full suite
   npm run typecheck && npm run lint && npm test && npm run build
   ```

3. **Group failures by root cause** — cluster by error signature:
   - Same missing import/export across files → path or export fix
   - Same type error pattern → interface mismatch
   - Same fixture/setup error → shared test infrastructure
   - Same logic assertion shape → bug in shared implementation

4. **Fix by root cause** (max 5 iterations total, not per file):
   - Pick the cluster affecting the most failures
   - Apply one fix addressing the root cause
   - Re-run only the affected test set
   - Remove resolved failures, repeat until clean or budget exhausted

5. **Mark tasks** — only check off test tasks once their tests pass. If failures remain after 5 root-cause iterations, mark with ⚠️ and report.

**Automatic Constraint Capture**

During implementation (step 6) or test fix iterations, if you fix an issue that reveals a recurring pattern, silently append a one-line entry to `.claude/memory.md`:

| Pattern Detected | Memory Section | Entry Format |
|-----------------|---------------|--------------|
| Import path breaks after file move | `## Common Failure Modes` | `- <change> (<date>): Moving files in <dir> requires updating <what>` |
| Interface mismatch between modules | `## Module Coupling` | `- <change> (<date>): <ModuleA> and <ModuleB> share <type> — changes must coordinate` |
| Env var required for feature/test | `## Common Failure Modes` | `- <change> (<date>): <feature> requires <ENV_VAR> even in <context>` |
| Test requires specific fixture order | `## Common Failure Modes` | `- <change> (<date>): <test area> requires <setup> before running` |
| Two files always change together | `## Module Coupling` | `- <change> (<date>): <fileA> changes always require updating <fileB>` |

Rules: only capture novel patterns (grep memory.md first), one line per entry, no user interruption, max 3 entries per session. Create `.claude/memory.md` with section headers if it doesn't exist.

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting (from the apply instructions output)
- If task is ambiguous, pause and ask before implementing
- If implementation reveals issues, pause and suggest artifact updates
- Keep code changes minimal and scoped to each task
- Update task checkbox immediately after completing each task
- Pause on errors, blockers, or unclear requirements - don't guess
- Use contextFiles from CLI output, don't assume specific file names
- **File moves**: When moving or renaming files, ALWAYS update all import paths — both in the moved file AND in every file that imports it. Run typecheck/tests immediately after to verify. This is the #1 source of post-apply failures.
- **Unknown APIs**: Do NOT guess config keys, CLI flags, or API names. Grep the codebase or check package docs first. If the first approach fails, investigate before trying alternatives — don't burn iterations on guesses.

**Fluid Workflow Integration**

This skill supports the "actions on a change" model:

- **Can be invoked anytime**: Before all artifacts are done (if tasks exist), after partial implementation, interleaved with other actions
- **Allows artifact updates**: If implementation reveals design issues, suggest updating artifacts - not phase-locked, work fluidly
