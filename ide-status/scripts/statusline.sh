#!/bin/bash
# Claude Code Status Line - Minimal Design

input=$(cat)

# Extract info
MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf "%.2f")
CTX=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | xargs printf "%d")

# Detect IDE connection
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

# Build status line
if [[ -n "$IDE" ]]; then
    echo "$IDE · $MODEL · \$$COST · ctx ${CTX}%"
else
    echo "$MODEL · \$$COST · ctx ${CTX}%"
fi
