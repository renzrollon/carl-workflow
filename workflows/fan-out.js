export const meta = {
  name: 'fan-out',
  description: 'Lightweight parallel execution for ad-hoc tasks without OpenSpec ceremony',
  whenToUse: 'When the user has 2-5 independent, file-disjoint tasks that do not need a full OpenSpec change. Replaces the gsd-fan-out skill with deterministic orchestration.',
  phases: [
    { title: 'Decompose', detail: 'Break goal into independent subtasks' },
    { title: 'Execute', detail: 'Run subtasks in parallel' },
    { title: 'Verify', detail: 'Check combined result' }
  ]
}

const DECOMPOSITION_SCHEMA = {
  type: 'object',
  properties: {
    goal: { type: 'string' },
    subtasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          description: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          verification: { type: 'string' }
        },
        required: ['id', 'description', 'files', 'verification']
      },
      minItems: 2,
      maxItems: 5
    },
    canParallelize: { type: 'boolean', description: 'false if tasks have file overlap or dependencies' },
    reason: { type: 'string', description: 'Why parallelization is/isnt safe' }
  },
  required: ['goal', 'subtasks', 'canParallelize']
}

const SUBTASK_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    subtaskId: { type: 'integer' },
    status: { type: 'string', enum: ['success', 'partial', 'failed'] },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    verificationPassed: { type: 'boolean' }
  },
  required: ['subtaskId', 'status', 'filesChanged', 'summary', 'verificationPassed']
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    passed: { type: 'boolean' },
    errors: { type: 'array', items: { type: 'string' } },
    fixApplied: { type: 'boolean' },
    fixDescription: { type: 'string' }
  },
  required: ['passed', 'errors']
}

// --- Phase 1: Decompose ---
phase('Decompose')

const goal = args || 'no goal provided'

const decomposition = await agent(
  `Decompose this goal into 2-5 independent, file-disjoint subtasks for parallel execution.

GOAL: ${goal}

Rules:
- Each subtask must touch DIFFERENT files (zero overlap between agents)
- Each subtask must NOT depend on another subtask's output
- Each subtask must be completable in isolation
- Each subtask needs a clear verification condition

If the work CANNOT be cleanly decomposed (shared state, sequential dependencies,
design decisions needed), set canParallelize=false and explain why.

Examine the codebase to identify the actual files each subtask will touch.
Verify there is no file overlap between subtasks.`,
  { label: 'decompose', schema: DECOMPOSITION_SCHEMA }
)

if (!decomposition) {
  log('Failed to decompose goal. Aborting.')
  return { status: 'failed', reason: 'decomposition-failed' }
}

if (!decomposition.canParallelize) {
  log(`Cannot parallelize: ${decomposition.reason}`)
  return {
    status: 'cannot-parallelize',
    reason: decomposition.reason,
    suggestion: 'Use /openspec-apply-change for coupled changes or /openspec-propose if design decisions are needed'
  }
}

log(`Decomposed into ${decomposition.subtasks.length} independent subtasks`)

// --- Phase 2: Execute ---
phase('Execute')

const results = await parallel(
  decomposition.subtasks.map(task => () =>
    agent(
      `Implement this subtask:

TASK: ${task.description}
FILES: ${task.files.join(', ')} — ONLY modify these files
VERIFICATION: ${task.verification}

Instructions:
- Implement ONLY the described subtask
- Stay within the listed files — do NOT touch other files
- Run verification after changes: ${task.verification}
- Report: what was done, files changed, verification result`,
      {
        label: `task:${task.id}`,
        phase: 'Execute',
        schema: SUBTASK_RESULT_SCHEMA
      }
    )
  )
)

const succeeded = results.filter(Boolean).filter(r => r.status === 'success').length
const failed = results.filter(Boolean).filter(r => r.status === 'failed').length

log(`Execution complete: ${succeeded} succeeded, ${failed} failed`)

// --- Phase 3: Verify ---
phase('Verify')

const allChangedFiles = results
  .filter(Boolean)
  .flatMap(r => r.filesChanged)

let verificationPassed = false

for (let attempt = 0; attempt < 2 && !verificationPassed; attempt++) {
  const verifyResult = await agent(
    `Run project-level verification after parallel fan-out execution.

Files changed: ${allChangedFiles.join(', ')}

Run whichever verification commands are available for this project:
- TypeScript: npx tsc --noEmit
- Tests: npm test (or equivalent)
- Lint: npm run lint (or equivalent)

If verification fails:
- Identify which subtask's output caused the failure
- Apply ONE targeted fix
- Report whether the fix resolved it

This is attempt ${attempt + 1} of 2.`,
    {
      label: `verify:${attempt + 1}`,
      schema: VERIFY_SCHEMA
    }
  )

  if (verifyResult && verifyResult.passed) {
    verificationPassed = true
    log('Project-level verification passed.')
  } else if (verifyResult && verifyResult.fixApplied) {
    log(`Verification fix applied (attempt ${attempt + 1}), re-checking...`)
  }
}

if (!verificationPassed) {
  log('Verification failed after 2 attempts. Manual intervention needed.')
}

return {
  status: verificationPassed ? 'success' : 'partial',
  goal: decomposition.goal,
  subtasks: results.filter(Boolean),
  succeeded,
  failed,
  verificationPassed
}
