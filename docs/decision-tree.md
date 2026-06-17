# Decision Tree

Companion to the methodology: pick the right skill for what's in front of you.

## Visual flow

```mermaid
flowchart TD
    Start([What are you trying to do?]) --> Q1{Brand-new repo,<br/>no specs yet?}

    Q1 -->|Yes| Bootstrap[openspec-bootstrap]
    Q1 -->|No| Q2{Reviewing<br/>someone else's<br/>work?}

    Q2 -->|GitLab MR| MR[gitlab-mr-review]
    Q2 -->|No| Q3{Need to<br/>understand<br/>before changing?}

    Q3 -->|Teach me this code| Explain[explain-code]
    Q3 -->|Investigate before designing| Q3a{Familiar<br/>territory?}
    Q3 -->|Already know enough| Q4{Designing a<br/>change?}

    Q3a -->|Yes| ExploreLite[openspec-explore]
    Q3a -->|Multi-subsystem or unfamiliar| ExploreDeep[openspec-explore-deep]

    Q4 -->|Yes| Propose[openspec-propose]
    Q4 -->|No| Q5{Implementing?}

    Propose --> Gate1{review-artifacts<br/>gate}
    Gate1 -->|Blockers| Propose
    Gate1 -->|Clean| Q5

    Q5 -->|Yes| Q6{How many<br/>independent<br/>tasks?}
    Q5 -->|No| Q7{Done<br/>implementing?}

    Q6 -->|Few, coupled| Apply[openspec-apply-change]
    Q6 -->|Many >5, parallel| Classify[gsd-classify-tasks]

    Classify --> Wave[gsd-wave-apply]
    Wave --> Commit[gsd-commit]

    Apply --> Q7
    Commit --> Q7

    Q7 -->|Yes| Gate2{review-code<br/>gate}
    Q7 -->|Mid-flight, context heavy| Handoff[gsd-context-handoff]

    Gate2 -->|Blockers| Q5
    Gate2 -->|Clean| Q8{Update specs<br/>now or later?}

    Q8 -->|Archive change<br/>and sync specs| Archive[openspec-archive-change]
    Q8 -->|Sync specs only,<br/>keep change open| Sync[openspec-sync-specs]
```

## When-to-use matrix

| Situation | Skill | Why | Doc |
|---|---|---|---|
| Adopting AI workflow on existing repo for first time | `openspec-bootstrap` | Generates initial-architecture + per-feature specs from working code so future proposals have context | [openspec.md](./skills/openspec.md) |
| Curious how an existing module works | `explain-code` | Teaching-mode walkthrough of files, functions, data flows, and infra calls | [explain-code.md](./skills/explain-code.md) |
| Investigating before designing a change | `openspec-explore` | Single-threaded thinking partner; reads code, asks questions, sketches options | [openspec.md](./skills/openspec.md) |
| Investigation spans multiple subsystems or unfamiliar territory | `openspec-explore-deep` | Fans out parallel investigators, synthesizes a single picture | [openspec.md](./skills/openspec.md) |
| Designing a feature, refactor, or bugfix | `openspec-propose` | Generates proposal + design + specs + tasks in one step | [openspec.md](./skills/openspec.md) |
| Validating a proposal before coding | `review-artifacts` | Architect + QA reviewers catch design and spec gaps before they cost rework | [review.md](./skills/review.md) |
| Implementing a small or coupled change | `openspec-apply-change` | Sequential, single-context loop through tasks.md | [openspec.md](./skills/openspec.md) |
| Implementing many independent tasks in parallel | `gsd-classify-tasks` then `gsd-wave-apply` | Classify dependencies, then run isolated subagents per wave | [gsd.md](./skills/gsd.md) |
| Validating a diff before archiving | `review-code` | TS/Frontend + DevOps reviewers catch quality and deploy-readiness issues | [review.md](./skills/review.md) |
| Single feature commit after wave execution | `gsd-commit` | Reads change artifacts to write a verb-phrase commit covering the whole wave | [gsd.md](./skills/gsd.md) |
| Preserving state before `/clear` | `gsd-context-handoff` | Writes a handoff doc so the next session resumes mid-change | [gsd.md](./skills/gsd.md) |
| Closing out a completed change | `openspec-archive-change` | Confirms completion, optionally syncs specs, moves change to archive | [openspec.md](./skills/openspec.md) |
| Updating canonical specs without archiving | `openspec-sync-specs` | Applies delta specs to main specs while change stays active | [openspec.md](./skills/openspec.md) |
| Reviewing a teammate's GitLab merge request | `gitlab-mr-review` | Posts a code summary to the MR and runs the standard reviewer pair | [gitlab-mr-review.md](./skills/gitlab-mr-review.md) |
| Need only one reviewer perspective | `review-arch` / `review-qa` / `review-ts` / `review-devops` | Single-persona variants for targeted feedback | [review.md](./skills/review.md) |

## Quick rules of thumb

- When you're not sure between `explore` and `explore-deep`, start with `explore`. Deep mode costs more tokens — reserve it for unfamiliar codebases or genuinely cross-cutting questions.
- If a task list has more than 5 items that don't share files, prefer `gsd-wave-apply`. Below that, the parallel overhead isn't worth it — `openspec-apply-change` is faster.
- Never skip `review-artifacts` on a proposal that touches auth, billing, schema migrations, or anything irreversible. Architecture mistakes are cheapest to fix here.
- Run the lighter skill first when in doubt — you can always escalate. Single-reviewer (`review-ts`) before full pair (`review-code`); `explore` before `explore-deep`; `apply-change` before reaching for waves.
- `gsd-commit` is the only commit step in the wave path. Wave-apply intentionally leaves changes uncommitted so one feature commit covers the whole change.
- `openspec-sync-specs` and `openspec-archive-change` both update main specs — pick `sync` when the change is still useful in flight, `archive` when it's done.
- If your context window is heavy mid-implementation, hand off with `gsd-context-handoff` before `/clear` rather than losing the thread.
