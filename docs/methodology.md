# The 7-Phase Workflow

## Why a workflow?

Ad-hoc prompt-driven coding feels fast in the moment, but it has predictable failure modes. Conversations drift as context grows. Decisions get made and immediately forgotten — the chat scrolls past them and the codebase carries no record. Diffs balloon because the model improvises while implementing, conflating what was asked for with what occurred to it mid-stream. By the time you go to review, the only artifact is the diff itself, with no companion document explaining intent, scope, or tradeoffs.

The thesis here is simple: AI collaboration becomes predictable when it is broken into a small number of phases, each with explicit inputs, explicit outputs, and a review gate where it makes sense. You don't get there by adding ceremony — you get there by separating *thinking* from *deciding* from *implementing*, and by writing down the artifacts of each step so the next step can read them.

The seven phases below are an opinionated take on that separation. They are durable: the artifacts they produce live in the repo as Markdown, not in chat history. They are reviewable: two gates catch the two distinct classes of error before they harden into bugs. And they are skippable: when a change is too small to warrant the full pipeline, the workflow steps out of the way.

## The seven phases

### 1. Bootstrap (one-time, brownfield only)

Greenfield projects skip this phase. For an existing codebase with no specs, `openspec-bootstrap` produces a snapshot of the current architecture and one spec per discovered feature, so future proposals start from a documented baseline rather than re-discovering the system from scratch each time.

### 2. Explore

`openspec-explore` is a thinking phase, not an implementing phase. The model investigates the codebase, asks clarifying questions, sketches options, and follows the conversation wherever it leads. The point is to understand the change before committing to one — what it touches, what's at stake, what's still ambiguous. The output is whatever clarity emerges, captured loosely.

### 3. Propose

`openspec-propose` turns that clarity into durable artifacts. It generates a proposal (the *what* and *why*), a design document (the *how*), delta specs (the requirements as Given/When/Then scenarios), and a task list (the implementation plan). These four files become the source of truth for everything downstream — review, implementation, and the eventual archive.

### 4. Review artifacts (gate 1)

Before any code is written, `review-artifacts` runs an architecture review and a QA review against the proposal. Architecture asks: are the design decisions sound, are the boundaries in the right place, does the approach fit the existing patterns? QA asks: do the specs have testable scenarios, are edge cases covered, does every feature task have a matching test task? Catching a wrong design here costs minutes; catching it after implementation costs hours.

### 5. Apply

`openspec-apply-change` walks the task list, reading every artifact first and checking off tasks as they complete. There are two paths:

- **Standard apply** is sequential and runs in the current conversation. This is the default — small changes don't benefit from anything more elaborate.
- **Wave apply** (`gsd-wave-apply`) groups independent tasks into waves and dispatches each wave to fresh-context subagents in parallel. Useful when a change has many tasks that don't depend on each other, and you want to avoid context bloat from running them all in one thread. Test waves run sequentially in the main context, where failures can share a root cause and the operator needs to iterate fixes.

### 6. Review code (gate 2)

`review-code` inspects the diff against the spec. The implementation reviewer checks task completion, type safety, language idioms, and test quality. A separate deploy-readiness reviewer runs only when the change touches infrastructure — new endpoints, new dependencies, new environment variables. Gate 2 catches what the spec couldn't anticipate: subtle bugs, mis-applied patterns, tests that pass for the wrong reason.

### 7. Archive

`openspec-archive-change` moves the change folder out of the active set into a dated archive directory, optionally syncing delta specs into the main spec corpus. The change becomes historical record; the specs become the new baseline that the next proposal will read.

## Why two review gates?

The two gates target different failure modes. Gate 1 catches *design* errors — wrong abstraction, missing scenarios, miscast boundaries — when fixing them means editing a Markdown file. Gate 2 catches *implementation* errors — type holes, broken hooks, missing auth checks — when the cost is a code edit but before the change is locked in by an archive. The cheapest bug is the one caught before the next phase begins; both gates exist because different bugs are visible at different moments.

## Skip rules

The gates are recommendations, not blockers. If the user says "skip review," "straight to apply," or "archive now," the workflow steps aside. Discipline by default; escape hatches when the change is too small to warrant ceremony or the operator has already done the equivalent review by hand.

## What this workflow is not

- Not a replacement for human review on important pull requests. Two automated gates catch a lot, but the final call on a load-bearing change still belongs to a person.
- Not a fork of the underlying agent harness — it's a methodology and a skill bundle that runs on top of a standard installation.
- Not opinionated about your stack. The phases work the same whether the codebase is Go, Python, Rust, TypeScript, or anything else `git` can track.

For a visual map of when to enter each phase and which gate to expect next, see [the decision tree](./decision-tree.md).
