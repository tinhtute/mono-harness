#!/usr/bin/env python3
"""Accept a child candidate over its parent on one split (HarnessMM-style rule).

Usage: accept.py <parent-report.json> <child-report.json> [max-ratio]   (default 0.9)
Reports come from report.py on the same split. Accept only when every task keeps its
pass rate (child passes/trials >= parent's) AND the summed per-task median total_tokens
is at most max-ratio x the parent's. Prints the verdict as JSON; exit 0 accept, 1 reject.
"""
import json
import sys


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    parent, child = (json.load(open(p))["tasks"] for p in sys.argv[1:3])
    ratio = float(sys.argv[3]) if len(sys.argv) == 4 else 0.9
    reasons = []
    if set(parent) != set(child):
        reasons.append(f"task sets differ: {sorted(parent)} vs {sorted(child)}")

    def rate(t):
        return t["passes"] / t["trials"] if t["trials"] else 0.0

    def tokens(r):
        return sum(t["total_tokens"]["median"] for t in r.values() if "total_tokens" in t)

    for name in sorted(set(parent) & set(child)):
        if rate(child[name]) < rate(parent[name]):
            reasons.append(f"{name}: pass rate {rate(child[name]):.2f} < parent {rate(parent[name]):.2f}")
    if any("total_tokens" not in t for t in list(parent.values()) + list(child.values())):
        reasons.append("total_tokens missing from a report")
    p_tok, c_tok = tokens(parent), tokens(child)
    if p_tok and c_tok > ratio * p_tok:
        reasons.append(f"tokens {c_tok} > {ratio} x parent {p_tok}")
    print(json.dumps({"accept": not reasons, "parent_tokens": p_tok, "child_tokens": c_tok,
                      "ratio": round(c_tok / p_tok, 4) if p_tok else None, "reasons": reasons},
                     sort_keys=True))
    sys.exit(0 if not reasons else 1)


if __name__ == "__main__":
    main()
