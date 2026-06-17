# CLAUDE.md snippet — OpenSpec workflow

Paste the block below into your project's `CLAUDE.md` to wire up the OpenSpec workflow rules.

## Snippet

```markdown
## OpenSpec Workflow
Flow: `/opsx:explore → /opsx:propose → /review-artifacts → /opsx:apply → /review-code → /opsx:archive`

**post-propose:** suggest `/review-artifacts`; don't run `/opsx:apply` until passed (or user skips).
**during apply:** read ALL artifacts first; follow `design.md` exactly; write tests per specs; check off `tasks.md`.
**post-apply:** suggest `/review-code`; don't suggest `/opsx:archive` until passed (or user skips).
**skip gate:** honor "skip review", "straight to apply", "archive now".
```

## Optional add-ons

Pick any that apply to your project and append them under the `**during apply:**` line.

- For projects with a Server/Client component split (e.g. Next.js App Router, Remix):

  ```markdown
  **during apply (framework):** respect Server/Client component boundaries from `design.md`.
  ```

- For projects that enforce co-located tests:

  ```markdown
  **during apply (tests):** co-locate test files next to the source they cover.
  ```

- For projects with a strict typed-API contract:

  ```markdown
  **during apply (api):** all new endpoints return typed responses via shared schemas.
  ```

- To branch and commit by change name:

  ```markdown
  **git:** branch names match change names (`feat/<change>`); PRs link `openspec/changes/<change>/`.
  ```
