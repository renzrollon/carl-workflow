---
name: copilot-wave-apply
description: Classify, preview, and execute OpenSpec tasks using GSD-style wave execution with context isolation and parallel subagents. Includes built-in task classification (formerly gsd-classify-tasks). No commits — use /gsd-commit afterward.
metadata:
  type: execution
  version: "1.1"
---

Classify, preview, and execute OpenSpec tasks using wave-based parallel execution with context isolation.

**Input**: Change name (optional — inferred from context or prompted) + `--no-confirm` flag (optional — skip preview, execute immediately)

**Steps**

1. **Load the change**

   ```bash
   openspec status --change "<name>" --json
   openspec instructions apply --change "<name>" --json
   ```

   Read all artifact files from contextFiles.

2. **Parse tasks into dependency graph**

   Read tasks.md and build:
   - Task groups (numbered sections: 1.x, 2.x, 3.x...)
   - Dependencies between groups (later groups depend on earlier)
   - Independent tasks within each group (can parallelize)

3. **Classify each task**

   For each task, assign a tier and model:

   | Pattern | Tier | Model | Context Budget |
   |---------|------|-------|----------------|
   | Single file, find-replace | 1 | sonnet | 200 tokens |
   | Single file, add/modify section | 2 | sonnet | 1K tokens |
   | Single file, new logic/component | 3 | sonnet | 3K tokens |
   | Multi-file coordination | 4 | opus | 6K tokens |
   | Architecture, new patterns | 5 | opus | 10K+ tokens |

   Classification heuristic:
   - Contains "replace", "rename", "update reference" → Tier 1-2
   - Contains "add", "create", "implement" + single file → Tier 3
   - Mentions multiple files or "throughout" → Tier 4
   - Mentions "pattern", "architecture", "refactor" → Tier 5

4. **Show execution plan and confirm** (skip if `--no-confirm`)

   Display the classified execution plan:

   ```
   ## Execution Plan: <change-name>

   ### Wave 1 (Group 1) — Sequential prerequisite
   | Task | Tier | Model  | Context | Files |
   |------|------|--------|---------|-------|
   | 1.1  |  2   | sonnet | 1K      | src/components/Task.tsx |
   | 1.2  |  1   | sonnet | 200     | src/types.ts |

   ### Wave 2 (Groups 2 + 3) — Parallel
   | Task | Tier | Model  | Context | Files |
   |------|------|--------|---------|-------|
   | 2.1  |  3   | sonnet | 3K      | src/pages/tasks.tsx |
   | 3.1  |  4   | opus   | 6K      | src/api/tasks.ts, src/db/schema.ts |

   ### Summary
   - Total tasks: N
   - Waves: N (estimated wall-clock: ~Nm)
   - Token budget: ~NK
   - Parallel savings: ~N% faster vs sequential
   ```

   Prompt user with options:
   - **"Execute"** — proceed to wave execution
   - **"Adjust"** — let user override tiers, models, or remove tasks before executing
   - **"Cancel"** — stop without executing

   If `--no-confirm` flag is set, skip this step and proceed directly to execution.

5. **Execute in waves**

   Group tasks into waves where all tasks in a wave are independent:
   - Wave = all tasks in a numbered group that have no cross-dependencies
   - Execute each wave using parallel subagents
   - Wait for wave to complete before starting next wave

   For each task in a wave, spawn a subagent with:
   ```
   CONTEXT (loaded per tier):
   - Task description from tasks.md
   - Relevant section of design.md (if tier >= 2)
   - Relevant spec file (if tier >= 3)
   - Full design + specs (if tier >= 4)

   INSTRUCTIONS:
   - Implement ONLY this specific task
   - Do NOT modify files outside the task scope
   - Run verification after changes (typecheck, lint)
   - Report: files changed, what was done, any issues
   ```

6. **Inter-wave dependency validation**

   After each implementation wave completes (before starting the next wave), run a quick typecheck to catch interface mismatches early:

   ```bash
   # Use the project's typecheck command (detect from package.json scripts)
   npm run typecheck 2>&1 || npx tsc --noEmit 2>&1
   ```

   **If typecheck passes:** proceed to the next wave.

   **If typecheck fails:**
   - Parse the errors to identify which files/interfaces are mismatched
   - Determine if the error is from THIS wave's output (likely) or pre-existing
   - If from this wave: fix the interface mismatch before proceeding (counts as part of the current wave, not a separate iteration)
   - If pre-existing: note it and proceed (don't block on unrelated issues)

7. **Post-execution summary**

   ```
   ## Execution Complete: <change-name>

   ### Results
   - Tasks completed: N/M
   - Waves executed: N
   - Failed tasks: N (if any)

   ### Next Steps
   - Run `/gsd-commit` to create a commit
   - Or continue with more changes
   ```

**Guardrails**
- Never execute waves without user confirmation (unless `--no-confirm`)
- If any wave fails, stop and report — don't auto-retry
- Keep subagent prompts focused and self-contained
- Validate typecheck between waves to catch cascading errors early
