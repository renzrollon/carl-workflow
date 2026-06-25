---
name: GitLab MR Review
description: Summarize and review a GitLab Merge Request — writes a code summary to the MR description and performs a structured code review.
tools: ['search/codebase', 'runCommand', 'githubRepo']
user-invocable: true
---

Summarize and review a GitLab Merge Request.

## Input

Accept an MR identifier. If none provided, detect the current branch and find its open MR. Formats:

- MR number: `!123` or `123`
- MR URL: `https://gitlab.example.com/group/project/-/merge_requests/123`
- Omitted: use `glab mr view` on the current branch

## Execution

Run both phases sequentially:

---

### Phase 1: MR Summary

Fetch the MR diff and metadata using `glab`, then produce a structured summary and update the MR description.

**Steps:**

1. Run `glab mr view <MR> --comments` to get MR metadata (title, description, labels, source/target branch).
2. Run `glab mr diff <MR>` to get the full diff.
3. Analyze the diff and produce a summary with:
   - **What changed** — 2-5 bullet points covering intent and scope
   - **Key files** — list of significant files with one-line explanation each
   - **Impact** — breaking changes, new dependencies, migration needed, env vars added
   - **Testing** — what tests were added/modified, what's untested
4. Update the MR description on GitLab by appending the summary:

```bash
glab mr update <MR> --description "<existing description>

---

## Code Summary

<generated summary>

---
_Summarized by AI agent_"
```

Preserve the existing description — append, never replace.

---

### Phase 2: Code Review

Review the MR diff for quality, correctness, and deploy-readiness.

#### Reviewer 1: TypeScript / Frontend Expert

Review the changed code for:

**Correctness:**
- Logic errors, off-by-one, null/undefined not handled
- Missing error handling at boundaries (API calls, user input)
- Race conditions in async code

**Type safety:**
- Zero `any` types (flag every instance)
- Zero unsafe `as` casts without justification
- Zod schemas at API boundaries

**React patterns:**
- Correct dependency arrays, cleanup functions on effects
- Server/Client boundary respected
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

**Skip if** the MR is purely UI/frontend with no new API routes, env vars, dependencies, or infra config.

When active, review for:

**Environment and config:**
- New env vars documented?
- No hardcoded URLs, ports, credentials

**Dependencies:**
- New packages justified? Known vulnerabilities?

**Security:**
- New API routes have auth checks
- User input validated before processing
- No sensitive data in client bundles

**Build health:**
- No `@ts-ignore` without justification
- Bundle size impact reasonable

---

## Final Output

```
===================================================
  GITLAB MR REVIEW: !<number> -- <title>
===================================================

-- MR SUMMARY (posted to GitLab) ---------------
<summary>

-- CODE REVIEW ---------------------------------
-- TYPESCRIPT / FRONTEND EXPERT ----------------
[passed] [passed items]
[WARNING] [file:line -- issue]
[BLOCKER] [file:line -- critical issue]

-- DEVOPS --------------------------------------
[passed] [passed items]
[WARNING] [specific issue]
[BLOCKER] [critical issue]
(or: Skipped -- UI-only change, no infra impact)

SUMMARY: N blockers, N warnings
Recommendation: [approve / request changes / discuss]
===================================================
```

If blockers are found, suggest specific fixes. If clean, recommend approval.
