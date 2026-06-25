export const meta = {
  name: 'wave-apply',
  description: 'Execute OpenSpec tasks in dependency-ordered waves with inter-wave verification and cross-failure test analysis',
  whenToUse: 'When an OpenSpec change has 5+ independent tasks ready for parallel execution. Replaces the gsd-wave-apply skill with deterministic orchestration.',
  phases: [
    { title: 'Load', detail: 'Read change artifacts and parse task graph' },
    { title: 'Classify', detail: 'Assign tier/model/context per task' },
    { title: 'Execute', detail: 'Run implementation waves with inter-wave verification' },
    { title: 'Test', detail: 'Cross-failure analysis on test wave' },
    { title: 'Report', detail: 'Summarize results and offer commit' }
  ]
}

const TASK_SCHEMA = {
  type: 'object',
  properties: {
    tasks: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string', description: 'Task ID like 1.1, 2.3' },
          group: { type: 'integer', description: 'Wave group number' },
          description: { type: 'string' },
          files: { type: 'array', items: { type: 'string' } },
          tier: { type: 'integer', minimum: 1, maximum: 5 },
          model: { type: 'string', enum: ['haiku', 'sonnet', 'opus'] },
          isTestTask: { type: 'boolean' }
        },
        required: ['id', 'group', 'description', 'tier', 'model', 'isTestTask']
      }
    }
  },
  required: ['tasks']
}

const IMPL_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    taskId: { type: 'string' },
    status: { type: 'string', enum: ['success', 'partial', 'failed'] },
    filesChanged: { type: 'array', items: { type: 'string' } },
    summary: { type: 'string' },
    issues: { type: 'array', items: { type: 'string' } }
  },
  required: ['taskId', 'status', 'filesChanged', 'summary']
}

const VERIFY_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    passed: { type: 'boolean' },
    errors: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          message: { type: 'string' },
          fromThisWave: { type: 'boolean' }
        },
        required: ['file', 'message', 'fromThisWave']
      }
    },
    fixApplied: { type: 'boolean' },
    fixDescription: { type: 'string' }
  },
  required: ['passed', 'errors']
}

const TEST_RESULT_SCHEMA = {
  type: 'object',
  properties: {
    passed: { type: 'boolean' },
    failures: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          test: { type: 'string' },
          error: { type: 'string' },
          signature: { type: 'string', description: 'Error signature for clustering' }
        },
        required: ['file', 'error', 'signature']
      }
    },
    rootCauseClusters: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          signature: { type: 'string' },
          affectedFiles: { type: 'array', items: { type: 'string' } },
          likelyCause: { type: 'string' },
          fixDescription: { type: 'string' },
          resolved: { type: 'boolean' }
        },
        required: ['signature', 'affectedFiles', 'likelyCause', 'resolved']
      }
    }
  },
  required: ['passed', 'failures']
}

// --- Phase 1: Load ---
phase('Load')

const changeName = args || 'auto-detect'

const artifacts = await agent(
  `Load the OpenSpec change artifacts for: ${changeName}.

If "${changeName}" is "auto-detect", run \`openspec status --json\` to find the active change.

Read ALL of these files:
- openspec/changes/<name>/proposal.md
- openspec/changes/<name>/design.md
- openspec/changes/<name>/tasks.md
- Any spec files in openspec/changes/<name>/specs/

Return the full content of tasks.md and a summary of the design. Also detect the project's
verification commands by checking package.json scripts, Makefile, or common patterns.`,
  {
    label: 'load-artifacts',
    schema: {
      type: 'object',
      properties: {
        changeName: { type: 'string' },
        tasksContent: { type: 'string', description: 'Full content of tasks.md' },
        designSummary: { type: 'string', description: 'Key design decisions and architecture' },
        specsSummary: { type: 'string', description: 'Summary of spec scenarios' },
        verifyCommands: {
          type: 'object',
          properties: {
            typecheck: { type: 'string' },
            test: { type: 'string' },
            lint: { type: 'string' },
            build: { type: 'string' }
          }
        },
        projectType: { type: 'string', description: 'ts, python, go, rust, or other' }
      },
      required: ['changeName', 'tasksContent', 'designSummary', 'verifyCommands', 'projectType']
    }
  }
)

if (!artifacts) {
  log('Failed to load artifacts. Aborting.')
  return { status: 'failed', reason: 'artifact-load-failed' }
}

log(`Loaded change: ${artifacts.changeName} (${artifacts.projectType})`)

// --- Phase 2: Classify ---
phase('Classify')

const classified = await agent(
  `Parse and classify these OpenSpec tasks into a dependency graph with tier/model assignments.

Tasks content:
${artifacts.tasksContent}

Design context:
${artifacts.designSummary}

Classification rules:
- Tier 1 (sonnet): Single file, find-replace or rename
- Tier 2 (sonnet): Single file, add/modify section
- Tier 3 (sonnet): Single file, new logic/component
- Tier 4 (opus): Multi-file coordination
- Tier 5 (opus): Architecture, new patterns

Group tasks by their numbered section (1.x = group 1, 2.x = group 2, etc.).
The last numbered group containing test/verify tasks should have isTestTask=true.
Tasks within a group are independent (can parallelize).
Groups must execute sequentially (group 2 depends on group 1).

Identify the specific files each task will touch based on the design context.`,
  { label: 'classify-tasks', schema: TASK_SCHEMA }
)

if (!classified) {
  log('Failed to classify tasks. Aborting.')
  return { status: 'failed', reason: 'classification-failed' }
}

const implTasks = classified.tasks.filter(t => !t.isTestTask)
const testTasks = classified.tasks.filter(t => t.isTestTask)
const groups = [...new Set(implTasks.map(t => t.group))].sort((a, b) => a - b)

log(`Classified ${classified.tasks.length} tasks: ${implTasks.length} impl + ${testTasks.length} test across ${groups.length} waves`)

// --- Phase 3: Execute ---
phase('Execute')

const waveResults = []
let failedTasks = 0

for (const groupNum of groups) {
  const waveTasks = implTasks.filter(t => t.group === groupNum)
  log(`Wave ${groupNum}: executing ${waveTasks.length} tasks in parallel`)

  const results = await parallel(
    waveTasks.map(task => () =>
      agent(
        `Implement this specific task from an OpenSpec change.

TASK: ${task.id} — ${task.description}
FILES: ${(task.files || []).join(', ') || 'Determine from context'}
TIER: ${task.tier}

DESIGN CONTEXT:
${task.tier >= 3 ? artifacts.designSummary : '(minimal — tier ' + task.tier + ')'}
${task.tier >= 4 && artifacts.specsSummary ? '\nSPECS:\n' + artifacts.specsSummary : ''}

INSTRUCTIONS:
- Implement ONLY this specific task
- Do NOT modify files outside the task scope
- Run verification after changes if possible (${artifacts.verifyCommands.typecheck || 'typecheck'})
- Report: files changed, what was done, any issues encountered`,
        {
          label: `impl:${task.id}`,
          phase: 'Execute',
          model: task.model === 'opus' ? 'opus' : 'sonnet',
          schema: IMPL_RESULT_SCHEMA
        }
      )
    )
  )

  const waveResult = { group: groupNum, tasks: [] }
  for (let i = 0; i < waveTasks.length; i++) {
    const result = results[i]
    if (result) {
      waveResult.tasks.push(result)
      if (result.status === 'failed') failedTasks++
    } else {
      waveResult.tasks.push({ taskId: waveTasks[i].id, status: 'failed', filesChanged: [], summary: 'Agent returned null' })
      failedTasks++
    }
  }

  if (failedTasks > 2) {
    log(`More than 2 tasks failed in wave ${groupNum}. Halting.`)
    waveResults.push(waveResult)
    return { status: 'halted', reason: 'too-many-failures', waveResults, failedTasks }
  }

  // Inter-wave verification gate
  if (groupNum < Math.max(...groups)) {
    log(`Wave ${groupNum} complete. Running inter-wave verification...`)

    let verified = false
    for (let attempt = 0; attempt < 2 && !verified; attempt++) {
      const verifyResult = await agent(
        `Run verification after implementation wave ${groupNum}.

Commands to run (use whichever are available):
- Typecheck: ${artifacts.verifyCommands.typecheck || 'npx tsc --noEmit'}
- Lint: ${artifacts.verifyCommands.lint || 'npm run lint'}

Files changed this wave: ${waveResult.tasks.flatMap(t => t.filesChanged || []).join(', ')}

If verification fails:
1. Parse the errors
2. Determine if errors are from THIS wave (likely) or pre-existing
3. If from this wave: apply ONE targeted fix
4. Report whether the fix resolved it

This is attempt ${attempt + 1} of 2.`,
        {
          label: `verify:wave-${groupNum}:${attempt + 1}`,
          phase: 'Execute',
          schema: VERIFY_RESULT_SCHEMA
        }
      )

      if (verifyResult && verifyResult.passed) {
        verified = true
        log(`Wave ${groupNum} verification passed.`)
      } else if (verifyResult && verifyResult.fixApplied) {
        log(`Wave ${groupNum} verification: fix applied (attempt ${attempt + 1}), re-checking...`)
      } else {
        const newErrors = (verifyResult && verifyResult.errors || []).filter(e => e.fromThisWave)
        if (newErrors.length === 0) {
          verified = true
          log(`Wave ${groupNum}: errors are pre-existing, proceeding.`)
        }
      }
    }

    if (!verified) {
      log(`Wave ${groupNum} verification failed after 2 attempts. Checking if errors block next wave...`)
    }
  }

  waveResults.push(waveResult)
}

// --- Phase 4: Test ---
phase('Test')

if (testTasks.length > 0) {
  log(`Running test wave: ${testTasks.length} test tasks with cross-failure analysis`)

  const testResult = await agent(
    `Execute the test wave for OpenSpec change "${artifacts.changeName}" using two-pass cross-failure analysis.

TEST TASKS:
${testTasks.map(t => `- ${t.id}: ${t.description}`).join('\n')}

VERIFICATION COMMANDS:
- Typecheck: ${artifacts.verifyCommands.typecheck || 'npx tsc --noEmit'}
- Test: ${artifacts.verifyCommands.test || 'npm test'}
- Lint: ${artifacts.verifyCommands.lint || 'npm run lint'}
- Build: ${artifacts.verifyCommands.build || 'npm run build'}

STRATEGY — Two-Pass Cross-Failure Analysis:

Pass 1 (Discovery):
a. Write all test files first (for "Write tests" tasks)
b. Run the FULL verification suite in one pass
c. Collect ALL failures — do NOT stop at the first one
d. Group failures by error signature into root-cause clusters:
   - Same missing import → wrong path or missing export
   - Same type error → interface shape mismatch
   - Same fixture/setup → missing test setup
   - Same env/config → missing env var
   - Same assertion pattern → logic bug in shared function

Pass 2 (Fix by root cause, max 5 iterations):
1. Pick the root cause affecting the MOST failures
2. Apply ONE fix addressing the root cause
3. Re-run ONLY the affected test set
4. Remove resolved failures, continue to next cluster

After all root-cause iterations, run the full suite one final time.

IMPORTANT:
- Budget is 5 root-cause iterations TOTAL, not per file
- One fix can resolve failures across multiple test files
- Fix SOURCE code when the bug is in implementation, not in the test
- Do NOT commit anything — leave all changes unstaged`,
    {
      label: 'test-wave',
      model: 'opus',
      schema: TEST_RESULT_SCHEMA
    }
  )

  if (testResult) {
    const resolved = (testResult.rootCauseClusters || []).filter(c => c.resolved).length
    const total = (testResult.rootCauseClusters || []).length
    log(`Test wave: ${testResult.passed ? 'PASSED' : 'PARTIAL'} — ${resolved}/${total} root causes resolved`)
  }
} else {
  log('No test tasks found — skipping test wave.')
}

// --- Phase 5: Report ---
phase('Report')

const totalTasks = classified.tasks.length
const completedTasks = waveResults.reduce((sum, w) => sum + w.tasks.filter(t => t.status === 'success').length, 0)

log(`Complete: ${completedTasks}/${totalTasks} tasks succeeded, ${failedTasks} failed`)

return {
  status: failedTasks === 0 ? 'success' : 'partial',
  change: artifacts.changeName,
  totalTasks,
  completedTasks,
  failedTasks,
  waves: waveResults.length,
  waveResults
}
