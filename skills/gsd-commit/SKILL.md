---
name: gsd-commit
description: Create a single feature-level commit after wave execution. Reads change artifacts to produce a verb-phrase commit message with a summary of changes and optional issue reference.
metadata:
  type: git
  version: "1.0"
---

Create a single, well-crafted commit for all changes produced by `/gsd-wave-apply`.

**Input**: Change name (optional — inferred from branch or prompted) + issue reference (optional)

**Steps**

1. **Determine change context**

   - Infer change name from current branch (`feat/<name>`) or ask user
   - If user provides an issue reference (GitLab `#123`, Jira `PROJ-456`), note it for the commit footer

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
     - Good: `feat(tasks): add task list page with filtering and status badges`
     - Good: `fix(auth): resolve token refresh race condition`
     - Bad: `feat(tasks): Task List Page` (not a verb phrase)
     - Bad: `feat(tasks): added the new task list page` (past tense, too wordy)
   - **Type**: `feat:` `fix:` `chore:` `refactor:` `test:` (match conventional commits)
   - **Scope**: the primary module/feature area (e.g., `tasks`, `auth`, `nav`)
   - **Summary bullets**: describe outcomes, not individual task completions
   - **Refs line**: only include if user provided an issue reference; supports:
     - GitLab: `Refs: #123` or `Refs: group/project#123`
     - Jira: `Refs: PROJ-456`
     - Multiple: `Refs: #123, PROJ-456`
   - Omit the `Refs:` line entirely if no issue reference provided

6. **Show commit preview and confirm**

   Display the full commit message to the user before committing.
   Ask: "Commit with this message?" (allow edits)

7. **Create the commit**

   ```bash
   git commit -m "<message>"
   ```

8. **Report**

   Show:
   - Commit hash + subject
   - Files changed count
   - Suggest next step: `/review-code` or `/opsx:archive`

**Examples**

Single feature:
```
feat(tasks): add task list page with filtering and detail view

Summary of changes:
- Added task list page with status filtering and search
- Created task detail page with metadata sidebar
- Implemented shared TaskCard and StatusBadge components
- Added Prisma schema and service layer for tasks
- Added unit and integration tests for task feature

Change: create-tasks-page
Refs: #142
Co-Authored-By: Claude <noreply@anthropic.com>
```

Bug fix:
```
fix(auth): resolve session expiry not redirecting to login

Summary of changes:
- Fixed middleware to catch expired tokens before route resolution
- Added redirect logic with return-to URL preservation
- Updated auth service tests for expiry edge case

Change: fix-session-expiry
Refs: BUG-789
Co-Authored-By: Claude <noreply@anthropic.com>
```
