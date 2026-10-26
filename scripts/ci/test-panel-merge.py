#!/usr/bin/env python3
"""Fixture tests for skills/stages/check/scripts/panel-merge.py (issue #156).

Run: python3 -I scripts/ci/test-panel-merge.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, "skills/stages/check/scripts/panel-merge.py")
BASE, HEAD = "a" * 40, "b" * 40


def finding(severity="major", file="src/a.rs", start=10, end=12, axis="Standards", **kw):
    return {"axis": axis, "file": file, "line_start": start, "line_end": end,
            "severity": severity, "evidence": "e", **kw}


def report(name, findings=(), tokens=100, status="ok", base=BASE, head=HEAD):
    return {"reviewer": name, "model": "m", "base_sha": base, "head_sha": head,
            "tokens": tokens, "status": status, "findings": list(findings)}


class PanelMerge(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def run_panel(self, reports, budget=1000):
        paths = []
        for i, r in enumerate(reports):
            path = os.path.join(self.tmp.name, f"r{i}.json")
            if r is not None:
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(r, f)
            paths.append(path)
        out = subprocess.run(
            [sys.executable, "-I", SCRIPT, "--base", BASE, "--head", HEAD,
             "--budget", str(budget), *paths],
            capture_output=True, text=True, check=True)
        return json.loads(out.stdout), out.stderr

    def test_unavailable_reviewer_degrades(self):
        res, err = self.run_panel([report("r1", [finding()]), None])
        self.assertEqual(res["panel"], "degraded (1/2)")
        self.assertIn("panel: degraded (1/2)", err)
        self.assertTrue(res["rejected"][0]["reason"].startswith("unavailable"))
        self.assertEqual(len(res["findings"]), 1)

    def test_timeout_status_is_invalid(self):
        res, _ = self.run_panel([report("r1"), report("r2", status="timeout")])
        self.assertEqual(res["panel"], "degraded (1/2)")
        self.assertEqual(res["rejected"], [{"reviewer": "r2", "reason": "status: timeout"}])

    def test_sha_mismatch_rejected(self):
        res, _ = self.run_panel([report("r1"), report("r2", head="c" * 40), report("r3")])
        self.assertEqual(res["panel"], "ok")
        self.assertEqual(res["valid"], ["r1", "r3"])

    def test_conflicting_severity_keeps_higher(self):
        res, _ = self.run_panel([
            report("r1", [finding("minor", start=10, end=10)]),
            report("r2", [finding("critical", start=13, end=14)]),
        ])
        self.assertEqual(res["panel"], "ok")
        [f] = res["findings"]
        self.assertEqual((f["severity"], f["reviewer"], f["agreed"]), ("critical", "r2", "2/2"))

    def test_tie_keeps_lowest_reviewer(self):
        res, _ = self.run_panel([
            report("r1", [finding(evidence="first")]),
            report("r2", [finding(evidence="second")]),
        ])
        [f] = res["findings"]
        self.assertEqual((f["reviewer"], f["evidence"]), ("r1", "first"))

    def test_distinct_findings_not_merged(self):
        res, _ = self.run_panel([
            report("r1", [finding(start=10, end=10), finding(axis="Spec", file="", req_id="R1")]),
            report("r2", [finding(start=14, end=14), finding(axis="Spec", file="", req_id="R2"),
                          finding(axis="Spec", start=10, end=10)]),
        ])
        self.assertEqual(len(res["findings"]), 5)
        self.assertTrue(all(f["agreed"] == "1/2" for f in res["findings"]))

    def test_spec_requirement_dedup(self):
        res, _ = self.run_panel([
            report("r1", [finding(axis="Spec", file="", req_id="R1")]),
            report("r2", [finding(axis="Spec", file="", req_id="R1")]),
        ])
        [f] = res["findings"]
        self.assertEqual(f["agreed"], "2/2")

    def test_order_severity_then_agreement(self):
        res, _ = self.run_panel([
            report("r1", [finding("major", file="x"), finding("major", file="y")]),
            report("r2", [finding("major", file="y"), finding("critical", file="z")]),
        ])
        self.assertEqual([f["file"] for f in res["findings"]], ["z", "y", "x"])

    def test_budget_drops_overflowing_reviewer(self):
        res, err = self.run_panel(
            [report("r1", tokens=400), report("r2", tokens=400), report("r3", tokens=400)],
            budget=1000)
        self.assertEqual(res["panel"], "ok")
        self.assertEqual(res["valid"], ["r1", "r2"])
        self.assertEqual(res["rejected"], [{"reviewer": "r3", "reason": "over budget"}])
        self.assertEqual(res["tokens"], 800)

    def test_budget_exhaustion_degrades(self):
        res, _ = self.run_panel([report("r1", tokens=900), report("r2", tokens=200)], budget=1000)
        self.assertEqual(res["panel"], "degraded (1/2)")

    def test_reviewer_limit(self):
        res, _ = self.run_panel([report(f"r{i}") for i in range(4)])
        self.assertEqual(len(res["valid"]), 3)
        self.assertEqual(res["rejected"][0]["reason"], "over reviewer limit")


if __name__ == "__main__":
    unittest.main()
