---
name: copilot-bootstrap
description: Bootstrap OpenSpec for a brownfield project — analyze existing codebase, produce an initial architecture doc and feature specs from what's already built. Use when onboarding a project with no existing specs.
metadata:
  type: discovery
  version: "1.0"
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
run(subagent_type="general-purpose", prompt="Bootstrap OpenSpec for this project. Run 'openspec init' if needed, then analyze the codebase from multiple angles and generate initial-architecture.md and feature specs.")
```

Spawns specialized exploration agents in parallel, synthesizes findings, then generates specs. Best for medium-to-large codebases where one pass would miss things.

### Quick Mode (`--quick`) — Sequential Single-Context

Runs all exploration in the current context sequentially. Faster, cheaper, sufficient for small repos (< 50 source files, single domain). Does NOT invoke subagents — runs inline following the steps below.

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
- Key directories and their purposes
- Entry points and configuration files
```

#### Agent: Dependency Analyzer
**Goal**: Understand package dependencies, framework choices, external services.
```
Analyze package.json (or equivalent). Report:
- Frameworks and libraries in use
- Version constraints
- Potential conflicts or unusual combinations
- External service dependencies (databases, APIs, CDNs)
```

#### Agent: Pattern Spotter
**Goal**: Identify architectural patterns, conventions, and design decisions.
```
Scan source code for patterns. Report:
- State management approach
- API/data fetching patterns
- Error handling strategy
- Testing patterns
- Authentication/authorization patterns
```

### 2. SYNTHESIZE — Architecture Document

Using findings from all agents, create `openspec/initial-architecture.md`:

```markdown
# Initial Architecture: <project-name>

## Overview
<Brief description of what this project does>

## Stack
- **Language**: ...
- **Framework**: ...
- **Database**: ...
- **Testing**: ...

## Directory Structure
<Explain the organization pattern>

## Key Patterns
- <Pattern 1>: <description>
- <Pattern 2>: <description>

## External Dependencies
- <dependency>: <purpose>

## Known Constraints
- <constraint 1>
- <constraint 2>
```

### 3. DISCOVER — Feature Specs

For each major feature/capability discovered:

```bash
mkdir -p openspec/specs/<feature-name>
```

Create `openspec/specs/<feature-name>/spec.md`:

```markdown
# Spec: <feature-name>

## Purpose
<Why this capability exists>

## Requirements
### Requirement: <requirement-name>
The system SHALL <capability>.

#### Scenario: <scenario-name>
- **WHEN** <trigger>
- **THEN** <expected-result>
```

### 4. UPDATE — Config

Update `openspec/config.yaml` with discovered context:

```yaml
projectContext:
  stack: "<language>/<framework>"
  patterns: ["<pattern1>", "<pattern2>"]
  constraints: ["<constraint1>"]
```

### 5. REPORT

```
## Bootstrap Complete

**Project**: <name>
**Architecture doc**: openspec/initial-architecture.md
**Features discovered**: N
**Specs created**:
- specs/<feature1>/spec.md
- specs/<feature2>/spec.md

Next steps:
- Review the architecture doc for accuracy
- Run `/opsx:propose` to start making changes
```

---

## Guardrails

- Don't overwrite existing specs — append new ones
- If the project is very small (< 10 source files), recommend quick mode
- Always validate that `openspec init` succeeded before proceeding
- Ask user confirmation before creating feature specs (don't auto-generate from assumptions)
