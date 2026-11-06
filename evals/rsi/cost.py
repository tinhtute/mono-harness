#!/usr/bin/env python3
"""Complete-trial model cost from a runtime trace. Frozen, evaluator-side.

Usage: cost.py <trace.jsonl>
Prints {"total_tokens": int, "cost_usd": float}: every input, cache read, cache write and
output token across all models and subagents, so authoring, retries and fallbacks count
(HarnessMM, arXiv 2610.32813). Claude Code stream-json: the final `result` modelUsage;
without one (timeout), the per-message usage, each message id once. omp: turn_end usage.
"""
import json
import sys


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    result, msgs, omp_tok, omp_cost = None, {}, 0, 0.0
    for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
        try:
            rec = json.loads(line)
        except ValueError:
            continue
        kind = rec.get("type")
        if kind == "result":
            result = rec
        elif kind == "assistant":
            msg = rec.get("message") or {}
            u = msg.get("usage") or {}
            msgs[msg.get("id") or id(rec)] = sum(int(u.get(k) or 0) for k in (
                "input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens", "output_tokens"))
        elif kind == "turn_end":
            u = (rec.get("message") or {}).get("usage") or {}
            omp_tok += int(u.get("totalTokens") or 0)
            omp_cost += float((u.get("cost") or {}).get("total") or 0)
    if result and result.get("modelUsage"):
        mu = result["modelUsage"].values()
        tok = sum(int(m.get(k) or 0) for m in mu for k in (
            "inputTokens", "outputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"))
        cost = float(result.get("total_cost_usd") or 0)
    elif msgs:
        tok, cost = sum(msgs.values()), float((result or {}).get("total_cost_usd") or 0)
    else:
        tok, cost = omp_tok, omp_cost
    print(json.dumps({"total_tokens": tok, "cost_usd": round(cost, 6)}, sort_keys=True))


if __name__ == "__main__":
    main()
