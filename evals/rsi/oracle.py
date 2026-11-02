# RSI oracle — frozen, evaluator-only scorer for evals/rsi/tasks.json.
# Restored from lean-oracle-v1 (git show d8ed43e^:docs/evals/evidence/lean-oracle-v1.txt), D05 added.
# Never copied into the agent-visible fixture. Usage:
#   python3 -I oracle.py <D01|D02|D03|D05> <final-tree>
# Prints one "<predicate>\t<pass|fail>" row per check for predicates.tsv.
import os
import subprocess
import sys

case, tree = sys.argv[1], os.path.abspath(sys.argv[2])
sys.path.insert(0, tree)
rows = []


def check(name, fn):
    try:
        ok = bool(fn())
    except Exception:
        ok = False
    rows.append((name, "pass" if ok else "fail"))


def run(*argv, stdin=""):
    return subprocess.run(argv, cwd=tree, input=stdin, capture_output=True, text=True)


def tracked():
    return run("git", "ls-files").stdout.split()


check("suite_green", lambda: run(sys.executable, "-m", "unittest", "-q").returncode == 0)

if case == "D01":
    import tally.core as core
    import tally.report as report

    check("renamed_api", lambda: core.word_count("a b") == 2 and not hasattr(core, "count_words"))
    check("callers_updated", lambda: report.report("a b c")["words"] == 3)
    check("no_old_name", lambda: run("git", "grep", "-q", "count_words").returncode != 0)
elif case == "D02":
    def cli(args, text):
        return run(sys.executable, "-c", "import sys; from tally.cli import main; sys.exit(main(sys.argv[1:]))", *args, stdin=text).stdout

    check("r1_ignore_case", lambda: cli(["--ignore-case"], "A a b") == "a 2\nb 1\n")
    check("r2_min", lambda: cli(["--min", "2"], "a a b") == "a 2\n")
    check("default_unchanged", lambda: cli([], "b a a") == "a 2\nb 1\n")
elif case == "D03":
    import unicodedata

    from tally.fmt import render
    from tally.parse import tokens

    check("r1_unicode_ws", lambda: tokens("a b　c") == ["a", "b", "c"])
    check("r1_punct", lambda: tokens("«hi», there!") == ["hi", "there"])
    nfd = unicodedata.normalize("NFD", "é")
    check("r2_nfc_sort", lambda: render({nfd: 1, "f": 1}).split("\n")[0] == "f 1")
    check("r3_cli_combined", lambda: run(sys.executable, "-c", "import sys; from tally.cli import main; sys.exit(main([]))", stdin="«a» a b").stdout == "a 2\nb 1\n")
elif case == "D05":
    import tally.core as core

    check("longest_basic", lambda: core.longest("a ccc bb") == "ccc")
    check("longest_tie_first", lambda: core.longest("ab cd e") == "ab")
    check("longest_empty", lambda: core.longest("   ") is None)
    check("has_test", lambda: run("git", "grep", "-q", "longest", "--", "tests").returncode == 0)
else:
    sys.exit(f"unknown case {case}")

for name, result in rows:
    print(f"{name}\t{result}")
