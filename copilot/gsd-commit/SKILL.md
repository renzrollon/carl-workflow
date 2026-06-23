---
name: gsd-commit
description: Create a single feature-level commit after wave execution. Reads change artifacts to produce a verb-phrase commit message with a summary of changes and optional issue reference.
metadata:
  type: git
  version: "1.0"
---

Create a single, well-crafted commit for all changes produced by `/gsd-wave-apply`.

**Input**: Change name (optional — inferred from branch or prompted) + issue reference (optional, e.g. `RD-65`, `PROJ-123`, `#42`)

**Invocation examples**:
- `/gsd-commit` — infers change name from branch, no issue ref
- `/gsd-commit RD-65` — uses RD-65 as scope and footer ref
- `/gsd-commit fix-login RD-65` — explicit change name + issue ref

**Steps**

1. **Determine change context**

   - Parse arguments: anything matching `[A-Z]+-\d+` or `#\d+` is an issue reference; remaining text is the change name
   - If no change name provided, infer from current branch (`feat/<name>`) or ask user
   - If no issue ref provided as argument, attempt to extract from branch name:
     - `feat/RD-65-task-page` → `RD-65`
     - `fix/PROJ-123-login-bug` → `PROJ-123`
     - `feature/TEAM-42-new-dashboard` → `TEAM-42`
   - **If on a feat/ or fix/ branch but no ref was detected:**
     - Warn the user: "⚠️ No issue reference found. Branch `<name>` looks like a feature branch — did you mean to include a ticket ref? Pass it as `/gsd-commit <REF>` to avoid rewriting later."
     - Wait for user to confirm proceeding without a ref, or to provide one
   - If on main/develop or a branch without feat/fix prefix: proceed silently without ref (it's truly optional)

2. **Read change artifacts for commit context**

   ```bash
   openspec status --change "<name>" --json
   ```

   Read:
   - `proposal.md` — for the one-line feature intent
   - `design.md` — for scope understanding
   - `tasks.md` — for summary of what was done (checked items)

3. **Inspect the diff**

   ```bash
   git status
   git diff --stat
   git diff --staged --stat
   ```

   Understand the full scope of file changes to write an accurate summary.

4. **Stage all relevant files**

   ```bash
   git add <specific-files>
   ```

   - Stage implementation files, test files, and updated `tasks.md`
   - Do NOT stage unrelated files (`.env`, editor configs, etc.)
   - If unsure about a file, ask the user

5. **Compose the commit message**

   Format:
   ```
   <type>(<scope>): <verb-phrase description>

   Summary of changes:
   - <what was added/changed, grouped logically>
   - <keep to 3-7 bullet points>

   Change: <change-name>
   Refs: <issue-reference>
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

   Rules:
   - **Subject line**: imperative verb phrase, lowercase after type, max 72 chars
   - **Type**: `feat:` `fix:` `chore:` `refactor:` `test:` (match conventional commits)
   - **Scope** (priority order):
     1. If issue ref exists → use it as scope: `feat(RD-65): add task list page`
     2. If no issue ref → use primary module/feature area: `feat(tasks): add task list page`
   - **Summary bullets**: describe outcomes, not individual task completions
   - **Refs line**: include when issue ref exists (mirrors the scope); omit entirely when no ref
     - Jira: `Refs: RD-65`
     - GitLab: `Refs: #123` or `Refs: group/project#123`
     - Multiple: `Refs: RD-65, #123`
   - Omit the `Refs:` line entirely if no issue reference was found

   Examples:
   - Good: `feat(RD-65): add task list page with filtering and status badges`
   - Good: `fix(PROJ-123): resolve token refresh race condition`
   - Good (no ref): `feat(tasks): add task list page with filtering`
   - Bad: `feat(tasks): Task List Page` (not a verb phrase)
   - Bad: `feat(tasks): added the new task list page` (past tense, too wordy)

6. **Show commit preview and confirm**

   Display the full commit message to the user before committing.
   Ask: "Commit with this message?" (allow edits)

7. **Create the commit**

   ```bash
   git commit -m "<message>"
   ```

8. **Append metrics to manifest**

   If `.claude/metrics/<change-name>-*.json` exists (emitted by `/gsd-wave-apply`), update it with commit metadata:

   Read the most recent metrics file for this change, then add a `commit` section:
   ```json
   {
     "commit": {
       "hash": "<short-hash>",
       "subject": "<commit subject line>",
       "filesChanged": 0,
       "insertions": 0,
       "deletions": 0
     }
   }
   ```

   Use `git diff --stat HEAD~1` to get file/insertion/deletion counts after committing.

9. **Report**

   Show:
   - Commit hash + subject
   - Files changed count
   - Metrics file path (if written)
   - Suggest next step: `/review-code` or `/opsx:archive`

**Examples**

Feature with issue ref (invoked as `/gsd-commit RD-142`):
```
feat(RD-142): add task list page with filtering and detail view

Summary of changes:
- Added task list page with status filtering and search
- Created task detail page with metadata sidebar
- Implemented shared TaskCard and StatusBadge components
- Added Prisma schema and service layer for tasks
- Added unit and integration tests for task feature

Change: create-tasks-page
Refs: RD-142
Co-Authored-By: Claude <noreply@anthropic.com>
```

Bug fix with ref extracted from branch `fix/BUG-789-session-expiry`:
```
fix(BUG-789): resolve session expiry not redirecting to login

Summary of changes:
- Fixed middleware to catch expired tokens before route resolution
- Added redirect logic with return-to URL preservation
- Updated auth service tests for expiry edge case

Change: fix-session-expiry
Refs: BUG-789
Co-Authored-By: Claude <noreply@anthropic.com>
```

Feature without issue ref:
```
feat(nav): add breadcrumb component to all pages

Summary of changes:
- Created reusable Breadcrumb component with auto-path parsing
- Integrated into app layout with route-based segment labels
- Added unit tests for path parsing logic

Change: add-breadcrumbs
Co-Authored-By: Claude <noreply@anthropic.com>
```
