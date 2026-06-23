---
name: gitlab-mr-review
description: Summarize and review a GitLab Merge Request. Spawns two subagents — one writes a code summary and updates the MR description, the other performs a structured code review.
metadata:
  type: review
  version: "1.0"
---

Summarize and review a GitLab Merge Request using two parallel subagents.

## Input

Accept an MR identifier. If none provided, detect the current branch and find its open MR. Formats:

- MR number: `!123` or `123`
- MR URL: `https://sgts.gitlab-dedicated.com/group/project/-/merge_requests/123`
- Omitted: use `glab mr view` on the current branch

## Execution

Spawn **two subagents in parallel**:

---

### Subagent 1: MR Summarizer

Fetch the MR diff and metadata using `glab`, then produce a structured code summary and update the MR description on GitLab.

**Steps:**

1. Run `glab mr view <MR> --comments` to get MR metadata (title, description, labels, source/target branch).
2. Run `glab mr diff <MR>` to get the full diff.
3. Analyze the diff and produce a summary with:
   - **What changed** — 2-5 bullet points covering the intent and scope of the change
   - **Key files** — list of significant files changed with one-line explanation each
   - **Impact** — breaking changes, new dependencies, migration needed, env vars added
   - **Testing** — what tests were added/modified, what's untested
4. Update the MR description on GitLab by appending the summary block at the bottom:

```
glab mr update <MR> --description "<existing description>

---

## Code Summary

<generated summary>

---
_Summarized by Claude (Opus 4.6) · [Claude Code](https://claude.com/claude-code)_"
```

Use `glab mr update` with the `--description` flag. Preserve the existing description — append, never replace.

**Output to main agent:** The generated summary text.

---

### Subagent 2: Code Reviewer

Review the MR diff for quality, correctness, and deploy-readiness. Follows the same review protocol as `/review-code` but operates on the MR diff rather than local uncommitted changes.

**Steps:**

1. Run `glab mr diff <MR>` to get the full diff.
2. Run `glab mr view <MR>` to understand context (title, description, target branch).
3. Identify the files changed and their types (frontend, backend, infra, config).
4. Apply the two-reviewer protocol:

#### Reviewer 1: TypeScript / Frontend Expert

Review the changed code for:

**Correctness:**
- Logic errors, off-by-one, null/undefined not handled
- Missing error handling at boundaries (API calls, user input parsing)
- Race conditions in async code

**Type safety:**
- Zero `any` types (flag every instance)
- Zero unsafe `as` casts without explicit justification
- Zod schemas used for runtime validation at API boundaries

**React patterns:**
- Hooks: correct dependency arrays, cleanup functions on effects
- Server/Client boundary: no `'use client'` on components that only fetch data
- No prop drilling beyond 2 levels

**Performance:**
- Unnecessary re-renders from unstable references
- Missing loading/error states
- N+1 queries in data fetching

**Test quality:**
- Tests cover behavior, not implementation details
- Assertions are specific
- Edge cases covered (empty, error, boundary)

#### Reviewer 2: DevOps Expert (conditional)

**Skip if** the MR is purely UI/frontend with no new: API routes, env vars, dependencies, or infrastructure config.

When active, review for:

**Environment and config:**
- New env vars documented?
- No hardcoded URLs, ports, credentials in source

**Dependencies:**
- New packages justified? Known vulnerabilities?
- No duplicate functionality

**Security:**
- New API routes have auth checks
- User input validated before processing
- No sensitive data in client bundles or URLs

**Build health:**
- No `@ts-ignore` without justification
- Bundle size impact reasonable

**Output format:**

```
── TYPESCRIPT / FRONTEND EXPERT ─────────────────
✓ [passed items — brief]
⚠ [WARNING: file:line — issue description]
✗ [BLOCKER: file:line — critical issue]

── DEVOPS ──────────────────────────────────────
✓ [passed items — brief]
⚠ [WARNING: specific issue]
✗ [BLOCKER: critical issue]
(or: Skipped — UI-only change, no infra impact)

SUMMARY: N blockers, N warnings, N suggestions
Recommendation: [approve / request changes / discuss]
```

---

## Final Output

After both subagents complete, present their results together:

```
═══════════════════════════════════════════════════
  GITLAB MR REVIEW: !<number> — <title>
═══════════════════════════════════════════════════

── MR SUMMARY (posted to GitLab) ───────────────
<summary from Subagent 1>

── CODE REVIEW ─────────────────────────────────
<review from Subagent 2>

═══════════════════════════════════════════════════
```

If blockers are found, suggest specific fixes. If clean, recommend approval.
