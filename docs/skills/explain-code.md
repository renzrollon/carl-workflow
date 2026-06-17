# explain-code

A teaching skill that explains TypeScript files in a Next.js App Router codebase to a frontend beginner — function breakdowns, cross-file call linking, API/data flows with infra services, and design pattern detection. It exists as a standalone skill because the explanation must build understanding sequentially across files and produces one coherent document, not parallelizable chunks.

## Purpose
Walk a beginner through `.ts`/`.tsx` files in `app/`, `lib/`, `components/`, `types/`, and `prisma/`, naming every external service call (PostgreSQL, S3, SQS, better-auth, external HTTP) and surfacing the React, TypeScript, and Next.js patterns in use.

## When to use
When a new contributor needs a guided tour of the codebase, or when you want a persistent reviewable artifact explaining how a directory or feature area works end to end.

## When to skip
Skip for code review, critique, or improvement suggestions — this skill teaches, it does not judge. Skip for test files, `node_modules`, generated files, and trivial boilerplate.

## Inputs
Optional `$ARGUMENTS` scoping the explanation to a directory or file. Otherwise the skill reads `docs/*.md` for domain context and walks all non-test source files.

## Outputs
A single Markdown document at `docs/CODE_EXPLANATION.md` (overwritten each run) plus a 5-10 line summary printed to the conversation.

## Dependencies
None — runs as a single-agent walkthrough with no subagents or workflows.

## Example invocations
- "Explain how `src/auth/middleware.ts` handles refresh tokens."
- "Walk me through the `app/api/v1/batches/` route handlers."
- "Explain the whole `lib/` directory to a frontend beginner."

## Source
`skills/explain-code/SKILL.md`
