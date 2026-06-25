---
name: openspec-propose
description: Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.4.0"
---

Propose a new change - create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

When ready to implement, run /opsx:apply

---

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Create the change directory**
   ```bash
   openspec new change "<name>"
   ```
   This creates a scaffolded change in the planning home resolved by the CLI with `.openspec.yaml`.

3. **Get the artifact build order**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to get:
   - `applyRequires`: array of artifact IDs needed before implementation (e.g., `["tasks"]`)
   - `artifacts`: list of all artifacts with their status and dependencies
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context. Use these instead of assuming repo-local paths.

4. **Create artifacts in strict dependency order**

   Use the **TodoWrite tool** to track progress through the artifacts.

   **CRITICAL: You MUST create artifacts in dependency order. NEVER skip ahead to a downstream artifact (e.g., tasks) before ALL of its upstream dependencies (e.g., specs, design) are created and confirmed "done" by the CLI.**

   Loop:

   a. **Run status to determine the next artifact to create**:
      ```bash
      openspec status --change "<name>" --json
      ```
      - Find the FIRST artifact with `status: "ready"` (dependencies satisfied, not yet created)
      - If NO artifact has `status: "ready"` and ALL artifacts have `status: "done"` → stop (step 4d)
      - **You may ONLY create an artifact that the CLI reports as `"ready"`**. If an artifact's status is `"pending"` (dependencies not yet satisfied), you MUST create its dependencies first.

   b. **Create the next ready artifact**:
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - The instructions JSON includes:
        - `context`: Project background (constraints for you - do NOT include in output)
        - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
        - `template`: The structure to use for your output file
        - `instruction`: Schema-specific guidance for this artifact type
        - `resolvedOutputPath`: Resolved path or pattern to write the artifact
        - `dependencies`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - Create the artifact file using `template` as the structure and write it to `resolvedOutputPath`
      - Apply `context` and `rules` as constraints - but do NOT copy them into the file
      - Show brief progress: "Created <artifact-id>"

   c. **If an artifact requires user input** (unclear context):
      - Use **AskUserQuestion tool** to clarify
      - Then continue with creation

   d. **Stopping condition: ALL artifacts must be "done"**
      - After creating each artifact, re-run `openspec status --change "<name>" --json`
      - Check that EVERY artifact in the `artifacts` array has `status: "done"`
      - **Do NOT stop just because `applyRequires` artifacts are done** — if any artifact still has status "ready" or "pending", you must continue creating them
      - Only stop when no artifacts remain with status "ready" or "pending"

5. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx:apply` or ask me to implement to start working on the tasks."

**Artifact Creation Guidelines**

- Follow the `instruction` field from `openspec instructions` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use `template` as the structure for your output file - fill in its sections
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- **NEVER skip artifacts**: Create ALL artifacts defined in the schema, not just those in `applyRequires`. The dependency graph must be fully satisfied.
- **NEVER create an artifact out of order**: Only create artifacts the CLI reports as `"ready"`. If you're tempted to jump ahead to `tasks` but `specs` is still "ready" or "pending", you MUST create `specs` first.
- **Use the CLI as the source of truth**: Always re-run `openspec status` after each artifact creation. Do not assume an artifact is done — confirm it via the CLI's status output.
- Always read dependency artifacts before creating a new one
- If context is critically unclear, ask the user - but prefer making reasonable decisions to keep momentum
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next
