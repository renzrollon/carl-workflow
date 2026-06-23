# Session Shapes

Four patterns that produce expert-level (5/5) sessions. Use these as mental models when starting a session — or let carl-dispatch / gsd-preflight auto-classify.

The key insight: expert sessions are not longer or harder — they are better structured from the start. The right shape chosen upfront eliminates backtracking, scope drift, and wasted exploration.

---

## Shape 1: Plan-then-Execute

**Duration:** 15-25 min | **Agents:** 4-6 | **Pattern:** think → structure → do

**Entry signal:** "I want to build X" — no active change exists, scope spans multiple files

**Flow:**
1. `/openspec-explore` (optional — skip if domain is well-understood)
2. `/openspec-propose` — generates proposal, design, tasks, specs
3. `/review-artifacts` — Gate 1 catches design errors cheaply
4. `/gsd-wave-apply` — parallel execution of independent tasks
5. `/gsd-commit` — single feature commit

**Expert version:** State the full scope upfront. Let propose generate all artifacts in one pass. Wave-apply handles execution in parallel. One commit covers everything. No mid-session design changes.

**Common failure mode (advanced, not expert):** Starting to code before proposing. Scope drifts mid-implementation. Multiple commits for what should be one logical change. 30+ minutes because exploration and execution are interleaved.

**Preconditions for expert execution:**
- Clear one-sentence scope statement before starting
- No ambiguity about boundaries (what's in/out)
- Domain knowledge sufficient to skip explore phase

---

## Shape 2: Structured Execute

**Duration:** 7-15 min | **Agents:** 3-13 (depends on task count) | **Pattern:** load → classify → do

**Entry signal:** "Apply the change" or "Execute the tasks" — active change with artifacts exists

**Flow:**
1. Load ALL artifacts (proposal + design + tasks + specs)
2. `/gsd-wave-apply --no-confirm` (or sequential for 1-4 tasks)
3. `/gsd-commit`

**Expert version:** Artifacts already exist from a prior session. This session is pure execution — zero exploration, zero design decisions. Fastest path to done. The agent reads everything before writing anything.

**Common failure mode:** Starting to implement after reading only the tasks (not the design). Making implementation decisions that contradict the design doc. Not using wave-apply when tasks are independent.

**Preconditions for expert execution:**
- All artifacts exist and were reviewed (Gate 1 passed)
- Tasks are well-defined with clear acceptance criteria
- Handoff from last session provides any missing context

---

## Shape 3: Investigate-then-Propose

**Duration:** 20-35 min | **Agents:** 2-5 | **Pattern:** understand → capture → structure

**Entry signal:** "How does X work? I might need to change it." — needs understanding before committing to a design

**Flow:**
1. `/openspec-explore-deep` — fan out investigators across subsystems
2. Synthesize findings into scope definition
3. `/openspec-propose` — convert understanding into durable artifacts
4. Stop (or continue to execute in same session if scope is small)

**Expert version:** Fan out 3-5 investigators across different subsystems simultaneously. Each returns findings independently. Synthesize into a proposal that future sessions consume without re-discovery. The exploration produces *artifacts*, not just conversation.

**Common failure mode:** Exploring in one long thread (single-threaded investigation). Findings live only in chat history and are lost after /clear. Never converting understanding into a proposal — the next session re-discovers everything.

**Preconditions for expert execution:**
- Multiple subsystems or modules are involved (justifies fan-out)
- Question is specific enough to decompose into parallel investigations
- Memory.md is checked first (avoid re-investigating known territory)

---

## Shape 4: Targeted Fix

**Duration:** 5-12 min | **Agents:** 0-1 | **Pattern:** locate → fix → verify

**Entry signal:** "X is broken" or "Fix the error in Y" — specific bug, narrow scope

**Flow:**
1. Check .claude/memory.md for known constraints about this area
2. Locate the issue (often a single file or function)
3. Fix it
4. Run tests to verify
5. Commit (or report if more investigation needed)

**Expert version:** Memory.md already contains the relevant constraint (e.g., "Alpine 3.24 removed standalone openssl package"). No exploration needed — go directly to the fix. Verify immediately. Done in under 10 minutes.

**Common failure mode:** Guessing at solutions without reading memory or checking constraints. Trying 3 wrong approaches before finding the right one. Exploring broadly when the fix is narrow. Not running tests after the fix.

**Preconditions for expert execution:**
- Error is specific (not "something is slow" — that's investigate-then-propose)
- Constraints for this area exist in memory.md
- Scope is genuinely narrow (one file, one concept)

---

## Shape Selection Heuristic

When in doubt, start with the simplest shape that fits:

```
Specific error + narrow scope → Targeted Fix
"Apply the tasks" + artifacts exist → Structured Execute
"Build X" + clear scope → Plan-then-Execute
"How/why/what if" + broad scope → Investigate-then-Propose
```

If you pick Targeted Fix and discover the scope is broader than expected, escalate to Investigate-then-Propose. If you pick Plan-then-Execute and the user already has artifacts, downgrade to Structured Execute. Shape classification is a starting point, not a commitment.

---

## Anti-Patterns (What NOT to Do)

| Anti-Pattern | Why It Fails | Instead |
|-------------|-------------|---------|
| "Explore everything first" | Burns 20 min before any output | Pick a shape, start executing |
| "Let me read the whole codebase" | Context window fills with irrelevant code | Read artifacts + memory, then act |
| "I'll figure out the approach as I go" | Leads to backtracking and scope drift | Classify shape, announce scope, then execute |
| "Just one more thing..." | Scope creep extends sessions past 30 min | Handoff + new session for new scope |
| Single-threading work that could parallelize | 3x wall-clock time for independent tasks | Wave-apply or fan-out when tasks are independent |
