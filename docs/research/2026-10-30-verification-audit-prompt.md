# Verification Audit — Prompt

The prompt given to `/mono` on 2026-10-30. The resulting report: [2026-10-30-verification-audit.md](2026-10-30-verification-audit.md).

```text
Audit the current agent setup (all prompts, skills, rules, AGENTS.md / CLAUDE.md, scripts, CLI tools, and CI/verification harness in this repo) against two principles. Read every file before judging. Do not change anything; produce a report only.

PRINCIPLE 1: Verification closes the loop.
An agent workflow is a loop only if the agent can (a) act, (b) observe the real result itself, (c) compare it with an explicit goal, (d) revise, without a human relaying evidence.
For each skill/prompt/workflow, answer:
1. Goal: Does it state a concrete pass/fail criterion (command + expected output, metric threshold, UI behavior)? Or only vague intent ("make it better", "fix the bug")?
2. Observation: What tools let the agent see the actual outcome (run the app, drive the UI, read logs/traces/console, snapshots, perf profiles, DB state)? Which outcomes can it NOT observe and must ask a human about?
3. Comparison: Is there an explicit step that puts evidence next to the goal and decides keep/revert/retry? Or does it end at "tests pass" / "done"?
4. Test quality: Flag tautological tests (restate the implementation, can't fail on real regressions), tests that never exercise user-facing behavior, and checks that are green by default.
5. Hill-climbing readiness: Where a score/rubric exists (perf, bundle size, error count), can the agent iterate against it automatically?
6. Human-as-adapter: List every place where a human currently copies information between the agent and a tool (DevTools, dashboards, logs, Slack, staging).

PRINCIPLE 2: Move repeatable mechanics out of the agent's judgment path.
Agents should spend judgment on what evidence matters and how to respond; scripts should do steps whose correct execution is known in advance.
For each skill/prompt, answer:
1. Mechanics in prose: Find instructions that describe deterministic step sequences in words (start server, log in, navigate, click, capture, parse, format, migrate N files) that every agent re-implements. Quote them.
2. Reinvention: Evidence (from instructions, past transcripts, or scripts directory) that agents repeatedly build throwaway drivers, scrapers, setup scripts, or one-off migration scripts.
3. Existing tools: Which mechanical steps already have a tested script/CLI? Are skills pointing to them, or duplicating them in prose?
4. Codemod opportunities: Repetitive code changes that should be AST transforms/codemods first, leaving only ambiguous cases to the agent.
5. Skill shape: Is each skill a thin guide around stable tools (when to use, how to read evidence), or a long recipe the model must execute by hand? Flag bloated skills.
6. Consistency risk: Where would two agents following the same instructions likely get different results?

OUTPUT FORMAT
A. Scorecard table: one row per skill/prompt/workflow; columns: Goal explicit (Y/N), Agent can observe (Y/partial/N), Compare step (Y/N), Mechanics scripted (Y/partial/N), Top issue.
B. Top 5 gaps ranked by (frequency of use × cost of failure), each with: file path + quoted evidence, why it breaks the loop or wastes judgment, concrete fix (exact script/CLI to add with its interface `name args -> output`, or exact text to delete/rewrite in the skill).
C. Proposed shared verification tool: one CLI spec (commands, args, JSON output schema) that would cover the most common observation needs found above.
D. Quick wins (< 1 hour each) vs. structural changes.
E. Unknowns: anything you could not verify from the files; say so, do not guess.

Rules: cite file paths and line numbers for every claim. No generic advice that is not tied to a specific file. If a section has no findings, write "none found" and say what you checked.
```
