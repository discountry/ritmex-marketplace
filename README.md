# ritmex-marketplace

Claude Code plugin marketplace hosting `claude-code-notification` and `browser-mcp` plugins.

## Quick start

- Add marketplace (GitHub):
  - `/plugin marketplace add discountry/ritmex-marketplace`
- Install plugins:
  - `/plugin install claude-code-notification@ritmex-marketplace`
  - `/plugin install browser-mcp@ritmex-marketplace`
- Verify:
  - `/plugin marketplace list`
  - `/plugin`

## Plugins

This marketplace hosts the following plugins:

| Plugin | Description |
|--------|-------------|
| `claude-code-notification` | Shows macOS notifications for Claude Code hooks |
| `browser-mcp` | Browser automation via MCP with Google Search command and Rootdata scraper skill |

## Dependencies for claude-code-notification (macOS)

Recommended (best experience: app icon + click actions):

- Install `terminal-notifier` via Homebrew:
  - `brew install terminal-notifier` (see [`terminal-notifier` Homebrew formula](https://formulae.brew.sh/formula/terminal-notifier))

Fallback (no install needed on most macOS machines):

- `osascript` (Notification Center)

Optional:

- `jq` (faster JSON parsing)
- `python3` (JSON parsing fallback if `jq` isn’t installed)

## Dependencies for browser-mcp

- Node.js and npm (for npx)
- The plugin uses `@browsermcp/mcp` package via npx (automatically installed)

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
    "claude-code-notification@ritmex-marketplace": true,
    "browser-mcp@ritmex-marketplace": true
  }
}
```

## Plugin: claude-code-notification

Shows macOS notifications and plays sounds for Claude Code hooks (Notification and Stop).

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
- For `Stop` hook events, plays a system sound (afplay).

## Plugin: browser-mcp

Browser automation via MCP (Model Context Protocol) with tools for web navigation, Google search, and scraping Rootdata fundraising data.

### Features

- **Google Search command**: Search Google and summarize results
- **Rootdata Scraper skill**: Scrape fundraising data with Token Issuance = No Token filter

### Usage

- Install plugin: `/plugin install browser-mcp@ritmex-marketplace`
- Use `/google-search` command
- Use `/rootdata-scraper` skill

## Files

- Marketplace definition: `.claude-plugin/marketplace.json`
- Plugin manifests:
  - `claude-code-notification/.claude-plugin/plugin.json`
  - `browser-mcp/.claude-plugin/plugin.json`
- Hooks config: `claude-code-notification/hooks/hooks.json`
- MCP configuration: `browser-mcp/.mcp.json`
- Commands: `browser-mcp/commands/google-search.md`
- Skills: `browser-mcp/skills/rootdata-scraper/SKILL.md`

## License

GPL-3.0 (see `LICENSE`).
