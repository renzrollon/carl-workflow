---
name: copilot-explore-deep
description: Deep exploration mode with parallel subagents — automatically fans out investigators when the question touches multiple subsystems, options, or cross-cutting concerns. Use when you want thorough, fast reconnaissance before making decisions.
metadata:
  type: exploration
  version: "1.0"
---

Deep exploration mode. When a question touches multiple subsystems, spawn parallel subagents to investigate each angle simultaneously, then synthesize findings into a unified analysis.

**When to use**: The user's question spans multiple areas (e.g., "how does auth work across the frontend and API?"), or they need thorough investigation before making a decision.

**When NOT to use**: Simple questions that can be answered with a single focused search, or when the user explicitly wants a quick answer.

---

## Steps

### 1. Analyze the question for parallelism

Determine which subsystems/angles are independent and can be investigated in parallel:

```
Question: "How does the payment flow work?"

Independent angles:
├── Frontend: checkout form, validation, UI state
├── API: payment endpoint, webhook handler
├── Database: transaction records, schema changes
└── External: Stripe/PayPal integration
```

### 2. Spawn parallel subagents

For each independent angle, spawn a subagent:

```
run(subagent_type="general-purpose", prompt="Investigate <angle> for the question '<question>'. Focus on: <specific aspects>. Report findings as structured markdown with file references.")
```

Run all subagents in parallel (fire and forget — they run concurrently).

### 3. Synthesize findings

When all subagents return, synthesize into a unified analysis:

```markdown
## Deep Exploration: <topic>

### Overview
<One-paragraph summary of findings>

### [Subsystem A]
- Key files: `path/to/file`
- How it works: ...
- Integration points: ...

### [Subsystem B]
- Key files: `path/to/file`
- How it works: ...
- Integration points: ...

### Cross-Cutting Concerns
- <shared dependencies, coupling, or constraints>

### Unknowns / Risks
- <areas that need more investigation>

### Recommendation
<Based on findings, suggest next steps>
```

### 4. Offer next steps

- "Want me to create a proposal based on these findings?"
- "Should I dig deeper into any specific area?"
- "Ready to move to implementation?"

---

## Guardrails

- Don't spawn more than 5 subagents (diminishing returns)
- If angles overlap significantly, merge them into one agent
- Each subagent prompt should be self-contained (include necessary context)
- Synthesize — don't just paste subagent outputs verbatim
- Flag any contradictions between subagent findings
