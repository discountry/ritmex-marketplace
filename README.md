# ritmex-marketplace

Local marketplace repo for Claude plugins.

## Contents

- **Marketplace definition**: `.claude-plugin/marketplace.json`
- **Plugin**: `claude-code-notification/`
  - **Plugin manifest**: `claude-code-notification/.claude-plugin/plugin.json`
  - **Hook config**: `claude-code-notification/hooks/hooks.json`
  - **Hook script**: `claude-code-notification/scripts/notification.sh`

## Plugins

### claude-code-notification

Shows a macOS notification when Claude Code triggers the `Notification` hook.

#### How it works

- Expects **JSON on stdin** from the hook runtime (fields like `message`, `notification_type`, `hook_event_name`, `transcript_path`).
- If `terminal-notifier` is available, it uses it (supports icons + click actions).
- Otherwise it falls back to `osascript` (Notification Center).
- For `notification_type=permission_prompt`, clicking the notification attempts to focus **Warp**, otherwise **Terminal**.
- If a `transcript_path` is present (and no focus action is configured), clicking opens the transcript file.

#### Requirements

- **macOS**
- One of:
  - **Recommended**: `terminal-notifier`
  - **Fallback**: `osascript` (usually present on macOS)
- Optional:
  - `jq` (faster JSON parsing)
  - `python3` (JSON parsing fallback if `jq` isn’t installed)

#### Configuration

- **Hook wiring**: `claude-code-notification/hooks/hooks.json`
- **Script path**: `${CLAUDE_PLUGIN_ROOT}/scripts/notification.sh`
- **Env vars**:
  - `CLAUDE_NOTIFY_TITLE` (defaults to `Claude Code`)

## License

GPL-3.0 (see `LICENSE`).
