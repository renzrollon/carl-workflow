# CLAUDE.md snippet — Review protocol

Paste the block below into your project's `CLAUDE.md` to standardize how Claude conducts review. The severity levels and output format are stack-neutral; the per-reviewer focus areas can be adapted (see below).

## Snippet

````markdown
## Review Protocol

Severity: **BLOCKER** (must fix) · **WARNING** (should fix) · **SUGGESTION** (optional)

Output format:
```
── REVIEWER NAME ──────────────────
✓ passed · ⚠ warnings (file:line) · ✗ blockers
SUMMARY: N blockers, N warnings, N suggestions
```

**`/review-arch`** (architecture): Is the design sound for the project's stack? Are module boundaries correct (server vs. client, public vs. internal, layer separation)? Is error handling explicit? Are accessibility / UX requirements addressed where relevant?

**`/review-qa`** (specs): Do all specs have Given/When/Then scenarios? Are edge cases covered (empty, error, loading, boundary values, permissions)? Does `tasks.md` have a test task per feature task? Is task ordering valid (dependencies satisfied)?

**`/review-ts`** (code correctness — rename for your language, e.g. `/review-go`, `/review-py`): Are all `tasks.md` boxes checked? Does the implementation match the design? Type safety enforced (no escape hatches without justification)? Tests cover spec scenarios, not implementation details? Any obvious performance issues?

**`/review-devops`** (infra & ops — skip for UI-only changes): New env vars in `.env.example`? No hardcoded URLs / credentials? Dependencies audited? Build passes? New endpoints have auth and input validation?
````

## Adapting to your stack

The severity framework and output format should stay constant across projects so reviewers stay comparable. Swap the per-reviewer prompts to match your stack:

- **Non-TypeScript projects:** rename `/review-ts` (e.g. `/review-go`, `/review-py`, `/review-rs`) and replace the type-safety questions with language-idiomatic ones (lints, error handling, generics usage).
- **Backend-only projects:** drop the accessibility focus from `/review-arch` and add API contract / schema-evolution focus.
- **UI-only projects:** keep `/review-arch` accessibility and `/review-ts` hooks/render focus; `/review-devops` will usually skip itself.
- **Monorepos:** add a workspace-boundary check to `/review-arch` (no cross-package imports that bypass public APIs).

If your project uses a different artifact pipeline (not OpenSpec), replace `tasks.md` and `specs/` references with your equivalent.
