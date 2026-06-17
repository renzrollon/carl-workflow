# gitlab-mr-review

Summarize and review a GitLab Merge Request by spawning two parallel subagents — one writes a structured code summary and posts it to the MR description, the other performs a structured code review on the diff. GitLab-specific: for GitHub-only users this skill is N/A.

## Purpose
Automate the two highest-leverage MR tasks — summarization and review — in a single invocation, with the summary persisted back to GitLab so reviewers see it inline.

## When to use
When you want a structured summary plus deploy-readiness review of a GitLab MR. Useful before requesting review, when triaging an unfamiliar MR, or to update an MR description that drifted from the diff.

## When to skip
For GitHub PRs (use a GitHub equivalent). For local uncommitted changes use `/review-code` instead — this skill operates on MR diffs, not the working tree.

## Inputs
An MR identifier in one of three forms: an MR number (`!123` or `123`), a full MR URL, or omitted (in which case the skill detects the current branch's open MR via `glab mr view`).

## Outputs
A combined report containing the generated MR summary (also appended to the MR description on GitLab with a Claude attribution footer) and a two-reviewer code review with blockers, warnings, suggestions, and an approve/request-changes/discuss recommendation.

## Dependencies
The `glab` CLI — used for `glab mr view`, `glab mr diff`, and `glab mr update --description`. The summary subagent appends to the existing description rather than replacing it.

## Example invocations
- `/gitlab-mr-review !1234`
- `/gitlab-mr-review 1234`
- `/gitlab-mr-review https://gitlab.example.com/group/project/-/merge_requests/1234`
- `/gitlab-mr-review` (auto-detects MR on current branch)

## Source
`skills/gitlab-mr-review/SKILL.md`
