# Playbook: perf

Every fix ties to a measurement; reading source is not measuring.

1. Capture a baseline on the real surface (benchmark, trace or profile; Claude Code `run` skill for an app or CLI). Before trusting any number: name what limits it, its unit, run count and variance, and rule out that it measured something other than the work.
2. `hunt` — hypotheses from the trace, not from source; no ceiling claim without running it.
3. Try the mantras cheapest first and stop at the first that meets the target: don't do it → don't do it again → do it less → do it later → do it when they're not looking → do it concurrently → do it cheaper.
4. `work` — one change per attempt, re-measured on the same harness before the next.
5. `check` — compare before/after artifacts; inconclusive or wrong-surface is not a pass.
6. `git` — cite the number in the commit or PR; only when the owner asks.

Reply: baseline, after, delta with unit, and the artifact path.
