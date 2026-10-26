# Thinking Lenses

Load from `think` step 5, or for `think lens <name>`. Each lens is a question with a required output. Pick the 3–5 that fit; running all of them is ceremony. A lens that finds nothing gets one line ("reversibility: two-way door, no finding"), not a paragraph.

## Core

**premise-collapse** — Which single assumption, if false, makes this plan wrong?
- Output: "This assumes X. If X fails, Y happens." Always name it; fragile X → deform the design to survive it.

**pre-mortem** — It is six months later and this failed. What is the most likely story?
- Output: top 1–2 failure stories and the design change preventing each. Inversion variant: "how would we guarantee failure?", then avoid that.

**reversibility** — One-way door or two-way door?
- Output: the rollback path and its cost (data, public API, muscle memory). Two-way → decide fast on less evidence. One-way → slow down, demand evidence, prefer a reversible first step.

**simplicity-gate** — Does the chosen plan beat the brute-force version?
- Minimal path: the one-line brute-force option; the plan must beat it on risk, rollback, or latency, not elegance.
- Defensive layers: every try/catch, retry, fallback, or flag maps to one named failure mode; delete layers that only "might" fail.
- Surface delta: list new commands, env vars, flags, services; prefer +0.
- Compensating complexity: workaround machinery bigger than the feature means the premise is wrong; name a route change.

## Risk

**attack-angles** — Run when the plan has external dependencies, concurrency, or data migration.

| Angle | Question |
|---|---|
| Dependency failure | If an external API, service, or tool is down, does the plan degrade gracefully? |
| Scale explosion | At 10× data or load, which step breaks first? |
| Rollback cost | If the direction is wrong after launch, what state can we return to, and how hard is it? |
| Concurrency | Two runs, two users, two tabs at once: what collides? |

- Output: which angles hold, which crack, and the deformation for each crack.

**second-order** — And then what? Who else is affected once this works?
- Output: the downstream effect on other users, teams, maintenance, incentives, or adjacent features that the first-order benefit hides.

**failure-modes** — Enumerate every way the core step can refuse or fail, not just the one you expect.
- Output: each branch with a distinguishable reason and a next action. A guard has a set of causes, not one.

## Design

**deletion-test** — Imagine deleting the module, layer, or setting.
- Output: complexity vanishes → it was a pass-through, remove it. Complexity reappears across N callers → it earns its keep.

**depth-and-seam** — How much behavior does a caller get per unit of interface they must learn, and where does the interface live?
- A **deep** module hides a lot behind a small interface; a **shallow** one's interface is nearly as complex as its body.
- The interface is the test surface: if you must test past it, the module is the wrong shape.
- One adapter is a hypothetical seam; two adapters is a real one. Do not add a seam unless something actually varies across it.
- Output: the proposed interface in a few lines, what it hides, and where the seam sits. For competing shapes, switch to `twice`.

**entity-delta** — What durable things does this add or remove? (settings, flags, env vars, commands, services, routes, schemas, dependencies, public APIs, long-lived helpers)
- Output: `Entity delta: +N / -N`, each addition with its distinct user need, owner, and why changing an existing default cannot achieve the same. +0 is the preferred outcome.

**prior-art** — Who already solved this?
- Output: the official or built-in solution if one exists (default choice unless it demonstrably falls short), plus the transferable mechanism taken from each of 2–3 mature implementations actually read.

## Evidence

**primary-sources** — Is each load-bearing claim traced to the source that owns it (official docs, source code, spec, live config), not a secondary write-up or memory?
- Output: claim → source for each load-bearing fact; unverified claims are flagged as assumptions.

**fact-vs-decision** — Split every open question into facts (look them up yourself) and decisions (the user's).
- Output: facts resolved with sources; decisions listed as a frontier with recommended answers.

**prototype-to-answer** — Can a throwaway artifact settle this faster than argument?
- Output: the exact question, the smallest artifact that answers it (a logic walkthrough in one HTML file, or several UI variants behind a switch), and what verdict would change the recommendation. Throwaway, no persistence, clearly marked, not merged.

## Communication

**re-pitch** — The last explanation did not land.
- Output: the same conclusion in short plain sentences, starting from context the user already has, using the project's own domain terms.
