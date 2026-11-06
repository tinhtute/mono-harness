#!/usr/bin/env python3
"""Aggregate RSI trials for one split: pass/fail per task, median and IQR per metric.

Usage: report.py <out-root> [train|val|test]   (default: train)
The proposer reads only the train report; val/test reports go to the selector.
"""
import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
METRICS = ("total_tokens", "cost_usd", "output_tokens", "peak_context", "compactions", "tool_use", "repeats",
           "proof_calls", "proof_turns", "approved_entries", "approved_rejected")


def iqr(xs):
    if len(xs) < 2:
        return 0
    q = statistics.quantiles(xs, n=4, method="inclusive")
    return q[2] - q[0]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root, which = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "train")
    split = json.load(open(os.path.join(HERE, "split.json")))
    if which not in ("train", "val", "test"):
        sys.exit(f"unknown split {which}")
    report = {"split": which, "tasks": {}}
    for task in split[which]:
        tdir = os.path.join(root, task)
        trials = sorted(os.listdir(tdir)) if os.path.isdir(tdir) else []
        passes, vals = [], {m: [] for m in METRICS}
        for n in trials:
            env = dict(l.rstrip("\n").split("=", 1) for l in open(os.path.join(tdir, n, "trial.env")) if "=" in l)
            passes.append(env.get("pass") == "1")
            m = json.load(open(os.path.join(tdir, n, "metrics.json")))
            for k in METRICS:
                if k in m:  # trials scored before #196 carry no finalization metrics
                    vals[k].append(m[k])
        report["tasks"][task] = {
            "trials": len(trials), "passes": sum(passes),
            "pass": bool(trials) and sum(passes) * 2 > len(trials),
            **{k: {"median": statistics.median(v), "iqr": iqr(v)} for k, v in vals.items() if v},
        }
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
