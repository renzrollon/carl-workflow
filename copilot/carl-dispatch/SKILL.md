---
name: copilot-dispatch
description: Route user intent to the appropriate carl-workflow skill. Checks project state, infers what the user wants, and either auto-invokes or presents ranked options.
metadata:
  type: routing
  version: "1.0"
---

Route user intent to the appropriate carl-workflow skill.

**Input**: Natural language request or empty (interactive mode)

**Steps**

1. **Assess project state**

   Run quick checks to understand where the project is:

   ```bash
   # Check if openspec is initialized
   ls openspec/ 2>/dev/null

   # Check for active changes
   openspec list --json 2>/dev/null

   # Check for active change status (if any)
   openspec status --json 2>/dev/null
   ```

   Determine:
   - `hasOpenspec`: Does `openspec/` exist?
   - `activeChanges`: List of non-archived changes
   - `currentPhase`: Where is the active change? (proposed / artifact-reviewed / applying / applied / code-reviewed)
   - `hasUncommittedWork`: Does `git status` show relevant changes?
   - `hasHandoff`: Does `.copilot/handoff/` contain recent files?

2. **Classify user intent**

   Match the user's request against these intent patterns:

   | Intent | Signal Words | Condition |
   |--------|-------------|-----------|
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
   | **explain** | "explain", "walk me through", "teach" | Any state |

3. **Route to skill**

   Based on intent + state, select the target skill:

   | Intent | State | Skill | Notes |
   |--------|-------|-------|-------|
   | bootstrap | No openspec/ | `/copilot-bootstrap` | One-time setup |
   | explore | Any | `/copilot-explore` | Use `-deep` if multi-subsystem |
   | propose | Has openspec | `/copilot-propose` | Creates change artifacts |
   | review-artifacts | Change has artifacts | `/copilot-review-artifacts` | Gate 1 |
   | apply (≤4 tasks) | Change has tasks | `/copilot-apply-change` | Sequential |
   | apply (≥5 tasks, independent) | Change has tasks | `/copilot-wave-apply` | Parallel (includes classification + preview) |
   | review-code | Change applied | `/copilot-review-code` | Gate 2 |
   | archive | All tasks done | `/copilot-archive-change` | Finalize |
   | fix | Any | `/copilot-apply-change` or direct fix | Context-dependent |
   | resume | Handoff exists | Read handoff → route | Continue from saved state |
   | commit | Uncommitted work | `/copilot-commit` | After wave execution |
   | explain | Any | `/copilot-explain-code` | Teaching mode |

4. **Execute or present options**

   **If intent is clear (high confidence):**
   - Announce: "Routing to `<skill-name>` — <one-line reason>"
   - Invoke the skill using the Skill tool or inline instructions

   **If intent is ambiguous (multiple valid interpretations):**
   - Present ranked options using `vscode_askQuestions`:
     ```
     Based on project state, you could:
     1. <most likely skill> — <why>
     2. <second option> — <why>
     3. <third option> — <why>
     ```
   - Invoke the selected skill

   **If no openspec and user wants to build something:**
   - Suggest `/copilot-bootstrap` first, then the desired action
   - Explain: "OpenSpec isn't set up yet. Bootstrap first for structured workflow, or I can help directly."

**Routing Heuristics**

- If the user says "just do it" or "quick fix" without ceremony → skip proposal/review, apply directly
- If the change has 5+ independent tasks → recommend GSD wave over standard apply
- If the user references a specific file → likely explore or fix, not propose
- If the user says "review" without qualifier → infer from phase (pre-apply = artifacts, post-apply = code)
- If context is heavy and user seems lost → suggest `/copilot-context-handoff` then clear context

**Output**

When routing succeeds:
```
## Dispatching

**Intent:** <classified intent>
**State:** <project state summary>
**Routing to:** <skill-name>

<invoke skill>
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
- If the user explicitly names a skill, just invoke it — no routing logic needed
