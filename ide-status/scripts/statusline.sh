#!/bin/bash
# Claude Code Status Line — single-line with color-coded mini progress bars
input=$(cat)

# ── ANSI Colors ────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
WHITE='\033[97m'

# ── Extract fields ─────────────────────────────────────────────────────
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
WEEK=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# ── Duration formatting ────────────────────────────────────────────────
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# ── IDE detection ──────────────────────────────────────────────────────
IDE=""
IDE_DIR="$HOME/.claude/ide"
if [[ -d "$IDE_DIR" ]]; then
    shopt -s nullglob
    lockfiles=("$IDE_DIR"/*.lock)
    shopt -u nullglob
    for lockfile in "${lockfiles[@]}"; do
        IDE_NAME=$(jq -r '.ideName // empty' "$lockfile" 2>/dev/null)
        [[ -n "$IDE_NAME" ]] && IDE="$IDE_NAME" && break
    done
fi

# ── Mini progress bar builder (fixed width 8) ─────────────────────────
# Sets BAR_RESULT for caller
BAR_WIDTH=8
make_bar() {
    local pct=${1:-0}
    local filled=$((pct * BAR_WIDTH / 100))
    [[ $filled -gt $BAR_WIDTH ]] && filled=$BAR_WIDTH
    [[ $filled -lt 0 ]] && filled=0
    local empty=$((BAR_WIDTH - filled))

    local color
    if [[ $pct -ge 90 ]]; then color="$RED"
    elif [[ $pct -ge 70 ]]; then color="$YELLOW"
    else color="$GREEN"; fi

    local f="" e=""
    [[ $filled -gt 0 ]] && printf -v f "%${filled}s" && f="${f// /█}"
    [[ $empty  -gt 0 ]] && printf -v e "%${empty}s"  && e="${e// /░}"

    BAR_RESULT="${color}${f}${DIM}${e}${RESET} ${color}$(printf '%2d' "$pct")%${RESET}"
}

# ── Build single line ──────────────────────────────────────────────────
LINE=""
[[ -n "$IDE" ]] && LINE="${CYAN}${IDE}${RESET} ${DIM}·${RESET} "
LINE="${LINE}${WHITE}${BOLD}${MODEL}${RESET}"
LINE="${LINE} ${DIM}·${RESET} ${YELLOW}\$${COST}${RESET}"
LINE="${LINE} ${DIM}·${RESET} ${DIM}⏱ ${MINS}m${SECS}s${RESET}"

# Context bar
make_bar "$PCT"
LINE="${LINE} ${DIM}·${RESET} ${DIM}ctx${RESET} ${BAR_RESULT}"

# Rate limit bars
if [[ -n "$FIVE_H" ]]; then
    make_bar "$(printf '%.0f' "$FIVE_H")"
    LINE="${LINE} ${DIM}·${RESET} ${DIM}5h${RESET} ${BAR_RESULT}"
fi
if [[ -n "$WEEK" ]]; then
    make_bar "$(printf '%.0f' "$WEEK")"
    LINE="${LINE} ${DIM}·${RESET} ${DIM}7d${RESET} ${BAR_RESULT}"
fi

echo -e "$LINE"
