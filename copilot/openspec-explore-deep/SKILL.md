---
name: openspec-explore-deep
description: Deep exploration mode with parallel subagents — automatically fans out investigators when the question touches multiple subsystems, options, or cross-cutting concerns. Use when you want thorough, fast reconnaissance before making decisions.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.4.0"
---

Deep explore mode. Think deeply. Fan out when breadth is needed. Synthesize into clear understanding.

**IMPORTANT: Explore mode is for thinking, not implementing.** You may read files, search code, and investigate the codebase, but you must NEVER write code or implement features. If the user asks you to implement something, remind them to exit explore mode first and create a change proposal. You MAY create OpenSpec artifacts (proposals, designs, specs) if the user asks—that's capturing thinking, not implementing.

---

## The Stance

Everything from standard explore mode applies — curious, visual, adaptive, patient, grounded. The difference is **depth and speed**: when a question is broad enough, you fan out parallel investigators rather than sequentially reading one file at a time.

---

## When to Fan Out (Automatic Decision)

You decide whether to use subagents based on these signals. **Fan out** when:

| Signal | Example |
|--------|---------|
| Multiple subsystems touched | "How does deployment work end-to-end?" |
| Comparative analysis needed | "Should we use Redis or SQLite for this?" |
| Cross-file tracing required | "What validates the uploaded zip?" |
| Multiple options to research | "What are our options for real-time?" |
| Cross-project validation | "Does this pattern hold in the second app?" |
| Architecture mapping | "Map how auth flows through the system" |

**Stay single-threaded** when:

| Signal | Example |
|--------|---------|
| Conversational back-and-forth | "What do you think about X?" |
| Single-file question | "What does this function do?" |
| Quick clarification | "Is this component server or client?" |
| Sequential discovery (A informs B) | "Now that we see that, what about..." |
| User is thinking out loud | Iterative refinement, not investigation |

When in doubt, start single-threaded and escalate to fan-out when you realize the question is broader than it seemed.

---

## Fan-Out Patterns

### Pattern 1: Subsystem Mapping

When the user asks about something that spans multiple parts of the codebase.

```
USER: How does project deployment work end-to-end?

YOU (thinks): This crosses upload → validation → GitLab → Northflank → build.
    Fan out 4 investigators.

SUBAGENTS (parallel):
  → Agent 1: "Trace the file upload and ZIP validation path"
  → Agent 2: "Trace the GitLab repo creation and push flow"  
  → Agent 3: "Map the Northflank service/build configuration"
  → Agent 4: "Trace environment/secrets handling during deploy"

YOU (synthesizes findings into diagram + narrative):

  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │  Upload  │───▶│ Validate │───▶│  GitLab  │───▶│Northflank│
  │  (ZIP)   │    │  (rules) │    │  (push)  │    │ (build)  │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘
       │               │               │               │
  multipart       framework       repo create      Dockerfile
  size limits     detection       CI config        env inject

  Here's how it all connects. Which layer do you want to dig into?
```

### Pattern 2: Comparative Research

When the user needs to evaluate options or approaches.

```
USER: What are our options for handling background jobs?

YOU (thinks): Multiple viable approaches, each with different tradeoffs.
    Fan out one agent per option.

SUBAGENTS (parallel):
  → Agent 1: "Research BullMQ — features, setup complexity, scaling"
  → Agent 2: "Research pg-boss — features, Postgres-native approach"
  → Agent 3: "Research Inngest — serverless, event-driven approach"
  → Agent 4: "Check current codebase for existing queue/job patterns"

YOU (synthesizes into comparison table):

                 BullMQ        pg-boss       Inngest
  ─────────────────────────────────────────────────────
  Infra needed   Redis ✗       Postgres ✓    Cloud svc ✗
  Complexity     Medium        Low           Low
  Retry/DLQ      Built-in      Built-in      Built-in
  Our stack fit  Extra dep     Uses our DB   Vendor lock
  Observability  Bull Board    pg queries    Dashboard

  Given we already have Postgres and want to minimize infra...
```

### Pattern 3: Cross-Cutting Trace

When the user wants to understand how a concept flows across the codebase.

```
USER: What validates the uploaded zip file?

YOU (thinks): Validation likely happens at multiple layers.
    Fan out by layer.

SUBAGENTS (parallel):
  → Agent 1: "Find client-side upload validation (size, type checks)"
  → Agent 2: "Find API route validation (middleware, request parsing)"
  → Agent 3: "Find business logic validation (ZIP contents, framework detection)"
  → Agent 4: "Find any post-upload validation (build-time checks, Northflank)"

YOU (synthesizes): Here's every validation layer, what it catches, and where gaps exist.
```

### Pattern 4: Impact Analysis

When the user wants to understand what a change would affect.

```
USER: What would break if we changed the project schema?

SUBAGENTS (parallel):
  → Agent 1: "Find all Prisma queries that reference Project model"
  → Agent 2: "Find all API routes that return/accept project data"
  → Agent 3: "Find all frontend components that consume project data"
  → Agent 4: "Find all tests that fixture or mock project data"

YOU (synthesizes): Impact map with severity per area.
```

---

## Subagent Instructions

When spawning subagents, follow these rules:

1. **Each agent gets a focused, specific prompt** — not "explore everything about X" but "trace the exact flow of Y through files A, B, C"
2. **Agents are read-only investigators** — they search, read, and report. They never write code.
3. **Each agent returns structured findings** — key files, code paths, important details, and open questions they couldn't resolve.
4. **Use 2-5 agents** — fewer than 2 isn't a fan-out, more than 5 means your decomposition is too granular.
5. **Label agents clearly** — so progress is visible to the user.
6. **Use the Explore agent type** (`subagent_type: "Explore"`) for read-only investigation tasks.

### Agent Prompt Template

Each subagent prompt should include:

```
Investigate: [specific question]

Context: [why we're looking at this — the broader exploration topic]

Look for:
- [specific thing 1]
- [specific thing 2]
- [specific thing 3]

Report back:
- Key files found (with paths and line numbers)
- How it works (brief explanation)
- Connections to other systems
- Open questions or gaps you noticed
```

---

## Synthesis Phase

After subagents return, you MUST synthesize — never just dump raw agent output. Synthesis means:

1. **Merge overlapping findings** — agents may discover the same files from different angles
2. **Build a unified diagram** — show how the pieces connect
3. **Identify gaps** — what did no agent find? What's still unclear?
4. **Surface contradictions** — if agents found conflicting information, highlight it
5. **Offer direction** — based on the full picture, what's interesting to explore next?

The synthesis should feel like a senior engineer who just talked to 4 specialists and is briefing you on what they learned.

---

## OpenSpec Awareness

Same as standard explore mode:

### Check for context at the start

```bash
openspec list --json
```

### When a change exists

1. Read existing artifacts for context via `openspec status --change "<name>" --json`
2. Reference artifacts naturally in conversation
3. Offer to capture decisions when they crystallize

### Capture Offers

| Insight Type | Where to Capture |
|---|---|
| New requirement discovered | `specs/<capability>/spec.md` |
| Requirement changed | `specs/<capability>/spec.md` |
| Design decision made | `design.md` |
| Scope changed | `proposal.md` |
| New work identified | `tasks.md` |
| Assumption invalidated | Relevant artifact |

---

## Full Session Example

```
USER: /openspec-explore-deep
      How does our build system handle different package managers?

YOU: Good question — this likely touches multiple layers. Let me fan out
     investigators across the build pipeline.

     ┌─ INVESTIGATING ─────────────────────────────────────────┐
     │  → Agent 1: Package manager detection logic             │
     │  → Agent 2: Dockerfile generation / build commands      │
     │  → Agent 3: Northflank build configuration              │
     │  → Agent 4: CI/CD pipeline integration                  │
     └─────────────────────────────────────────────────────────┘

[agents complete]

YOU: Here's the full picture:

     ┌─────────────────────────────────────────────────────────┐
     │              PACKAGE MANAGER FLOW                        │
     └─────────────────────────────────────────────────────────┘

          Detection               Build                Deploy
     ┌──────────────┐      ┌──────────────┐      ┌──────────┐
     │ Lock file?   │─────▶│  Dockerfile  │─────▶│Northflank│
     │ package.json │      │  generation  │      │  build   │
     │ engines field│      │              │      │          │
     └──────┬───────┘      └──────┬───────┘      └────┬─────┘
            │                     │                    │
       ┌────┼────┐           ┌────┼────┐          uses Docker
       ▼    ▼    ▼           ▼    ▼    ▼          multistage
      npm  pnpm yarn       npm   pnpm  yarn
                           install install install

     Key findings:
     • Detection: checks lock files first, falls back to engines field
     • Build: Dockerfile template switches install command per manager
     • Gap: yarn berry (PnP mode) not handled — would fail silently
     • Gap: no workspace detection for monorepos

     Interesting threads:
     1. The yarn berry gap — is that a real risk for your users?
     2. Monorepo support — do any current projects use workspaces?
     3. The detection priority — should engines field override lock file?

     Which thread interests you?

USER: The yarn berry gap — we had a user hit that last week.

YOU: [continues single-threaded, conversationally — no need to fan out
     for a focused follow-up question]
```

---

## What You Don't Have To Do

- Fan out for every question (most follow-ups are conversational)
- Use exactly 4 agents (use 2-5 based on the question's breadth)
- Follow a rigid pattern (adapt the fan-out shape to the question)
- Produce a specific artifact
- Reach a conclusion
- Be brief (this is deep thinking time)

---

## Ending Deep Exploration

Same as standard explore mode — no required ending. But because deep exploration surfaces more information faster, you'll often reach decision points sooner:

- "This feels solid enough for a proposal. Want me to create one?"
- "We found 3 gaps. Want to explore any of them deeper?"
- "The comparison is clear — [option] wins for your constraints."

---

## Guardrails

- **Don't implement** — Never write code. OpenSpec artifacts are fine, application code is not.
- **Don't fan out unnecessarily** — Single-threaded conversation is fine for follow-ups
- **Don't dump raw agent output** — Always synthesize into a coherent picture
- **Don't use more than 5 agents** — If you need more, your decomposition is wrong
- **Do decide autonomously** — Don't ask "should I fan out?" — just do it when the signals are there
- **Do visualize** — Synthesis diagrams are mandatory for subsystem mapping
- **Do label progress** — Show the user what's being investigated while agents run
- **Do ground in code** — Agents should find actual files and line numbers, not theorize
