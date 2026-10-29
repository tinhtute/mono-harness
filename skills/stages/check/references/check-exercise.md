# Exercise the Change

Tests prove the code does what the tests say. Running the changed path once, the way a user or client would, finds what the tests don't cover, and its evidence lets a reviewer skip checking out a small PR. Loaded by [check.md](check.md) step 6.

## When

Exercise when the diff changes runtime behavior (a CLI, a hook, a script, an installed skill's effect), not only docs, tests, CI configuration, or comments. Otherwise report `not exercised: no runtime change`.

Recipe, first match wins: the host's run skill (Claude Code: `/run`); run commands in `AGENTS.md` or the docs it points to. With neither, report `not exercised: no way to run it`. Never guess how to start the app.

## How

1. A step only a human can do (a login, a key, a running service): ask in an attended session; unattended, skip it and list it as `needs <action>`.
2. Start what the recipe names, in the background, and wait for readiness in one bounded shell loop.
3. Drive the changed path once and check one thing the tests can't easily show: what is stored, what the caller receives, what stayed unchanged.
4. Drive one failure case where the change has one: invalid input, a missing file, an unauthorized caller.
5. Stop everything you started.

A run that did not reach the changed path is not evidence, whatever it printed.

## Outcomes

- **Intended** → write the report.
- **Wrong** → fix it with a test that fails without the fix, rerun the gates, exercise again. Still wrong → ask the owner, or report `wrong: <observed> vs <expected>` so the risk verdict sees it.
- **Can't start** → `not exercised: <why>`.

## Report

The PR body's `## Exercised` section, and the `output` proof of the check entry:

```markdown
## Exercised

- `<command>` → <observed result>
- Failure case: `<command>` → <observed result>
- Not exercised: <what, and why> (or "nothing")
- Try it: `<commands a reviewer can paste>`
```

One line per thing exercised, command and observation, no logs, never a real secret.
