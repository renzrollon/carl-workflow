---
name: gsd-context-handoff
description: Save current session state to a handoff document before /clear. Preserves decisions, progress, and next steps across context resets.
metadata:
  type: utility
  version: "1.0"
---

Save session state before clearing context.

**When to use**: Before running /clear between phases, or when context is getting heavy.

**Steps**

1. Summarize current state:
   - Active change name and progress
   - Key decisions made this session
   - Files modified
   - Issues encountered
   - What comes next

2. Check for project memory:
   - If `.claude/memory.md` exists, read it and include relevant entries in the handoff (entries related to modules being modified or patterns being used)
   - This ensures the next session inherits institutional knowledge without re-discovering it

3. Write to `.claude/handoff/<change-name>-<timestamp>.md`:
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

   ## Relevant Memory
   <!-- Entries from .claude/memory.md that relate to this change -->
   - <relevant memory entries, if any>

   ## Issues/Blockers
   - <any issues>

   ## Next Steps
   - <what to do after /clear>
   ```

4. **Capture friction as permanent memory**

   Review the "Issues/Blockers" from this session. For each issue that represents a reusable constraint (not a one-time bug), suggest adding it to `.claude/memory.md`:

   ```
   ## Suggested Memory Entries

   These issues from this session could prevent friction in future sessions:

   - [ ] "<constraint>" → add to ## Common Failure Modes
   - [ ] "<constraint>" → add to ## Module Coupling
   ```

   If the user confirms (or if the constraint was already captured automatically during execution), append the entry. If the user declines, skip — the handoff still preserves the context for the next session.

5. Instruct user: "Context saved. Run /clear, then resume with: 'Continue <change-name> — read handoff at .claude/handoff/<file>'"
