# hunt: output

Loaded by `hunt` when reporting.

Open with one plain line: the outcome and whether changes are committed.

```
Root cause:        [what was wrong, file:line]
Loop:              [the red-capable command]
Fix:               [what changed, file:line]  (diagnose mode: "not applied")
Sibling sweep:     [N sites checked: N fixed / safe / unsure]  or  [not run, why]
Confirmed:         [loop red → green, original scenario re-run]
Regression guard:  [test file:line, red run shown]  or  [none: no correct seam, why]
```

Status: **resolved**, **resolved with caveats** (state them), **blocked**.

**Handoff (blocked):** the symptom in one sentence; each hypothesis, its probe, and why it was ruled out; evidence (log excerpts, repro steps, versions, config); unknowns; next steps naming any tool, access, or context the user must supply.
