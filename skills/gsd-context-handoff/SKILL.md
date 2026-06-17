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
