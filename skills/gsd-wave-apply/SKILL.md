---
name: gsd-wave-apply
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

6. **Inter-wave verification and self-correction**

   After each implementation wave completes (before starting the next wave), run verification to catch issues early and self-correct before they cascade.

   **6a. Detect verification commands**

   Auto-detect from `package.json` scripts, `Makefile`, or project conventions:

   ```bash
   # Priority order — run the first available set:
   # 1. TypeScript projects: typecheck first (fastest, catches interface issues)
   npm run typecheck 2>&1 || npx tsc --noEmit 2>&1

   # 2. If tests exist for the modified files, run them
   npx vitest run --reporter=dot <modified-files-glob> 2>&1

   # 3. Lint (if fast — skip if >10s)
   npm run lint 2>&1
   ```

   For non-JS/TS projects, adapt:
   - Python: `mypy <files>` then `pytest <files> -x`
   - Go: `go build ./...` then `go test ./...`
   - Rust: `cargo check` then `cargo test`

   **6b. Self-correction loop (max 2 iterations per wave)**

   ```
   verification_attempts = 0
   MAX_WAVE_FIX_ATTEMPTS = 2

   WHILE verification fails AND verification_attempts < 2:
     1. Parse errors — identify which files/interfaces are mismatched
     2. Determine if error is from THIS wave (likely) or pre-existing
     3. If from this wave: fix the issue (one targeted change)
     4. Re-run only the failing verification step
     5. verification_attempts++

   IF still failing after 2 attempts:
     - Log the unresolved errors
     - Determine if they block the next wave:
       - Type errors in exports that wave N+1 imports → HALT, report to user
       - Isolated test failures that don't affect downstream → proceed with warning
   ```

   **Why:** The insights data shows agents repeatedly reporting "done" only for the user to paste back the same build errors. Self-correction catches 80% of issues (broken imports, interface mismatches) before they waste the user's time or cascade into the next wave.

   **Skip conditions:**
   - Project has no detectable verification commands — log warning and proceed
   - Pre-existing failures (present before this wave started) — note and proceed
   - If verification itself takes >60s, run only typecheck/compile (skip tests)

7. **Update tasks.md**

   Mark completed tasks: `- [ ]` → `- [x]`
   Do NOT commit — leave all changes unstaged/staged for `/gsd-commit`.

8. **Report wave completion and offer commit**

   After all waves complete, show:
   - Tasks completed per wave
   - Any tasks that failed (with error context)
   - Overall progress

   **Auto-chain to commit:**
   - Detect issue ref from:
     1. Input arg passed to this skill (if any)
     2. Branch name pattern: `feat/RD-65-slug` or `fix/PROJ-123-slug` → extract `RD-65` / `PROJ-123`
   - Prompt user: "All waves complete. Run `/gsd-commit <ref>`?" with options:
     - **"Yes, commit now"** → invoke `/gsd-commit <ref>` (or `/gsd-commit` if no ref found)
     - **"No, I'll commit later"** → stop here
   - If user confirms, invoke the skill with the detected ref

9. **Handle the Verification/Test wave (Cross-Failure Analysis)**

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

   **Execution strategy — Two-Pass Cross-Failure Analysis:**

   Instead of retrying each test independently, use a discovery → fix-by-root-cause approach. This prevents wasting iterations on symptoms of the same underlying problem.

   **Pass 1 — Discovery (run all, group by root cause):**

   a. Write all test files first (for "Write tests" tasks), based on spec scenarios.
   b. Run the full verification suite in one pass:
      - All "Verify X" checks
      - All newly written test files
      - Final verification commands (`typecheck`, `lint`, `test`, `build`)
   c. Collect ALL failures — do NOT stop at the first one.
   d. Group failures by error signature into root-cause clusters:

      | Signature | Example | Likely Shared Root Cause |
      |-----------|---------|--------------------------|
      | Same missing import | `Cannot find module './utils'` across 3 files | Missing export or wrong path |
      | Same type error | `Type 'X' not assignable to 'Y'` in multiple files | Interface shape mismatch |
      | Same fixture/setup | `ReferenceError: db is not defined` | Missing test setup or shared fixture |
      | Same env/config | `ECONNREFUSED` or `env.X is undefined` | Missing env var or config |
      | Same assertion pattern | Multiple `expected X received Y` with similar shape | Logic bug in shared function |

   **Pass 2 — Fix by Root Cause (dependency order, 5 iterations total):**

   ```
   root_cause_iterations = 0
   MAX_ROOT_CAUSE_ITERATIONS = 5

   WHILE failures remain AND root_cause_iterations < 5:
     1. Pick the root cause affecting the MOST failures
     2. Identify the single fix that resolves the cluster:
        - Import/path error → fix the export or path
        - Type mismatch → fix the interface or implementation
        - Missing fixture → add shared setup
        - Logic bug → fix the source function (prefer implementation over test)
        - Config issue → fix env/config
     3. Apply the fix (one change addressing the root cause)
     4. Re-run ONLY the affected test set (files in this cluster)
     5. Remove resolved failures from the failure list
     6. root_cause_iterations++

   IF failures remain after 5 root-cause iterations:
     - Mark remaining tasks with ⚠️ and failure reason
     - Report the unresolved clusters and what was attempted
   ```

   **Key differences from per-file retries:**
   - Budget is 5 root-cause iterations TOTAL, not 3 per file
   - One fix can resolve failures across 4-6 test files simultaneously
   - Fixes are ordered by impact (most-affected cluster first)
   - Each iteration targets the ROOT CAUSE, not individual symptoms

   **For "Final verification" tasks** (run full suite):
   ```bash
   npm run typecheck && npm run lint && npm test && npm run build
   ```
   - Run AFTER all root-cause iterations are complete
   - If any command fails: treat as a new root cause (counts toward the 5-iteration budget)
   - This is the LAST task — all prior tasks must pass before marking done

   **No commits during test wave:**
   - All test files and fixes remain uncommitted
   - `/gsd-commit` will bundle everything into a single feature commit after execution

10. **Emit metrics**

   After all waves complete (including the test wave), write a metrics manifest:

   ```bash
   mkdir -p .claude/metrics
   ```

   Write to `.claude/metrics/<change-name>-<timestamp>.json`:
   ```json
   {
     "change": "<change-name>",
     "timestamp": "<ISO-8601>",
     "skill": "gsd-wave-apply",
     "execution": {
       "totalTasks": 0,
       "completedTasks": 0,
       "failedTasks": 0,
       "waves": [
         {
           "waveNumber": 1,
           "tasks": 3,
           "tierDistribution": {"1": 1, "2": 1, "3": 1},
           "models": ["sonnet", "opus"],
           "status": "complete"
         }
       ],
       "testWave": {
         "rootCauseIterations": 0,
         "clustersFound": 0,
         "clustersResolved": 0,
         "unresolvedFailures": 0
       }
     },
     "duration": {
       "totalSeconds": 0,
       "perWave": [0, 0, 0]
     }
   }
   ```

   Record actual values observed during execution. Duration is approximate (track wall-clock from wave start to completion). This data enables data-driven routing refinement over time.

**Guardrails**
- Never execute a task in a wave that depends on an incomplete task
- If a task fails, mark it and continue with independent tasks
- Keep subagent prompts focused — minimal context per tier
- Do NOT commit during execution — all commits are handled by `/gsd-commit`
- If >2 tasks fail in a wave, halt and report
- Test wave tasks MUST NOT be parallelized via subagents — run them in the main context where you can see failures and iterate fixes
- Never mark a test task complete if the test is still failing