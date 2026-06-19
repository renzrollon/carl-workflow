# Roadmap: Harness Engineering Improvements

Based on Google's "The New SDLC with Vibe Coding" (May 2026, Addy Osmani et al.). Scoped to brownfield projects — agent usage, tooling, and optimization.

---

## Context

The white paper's key thesis: **Agent = Model + Harness**, and the harness (context engineering, tools, guardrails, observability) matters more than the model itself. Teams improved benchmark scores 30%+ by changing only the harness.

carl-workflow already implements several of these ideas well (artifact-first culture, dual review gates, wave execution with model routing). This roadmap focuses on the gaps most relevant to **brownfield** work: better feedback loops, smarter context management, operational observability, and safety guardrails for mature codebases.

---

## TIER 1 — High Leverage, Do First

### 1.1 Cross-Failure Test Analysis

**Paper concept:** Factory Model — tests are the assembly line; the 80% problem lives in integration failures.

**Enhances:** `gsd-wave-apply` (test wave), `openspec-apply-change`

**Change:** Replace the flat "3 retries per test file" loop with a two-pass approach:
1. **Discovery** — run all tests, group failures by error signature (shared import, missing fixture, type mismatch)
2. **Fix by root cause** — address shared causes first (dependency order), then re-run affected set. Budget: 5 root-cause iterations total, not 3 per file.

**Why (brownfield):** Mature test suites have deep shared fixtures. One broken setup cascades across 4-6 files — independent retries waste all their budget on the same underlying problem.

---

### 1.2 Observability Layer (Token/Cost Metrics)

**Paper concept:** "Without observability, you inherit the model provider's." Token economics as financial lever.

**Adds:** Metrics tracking across all skill invocations.

**Change:** Emit a session manifest to `.claude/metrics/<change>-<ts>.json` containing:
- Skill invocations (name, model, input/output tokens, duration)
- Wave execution stats (tasks/wave, fix iterations, tier distribution)
- Review scores (from 2.1 when implemented)

Add a summary step in `gsd-commit` / `openspec-archive-change` that appends cost data to the archive record. Over time this enables data-driven routing refinement.

---

### 1.3 Automated Skill Routing (Decision Dispatcher)

**Paper concept:** Progressive Disclosure — skills load on demand; Orchestrator mode — the agent decomposes and delegates.

**Adds:** New entry-point skill `workflow-dispatch`

**Change:** Encode the decision tree as executable logic:
- Check project state (`openspec/` exists? active change? current phase?)
- Pattern-match user intent (explore/fix/build/review/explain)
- Auto-invoke the appropriate skill or present ranked options when ambiguous

Reduces cognitive overhead of "which skill do I use?" to "tell Carl what you want."

**Why (brownfield):** Developers jump between modes constantly in mature projects — explore, fix, add, review — all in one session.

---

### 1.4 Cross-Session Project Memory

**Paper concept:** Context Engineering — Memory as one of six context types. Knowledge that accumulates across sessions.

**Enhances:** `gsd-context-handoff`, `openspec-archive-change`

**Change:**
- Add `.claude/memory.md` to the project (version-controlled) containing codebase-specific learnings:
  - Module coupling hints ("billing and invoicing always change together")
  - Common failure modes ("auth module has circular dep if imported from tests")
  - Patterns that worked / didn't work
- `openspec-archive-change` prompts: "Anything future sessions should know?" and appends to memory
- Include `.claude/memory.md` as static context in CLAUDE.md

**Why (brownfield):** Institutional knowledge lives in people's heads. The same gotchas get rediscovered session after session. Memory captures them once.

---

## TIER 2 — Medium Leverage, Build After Tier 1

### 2.1 Eval-Driven Review Scoring

**Paper concept:** "Tests verify implementation; evals verify AI behavior. Without both, it's always vibe coding."

**Enhances:** `review-artifacts`, `review-code`, all single-persona reviewers

**Change:** Add scored rubrics to each reviewer persona:
- Architecture: boundary clarity (0-3), pattern fitness (0-3), completeness (0-3)
- QA: scenario coverage (0-3), edge-case depth (0-3), testability (0-3)
- Code: type safety (0-3), pattern adherence (0-3), test quality (0-3)

Track scores in `.claude/metrics/`. Over time, correlate review scores with actual post-ship bugs to calibrate which dimensions are predictive for YOUR codebase.

---

### 2.2 Dynamic Model Routing (Beyond Static Tiers)

**Paper concept:** Intelligent Model Routing — large models for complex reasoning, smaller for deterministic tasks.

**Enhances:** `gsd-classify-tasks`

**Change:** Enrich tier classification with dynamic signals before assigning:
- File complexity (LOC >300, imports >15 → bump tier)
- Historical failure data from `.claude/metrics/` (this module previously needed fix iterations → bump)
- Budget mode flag (cap Opus to Tier 5 only for cost-constrained runs)

---

### 2.3 CI/CD Feedback Integration

**Paper concept:** Factory Model — the harness includes the full pipeline, not just local execution.

**Adds:** CI awareness via `glab`/`gh` integration

**Change:**
- **Pre-apply:** Check current pipeline status. If red, surface failures as context before adding changes.
- **Post-apply:** Run the same checks CI would (lint, typecheck, test, build) and surface failures before review gate.
- **Flakiness detection:** Query recent pipeline runs for affected test files. Flag intermittently-failing tests.

---

### 2.4 Inter-Wave Dependency Validation

**Paper concept:** The 80% Problem — integration points are disproportionately hard.

**Enhances:** `gsd-wave-apply` (inter-wave handoff)

**Change:** After each implementation wave, run a typecheck (`tsc --noEmit` or equivalent) before starting the next wave. If wave 1 produces an export with the wrong shape, catch it immediately — not after wave 2 fails trying to import it.

---

## TIER 3 — Strategic, Build When Mature

### 3.1 Codebase Pattern Library

**Paper concept:** Examples as a context type; progressive disclosure.

**Adds:** `openspec/patterns/<name>/` directory with proven implementation templates.

After archiving a change that establishes a repeatable pattern (new endpoint, new component, new migration), offer to extract it. Future `openspec-propose` invocations that match a pattern load it as dynamic context — higher-quality artifacts without re-learning.

---

### 3.2 Refactoring-Specific Workflow Branch

**Paper concept:** The 80% Problem has different risk in refactoring (regression, not missing functionality).

**Adds:** `--refactor` mode in `openspec-propose` / `openspec-apply-change`

- Behavior snapshot before refactoring (test suite pass set, exported API surface)
- Preservation contract instead of feature spec ("maintain Y while restructuring Z")
- Continuous regression check after each task (not just test wave)
- Per-task commits (safe rollback points, overriding GSD's no-commit rule)

---

### 3.3 Static Context Optimization

**Paper concept:** Static vs dynamic context is an engineering decision; every static token is paid every turn.

**Change:** Restructure CLAUDE.md template with explicit STATIC (always needed: stack, boundaries, style) vs DYNAMIC (phase-specific: review protocol, GSD rules) sections. Move phase-specific rules into the skills that use them. Add a `carl-audit-context` utility that reports token overhead.

---

### 3.4 Guardrail Framework

**Paper concept:** Guardrails as a harness component — hard limits, not soft suggestions.

**Adds:** `openspec/config.yaml` guardrails section:
```yaml
guardrails:
  protected_paths:
    - "src/auth/**"           # require review-arch before touching
    - "prisma/schema.prisma"  # require migration plan in tasks
  max_files_per_task: 8
  require_test_for: ["src/lib/**", "src/api/**"]
```

Pre-apply validation scans tasks against guardrails and halts on violations BEFORE writing code.

**Why (brownfield):** Mature codebases have "here be dragons" zones. Guardrails encode safety boundaries as machine-enforced rules.

---

## Implementation Sequence

| Phase | Items | Rationale |
|-------|-------|-----------|
| A (immediate) | 1.1, 1.2, 1.4 | Internal skill changes, no UX disruption, compounds immediately |
| B (next) | 1.3, 2.4 | Changes the entry-point UX and tightens execution quality |
| C (with data) | 2.1, 2.2, 2.3 | Require observability data from Phase A to be meaningful |
| D (mature) | 3.1–3.4 | Strategic investments that require earlier tiers to be stable |

---

## Key Files to Modify

- `skills/gsd-wave-apply/SKILL.md` — 1.1, 2.2, 2.4, 3.4
- `skills/gsd-classify-tasks/SKILL.md` — 2.2
- `skills/openspec-apply-change/SKILL.md` — 1.1, 3.2, 3.4
- `skills/openspec-archive-change/SKILL.md` — 1.4, 3.1
- `install/CLAUDE.md.template` — 1.4, 3.3
- New: `skills/workflow-dispatch/SKILL.md` — 1.3
- New: `.claude/metrics/` directory — 1.2
- New: `.claude/memory.md` pattern — 1.4

---

## Verification

- **Tier 1:** Run a real brownfield change through the updated workflow. Confirm test feedback catches a shared root cause; confirm metrics emit; confirm memory persists to next session.
- **Tier 2:** Compare a wave execution with/without the improvement (e.g., inter-wave typecheck catches an interface mismatch that previously only surfaced in the test wave).
- **Tier 3:** Run `openspec-propose` on a task that matches a saved pattern and confirm it produces more accurate artifacts than without the pattern.
