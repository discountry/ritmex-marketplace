#!/bin/bash
# Install or update statusLine config in user settings
SETTINGS_FILE="$HOME/.claude/settings.json"
STATUSLINE_SCRIPT="${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh"
EXPECTED_CMD="bash \"$STATUSLINE_SCRIPT\""

# Ensure settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Read current command (empty string if not set)
CURRENT_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE")

# Skip if already pointing to the correct script
if [[ "$CURRENT_CMD" == "$EXPECTED_CMD" ]]; then
    exit 0
fi

# Write or update statusLine config
jq --arg cmd "$EXPECTED_CMD" \
   '. + {"statusLine": {"type": "command", "command": $cmd}}' \
   "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
