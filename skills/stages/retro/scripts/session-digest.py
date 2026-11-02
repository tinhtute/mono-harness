#!/usr/bin/env python3
"""Condense a Claude Code session log into the signals a retro needs.

Usage: session-digest.py [--json] [SESSION_JSONL | SESSION_ID]
With no argument, reads the newest session for the current directory under
~/.claude/projects/<cwd-slug>/. Also reads `claude -p --output-format
stream-json` traces. Prints plain text, or one JSON object with --json;
reads nothing else.
"""
import collections
import glob
import json
import os
import re
import sys

PROJECTS = os.path.expanduser("~/.claude/projects")


def resolve(arg):
    if arg and os.path.isfile(arg):
        return arg
    slug = re.sub(r"[^A-Za-z0-9]", "-", os.getcwd())
    if arg:
        hits = glob.glob(os.path.join(PROJECTS, "*", arg + ".jsonl"))
        if hits:
            return hits[0]
        sys.exit(f"session not found: {arg}")
    logs = glob.glob(os.path.join(PROJECTS, slug, "*.jsonl"))
    if not logs:
        sys.exit(f"no sessions under {os.path.join(PROJECTS, slug)}; pass a path")
    return max(logs, key=os.path.getmtime)


def text_of(content):
    if isinstance(content, str):
        return content
    parts = []
    for block in content or []:
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
        elif block.get("type") == "tool_result":
            parts.append(text_of(block.get("content")))
    return "\n".join(parts)


def short(s, n=160):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[: n - 1] + "…"


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    args = [a for a in args if a != "--json"]
    path = resolve(args[0] if args else None)
    seen = set()
    calls = {}
    counts = collections.Counter()
    repeats = collections.Counter()
    errors, results, prompts, answers = [], [], [], []
    peak_context = output_tokens = compactions = 0

    with open(path, encoding="utf-8") as f:
        for line in f:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("isSidechain") or rec.get("parent_tool_use_id"):
                continue
            if rec.get("type") == "system" and "compact" in str(rec.get("subtype", "")):
                compactions += 1
            msg = rec.get("message") or {}
            content = msg.get("content")
            usage = msg.get("usage") if rec.get("type") == "assistant" else None
            if usage and (msg.get("id") is None or msg["id"] not in seen):  # one API message spans several records
                seen.add(msg.get("id"))
                context = sum(usage.get(k) or 0 for k in (
                    "input_tokens", "cache_read_input_tokens", "cache_creation_input_tokens"))
                peak_context = max(peak_context, context)
                output_tokens += usage.get("output_tokens") or 0
            if rec.get("type") == "assistant" and isinstance(content, list):
                for b in content:
                    if b.get("type") == "tool_use":
                        sig = short(json.dumps(b.get("input"), sort_keys=True), 200)
                        calls[b["id"]] = (b["name"], sig)
                        counts[b["name"]] += 1
                        repeats[(b["name"], sig)] += 1
            elif rec.get("type") == "user":
                if isinstance(content, str):
                    if not content.startswith("<"):
                        prompts.append(short(content, 240))
                    continue
                for b in content or []:
                    if b.get("type") == "text" and not b.get("text", "").startswith("<"):
                        prompts.append(short(b["text"], 240))
                    if b.get("type") != "tool_result":
                        continue
                    name, sig = calls.get(b.get("tool_use_id"), ("?", ""))
                    body = text_of(b.get("content"))
                    results.append((len(body), name, sig))
                    if name == "AskUserQuestion":
                        answers.append(short(body, 240))
                    if b.get("is_error"):
                        errors.append((name, short(body)))

    if as_json:
        print(json.dumps({
            "session": path, "user_prompts": len(prompts),
            "tool_use": sum(counts.values()), "tool_use_by_name": dict(counts),
            "repeats": sum(n - 1 for n in repeats.values()),
            "top_repeats": [{"name": k[0], "input": k[1], "count": n}
                            for k, n in repeats.most_common(5) if n > 1],
            "errors": len(errors), "peak_context": peak_context,
            "output_tokens": output_tokens, "compactions": compactions,
        }, sort_keys=True))
        return
    print(f"session: {path}")
    print(f"user prompts: {len(prompts)}  tool calls: {sum(counts.values())}")
    print(f"peak context tokens: {peak_context}  output tokens: {output_tokens}  "
          f"compactions: {compactions}")
    subagents = glob.glob(os.path.join(path[: -len(".jsonl")], "subagents", "*.jsonl"))
    if subagents:
        print(f"sub-agent logs: {len(subagents)} (pass one as the argument to digest it)")
    print("\n## tool calls by name")
    for name, n in counts.most_common():
        print(f"- {name}: {n}")
    print(f"\n## errored tool results ({len(errors)})")
    for name, body in errors:
        print(f"- {name}: {body}")
    print("\n## repeated identical calls")
    for (name, sig), n in repeats.most_common():
        if n < 2:
            break
        print(f"- {name} x{n}: {sig}")
    print("\n## largest tool results (chars)")
    for size, name, sig in sorted(results, reverse=True)[:5]:
        print(f"- {size} {name}: {sig}")
    print("\n## user prompts (corrections and steering show up here)")
    for i, p in enumerate(prompts, 1):
        print(f"{i}. {p}")
    print(f"\n## answers to structured questions ({len(answers)})")
    for a in answers:
        print(f"- {a}")


if __name__ == "__main__":
    main()
