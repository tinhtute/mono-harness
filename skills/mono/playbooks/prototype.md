# Playbook: prototype

The prototype is a throwaway instrument for one decision; the real build follows `feature`. Speed over polish: no plan, no tests, no abstractions.

1. `think` — name the one decision (layout, interaction, behavior, timing, approach). A fork answerable by observation is settled here, not asked. No decision → route to `feature`.
2. `read` — gather prior art when the design space is open; skip when the direction is set.
3. Build in the scratchpad, never in production source: plain HTML/CSS/JS with CDN deps for a visual call, the smallest script for a behavioral one.
4. Put alternatives behind one switcher, each variant labeled.
5. Observe each variant on its surface: screenshot and drive the UI with Claude Code's `run` skill (or `claude-in-chrome` for a browser page), or log the timing or output. The observation is the test.
6. Recommend one variant with its trade-offs; hand it to `feature`.

Reply: variants explored, evidence (screenshots, output, timing), the recommendation, the scratch path, and that the prototype is throwaway.
