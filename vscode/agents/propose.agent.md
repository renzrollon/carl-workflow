---
name: Propose Change
description: Propose a new change with all artifacts — proposal, design, specs, and tasks — ready for implementation.
tools: ['search/codebase', 'search/usages', 'runCommand', 'createFile', 'editFiles']
user-invocable: true
handoffs:
  - label: "Review before implementing"
    agent: "Review: Artifacts"
    prompt: "Review the proposal for"
    send: false
  - label: "Skip review, start implementing"
    agent: Apply Change
    prompt: "Implement the tasks for"
    send: false
---

Propose a new change — create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

---

## Steps

1. **If no clear input provided, ask what they want to build**

   Ask: "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" -> `add-user-auth`).

2. **Create the change directory**
   ```bash
   openspec new change "<name>"
   ```

3. **Get the artifact build order**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to get:
   - `applyRequires`: array of artifact IDs needed before implementation
   - `artifacts`: list of all artifacts with their status and dependencies
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context

4. **Create artifacts in sequence until apply-ready**

   Loop through artifacts in dependency order (no pending dependencies first):

   a. For each ready artifact:
      - Get instructions: `openspec instructions <artifact-id> --change "<name>" --json`
      - Read any completed dependency files for context
      - Create the artifact file using `template` as structure, write to `resolvedOutputPath`
      - Apply `context` and `rules` as constraints — do NOT copy them into the file
      - Show progress: "Created <artifact-id>"

   b. Continue until all `applyRequires` artifacts are complete
      - After each artifact, re-run `openspec status --change "<name>" --json`
      - Stop when all `applyRequires` artifacts have `status: "done"`

   c. If an artifact requires user input (unclear context): ask for clarification

5. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

---

## Output

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- Status: "All artifacts created! Ready for implementation."
- Offer the handoff buttons for next step

---

## Artifact Creation Guidelines

- Follow the `instruction` field from `openspec instructions` for each artifact type
- Read dependency artifacts for context before creating new ones
- Use `template` as structure — fill in its sections
- `context` and `rules` are constraints for YOU, not content for the file
- Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into artifacts

---

## Guardrails

- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- If context is critically unclear, ask — but prefer making reasonable decisions to keep momentum
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next
