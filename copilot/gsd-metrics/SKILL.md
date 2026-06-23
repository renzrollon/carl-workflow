---
name: gsd-metrics
description: Summarize execution metrics from .claude/metrics/*.json. Shows aggregated stats across changes — task counts, model distribution, test iterations, durations — and highlights outliers for tier tuning.
metadata:
  type: analysis
  version: "1.0"
---

Summarize GSD wave execution metrics across all recorded changes.

**Input**: None (reads all metrics files), or a specific change name to filter

**Steps**

1. **Load metrics files**

   ```bash
   ls .claude/metrics/*.json 2>/dev/null
   ```

   If no files found, report: "No metrics recorded yet. Run `/gsd-wave-apply` to generate execution metrics."

   Read each JSON file. Expected schema (from `gsd-wave-apply` step 10):
   ```json
   {
     "change": "<name>",
     "timestamp": "<ISO-8601>",
     "execution": { "totalTasks", "completedTasks", "failedTasks", "waves": [...], "testWave": {...} },
     "duration": { "totalSeconds", "perWave": [...] },
     "commit": { "hash", "subject", "filesChanged", "insertions", "deletions" }
   }
   ```

2. **Compute aggregates**

   Across all changes:
   - Total changes recorded
   - Total tasks executed / completed / failed
   - Average tasks per wave
   - Model distribution: % sonnet vs % opus across all waves
   - Average test wave iterations (rootCauseIterations)
   - Average duration per change (totalSeconds)
   - Average files changed per commit

3. **Show per-change breakdown**

   ```
   ## GSD Metrics Summary

   | Change | Date | Tasks | Waves | Models (S/O) | Test Iters | Duration | Commit |
   |--------|------|-------|-------|--------------|------------|----------|--------|
   | create-tasks-page | 2024-03-15 | 12/12 | 4 | 8/4 | 2 | 340s | a1b2c3d |
   | fix-session-expiry | 2024-03-16 | 5/5 | 2 | 5/0 | 0 | 120s | e4f5g6h |

   ### Aggregates
   - Changes: 2
   - Tasks: 17 total, 17 completed, 0 failed
   - Avg tasks/wave: 4.3
   - Model split: 76% sonnet, 24% opus
   - Avg test iterations: 1.0
   - Avg duration: 230s
   ```

4. **Highlight outliers**

   Flag any change where:
   - Failed tasks > 0 → "⚠️ <change>: N tasks failed"
   - Test iterations ≥ 4 (out of 5 budget) → "⚠️ <change>: high test churn (N/5 iterations)"
   - Duration > 2× average → "⚠️ <change>: unusually slow (Ns vs avg Ns)"
   - Opus usage > 60% → "💡 <change>: heavy opus usage — check if tier 4-5 classification is too aggressive"

5. **Suggest tuning** (if patterns emerge)

   Based on the data:
   - If opus % is high across all changes → "Consider loosening tier 4 threshold — many tasks may work at tier 3 with sonnet"
   - If test iterations are consistently high → "Test wave is burning budget — consider pre-validating interfaces between waves more aggressively"
   - If avg duration is growing over time → "Changes are getting larger — consider breaking proposals into smaller scopes"

**Output**

Display the full summary table, aggregates, outliers, and any tuning suggestions. Keep it scannable — this is a retrospective tool, not a blocker.
