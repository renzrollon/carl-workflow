---
name: gsd-session-primer
description: Load project context at session start — git state, recent commits, open tasks, in-progress changes, and handoff files. Outputs a 5-line briefing so the agent starts working immediately without exploratory warm-up.
metadata:
  type: utility
  version: "1.0"
---

Load project context and produce a concise status briefing at session start.

**Input**: None (reads from project state)

**Why**: Sessions typically burn 3-5 exploratory Read/Bash calls before the agent understands the project state. This skill front-loads that context in one pass.

**Steps**

1. **Gather state in parallel**

   Run these commands together:

   ```bash
   # Git state
   git branch --show-current
   git status --short
   git log --oneline -5

   # OpenSpec state (if available)
   openspec list --json 2>/dev/null

   # Active change status
   openspec status --json 2>/dev/null

   # Open tasks
   find openspec/changes/*/tasks.md -exec grep -l '\- \[ \]' {} \; 2>/dev/null

   # Recent handoff
   ls -t .claude/handoff/*.md 2>/dev/null | head -1

   # Project memory
   cat .claude/memory.md 2>/dev/null | head -20
   ```

2. **Read handoff if exists**

   If a handoff file was found, read it — it contains decisions and next steps from the last session.

3. **Compose briefing**

   Output a structured briefing (target: 5-8 lines):

   ```
   ## Session Briefing

   **Branch:** <branch> (<N commits ahead of main>)
   **Last activity:** <most recent commit subject + time>
   **Active change:** <name> — phase: <phase>, tasks: <done>/<total>
   **Uncommitted:** <file count> files (<staged>/<unstaged>)
   **Resume from:** <handoff summary or "fresh start">

   **Next step:** <inferred from state — e.g., "continue wave 3", "run /gsd-commit", "all done — /openspec-archive-change">
   ```

4. **Infer next action**

   Based on state, suggest the most likely next skill:

   | State | Suggestion |
   |-------|-----------|
   | Handoff file exists | "Resume with: `Continue <change> — read handoff at <path>`" |
   | Active change, unchecked tasks remain | "/gsd-wave-apply <change>" |
   | Active change, all tasks done, uncommitted work | "/gsd-commit" |
   | Active change, committed but not archived | "/openspec-archive-change" |
   | No active change, clean state | "Ready for new work — /openspec-propose or /openspec-explore" |
   | Uncommitted work, no active change | "Uncommitted changes — review with `git diff` or commit" |

5. **Readiness assessment**

   Evaluate expert-session preconditions based on gathered state:

   | Precondition | Check | How to Fulfill |
   |-------------|-------|----------------|
   | Scope defined | Active change exists OR user stated clear intent | Define what you're building/fixing before executing |
   | Constraints loaded | memory.md was read and relevant entries exist | Add project constraints to .claude/memory.md |
   | Orchestration decided | Task count known, parallel vs sequential determined | Classify tasks → decide wave-apply vs sequential |
   | Artifacts available | If executing: proposal + design + tasks exist | Run /openspec-propose first |
   | Handoff consumed | If resuming: handoff file was read | Read .claude/handoff/ before starting |

   Append to briefing:

   ```
   **Readiness:** N/5 preconditions met [list which are met/missing]
   ```

   - If all 5 met: "Ready for expert-level execution."
   - If < 3 met: suggest how to fulfill the most impactful missing precondition before proceeding.
   - Skip preconditions that don't apply (e.g., "Handoff consumed" is N/A on fresh starts; "Artifacts available" is N/A for explore/fix intents).

**Guardrails**
- NEVER modify any files — this is read-only
- Keep output under 20 lines total — briefing + readiness assessment
- If openspec CLI is not available, skip OpenSpec-specific checks gracefully
- Include memory entries only if they relate to the current branch/change
