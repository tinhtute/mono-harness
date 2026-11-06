#!/usr/bin/env python3
"""Derive the frozen train/val/test split from tasks.json's seed and pins.

Usage: split.py           print split.json content
       split.py --check   exit 1 unless split.json matches the seed
"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(os.path.join(HERE, "tasks.json")))
# "pinned" tasks join a split by name and stay out of the shuffle, so adding one
# never reshuffles the seeded tasks or invalidates their earlier reports.
pinned = cfg.get("pinned", {})
ids = sorted(t for t in cfg["tasks"] if t not in pinned)
random.Random(cfg["seed"]).shuffle(ids)
n_val = n_test = max(1, len(ids) // 4)
split = {"seed": cfg["seed"], "train": ids[n_val + n_test:],
         "val": ids[:n_val], "test": ids[n_val:n_val + n_test]}
for task, name in pinned.items():
    split[name].append(task)
split = {k: sorted(v) if isinstance(v, list) else v for k, v in split.items()}
text = json.dumps(split, indent=2) + "\n"
if "--check" in sys.argv:
    on_disk = open(os.path.join(HERE, "split.json")).read()
    sys.exit(0 if on_disk == text else "split.json does not match tasks.json seed")
sys.stdout.write(text)
