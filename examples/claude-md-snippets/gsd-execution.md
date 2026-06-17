# CLAUDE.md snippet — GSD wave execution (optional)

Paste the block below into your project's `CLAUDE.md` if you want Claude Code to use GSD-style parallel wave execution for changes with many independent tasks.

## Snippet

```markdown
## GSD-Style Execution (Optional)

When applying changes with many independent tasks:
- Use `/gsd-classify-tasks` to preview the execution plan (waves, tiers, dependency graph)
- Use `/gsd-wave-apply` for parallel fresh-context execution
- Use `/gsd-commit` to create a single feature-level commit after execution
- Use `/gsd-context-handoff` before `/clear` to preserve state across resets

Model routing:
- Tier 1-3 tasks: use the fast/cheap tier (sufficient for mechanical work)
- Tier 4-5 tasks: use the most capable tier (multi-file or architectural reasoning)
- Review/verification: use a small tier (validation only)

Commit strategy:
- No commits during wave execution — all changes stay uncommitted
- After execution + review, `/gsd-commit` creates one commit per feature
- Commit subject: verb-phrase in imperative mood, max 72 chars
- Optional issue reference at end (e.g. `Refs: #123` or `Refs: PROJ-456`)

Verification wave:
- The last numbered group in `tasks.md` (tests / final verification) is run sequentially in the main context, never via parallel subagents — failures often share a root cause.
```

## When to enable this

Most projects don't need GSD. Enable it when a single change has 5+ tasks that touch different files or modules and don't share state — that's where parallel waves with isolated contexts pay off. For small or tightly coupled changes, the standard sequential `/opsx:apply` is faster and produces a cleaner reviewable diff.

## Notes

- The model-tier names are stack-neutral on purpose; map them to specific model IDs in your `CLAUDE.md` or harness settings if needed.
- Pairs cleanly with `openspec-flow.md` — GSD execution slots into the `/opsx:apply` step of the OpenSpec flow.
- `/gsd-context-handoff` writes to `.claude/handoff/<change>-<timestamp>.md`; add that path to `.gitignore` if you don't want handoffs checked in.
