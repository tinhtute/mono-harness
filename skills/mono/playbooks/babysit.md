# Playbook: babysit

Get open PRs to merge-ready. Never merges: landing is `ship`.

1. Declare the mode before any poll: `drive` (loop to merge-ready; in Claude Code run it under `/loop` self-paced, never a sleep loop), `threads-only` (answer review comments only), or `check` (one status pass and a report).
2. Work the lowest unmerged PR only; read and batch upstack threads, never fix them while the bottom is red.
3. Never rebase, retarget or force-push from here; report rebase-shaped work to the owner and stop.
4. Order: conflicts, then review threads, then CI. Batch every known fix into one push.
5. `hunt` — classify CI before any rerun: flake or infrastructure earns one fresh run; an identical second failure is real, read the logs. A failure in code the diff never touches → `git merge-base --is-ancestor origin/<base> HEAD`; false means a stale base, report it.
6. Review bots: verify each claim against the code; fix real findings with a red-first test in the PR that owns the code, dismiss noise with a concrete reason.
7. Trust the forge, not a green list: `gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision`. Stop at merge-ready or at the owner's approval gate.

Reply: the mode, each PR's state and blocker, fixes pushed with SHAs, and what waits on the owner.
