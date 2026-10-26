# Playbook: bug-fix

1. `hunt` — reproduce the symptom yourself before reading a fix into the code; bisect when it is a regression.
2. Write the failing test that captures the repro; land it before the fix and watch it fail for the named reason. No cheap seam → `skip: <reason>` and keep the step 1 repro as the proof.
3. `work` — the least change that turns the test green; revert anything a refuted hypothesis added; `bounded` unless the fix spans sessions or needs recovery.
4. `check` — run the gate on the fix diff.
5. `git` — only when the owner asks.

Reply: the root cause, the repro test, and the fix evidence.
