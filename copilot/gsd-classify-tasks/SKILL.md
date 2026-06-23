---
name: gsd-classify-tasks
description: "DEPRECATED — classification is now built into /gsd-wave-apply (step 3-4). This file is kept as reference for classification rules only."
disable-model-invocation: true
metadata:
  type: analysis
  version: "1.0"
  deprecated: true
  supersededBy: gsd-wave-apply
---

> **Deprecated**: Task classification is now built into `/gsd-wave-apply` (steps 3-4: classify → preview → confirm → execute). Use `/gsd-wave-apply` directly. This file is retained as a reference for the classification rules.

---

Analyze an OpenSpec change's tasks and produce an execution plan.

**Input**: Change name (optional)

**Steps**

1. Load tasks.md from the active change
2. Parse into structured format:
   - Group number, task number, description
   - File targets mentioned
   - Complexity classification (tier 1-5)
   - Model recommendation (haiku/sonnet/opus)
3. Build dependency graph:
   - Inter-group dependencies (group 2 depends on group 1)
   - Intra-group independence (tasks within a group can parallelize)
4. Produce execution plan

**Output**

```
## Execution Plan: <change-name>

### Wave 1 (Group 1) — Sequential prerequisite
| Task | Tier | Model  | Context | Files |
|------|------|--------|---------|-------|
| 1.1  |  2   | sonnet | 1K      | nextjs-guide.md |
| 1.2  |  1   | sonnet | 200     | nextjs-guide.md |

### Wave 2 (Groups 2 + 3) — Parallel
| Task | Tier | Model  | Context | Files |
|------|------|--------|---------|-------|
| 2.1  |  2   | sonnet | 1K      | nextjs-guide.md |
| 3.1  |  1   | sonnet | 200     | nextjs-guide.md |

### Wave 3 (Group 4) — Depends on Wave 1
| Task | Tier | Model  | Context | Files |
|------|------|--------|---------|-------|
| 4.1  |  3   | opus   | 3K      | CLAUDE.md |

### Summary
- Total tasks: N
- Waves: N (estimated wall-clock: ~Nm)
- Token budget: ~NK (vs ~NK standard apply)
- Parallel savings: ~N% faster
```

**Classification Rules**

Tier 1 — Trivial:
- Pattern: badge/label change, single-word replacement
- Signal: "promote", "replace X with Y", "remove row"
- Context: task description + file path only

Tier 2 — Simple:
- Pattern: add a row/section, update a paragraph
- Signal: "add", "update", "modify" + single file
- Context: + relevant design section

Tier 3 — Moderate:
- Pattern: implement new logic, write component, update spec
- Signal: "implement", "create", "write" + specific behavior
- Context: + relevant spec

Tier 4 — Complex:
- Pattern: multi-file changes, cross-cutting concerns
- Signal: "throughout", "all references", "align"
- Context: + full design + related specs

Tier 5 — Architectural:
- Pattern: new patterns, system design, refactors
- Signal: "architecture", "pattern", "refactor", "system"
- Context: all artifacts

---

## Context Handoff

Save session state before clearing context.

**When to use**: Before running /clear between phases, or when context is getting heavy.

**Steps**

1. Summarize current state:
   - Active change name and progress
   - Key decisions made this session
   - Files modified
   - Issues encountered
   - What comes next

2. Write to `.claude/handoff/<change-name>-<timestamp>.md`:
   ```markdown
   # Context Handoff: <change-name>
   ## Date: <ISO timestamp>

   ## Progress
   - Tasks completed: N/M
   - Current wave: N

   ## Decisions Made
   - <decision 1>
   - <decision 2>

   ## Files Modified
   - <file list>

   ## Issues/Blockers
   - <any issues>

   ## Next Steps
   - <what to do after /clear>
   ```

3. Instruct user: "Context saved. Run /clear, then resume with: 'Continue <change-name> — read handoff at .claude/handoff/<file>'"