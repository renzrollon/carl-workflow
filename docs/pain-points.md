# Pain Points & Gotchas

These are recurring failure modes observed across many AI-coding sessions — patterns that cost real debugging time before being diagnosed. Each comes with a CLAUDE.md mitigation snippet you can lift directly into a project to prevent the next session from re-discovering the same trap.

## 1. Environment config drift (.env vs .env.local vs .env.example)

### Symptom
Agent creates a plain `.env` and runs migrations or starts the dev server; the app then fails with "missing DATABASE_URL" or silently reads stale values, because the framework (Next.js, Vite, etc.) actually loads `.env.local`. Mid-session correction wastes an iteration and sometimes leaves an orphan `.env` that gets committed.

### Why it happens
Frameworks have layered precedence (`.env.local` > `.env.development` > `.env`), but agents default to the bare `.env` name unless told otherwise. The convention isn't discoverable from the file tree if `.env.local` is gitignored.

### Mitigation snippet
```markdown
## Local Development
- Secrets and local overrides live in `.env.local` (gitignored). Never create a plain `.env` file.
- `.env.example` is the template — copy it to `.env.local` and fill in values.
- When adding a new env var: update `.env.example`, document it in the PR, and reference it from code via a typed config module (no raw `process.env.X` in feature code).
```

## 2. Test mock isolation (module-level state leaking between tests)

### Symptom
Tests pass individually but fail when run as a suite. Or: a mock works on the first test and the second test sees the real implementation. Symptoms include "expected mock to be called" failures, stale singleton state, and env vars that mocks can't override because they were captured at import time.

### Why it happens
Modules are evaluated once per process. Anything read at the top level (env vars, config singletons, frozen registries) is captured before `beforeEach` mocks apply. `vi.resetModules()` reloads the module graph but invalidates any mock binding established with `vi.mock()` at the top of the file — the mock factory runs again with no reference to your spy.

### Mitigation snippet
```markdown
## Testing Conventions
- Do not call `vi.resetModules()` inside tests that use top-level `vi.mock()` — it breaks the mock binding.
- For modules that read env vars at import time: set the env var in `vitest.setup.ts` (or a per-test `vi.stubEnv`) before the import, not inside the test body.
- Prefer dependency injection over module-level singletons for anything you'll need to mock.
- Use `vi.importActual` + `vi.mock` with a factory when you need to replace a single export and keep the rest real.
- Co-locate mocks near the test that owns them; do not share mutable mock state across files.
```

## 3. Working-directory sensitivity for skill / config detection

### Symptom
A custom skill, slash command, or config file is silently ignored. The agent reports "skill not found" or falls back to default behavior, even though the file clearly exists in the repo. Often happens when an editor opened a parent folder, or when the agent was launched from `~` instead of the project root.

### Why it happens
Tools that read `.claude/`, `.vscode/`, `pyproject.toml`, `package.json`, etc. resolve them relative to the current working directory (or walk up from it). If the session starts above the project root, project-scoped configuration is invisible.

### Mitigation snippet
```markdown
## Working Directory
- Always launch sessions from the project root (the directory containing `.claude/`, `package.json`, or the equivalent manifest). Verify with `pwd` before invoking project-scoped skills.
- If a custom skill or slash command is "not found," first check `pwd` — do not assume the skill file is broken.
- When delegating to sub-agents, pass absolute paths for any file argument; do not rely on the sub-agent inheriting your cwd.
```

## 4. Git commit-signing config conflicts

### Symptom
`git commit` fails with a signing error mid-session, blocking every subsequent commit until diagnosed. Common forms: "gpg failed to sign the data," "error: cannot run ssh-keygen," or silent unsigned commits when signing was expected.

### Why it happens
Both `commit.gpgsign=true` and `gpg.format=ssh` (or a stale `user.signingkey` pointing at a missing GPG key) end up configured at different scopes (system, global, local). The agent picks up an inconsistent combination and can't tell which one is authoritative.

### Mitigation snippet
```markdown
## Git
- Commit signing for this project uses [SSH | GPG | none] — pick one and document it here.
- If `git commit` fails with a signing error, run `git config --show-origin --get-all commit.gpgsign` and `... gpg.format` before changing anything; resolve the conflict at the highest-precedence scope only.
- Do not pass `--no-verify` or `--no-gpg-sign` to bypass a real signing problem.
```

## 5. Package manager / version mismatch (corepack, pnpm, node versions)

### Symptom
`pnpm install` works but `pnpm test` fails parsing the config, or vice versa. CI passes but local fails (or the reverse). Lockfile churn appears in diffs after a routine install.

### Why it happens
Corepack ships a different `pnpm` shim than a globally installed `pnpm`, and the project's `packageManager` field in `package.json` may pin a version that neither matches. Node version drift (`.nvmrc` vs system Node) compounds this — some configs are parsed differently across Node majors.

### Mitigation snippet
```markdown
## Toolchain
- Package manager: [pnpm 9.x | npm 10.x | yarn 4.x] via corepack. Do not suggest alternatives.
- Node version is pinned in `.nvmrc` — run `nvm use` (or `fnm use`) before installing.
- If install/test commands behave inconsistently, run `which pnpm` and `corepack enable` before deeper debugging — version mismatch is the most likely cause.
- Never commit lockfile changes that result purely from a different package manager version.
```

## When to add your own

As you collect your own painful sessions — debugging loops where you, in retrospect, wish the agent had known one fact upfront — add a new section here. The pattern is always the same: **symptom** (what the user sees), **root cause** (one or two sentences of why), **CLAUDE.md snippet** (a self-contained block the next session can read without context). The point is not to document every bug; it's to capture the rules that, if known, would have made the bug a non-event.
