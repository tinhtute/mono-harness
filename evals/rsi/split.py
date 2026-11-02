#!/usr/bin/env python3
"""Derive the frozen train/val/test split from tasks.json's seed.

Usage: split.py           print split.json content
       split.py --check   exit 1 unless split.json matches the seed
"""
import json
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(os.path.join(HERE, "tasks.json")))
ids = sorted(cfg["tasks"])
random.Random(cfg["seed"]).shuffle(ids)
n_val = n_test = max(1, len(ids) // 4)
split = {"seed": cfg["seed"], "train": sorted(ids[n_val + n_test:]),
         "val": sorted(ids[:n_val]), "test": sorted(ids[n_val:n_val + n_test])}
text = json.dumps(split, indent=2) + "\n"
if "--check" in sys.argv:
    on_disk = open(os.path.join(HERE, "split.json")).read()
    sys.exit(0 if on_disk == text else "split.json does not match tasks.json seed")
sys.stdout.write(text)
