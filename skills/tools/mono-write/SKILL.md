---
name: mono-write
version: "1.0.0"
description: "Polish a research or learn draft (EN/VI) so it reads naturally, and write CHANGELOG entries and release notes from a commit list. Not for UI copy, marketing or tone changes."
---

`mono-write` does two jobs for the mono playbooks (`research`, `ship`) and `learn`. Any other writing (UI copy, marketing, tone changes, Notion reports, prose from scratch) belongs to `write` from [monoclaudian](https://github.com/tinhtute/monoclaudian): use it when it is installed; otherwise say it is not installed and stop.

Defer to: `git` for commit messages and PR text.

Both jobs change wording, never meaning. Keep every fact, caveat, number, citation, link, code span and heading. Source text missing → ask for it and stop. Return the final prose only; explain changes only when asked.

## Polish a draft

Edit lightly: cut filler and repetition, fix rhythm within a paragraph, and keep the outline and the author's voice. Restructure sections only when asked.

- Cut throat-clearing openings, meta-writing (`in this section we will explore`), and conclusions that restate the body.
- Cut filler: `it is worth noting that`, `in today's fast-paced landscape`, `moving forward`, `this highlights the importance of`.
- Replace formulaic patterns with direct statements: `not X, but Y`, rhetorical questions, fake suspense, stacked tricolons, bold claims without evidence.
- Prefer plain, active, specific words: name the actor; `use` over `utilize`, `show` over `demonstrate`.
- Vietnamese: cut `có thể thấy rằng`, `điều này cho thấy`, `nhằm mục đích`, `đóng vai trò quan trọng`, `trong bối cảnh hiện nay`, `một cách hiệu quả`; use active voice and avoid calques of English structure; no em-dash; keep common English terms (`API`, `prompt`, `token`); one form of address and one term per concept.
- Mixed EN/VI: apply each language's rules to its own text and use the same term for the same concept throughout.

## CHANGELOG and release notes

Input: the commit list since the last tag (`git log --oneline <tag>..HEAD`) and the current `CHANGELOG.md`.

- Follow the file's existing format and sections (Keep a Changelog here, under `## [Unreleased]`).
- Breaking changes first. Each entry states what changed and the exact migration step the user runs.
- Write the user-visible effect, not the commit subject. Combine the commits behind one change into one entry; drop CI-only and chore commits unless users see the effect.
- Add only changes the commits show; an unclear commit → read its diff, not guess.
- Release notes: the same entries, shortest form, breaking changes on top.
