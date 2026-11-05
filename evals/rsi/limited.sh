#!/usr/bin/env bash
# Print 1 when a trial ended on a rate limit, else 0. Usage: limited.sh <trace.jsonl> <stderr.txt>
# Only the final trace record and stderr count: omp retries a mid-run 429 on another credential
# and finishes, so a 429 earlier in the trace is not a limited trial. A bare `429` is not a
# signal either; it also matches token counts, costs and call ids.
set -uo pipefail
if { tail -n 1 "$1" 2>/dev/null; cat "$2" 2>/dev/null; } \
   | grep -qiE '5-hour limit|rate.?limit|quota (exceeded|reached)|resource_exhausted|"code": *429'; then
  echo 1
else
  echo 0
fi
