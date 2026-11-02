#!/usr/bin/env bash
# bench.sh - time a command: warmup runs, then N measured wall-clock runs.
#
# Usage: bench.sh -n N [--warmup W] -- CMD [ARGS...]
#
# Runs CMD W times unmeasured (default 1), then N times measured; CMD output is
# discarded. Prints one JSON line to stdout:
#   {"n":N,"median_ms":..,"p90_ms":..,"stdev_ms":..,"min_ms":..,"max_ms":..}
# Exit 0 when every run exits 0; exit 1 with {"error":"run K exited RC"} when any
# run fails (K is 0 for a warmup run); exit 2 on bad usage.

set -euo pipefail

usage() { echo "usage: bench.sh -n N [--warmup W] -- CMD [ARGS...]" >&2; exit 2; }

n=""; warmup=1
while [ $# -gt 0 ]; do
	case "$1" in
		-n) [ $# -ge 2 ] || usage; n="$2"; shift 2 ;;
		--warmup) [ $# -ge 2 ] || usage; warmup="$2"; shift 2 ;;
		--) shift; break ;;
		*) usage ;;
	esac
done
case "$n" in ''|*[!0-9]*|0) usage ;; esac
case "$warmup" in ''|*[!0-9]*) usage ;; esac
[ $# -gt 0 ] || usage

for ((i = 0; i < warmup; i++)); do
	rc=0; "$@" >/dev/null 2>&1 || rc=$?
	[ "$rc" -eq 0 ] || { printf '{"error":"run 0 exited %s"}\n' "$rc"; exit 1; }
done

times=()
for ((k = 1; k <= n; k++)); do
	start=$(date +%s%N)
	rc=0; "$@" >/dev/null 2>&1 || rc=$?
	end=$(date +%s%N)
	[ "$rc" -eq 0 ] || { printf '{"error":"run %s exited %s"}\n' "$k" "$rc"; exit 1; }
	times+=("$(( (end - start) / 1000 ))")   # microseconds
done

printf '%s\n' "${times[@]}" | sort -n | awk '
	{ v[NR] = $1 / 1000; s += v[NR] }
	END {
		n = NR; m = s / n
		for (i = 1; i <= n; i++) d += (v[i] - m) ^ 2
		sd = (n > 1) ? sqrt(d / (n - 1)) : 0
		med = (n % 2) ? v[(n + 1) / 2] : (v[n / 2] + v[n / 2 + 1]) / 2
		p = int(0.9 * n); if (p < 0.9 * n) p++; if (p < 1) p = 1
		printf "{\"n\":%d,\"median_ms\":%.2f,\"p90_ms\":%.2f,\"stdev_ms\":%.2f,\"min_ms\":%.2f,\"max_ms\":%.2f}\n", n, med, v[p], sd, v[1], v[n]
	}'
