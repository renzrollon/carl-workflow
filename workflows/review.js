export const meta = {
  name: 'review',
  description: 'Multi-dimensional code review with adversarial verification — fans out reviewers, then skeptics challenge each finding',
  whenToUse: 'After implementation, when you want a thorough review that filters false positives. Use instead of /review-code for high-stakes changes.',
  phases: [
    { title: 'Scope', detail: 'Identify changed files and review dimensions' },
    { title: 'Review', detail: 'Parallel reviewers examine code from different angles' },
    { title: 'Verify', detail: 'Adversarial agents challenge each finding' },
    { title: 'Synthesize', detail: 'Merge verified findings into final report' }
  ]
}

const FINDING_SCHEMA = {
  type: 'object',
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          severity: { type: 'string', enum: ['blocker', 'warning', 'suggestion'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          description: { type: 'string' },
          suggestion: { type: 'string' }
        },
        required: ['severity', 'file', 'title', 'description']
      }
    }
  },
  required: ['dimension', 'findings']
}

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    findingTitle: { type: 'string' },
    isReal: { type: 'boolean', description: 'true if the finding is a genuine issue' },
    confidence: { type: 'number', minimum: 0, maximum: 1 },
    reasoning: { type: 'string' },
    refinedSeverity: { type: 'string', enum: ['blocker', 'warning', 'suggestion', 'dismiss'] }
  },
  required: ['findingTitle', 'isReal', 'confidence', 'reasoning', 'refinedSeverity']
}

// --- Phase 1: Scope ---
phase('Scope')

const changeName = args || 'auto-detect'

const scope = await agent(
  `Identify the scope for code review.

If "${changeName}" is "auto-detect", check:
1. \`openspec status --json\` for an active change
2. \`git diff --stat\` for uncommitted changes
3. \`git diff HEAD~1 --stat\` for the last commit

Return the list of changed source files (skip lock files, config, artifacts).
Also determine which review dimensions are relevant:
- "typescript": Always include for .ts/.tsx/.js/.jsx files
- "architecture": Include if new modules, patterns, or structural changes
- "qa": Include if test files changed or new features added
- "devops": Include if env vars, deps, Dockerfiles, CI, or API routes changed
- "security": Include if auth, input handling, or sensitive data flows changed`,
  {
    label: 'scope',
    schema: {
      type: 'object',
      properties: {
        changeName: { type: 'string' },
        changedFiles: { type: 'array', items: { type: 'string' } },
        dimensions: { type: 'array', items: { type: 'string' } },
        diffSummary: { type: 'string', description: 'Brief summary of what changed' }
      },
      required: ['changedFiles', 'dimensions', 'diffSummary']
    }
  }
)

if (!scope || scope.changedFiles.length === 0) {
  log('No changed files found. Nothing to review.')
  return { status: 'skipped', reason: 'no-changes' }
}

log(`Reviewing ${scope.changedFiles.length} files across ${scope.dimensions.length} dimensions: ${scope.dimensions.join(', ')}`)

// --- Phase 2: Review ---
phase('Review')

const DIMENSION_PROMPTS = {
  typescript: `You are a senior TypeScript and React developer. Review these changed files for:
- Type safety: any types, unsafe casts, missing return types
- React patterns: hook deps, cleanup, Server/Client boundary, prop drilling
- Performance: unstable references, unnecessary re-renders
- Test quality: spec coverage, Testing Library queries, specific assertions
Be ruthlessly specific — file paths, line numbers, exact code.`,

  architecture: `You are a senior software architect. Review these changed files for:
- Boundary clarity: are module boundaries respected?
- Pattern fitness: do changes follow existing codebase patterns?
- Complexity: unnecessary abstraction? missing abstraction?
- Coupling: do changes create hidden dependencies between modules?
Be concrete — reference actual files and explain the architectural impact.`,

  qa: `You are a senior QA engineer. Review these changed files for:
- Missing test scenarios: what behaviors are untested?
- Edge cases: empty states, errors, boundaries, permissions
- Spec alignment: does the implementation match what specs describe?
- Regression risk: could these changes break existing behavior?
Be specific about what tests should exist but don't.`,

  devops: `You are a DevOps/infrastructure engineer. Review these changed files for:
- Environment: new env vars documented? No hardcoded secrets?
- Dependencies: justified? No duplicates? No vulnerabilities?
- Security: auth on new routes? Input validated? No sensitive data exposed?
- Build health: does this break the build? Bundle size impact?
Focus on deploy-readiness, not feature logic.`,

  security: `You are a security engineer. Review these changed files for:
- Authentication/authorization: proper checks on all paths?
- Input validation: sanitized before use? Injection vectors?
- Data exposure: sensitive data in logs, URLs, client bundles?
- OWASP Top 10: XSS, CSRF, broken access control, injection?
Be paranoid — assume adversarial input on every user-facing path.`
}

const reviewResults = await parallel(
  scope.dimensions.map(dim => () =>
    agent(
      `${DIMENSION_PROMPTS[dim] || 'Review these files for quality issues.'}

CHANGED FILES:
${scope.changedFiles.join('\n')}

DIFF SUMMARY:
${scope.diffSummary}

Read each changed file. Report findings with exact file paths and line numbers.
Only report genuine issues — not style preferences or nitpicks.
Classify each finding as: blocker (must fix), warning (should fix), or suggestion (could improve).`,
      {
        label: `review:${dim}`,
        phase: 'Review',
        schema: FINDING_SCHEMA
      }
    )
  )
)

const allFindings = reviewResults
  .filter(Boolean)
  .flatMap(r => r.findings.map(f => ({ ...f, dimension: r.dimension })))

log(`Found ${allFindings.length} findings across all dimensions`)

if (allFindings.length === 0) {
  log('Clean review — no findings.')
  return {
    status: 'clean',
    dimensions: scope.dimensions,
    filesReviewed: scope.changedFiles.length,
    findings: []
  }
}

// --- Phase 3: Verify ---
phase('Verify')

const blockersAndWarnings = allFindings.filter(f => f.severity === 'blocker' || f.severity === 'warning')
const suggestions = allFindings.filter(f => f.severity === 'suggestion')

log(`Adversarially verifying ${blockersAndWarnings.length} blockers/warnings (${suggestions.length} suggestions pass through)`)

const verified = await parallel(
  blockersAndWarnings.map(finding => () =>
    parallel([
      () => agent(
        `You are a skeptical code reviewer. Your job is to REFUTE this finding if possible.

FINDING: ${finding.title}
SEVERITY: ${finding.severity}
FILE: ${finding.file}${finding.line ? ':' + finding.line : ''}
DESCRIPTION: ${finding.description}
DIMENSION: ${finding.dimension}

Read the actual file and surrounding context. Try to prove this finding is:
- A false positive (the code is actually correct)
- Overstated (the severity should be lower)
- Missing context (there's a reason for the pattern)

Default to isReal=true if genuinely uncertain — don't dismiss real issues.
But DO dismiss findings that misread the code or ignore surrounding context.`,
        { label: `skeptic-1:${finding.file}`, phase: 'Verify', schema: VERDICT_SCHEMA }
      ),
      () => agent(
        `You are an independent code reviewer providing a second opinion on this finding.

FINDING: ${finding.title}
SEVERITY: ${finding.severity}
FILE: ${finding.file}${finding.line ? ':' + finding.line : ''}
DESCRIPTION: ${finding.description}
SUGGESTION: ${finding.suggestion || 'none provided'}

Read the actual file. Independently assess:
1. Is this a real issue? (not a false positive)
2. Is the severity correct? (or should it be higher/lower)
3. Is the suggested fix appropriate?

Be honest — confirm real issues, dismiss false ones.`,
        { label: `skeptic-2:${finding.file}`, phase: 'Verify', schema: VERDICT_SCHEMA }
      )
    ]).then(votes => {
      const validVotes = votes.filter(Boolean)
      const realCount = validVotes.filter(v => v.isReal).length
      const survives = realCount >= Math.ceil(validVotes.length / 2)
      const refinedSeverity = survives
        ? validVotes.find(v => v.isReal)?.refinedSeverity || finding.severity
        : 'dismiss'
      return { ...finding, survives, refinedSeverity, votes: validVotes }
    })
  )
)

const confirmedFindings = verified
  .filter(Boolean)
  .filter(f => f.survives)
  .map(f => ({ ...f, severity: f.refinedSeverity === 'dismiss' ? f.severity : f.refinedSeverity }))

const dismissedCount = verified.filter(Boolean).filter(f => !f.survives).length

log(`Verification complete: ${confirmedFindings.length} confirmed, ${dismissedCount} dismissed as false positives`)

// --- Phase 4: Synthesize ---
phase('Synthesize')

const finalFindings = [...confirmedFindings, ...suggestions]
const blockers = finalFindings.filter(f => f.severity === 'blocker')
const warnings = finalFindings.filter(f => f.severity === 'warning')
const suggs = finalFindings.filter(f => f.severity === 'suggestion')

log(`Final report: ${blockers.length} blockers, ${warnings.length} warnings, ${suggs.length} suggestions`)

return {
  status: blockers.length > 0 ? 'blockers-found' : warnings.length > 0 ? 'warnings-found' : 'clean',
  change: scope.changeName,
  filesReviewed: scope.changedFiles.length,
  dimensions: scope.dimensions,
  summary: {
    blockers: blockers.length,
    warnings: warnings.length,
    suggestions: suggs.length,
    dismissed: dismissedCount
  },
  findings: finalFindings,
  recommendation: blockers.length > 0
    ? 'Fix blockers before proceeding'
    : warnings.length > 0
      ? 'Address warnings, then proceed to archive'
      : 'Clean — proceed to /openspec-archive-change'
}
