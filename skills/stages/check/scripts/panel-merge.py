#!/usr/bin/env python3
"""Merge multi-model panel reports per check-review.md § Multi-model panel.

Usage:
  panel-merge.py --base SHA --head SHA [--diff-hash H] --budget TOKENS REPORT...

Each REPORT is a JSON file, in reviewer-index order:
  {"reviewer": "r1", "model": "...", "base_sha": "...", "head_sha": "...",
   "diff_hash": "...", "tokens": 1234, "status": "ok",
   "findings": [{"axis": "Spec"|"Standards", "file": "a.rs", "line_start": 1,
                 "line_end": 3, "req_id": "R1",
                 "severity": "critical"|"major"|"minor", "evidence": "..."}]}

A missing or unreadable file counts as an unavailable reviewer. Only the first
3 reports are reviewers; the rest are rejected. A report is invalid when its
status is not "ok", its SHAs differ from --base/--head (or --diff-hash when
given), or its tokens push the running total over --budget.

Stdout is JSON: {"panel": "ok"|"degraded (valid/N)", "valid": [...],
"rejected": [{"reviewer", "reason"}], "findings": [...]}, where each merged
finding adds "reviewer" (the kept copy's index) and "agreed": "n/N". Findings
come from valid reports only and are ordered by severity, then agreement.
Agreement orders findings; it never validates them.

Exit codes:
  0  merged (including degraded)
  2  invocation error
"""

from __future__ import annotations

import argparse
import json
import sys

MAX_REVIEWERS = 3
LINE_GAP = 3
SEVERITY = {"critical": 3, "major": 2, "minor": 1}
AXES = ("Spec", "Standards")


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as e:
        return None, f"unavailable: {e.__class__.__name__}"
    if not isinstance(data, dict):
        return None, "unavailable: not an object"
    return data, None


def check_report(data, args, spent):
    if data.get("status") != "ok":
        return f"status: {data.get('status')}"
    if data.get("base_sha") != args.base or data.get("head_sha") != args.head:
        return "sha mismatch"
    if args.diff_hash is not None and data.get("diff_hash") != args.diff_hash:
        return "diff hash mismatch"
    tokens = data.get("tokens")
    if not isinstance(tokens, int) or tokens < 0:
        return "tokens missing"
    if spent + tokens > args.budget:
        return "over budget"
    for f in data.get("findings", []):
        if f.get("axis") not in AXES or f.get("severity") not in SEVERITY:
            return "bad finding"
        if not f.get("file") and not (f.get("axis") == "Spec" and f.get("req_id")):
            return "finding without file or requirement"
    return None


def same(a, b):
    if a["axis"] != b["axis"]:
        return False
    if not a.get("file") or not b.get("file"):
        return (not a.get("file") and not b.get("file")
                and a.get("req_id") == b.get("req_id"))
    if a["file"] != b["file"]:
        return False
    a0 = a.get("line_start", 0)
    a1 = a.get("line_end", a0)
    b0 = b.get("line_start", 0)
    b1 = b.get("line_end", b0)
    return a0 <= b1 + LINE_GAP and b0 <= a1 + LINE_GAP


def merge(valid):
    groups = []  # each: {"kept": finding, "idx": int, "reviewers": set}
    for idx, report in enumerate(valid):
        for f in report.get("findings", []):
            group = next((g for g in groups if same(g["kept"], f)), None)
            if group is None:
                groups.append({"kept": f, "idx": idx, "reviewers": {idx}})
                continue
            group["reviewers"].add(idx)
            rank = SEVERITY[f["severity"]]
            kept = SEVERITY[group["kept"]["severity"]]
            if rank > kept or (rank == kept and idx < group["idx"]):
                group["kept"], group["idx"] = f, idx
    n = len(valid)
    out = []
    for g in groups:
        f = dict(g["kept"])
        f["reviewer"] = valid[g["idx"]].get("reviewer", str(g["idx"]))
        f["agreed"] = f"{len(g['reviewers'])}/{n}"
        out.append((SEVERITY[f["severity"]], len(g["reviewers"]), g["idx"],
                    f.get("file") or "", f.get("line_start", 0), f))
    out.sort(key=lambda t: (-t[0], -t[1], t[2], t[3], t[4]))
    return [t[-1] for t in out]


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--base", required=True)
    p.add_argument("--head", required=True)
    p.add_argument("--diff-hash")
    p.add_argument("--budget", type=int, required=True)
    p.add_argument("reports", nargs="+")
    args = p.parse_args(argv)

    valid, rejected, spent = [], [], 0
    for i, path in enumerate(args.reports):
        if i >= MAX_REVIEWERS:
            rejected.append({"reviewer": path, "reason": "over reviewer limit"})
            continue
        data, err = load(path)
        if err is None:
            err = check_report(data, args, spent)
        if err is not None:
            name = data.get("reviewer", path) if data else path
            rejected.append({"reviewer": name, "reason": err})
            continue
        spent += data["tokens"]
        valid.append(data)

    total = min(len(args.reports), MAX_REVIEWERS)
    panel = "ok" if len(valid) >= 2 else f"degraded ({len(valid)}/{total})"
    json.dump({
        "panel": panel,
        "valid": [r.get("reviewer", "") for r in valid],
        "rejected": rejected,
        "tokens": spent,
        "findings": merge(valid),
    }, sys.stdout, indent=2)
    sys.stdout.write("\n")
    print(f"panel: {panel}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
