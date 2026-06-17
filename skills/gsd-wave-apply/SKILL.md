---
name: gsd-wave-apply
description: Execute OpenSpec tasks using GSD-style wave execution with context isolation and parallel subagents. No commits — use /gsd-commit afterward. Use instead of standard /opsx:apply when you want fresh-context parallel execution.
metadata:
  type: execution
  version: "1.0"
---

Execute OpenSpec tasks using wave-based parallel execution with context isolation.

**Input**: Change name (optional — inferred from context or prompted)

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

4. **Execute in waves**

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

5. **Update tasks.md**

   Mark completed tasks: `- [ ]` → `- [x]`
   Do NOT commit — leave all changes unstaged/staged for `/gsd-commit`.

6. **Report wave completion**

   After all waves complete, show:
   - Tasks completed per wave
   - Any tasks that failed (with error context)
   - Overall progress
   - Suggest: run `/gsd-commit` to create a single feature commit

8. **Handle the Verification/Test wave**

   OpenSpec typically groups all tests as the LAST numbered section in tasks.md (e.g., "## 6. Tests" or "## N. Verification"). This wave is fundamentally different from implementation waves.

   **Identify the test wave:**
   - Last numbered group in tasks.md
   - Tasks starting with "Verify", "Write tests", "Test that", or "Final verification"
   - May contain: assertion checks, test file creation, or run commands (`typecheck`, `lint`, `test`, `build`)

   **Two test task patterns:**

   | Pattern | Example | Handling |
   |---------|---------|----------|
   | Verification assertions | "Verify X contains Y" | Run a check (grep, read file, run command), pass/fail |
   | Write test files | "Write tests: login form renders..." | Create test file, run it, fix until green |

   **Execution strategy for test wave:**

   a. **DO NOT parallelize blindly** — run tests sequentially or in small batches because failures often share a root cause (missing import, wrong config, broken fixture).

   b. **For "Verify X" tasks** (assertion-style):
      - Run the check directly (grep, typecheck, lint, build)
      - If it fails: trace back to which implementation task produced the issue, fix the source file, re-run
      - Do NOT mark the task as done until the check passes

   c. **For "Write tests" tasks** (create test files):
      1. Write the test file based on the spec scenarios (Given/When/Then)
      2. Run the test: `npm test -- <file>`
      3. If tests fail → enter the **fix loop**:
         - Read the failure output
         - Determine if the bug is in the TEST or the IMPLEMENTATION
         - Fix the appropriate file (prefer fixing implementation to match spec intent)
         - Re-run the test
         - Max 3 fix iterations per test file; if still failing, report and move on
      4. Only commit once the test passes

   d. **For "Final verification" tasks** (run full suite):
      ```bash
      npm run typecheck && npm run lint && npm test && npm run build
      ```
      - If any command fails: fix the issue, re-run the full chain
      - This is the LAST task — all prior tasks must pass before marking done

   **Fix loop protocol:**
   ```
   WHILE test fails AND attempts < 3:
     1. Read error output (focus on first failure)
     2. Identify root cause:
        - Import/path error → fix import
        - Type error → fix type or add assertion
        - Logic mismatch → check spec, fix implementation (not test)
        - Missing mock/setup → add test infrastructure
     3. Apply fix to the correct file
     4. Re-run ONLY the failing test (not full suite)
     5. attempts++

   IF still failing after 3 attempts:
     - Mark task with ⚠️ and failure reason
     - Continue to next test task (it may reveal the shared root cause)
   ```

   **No commits during test wave:**
   - All test files and fixes remain uncommitted
   - `/gsd-commit` will bundle everything into a single feature commit after execution

**Guardrails**
- Never execute a task in a wave that depends on an incomplete task
- If a task fails, mark it and continue with independent tasks
- Keep subagent prompts focused — minimal context per tier
- Do NOT commit during execution — all commits are handled by `/gsd-commit`
- If >2 tasks fail in a wave, halt and report
- Test wave tasks MUST NOT be parallelized via subagents — run them in the main context where you can see failures and iterate fixes
- Never mark a test task complete if the test is still failing