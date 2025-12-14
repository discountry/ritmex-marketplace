# ritmex-marketplace

Claude Code plugin marketplace hosting `claude-code-notification`.

## Quick start

- Add marketplace (GitHub):
  - `/plugin marketplace add discountry/ritmex-marketplace`
- Install plugin:
  - `/plugin install claude-code-notification@ritmex-marketplace`
- Verify:
  - `/plugin marketplace list`
  - `/plugin`

## Dependencies (macOS)

Recommended (best experience: app icon + click actions):

- Install `terminal-notifier` via Homebrew:
  - `brew install terminal-notifier` (see [`terminal-notifier` Homebrew formula](https://formulae.brew.sh/formula/terminal-notifier))

Fallback (no install needed on most macOS machines):

- `osascript` (Notification Center)

Optional:

- `jq` (faster JSON parsing)
- `python3` (JSON parsing fallback if `jq` isn’t installed)

## Team / project setup (optional)

Add the marketplace automatically for a repo by setting `extraKnownMarketplaces` in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ritmex-marketplace": {
      "source": {
        "source": "github",
        "repo": "discountry/ritmex-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "claude-code-notification@ritmex-marketplace": true
  }
}
```

## Plugin: claude-code-notification

Shows a macOS notification when Claude Code triggers the `Notification` hook.

### Configuration

- **Hook wiring**: `claude-code-notification/hooks/hooks.json`
- **Script**: `claude-code-notification/scripts/notification.sh`
- **Env**:
  - `CLAUDE_NOTIFY_TITLE` (default: `Claude Code`)

### Behavior

- Reads **JSON from stdin** (e.g. `message`, `notification_type`, `hook_event_name`, `transcript_path`).
- Uses `terminal-notifier` if available; otherwise uses `osascript`.
- If `notification_type=permission_prompt`, clicking focuses **Warp** (if installed) or **Terminal**.
- Otherwise, if `transcript_path` is present, clicking opens the transcript file.

## Files

- Marketplace definition: `.claude-plugin/marketplace.json`
- Plugin manifest: `claude-code-notification/.claude-plugin/plugin.json`
- Hooks config: `claude-code-notification/hooks/hooks.json`

## License

GPL-3.0 (see `LICENSE`).
