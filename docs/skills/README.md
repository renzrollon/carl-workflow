# Skill catalog

Per-family and standalone documentation for the 19 bundled skills. Each family doc collects related skills together and shows how they compose; standalones get their own file.

## Families

- **[OpenSpec](./openspec.md)** — spec-driven change management. Bootstrap a brownfield repo, explore before designing, propose durable artifacts, apply, archive, and sync canonical specs. The seven-phase backbone.
  - `openspec-bootstrap` · `openspec-explore` · `openspec-explore-deep` · `openspec-propose` · `openspec-apply-change` · `openspec-archive-change` · `openspec-sync-specs`

- **[GSD](./gsd.md)** — wave execution. Optional alternate `apply` path that classifies tasks into waves and runs independent work in parallel via fresh-context subagents. Pairs with a single feature-level commit at the end.
  - `gsd-classify-tasks` · `gsd-wave-apply` · `gsd-commit` · `gsd-context-handoff`

- **[Review](./review.md)** — multi-perspective review gates. Two composite gates (`review-artifacts`, `review-code`) flank the highest-leverage moments in the flow; four single-persona reviewers can also be invoked directly. Shared severity framework: BLOCKER / WARNING / SUGGESTION.
  - `review-artifacts` · `review-code` · `review-arch` · `review-qa` · `review-ts` · `review-devops`

## Standalones

- **[explain-code](./explain-code.md)** — teaching-mode walkthrough of an existing module, file, or data flow. Outputs a written explanation rather than a thinking-partner conversation.
- **[gitlab-mr-review](./gitlab-mr-review.md)** — review a teammate's GitLab merge request. Posts a structured code summary and runs the standard reviewer pair against the diff. GitHub users: N/A.

## How to choose

If you're unsure which skill fits, start at the [decision tree](../decision-tree.md). It branches by intent and points back into these family docs.

## Source

Each doc points at the canonical SKILL.md under `../../skills/<name>/SKILL.md` — that's the source of truth the install script copies into `~/.claude/skills/`.
