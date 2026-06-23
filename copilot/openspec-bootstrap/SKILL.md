---
name: openspec-bootstrap
description: Bootstrap OpenSpec for a brownfield project — analyze existing codebase, produce an initial architecture doc and feature specs from what's already built. Use when onboarding a project with no existing specs.
license: MIT
compatibility: Requires openspec CLI. Best with workflow support for parallel subagents.
metadata:
  author: custom
  version: "1.0"
  type: discovery
---

Bootstrap OpenSpec specifications from an existing (brownfield) codebase.

**Purpose**: Analyze a project that has working code but no OpenSpec specs, and produce:
1. `openspec/initial-architecture.md` — a snapshot of the current architecture, patterns, and design decisions
2. `openspec/specs/<feature>/spec.md` — one spec per discovered feature/capability
3. Updated `openspec/config.yaml` — with discovered project context for future artifact generation

This gives future `/opsx:propose` and `/opsx:apply` iterations full awareness of what exists.

---

## When To Use

- First time setting up OpenSpec on an existing project
- Joining a codebase with no specs and needing a structured understanding
- Before the first OpenSpec change on a brownfield repo

---

## Input

**Arguments** (optional):
- `--quick` — Run a lighter analysis (single-agent sequential, good for small repos < 50 files)
- `--scope <path>` — Limit analysis to a subdirectory (e.g., `src/features/auth`)
- No arguments = full parallel workflow analysis

---

## Execution Modes

### Full Mode (default) — Parallel Subagent Workflow

Invoke via:
```
Workflow({ name: 'openspec-bootstrap', args: { scope: '.' } })
```

Spawns specialized exploration agents in parallel, synthesizes findings, then generates specs. Best for medium-to-large codebases where one pass would miss things.

The workflow script lives at `.claude/workflows/openspec-bootstrap.js`.

### Quick Mode (`--quick`) — Sequential Single-Context

Runs all exploration in the current context sequentially. Faster, cheaper, sufficient for small repos (< 50 source files, single domain). Does NOT invoke the Workflow tool — runs inline following the steps below.

---

## Steps

### 0. Pre-flight

```bash
# Ensure openspec is initialized
ls openspec/config.yaml 2>/dev/null || openspec init
```

Check if `openspec/specs/` already has content. If specs exist, warn the user:
> "This project already has N specs. Bootstrap will ADD new specs for undocumented features but won't overwrite existing ones. Continue?"

### 1. DISCOVER — Parallel Exploration

Spawn subagents (or run sequentially in `--quick` mode) to explore the codebase from multiple angles. Each agent returns structured JSON.

#### Agent: Structure Mapper
**Goal**: Map the file/directory layout, identify conventions, route structure.
```
Explore the project directory structure. Report:
- Top-level organization pattern (by feature, by layer, hybrid)
- Route/page structure (for web frameworks)
- Naming conventions observed (files, directories, exports)
- Key config files and what they configure
- Monorepo structure if applicable

Return as JSON: { organization, routes[], conventions[], configFiles[], monorepo: bool }
```

#### Agent: Dependency & Data Model Analyzer
**Goal**: Map external dependencies, internal module graph, and data layer.
```
Analyze the project's dependency graph and data model. Report:
- Key dependencies and their roles (ORM, auth, UI, state, testing)
- Internal module dependency flow (which layers import from which)
- Database schema / data models (Prisma, TypeORM, raw SQL, etc.)
- Entity relationships
- API client/SDK integrations

Return as JSON: { dependencies[], internalLayers[], dataModels[], entityRelationships[], integrations[] }
```

#### Agent: Pattern Extractor
**Goal**: Identify established architectural patterns and conventions.
```
Read the implementation code and identify recurring patterns. Report:
- Component patterns (HOCs, hooks, compound, render props, etc.)
- State management approach (context, stores, URL state, server state)
- Error handling patterns (boundaries, try/catch, Result types)
- Authentication/authorization patterns
- Data fetching patterns (server components, client fetch, actions, loaders)
- Testing patterns (what's tested, how, coverage approach)
- Code style patterns (functional vs class, named vs default exports, etc.)

Return as JSON: { componentPatterns[], stateManagement, errorHandling, auth, dataFetching, testing, codeStyle }
```

#### Agent: API & Interface Scanner
**Goal**: Map all external-facing interfaces (routes, actions, exports).
```
Find and catalog all public interfaces. Report:
- API routes/endpoints (REST, GraphQL, tRPC)
- Server Actions (Next.js) or equivalent mutation endpoints
- Shared schemas/validators (Zod, Yup, io-ts)
- Public module exports (barrel files, SDK surface)
- WebSocket/real-time endpoints
- CLI commands (if applicable)

Return as JSON: { apiRoutes[], serverActions[], schemas[], publicExports[], realtime[], cli[] }
```

#### Agent: Infrastructure & Config Reader
**Goal**: Map deployment, environment, and tooling configuration.
```
Analyze infrastructure and tooling configuration. Report:
- Build system and scripts (package.json scripts, Makefile, etc.)
- Environment variables used (from .env.example, code references)
- CI/CD configuration (GitHub Actions, GitLab CI, etc.)
- Deployment target (Vercel, Docker, AWS, etc.)
- Linting/formatting config (ESLint, Prettier, Biome)
- TypeScript configuration (strict mode, paths, etc.)

Return as JSON: { buildSystem, scripts[], envVars[], cicd, deployment, linting, typescript }
```

### 2. SYNTHESIZE — Architecture Document

A synthesis agent reads ALL Phase 1 outputs and produces `openspec/initial-architecture.md`:

```markdown
# Initial Architecture

> Auto-generated by openspec-bootstrap on {date}.
> This is a point-in-time snapshot, not a living document.

## Stack & Infrastructure

{technology stack, versions, deployment target}

## Project Organization

{directory layout pattern, key directories and their purpose}

## Architecture Overview

{high-level system diagram in ASCII}
{subsystem boundaries, data flow direction}

## Data Model

{entity relationship summary}
{key models and their relationships}

## Subsystems & Features

{table: subsystem | location | responsibility | key patterns}

## Established Patterns

### Component Architecture
{patterns discovered: server/client split, composition approach}

### Data Flow
{how data moves: fetching, mutations, caching, revalidation}

### State Management
{URL state, server state, client state — where each is used}

### Error Handling
{strategy: boundaries, error types, user-facing vs internal}

### Authentication & Authorization
{auth approach, permission model, middleware}

### Testing Strategy
{what's tested, frameworks used, coverage approach}

## API Surface

{routes, actions, schemas — summary table}

## Design Decisions (Inferred)

{key decisions that can be read from the code — with confidence tags}
- [EXTRACTED] Decision from explicit code comments/docs
- [INFERRED] Decision deduced from consistent patterns
- [AMBIGUOUS] Unclear intent — multiple patterns coexist

## Gaps & Risks

{things that look incomplete, inconsistent, or risky}
{features started but not finished}
{patterns that conflict with each other}
```

### 3. IDENTIFY FEATURES — Boundary Detection

From the synthesis, identify distinct features/capabilities that should each become a spec. Use these heuristics:

- **Route-based**: Each major route group or page = potential feature
- **Domain-based**: Each data model with CRUD operations = potential feature
- **Capability-based**: Cross-cutting concerns (auth, error handling, observability) = potential feature
- **Module-based**: Feature directories or barrel exports = potential feature

Produce a feature list for user confirmation:

```
Discovered N features to spec:
1. authentication — Login, register, session management
2. task-crud — Create, read, update, delete tasks
3. app-shell — Layout, navigation, route protection
...

Generate specs for all? Or select specific ones?
```

### 4. SPEC GENERATION — Parallel Per Feature

For each confirmed feature, spawn a subagent (or run sequentially in quick mode):

```
You are generating an OpenSpec spec for an EXISTING feature — documenting what IS built, not what SHOULD be built.

Feature: {name}
Architecture context: {relevant section from initial-architecture.md}
Source files: {file paths for this feature}

Read the implementation files and produce a spec following this template:

## Purpose
{What this feature does — one paragraph}

## Requirements

### Requirement: {requirement name}
{What the system does — use "SHALL" language, present tense, describing current behavior}

#### Scenario: {scenario name}
- **WHEN** {trigger condition}
- **THEN** {observable outcome}

Rules:
- Document CURRENT behavior, not aspirational
- Every requirement must be verifiable against the existing code
- Include edge cases you can observe in the code (error handling, validation, empty states)
- Use the Given/When/Then format for scenarios
- Tag any requirement where behavior is unclear: <!-- INFERRED: reason -->
```

### 5. UPDATE CONFIG

Update `openspec/config.yaml` with discovered project context:

```yaml
schema: spec-driven

context: |
  Tech stack: {discovered stack}
  Architecture: {one-line summary}
  Conventions: {key conventions}
  Domain: {project domain}

rules:
  proposal:
    - Reference openspec/initial-architecture.md for current-state context
    - Check existing specs before proposing overlapping features
  design:
    - Follow established patterns documented in initial-architecture.md
    - Justify deviations from existing patterns
  specs:
    - New specs must not contradict existing spec requirements
    - Use the same terminology as existing specs
```

### 6. FINAL REPORT

```
## Bootstrap Complete

Architecture: openspec/initial-architecture.md
Specs generated: N
  - {list of spec names}
Config updated: openspec/config.yaml

Existing specs preserved: {list if any}
Confidence: {HIGH if small/clear codebase, MEDIUM if large/complex, LOW if inconsistent patterns}

### Recommended Next Steps
1. Review initial-architecture.md — correct any misinterpretations
2. Review generated specs — mark any INFERRED requirements to verify
3. Run `openspec validate` to check spec structure
4. Use `/opsx:propose` for your next feature — it now has full context
```

---

## Subagent Orchestration (Full Mode)

Full mode invokes the `openspec-bootstrap` workflow (`.claude/workflows/openspec-bootstrap.js`):

```
Workflow({ name: 'openspec-bootstrap', args: { scope: args.scope || '.' } })
```

The workflow runs 5 phases:
1. **Discover** — 5 parallel sonnet agents explore structure, deps, patterns, API, infra
2. **Synthesize** — opus agent merges all findings into `initial-architecture.md`
3. **Identify** — opus agent detects feature boundaries (skips already-specced features)
4. **Spec** — pipeline of sonnet agents generates one spec per feature
5. **Finalize** — updates `config.yaml`, reports results

Model routing:
- Phase 1 agents: sonnet (exploration, structured output)
- Phase 2 synthesis: opus (cross-referencing, judgment calls)
- Phase 3 detection: opus (boundary judgment)
- Phase 4 agents: sonnet (template-following, per-feature)
- Phase 5: sonnet (file writing)

---

## Guardrails

- **Never overwrite existing specs** — Only generate specs for features that don't already have one
- **Never modify source code** — This is analysis only, no implementation
- **Tag confidence** — Use EXTRACTED/INFERRED/AMBIGUOUS tags so the user knows what to verify
- **Respect .gitignore** — Don't analyze node_modules, build output, etc.
- **Cap subagents** — Maximum 8 parallel agents in Phase 1, 12 in Phase 4 (even for large repos, batch)
- **Scope option** — If `--scope` is provided, limit all exploration to that path
- **Idempotent** — Running again should produce consistent results (skip already-specced features)

---

## Quick Mode Differences

When `--quick` is passed:
- No subagents — all exploration runs sequentially in main context
- Phase 1 collapses into: read tree, read package.json, scan key files (max 20)
- Phase 2 produces a shorter architecture doc (skip ASCII diagrams, shorter tables)
- Phase 4 generates specs sequentially (no parallel)
- Total: ~5 min for a small repo vs ~2 min per feature in full mode

---

## Integration with OpenSpec Workflow

After bootstrap:
- `/opsx:explore` can reference `initial-architecture.md` for grounding
- `/opsx:propose` sees specs from `openspec list --specs` — won't duplicate existing features
- `openspec instructions` pulls context from `config.yaml` — enriches all future artifact generation
- `/review-arch` can validate new designs against established patterns in architecture doc
