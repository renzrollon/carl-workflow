---
name: copilot-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
metadata:
  type: finalization
  version: "1.0"
---

Archive a completed change in the experimental workflow.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use `vscode_askQuestions` to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context
   - `artifacts`: List of artifacts with their status (`done` or other)

   If status reports `actionContext.mode: "workspace-planning"`, explain that workspace archive is not supported in this slice and STOP. Do not move workspace changes into repo-local archives or edit linked repos.

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Use `vscode_askQuestions` to confirm user wants to proceed
   - Proceed if user confirms

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Use `vscode_askQuestions` to confirm user wants to proceed
   - Proceed if user confirms

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Use `artifactPaths.specs.existingOutputPaths` from status JSON to check for delta specs. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   If user chooses sync, invoke openspec-sync-specs for change '<name>'. Delta spec analysis: <include the analyzed delta spec summary>. Proceed to archive regardless of choice.

5. **Attach metrics to archive record**

   Check if `.copilot/metrics/<change-name>-*.json` exists. If so:
   - Read the metrics file
   - Copy it into the change directory before archiving (so it travels with the archive):
     ```bash
     .copilot/metrics/<change-name>-*.json "<changeRoot>/metrics.json"
     ```
   - This preserves execution data (wave stats, test iterations, duration, commit info) as part of the permanent change record.

   If no metrics file exists, skip this step silently.

6. **Perform the archive**

   Create an `archive` directory under `planningHome.changesDir` if it doesn't exist:
   ```bash
   mkdir -p "<planningHome.changesDir>/archive"
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move `changeRoot` to the archive directory

   ```bash
   mv "<changeRoot>" "<planningHome.changesDir>/archive/YYYY-MM-DD-<name>"
   ```

7. **Prompt for project memory**

   Before displaying the final summary, ask the user:

   > "Anything future sessions should know about this change? (e.g., gotchas discovered, coupling between modules, patterns that worked/failed, or things that surprised you)"

   Use `vscode_askQuestions` with options:
   - "Yes, let me add a note"
   - "No, archive as-is"

   **If user provides a note:**
   - Read `.copilot/memory.md` (create if it doesn't exist)
   - Append an entry under the appropriate section:
     ```markdown
     ### <change-name> (<date>)
     - <user's note>
     ```
   - Sections in memory.md: `## Module Coupling`, `## Common Failure Modes`, `## Patterns & Decisions`
   - Place the note under whichever section best fits; if unclear, use `## Patterns & Decisions`

8. **Display summary**
