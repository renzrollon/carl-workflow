---
name: gsd-fan-out
description: General-purpose parallel execution for ad-hoc work that doesn't require the full OpenSpec workflow. Decomposes a goal into independent subtasks, dispatches subagents in parallel, verifies results.
metadata:
  type: execution
  version: "1.0"
---

Parallel execution for work outside the OpenSpec lifecycle.

**Input**: User's goal (natural language) + optional `--no-confirm` flag

**When to use**: carl-dispatch routes here when:
- Intent is "apply" or "fix" but NO active OpenSpec change exists
- The work decomposes into 2-5 independent, file-disjoint pieces
- Full OpenSpec ceremony (propose/review/archive) would be overkill

**When NOT to use**:
- Single-file changes (just do them directly)
- Tasks with dependencies between them (use sequential apply)
- Work that needs design decisions (use openspec-propose first)
- Exploratory questions (use openspec-explore or explore-deep)

**Steps**

1. **Decompose the goal**

   Break the user's request into 2-5 independent subtasks. Each subtask must:
   - Touch different files (no overlap between agents)
   - Not depend on another subtask's output
   - Be completable in isolation by a single agent
   - Have a clear verification condition

   If the work cannot be cleanly decomposed (shared state, sequential logic, design decisions needed), abort and suggest the appropriate alternative:
   - Coupled changes → `/openspec-apply-change` (sequential)
   - Needs design first → `/openspec-propose`
   - Single focused fix → do it directly (no fan-out overhead)

2. **Show decomposition and confirm** (skip if `--no-confirm`)

   ```
   ## Fan-Out Plan

   **Goal:** <user's goal>
   **Subtasks:** <N> independent pieces

   | # | Subtask | Files | Verification |
   |---|---------|-------|-------------|
   | 1 | <description> | <file list> | <how to verify> |
   | 2 | <description> | <file list> | <how to verify> |
   | 3 | <description> | <file list> | <how to verify> |

   Execute in parallel? [Yes / Adjust / Cancel]
   ```

3. **Execute in parallel**

   Spawn one subagent per subtask with a focused prompt:

   ```
   TASK: <subtask description>
   FILES: <only these files — do NOT modify anything else>
   CONTEXT: <relevant memory.md entries if any>
   VERIFICATION: <what to check after changes>

   Instructions:
   - Implement ONLY the described subtask
   - Stay within the listed files — do NOT touch other files
   - Run verification after changes
   - Report: what was done, files changed, verification result
   ```

   All agents run concurrently. Wait for all to complete.

4. **Verify combined result**

   After all agents complete, run project-level verification:

   ```bash
   # Auto-detect and run (same as gsd-wave-apply step 6a):
   npm run typecheck 2>&1 || npx tsc --noEmit 2>&1
   npm test 2>&1
   npm run lint 2>&1
   ```

   If verification fails:
   - Identify which subtask's output caused the failure
   - Apply a targeted fix (max 2 attempts)
   - If still failing, report the conflict to the user

5. **Report and suggest commit**

   ```
   ## Fan-Out Complete

   **Goal:** <goal>
   **Results:**
   | # | Subtask | Status | Files Changed |
   |---|---------|--------|---------------|
   | 1 | <desc>  | done   | <files>       |
   | 2 | <desc>  | done   | <files>       |

   **Verification:** All checks passed

   Ready to commit? Run `/gsd-commit` or commit manually.
   ```

**Guardrails**
- Maximum 5 subtasks per fan-out (more than 5 = too complex for ad-hoc, use OpenSpec)
- Each subtask MUST touch different files — if there's any file overlap, reduce to sequential
- If any subtask fails, report it individually (don't fail the entire fan-out)
- Do NOT commit during execution — leave for `/gsd-commit`
- If decomposition is forced (overlapping files, unclear boundaries), abort early and suggest alternatives
- Total execution should complete in under 10 minutes — if a subtask is too large, break it further or use wave-apply
