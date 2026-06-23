---
name: carl-dispatch
description: Route user intent to the appropriate skill. Checks project state, infers what the user wants, and either auto-invokes or presents ranked options.
metadata:
  type: routing
  version: "1.0"
---

Route user intent to the appropriate carl-workflow skill.

**Input**: Natural language request or empty (interactive mode)

**Steps**

0. **Pre-flight context load** (silent — no output to user)

   Before classifying intent, gather minimum viable context:

   ```bash
   # Institutional knowledge
   cat .claude/memory.md 2>/dev/null | head -40

   # Handoff state
   ls -t .claude/handoff/*.md 2>/dev/null | head -1

   # Branch context (issue ref extraction)
   git branch --show-current

   # OpenSpec state
   openspec status --json 2>/dev/null
   ```

   This step runs EVERY dispatch and ensures:
   1. Memory constraints (env gotchas, module coupling, failure modes) are loaded before any skill executes
   2. Handoff state informs routing — if a handoff exists and user intent is vague, resume from it
   3. Branch name provides issue ref context (e.g., `feat/RD-65-*` → issue ref = RD-65)
   4. Active change phase feeds the routing decision

   If a handoff file exists, read it. Set `handoffNextStep` from its "Next Steps" section.

   DO NOT output this to the user — it feeds the routing logic silently.

1. **Assess project state**

   From the pre-flight data, determine:

   - `hasOpenspec`: Does `openspec/` exist?
   - `activeChanges`: List of non-archived changes
   - `currentPhase`: Where is the active change? (proposed / artifact-reviewed / applying / applied / code-reviewed)
   - `hasUncommittedWork`: Does `git status` show relevant changes?
   - `hasHandoff`: Does `.claude/handoff/` contain recent files?
   - `handoffNextStep`: What did the last session recommend as next action?
   - `memoryConstraints`: Relevant entries from .claude/memory.md for the current branch/change
   - `issueRef`: Extracted from branch name if matches pattern (e.g., RD-65, PROJ-123)

2. **Classify user intent**

   Match the user's request against these intent patterns:

   | Intent | Signal Words | Condition |
   |--------|-------------|-----------|
   | **resume** | "continue", "pick up", "let's go", "where was I", or empty/vague message | hasHandoff = true |
   | **primer** | "status", "where am I", "what's going on", "briefing" | Any state (session start) |
   | **bootstrap** | "set up", "initialize", "onboard" | No `openspec/` directory |
   | **explore** | "how does", "where is", "understand", "investigate", "explain" | Any state |
   | **propose** | "build", "add feature", "implement", "create", "new" | Has openspec, no active change for this work |
   | **review-artifacts** | "review design", "check proposal", "validate plan" | Active change with artifacts, pre-apply |
   | **apply** | "implement", "do it", "execute", "apply", "start coding" | Active change with tasks |
   | **review-code** | "review code", "check implementation", "code review" | Active change, post-apply |
   | **archive** | "done", "finish", "archive", "wrap up" | Active change, all tasks complete |
   | **fix** | "fix", "bug", "broken", "error" | Any state (may bypass full flow) |
   | **resume** | "continue", "pick up", "where was I" | Handoff file exists |
   | **commit** | "commit", "save changes" | Uncommitted work after wave apply |
   | **metrics** | "metrics", "stats", "how did it go", "performance" | Metrics files exist |
   | **explain** | "explain", "walk me through", "teach" | Any state |

3. **Route to skill**

   Based on intent + state, select the target skill:

   | Intent | State | Skill | Notes |
   |--------|-------|-------|-------|
   | resume | Handoff exists | Route to skill indicated by `handoffNextStep` | Load handoff context first, then invoke target skill |
   | primer | Any | `/gsd-session-primer` | Read-only status briefing |
   | bootstrap | No openspec/ | `/openspec-bootstrap` | One-time setup |
   | explore | Any | `/openspec-explore` | Use `-deep` if multi-subsystem |
   | propose | Has openspec | `/openspec-propose` | Creates change artifacts |
   | review-artifacts | Change has artifacts | `/review-artifacts` | Gate 1 |
   | apply (≤4 tasks) | Change has tasks | `/openspec-apply-change` | Sequential |
   | apply (≥5 tasks, independent) | Change has tasks | `/gsd-wave-apply` | Parallel (includes classification + preview) |
   | review-code | Change applied | `/review-code` | Gate 2 |
   | archive | All tasks done | `/openspec-archive-change` | Finalize |
   | fix | Any | `/openspec-apply-change` or direct fix | Context-dependent |
   | commit | Uncommitted work | `/gsd-commit` | After wave execution |
   | metrics | Metrics exist | `/gsd-metrics` | Retrospective |
   | explain | Any | `/explain-code` | Teaching mode |

4. **Execute or present options**

   **If intent is clear (high confidence):**
   - Announce: "Routing to `/skill-name` — <one-line reason>"
   - Invoke the skill using the Skill tool

   **If intent is ambiguous (multiple valid interpretations):**
   - Present ranked options using AskUserQuestion:
     ```
     Based on project state, you could:
     1. <most likely skill> — <why>
     2. <second option> — <why>
     3. <third option> — <why>
     ```
   - Invoke the selected skill

   **If no openspec and user wants to build something:**
   - Suggest `/openspec-bootstrap` first, then the desired action
   - Explain: "OpenSpec isn't set up yet. Bootstrap first for structured workflow, or I can help directly."

**Routing Heuristics**

Core rules:
- If the user says "just do it" or "quick fix" without ceremony → skip proposal/review, apply directly
- If the change has 5+ independent tasks → recommend GSD wave over standard apply
- If the user references a specific file → likely explore or fix, not propose
- If the user says "review" without qualifier → infer from phase (pre-apply = artifacts, post-apply = code)
- If context is heavy and user seems lost → suggest `/gsd-context-handoff` then `/clear`

Context-aware (uses pre-flight data):
- If `memoryConstraints` contains entries relevant to the current task → include them in the skill invocation context so the agent starts with institutional knowledge
- If `issueRef` was extracted from branch → pass it to /gsd-commit automatically (no user reminder needed)
- If handoff indicates unresolved blockers from last session → surface them immediately: "Last session hit: <blocker>. Resolve first, or work around it?"

Escalation (prevent sessions from drifting to lower quality):
- Single find-replace or rename → apply directly without full workflow: "This is a 1-minute change — applying directly."
- Task spans >3 files AND no active change exists → escalate to propose: "This touches enough surface area for a structured change. Running /openspec-propose."
- Vague request without clear scope or constraints → escalate to explore: "This needs scoping. Running /openspec-explore to define boundaries."
- Question spans 3+ subsystems → route to explore-deep instead of standard explore

De-escalation (keep sessions short and decisive):
- Session running >20 min without commit or artifact → warn: "Session running long. Consider /gsd-context-handoff + /clear, or /gsd-commit to lock in progress."
- 3+ user corrections or wrong approaches in one session → pause: "Multiple corrections suggest unclear scope. Suggest /openspec-explore to solidify constraints before continuing."

Preflight integration:
- If target skill is a producing skill (propose, apply, wave-apply, fix, explore-deep), invoke `/gsd-preflight` as intermediary before the target skill
- If target skill is read-only (primer, explain, metrics, explore-light, archive), skip preflight — invoke directly

**Output**

When routing succeeds:
```
## Dispatching

**Intent:** <classified intent>
**State:** <project state summary>
**Routing to:** /skill-name

<invokes skill>
```

When presenting options:
```
## What would you like to do?

**Project state:** <summary>
**Active change:** <name> (phase: <phase>)

I see a few directions from here:
```

**Guardrails**
- Never auto-invoke a destructive action (archive, force-push) without confirmation
- If state detection fails (openspec CLI not available), fall back to intent-only routing
- Always announce which skill is being invoked and why
- If the user explicitly names a skill (e.g., "run /review-code"), just invoke it — no routing logic needed
