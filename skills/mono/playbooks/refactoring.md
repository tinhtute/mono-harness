# Playbook: refactoring

The structure changes; the behavior does not. A missing feature or real bug found on the way is split out and routed to `feature` or `bug-fix` after the structural change lands.

1. `think` — learn the contract of the affected code; name the structure it is missing (state machine, table, typed model) and the target shape as if built today. The reshape must delete branches or invalid states, not add indirection.
2. Pin the behavior before any structure moves: a characterization test, snapshot, or old-vs-new equivalence script. Type check and lint are not a pin.
3. `work` — subtract first: delete dead code, one-caller wrappers and orphan references. Then move in small steps, each keeping the pin green; migrate every caller and delete the old API in the same wave, no shims.
4. Spot-check every rename against strings, docs and back-references.
5. `check` — the pin passes on the real artifact, plus the gate commands.
6. Keep it only if reader load dropped (fewer layers, branches or hidden state); otherwise revert.
7. `git` — subtraction commit, then reshape, then cleanup; only when the owner asks.

Reply: the structure that changed, the pin, the equivalence proof, the reader-load delta, and what was reverted.
