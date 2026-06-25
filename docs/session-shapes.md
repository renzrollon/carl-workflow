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

## Shape 5: Workflow-Orchestrated

**Duration:** 10-40 min | **Agents:** 10-50+ | **Pattern:** script controls flow, agents do work

**Entry signal:** Complex tasks that benefit from deterministic orchestration — the user says "ultracode", asks for a workflow, or the task clearly maps to a saved workflow.

**Flow (wave-apply):**
1. Load artifacts → classify tasks (schema-validated) → execute in parallel waves
2. Inter-wave verification gates catch interface mismatches immediately
3. Test wave uses cross-failure analysis (root-cause clustering, not per-file retries)
4. Resumable — stopped runs pick up where they left off

**Flow (review):**
1. Fan out 3-5 dimension reviewers (arch, ts, qa, devops, security) in parallel
2. Adversarially verify each finding — 2 skeptics try to refute it
3. Only confirmed findings survive into the final report
4. Eliminates false positives that waste developer time

**Flow (fan-out):**
1. Decompose goal into 2-5 file-disjoint subtasks
2. Execute all in parallel with per-task verification
3. Run project-level verification on combined result

**Expert version:** The script holds the plan, not the model's context window. Intermediate results stay in variables, not chat history. Budget-aware — scales depth to token ceiling. Deterministic retry logic instead of prompt-based "hopefully it retries."

**Common failure mode:** Using a workflow for work that's genuinely sequential or requires human-in-the-loop decisions between steps.

**Preconditions for expert execution:**
- Tasks are independent (can parallelize without file conflicts)
- Verification commands are detectable (typecheck, test, lint)
- For wave-apply: artifacts exist and passed Gate 1
- For review: implementation is complete (files to review exist)

---

## Shape 6: Agent-Team Investigation

**Duration:** 15-45 min | **Agents:** 3-6 persistent teammates | **Pattern:** debate → converge → decide

**Entry signal:** "The root cause is unclear" or "we need to investigate from multiple angles simultaneously" — when competing hypotheses need adversarial testing, not just parallel exploration.

**Flow:**
1. Spawn 3-5 teammates, each assigned a different hypothesis or angle
2. Teammates investigate independently AND challenge each other's findings
3. The debate structure surfaces the theory that survives scrutiny
4. Lead synthesizes consensus into a decision or proposal

**Expert version:** Unlike workflow fan-out (which collects results silently), agent teams *communicate*. Teammate A finds evidence that contradicts Teammate B's theory and messages them directly. The adversarial communication is the value — it prevents anchoring on the first plausible explanation.

**Best use cases:**
- Debugging with unclear root cause (spawn investigators per hypothesis)
- Architecture decisions with genuine tradeoffs (spawn advocates per approach)
- Cross-layer coordination where subsystem owners need to negotiate interfaces

**Common failure mode:** Using teams for work that's purely mechanical parallelism (use workflows instead). Teams add coordination overhead — only worth it when agents need to *talk to each other*.

**Preconditions:**
- Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings
- Problem has multiple plausible approaches/causes (not a single clear path)
- Value comes from inter-agent communication, not just parallel execution

---

## Shape Selection Heuristic

When in doubt, start with the simplest shape that fits:

```
Specific error + narrow scope → Targeted Fix
"Apply the tasks" + artifacts exist → Structured Execute
"Build X" + clear scope → Plan-then-Execute
"How/why/what if" + broad scope → Investigate-then-Propose
5+ independent tasks + "ultracode" → Workflow-Orchestrated
Unclear root cause + competing theories → Agent-Team Investigation
```

If you pick Targeted Fix and discover the scope is broader than expected, escalate to Investigate-then-Propose. If you pick Plan-then-Execute and the user already has artifacts, downgrade to Structured Execute. Shape classification is a starting point, not a commitment.

**Choosing between Workflow and Agent Team:**
- Tasks are independent and the orchestration is known → Workflow (deterministic, cheaper)
- Agents need to communicate, challenge, or negotiate → Agent Team (higher cost, richer coordination)

---

## Anti-Patterns (What NOT to Do)

| Anti-Pattern | Why It Fails | Instead |
|-------------|-------------|---------|
| "Explore everything first" | Burns 20 min before any output | Pick a shape, start executing |
| "Let me read the whole codebase" | Context window fills with irrelevant code | Read artifacts + memory, then act |
| "I'll figure out the approach as I go" | Leads to backtracking and scope drift | Classify shape, announce scope, then execute |
| "Just one more thing..." | Scope creep extends sessions past 30 min | Handoff + new session for new scope |
| Single-threading work that could parallelize | 3x wall-clock time for independent tasks | Wave-apply or fan-out when tasks are independent |
| Using agent teams for mechanical parallelism | Coordination overhead for no benefit | Use workflows — deterministic and cheaper |
| Using workflows for work that needs debate | Can't replicate adversarial communication | Use agent teams — teammates challenge each other |
| Running skill-based wave-apply for 10+ tasks | Context window fills, intermediate results lost | Use /wave-apply workflow — results stay in script variables |
