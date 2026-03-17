#!/bin/bash
# Install statusLine config into user settings if not already present
SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"

# Ensure settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Check if statusLine is already configured
if jq -e '.statusLine' "$SETTINGS_FILE" > /dev/null 2>&1; then
    exit 0
fi

# Add statusLine config
jq --arg cmd "bash \"$STATUSLINE_SCRIPT\"" '. + {"statusLine": {"type": "command", "command": $cmd}}' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
