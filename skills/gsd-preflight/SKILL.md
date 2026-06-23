---
name: gsd-preflight
description: Classify the session into a shape (plan-execute, structured-execute, investigate-propose, targeted-fix) and emit a constraint block that downstream skills consume. Fires automatically for producing actions via carl-dispatch.
metadata:
  type: utility
  version: "1.0"
---

Classify the incoming work into a session shape and load the appropriate execution template.

**Input**: User intent (from carl-dispatch) + pre-flight context (memory, handoff, openspec state)

**Why**: Expert-level sessions always start with explicit scope, correct orchestration strategy, and loaded constraints. This skill makes those three properties automatic for every producing session.

**When it fires**: carl-dispatch invokes this as an intermediary before producing skills (propose, apply, wave-apply, fix, explore-deep). Read-only skills (primer, explain, metrics, explore-light) skip preflight entirely.

**Steps**

1. **Classify session shape**

   Based on signals from carl-dispatch's pre-flight context:

   | Shape | Signals | Default Flow |
   |-------|---------|--------------|
   | **Plan-then-Execute** | No active change, user wants to build something new, scope spans multiple files/concepts | Explore → Propose → Review → Wave-apply |
   | **Structured Execute** | Active change with tasks, user says "apply", "do it", "execute" | Load artifacts → Classify tasks → Wave or sequential |
   | **Investigate-then-Propose** | User needs understanding before designing, question spans 3+ subsystems or has ambiguous scope | Explore-deep (fan-out) → Synthesize → Propose |
   | **Targeted Fix** | Specific bug, error message, or file mentioned, scope is narrow and clear | Load memory → Locate → Fix → Verify |

   Disambiguation rules:
   - If both "build new" AND "active change with tasks" → Structured Execute (artifacts already exist)
   - If "explore" intent but user said "then fix/build" → Investigate-then-Propose (not pure explore)
   - If task count is 1-2 and trivial → Targeted Fix (even if artifacts exist — skip ceremony)

2. **Set session scope**

   Compose a one-line scope statement from:
   - User's intent (what they said)
   - Active change name (if any)
   - Issue ref (if extracted from branch)

   Example: "Implement container security hardening tasks (RD-65) — 12 tasks across Dockerfile templates"

3. **Decide orchestration level**

   This is the critical decision that expert sessions always get right:

   | Condition | Orchestration | Reasoning |
   |-----------|--------------|-----------|
   | Task count >= 5 AND tasks are independent (no sequential deps) | Wave-apply (multi-agent parallel) | Parallel saves wall-clock time |
   | Question spans 3+ subsystems or modules | Explore-deep (fan-out 3-5 agents) | Each subsystem investigated independently |
   | Task count 2-4 with dependencies between them | Sequential apply (single-thread) | Dependencies require ordered execution |
   | Single file or concept, clear fix | Direct (no orchestration) | Overhead of coordination exceeds benefit |
   | 2-5 independent pieces, no OpenSpec artifacts | Fan-out (gsd-fan-out) | Parallelism without full spec lifecycle |

4. **Emit constraint block**

   Output the classification as a structured block that the downstream skill reads:

   ```
   ## Preflight

   **Shape:** <shape>
   **Scope:** <one-line scope statement>
   **Orchestration:** <single-thread | fan-out N agents | wave-apply | explore-deep>
   **Constraint sources loaded:**
   - memory.md: <N relevant entries> 
   - handoff: <yes/no — summary if yes>
   - artifacts: <list if available>
   **Task tracking:** <required | optional>
   ```

5. **Pass control** to the target skill with the constraint block as prefix context.

**Guardrails**
- Total preflight output: under 10 lines. This is classification, not exploration.
- NEVER modify files — this is read-only classification.
- If classification is ambiguous, default to the simpler shape (targeted-fix > investigate, sequential > wave-apply).
- If user explicitly names a skill, skip classification — just load constraints and pass through.
- Do NOT add ceremony to trivial tasks. If the user's request is a single line edit or quick question, skip preflight entirely (carl-dispatch handles this via read-only skill routing).
