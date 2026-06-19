---
name: copilot-context-handoff
description: Save current session state to a handoff document before clearing context. Preserves decisions, progress, and next steps across context resets.
metadata:
  type: utility
  version: "1.0"
---

Save session state before clearing context.

**When to use**: Before clearing context between phases, or when context is getting heavy.

**Steps**

1. Summarize current state:
   - Active change name and progress
   - Key decisions made this session
   - Files modified
   - Issues encountered
   - What comes next

2. Check for project memory:
   - If `.copilot/memory.md` exists, read it and include relevant entries in the handoff (entries related to modules being modified or patterns being used)
   - This ensures the next session inherits institutional knowledge without re-discovering it

3. Write to `.copilot/handoff/<change-name>-<timestamp>.md`:
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
   <!-- Entries from .copilot/memory.md that relate to this change -->
   - <relevant memory entries, if any>

   ## Issues/Blockers
   - <any issues>

   ## Next Steps
   - <what to do after context reset>
   ```

4. Instruct user: "Context saved. Clear your context, then resume with: 'Continue <change-name> — read handoff at .copilot/handoff/<file>'"
