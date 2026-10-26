#!/usr/bin/env bash
# setup-statusline.sh — Install the @slim statusline for Claude Code

set -euo pipefail

DEST="${HOME}/.claude/statusline.sh"
BACKUP="${DEST}.backup.$(date +%s)"

echo "Installing slim statusline..."

# Backup existing
if [ -f "$DEST" ]; then
  cp "$DEST" "$BACKUP"
  echo "  Backed up existing statusline to ${BACKUP}"
fi

# Write the statusline script
cat > "$DEST" << 'STATUSLINE_EOF'
#!/bin/sh
# slim.sh — model-first layout: 👾 model  effort  ▰▱ N%  ϟ tpm  ★ cache%  ⌥ branch

TPM_STATE_PREFIX="claude-code-statusline-tpm"
TPM_WINDOW_MS=300000
MODEL_STATE_PREFIX="claude-code-statusline-model"
SUBAGENT_STATE_PREFIX="claude-code-statusline-subagent"

input=$(cat)

eval "$(echo "$input" | jq -r '
  "cwd=\(.cwd // "" | @sh)",
  "session_id=\(.session_id // "" | @sh)",
  "transcript_path=\(.transcript_path // "" | @sh)",
  "used=\(.context_window.used_percentage // 0 | floor | @sh)",
  "model=\(.model.display_name // "unknown" | @sh)",
  "effort=\(.effort.level // "" | @sh)",
  "duration_ms=\(.cost.total_duration_ms // 0 | floor | @sh)",
  "api_ms=\(.cost.total_api_duration_ms // 0 | floor | @sh)",
  "pc_obs=\(.prompt_cache.caching_observed // false | @sh)",
  "pc_hit=\(.prompt_cache.hit_ratio | if . == null then "" else . * 100 | floor end | @sh)",
  "pc_exp=\(.prompt_cache.expires_at | if . == null then "" else floor end | @sh)",
  "pc_miss=\(.prompt_cache.misses // 0 | floor | @sh)",
  "pc_miss_at=\(.prompt_cache.last_miss_at // 0 | floor | @sh)",
  "pc_cause=\(.prompt_cache.last_miss_cause.causes[0]? // "" | @sh)"
')"

used=${used:-0}; model=${model:-unknown}; effort=${effort:-}
duration_ms=${duration_ms:-0}; api_ms=${api_ms:-0}
pc_miss=${pc_miss:-0}

safe_id=$(printf '%s' "$session_id" | tr -dc 'a-zA-Z0-9_-')

# TPM: session output tokens (main transcript, deduped by message.id) per API-minute.
# total_*_tokens in the JSON are the current context size, not session totals.
# Incremental: state file keeps "byte_offset out_sum last_msg_id".
tpm=0
if [ -n "$safe_id" ] && [ -f "$transcript_path" ] && [ "$api_ms" -gt 0 ]; then
  tpm_file="/tmp/${TPM_STATE_PREFIX}-${safe_id}"
  off=0; out_sum=0; last_id=""
  [ -f "$tpm_file" ] && read -r off out_sum last_id < "$tpm_file"
  size=$(stat -c %s "$transcript_path" 2>/dev/null || echo 0)
  [ "$size" -lt "${off:-0}" ] && { off=0; out_sum=0; last_id=""; }
  if [ "$size" -gt "$off" ]; then
    # Only advance past a complete trailing line; a half-written line is re-read next run
    last_byte=$(tail -c +"$size" "$transcript_path" | head -c 1 | od -An -tx1 | tr -d ' \n')
    eval "$(tail -c +$((off + 1)) "$transcript_path" | head -c $((size - off)) \
      | jq -R -r 'fromjson? | select(.type == "assistant" and (.isSidechain | not))
                  | "\(.message.id) \(.message.usage.output_tokens // 0)"' \
      | awk -v s="$out_sum" -v l="$last_id" '$1 != l { s += $2; l = $1 } END { printf "out_sum=%d last_id=%s\n", s, l }')"
    [ "$last_byte" = "0a" ] && printf '%s %s %s\n' "$size" "$out_sum" "$last_id" > "$tpm_file"
  fi
  tpm=$(( out_sum * 60000 / api_ms ))
fi

# Session-scoped model cache
if [ -n "$safe_id" ]; then
  model_file="/tmp/${MODEL_STATE_PREFIX}-${safe_id}"
  if [ -f "$model_file" ]; then
    cached_model=$(head -1 "$model_file" 2>/dev/null)
    cached_duration=$(tail -1 "$model_file" 2>/dev/null | grep -E '^[0-9]+$' || echo 0)
    if [ "$duration_ms" -lt "$cached_duration" ] 2>/dev/null; then
      [ "$model" != "unknown" ] && printf '%s\n%s\n' "$model" "$duration_ms" > "$model_file"
    elif [ "$duration_ms" -gt "$cached_duration" ] 2>/dev/null && [ "$model" != "unknown" ]; then
      printf '%s\n%s\n' "$model" "$duration_ms" > "$model_file"
    else
      [ -n "$cached_model" ] && model="$cached_model"
    fi
  elif [ "$model" != "unknown" ]; then
    printf '%s\n%s\n' "$model" "$duration_ms" > "$model_file"
  fi
fi

# Progress bar
filled=$((used * 8 / 100))
[ "$filled" -gt 8 ] && filled=8
case $filled in
  0) bar="────────" ;; 1) bar="━───────" ;; 2) bar="━━──────" ;;
  3) bar="━━━─────" ;; 4) bar="━━━━────" ;; 5) bar="━━━━━───" ;;
  6) bar="━━━━━━──" ;; 7) bar="━━━━━━━─" ;; 8) bar="━━━━━━━━" ;;
esac

# Context color
if [ "$used" -ge 75 ]; then
  ctx_color="\033[91m"
elif [ "$used" -ge 50 ]; then
  ctx_color="\033[93m"
else
  ctx_color="\033[38;5;247m"
fi

dim="\033[38;5;247m"
reset="\033[0m"
sep=" · "

# Git branch
branch=""
if [ -n "$cwd" ]; then
  branch=$(git --no-optional-locks -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$branch" = "HEAD" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# Output
printf "\033[38;5;208m👾 %s${reset}" "$model"
[ -n "$effort" ] && printf "${sep}\033[35m%s${reset}" "$effort"
# Token Weather icon: ☀ <25 ☁ <50 ☂ <75 ☇ <90 ↯ 90+
if [ "$used" -ge 90 ]; then wx="↯"
elif [ "$used" -ge 75 ]; then wx="☇"
elif [ "$used" -ge 50 ]; then wx="☂"
elif [ "$used" -ge 25 ]; then wx="☁"
else wx="☀"
fi
printf "${sep}${ctx_color}%s  %s %s%%${reset}" "$wx" "$bar" "$used"
if [ "$tpm" -gt 0 ]; then
  if [ "$tpm" -ge 10000 ]; then
    tpm_display="$((tpm / 1000))k"
  elif [ "$tpm" -ge 1000 ]; then
    tpm_display="$((tpm / 1000)).$((tpm % 1000 / 100))k"
  else
    tpm_display="$tpm"
  fi
  printf "${sep}\033[93mϟ${reset} ${dim}%s tpm${reset}" "$tpm_display"
fi
# Session prompt cache (Claude Code's prompt_cache): hit%, TTL left, misses + last cause
if [ "$pc_obs" = "true" ] && [ -n "$pc_hit" ]; then
  if [ "$pc_hit" -ge 90 ]; then cache_color="\033[92m"
  elif [ "$pc_hit" -ge 70 ]; then cache_color="\033[93m"
  else cache_color="\033[91m"
  fi
  printf "${sep}${cache_color}★ %s%%${reset}" "$pc_hit"
  now=$(date +%s)
  if [ -n "$pc_exp" ] && [ "$pc_exp" -gt "$now" ]; then
    printf " ${dim}◷ %sm${reset}" "$(( (pc_exp - now + 59) / 60 ))"
  else
    printf " \033[94m❄ cold${reset}"
  fi
  if [ "$pc_miss" -gt 0 ]; then
    # Label the last miss only while it's fresh (<10m); TTL expiry = idle (yellow), others red
    miss_color="\033[91m"; label=""
    if [ $((now - ${pc_miss_at:-0})) -lt 600 ]; then
      case $pc_cause in
        ttl_expired_*) label="idle"; miss_color="\033[93m" ;;
        tools_changed) label="tools" ;;
        system_prompt_changed) label="sys" ;;
        likely_server_side) label="server" ;;
        *) label=${pc_cause%_changed} ;;
      esac
    else
      miss_color="$dim"
    fi
    printf " ${miss_color}✗%s%s${reset}" "$pc_miss" "${label:+ $label}"
  fi
fi
[ -n "$branch" ] && printf "${sep}\033[36m⌥ %s${reset}" "$branch"
printf "\n"
STATUSLINE_EOF

chmod +x "$DEST"

echo "  Installed to ${DEST}"
echo ""
echo "Add this to your ~/.claude/settings.json:"
echo '  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh", "refreshInterval": 30 }'
echo ""
echo "Requires jq (brew install jq)."
