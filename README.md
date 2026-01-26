# ritmex-marketplace

Claude Code plugin marketplace hosting `claude-code-notification`, `browser-mcp`, `remote-figma`, `ide-status`, and `web3-agent-browser` plugins.

## Quick start

- Add marketplace (GitHub):
  - `/plugin marketplace add discountry/ritmex-marketplace`
- Install plugins:
  - `/plugin install claude-code-notification@ritmex-marketplace`
  - `/plugin install browser-mcp@ritmex-marketplace`
  - `/plugin install remote-figma@ritmex-marketplace`
  - `/plugin install ide-status@ritmex-marketplace`
  - `/plugin install web3-agent-browser@ritmex-marketplace`
- Verify:
  - `/plugin marketplace list`
  - `/plugin`

## Plugins

This marketplace hosts the following plugins:

| Plugin | Description |
|--------|-------------|
| `claude-code-notification` | Shows macOS notifications for Claude Code hooks |
| `browser-mcp` | Browser automation via MCP with Google Search command and Rootdata scraper skill |
| `remote-figma` | Figma design integration via MCP with design implementation skills |
| `ide-status` | Display IDE connection status and model info in Claude Code status line |
| `web3-agent-browser` | Web3 data scraping automation using agent-browser CLI for airdrops, fundraising, and token data |

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

## Dependencies for web3-agent-browser

- `agent-browser` CLI installed and configured
- Telegram notification MCP (optional, for notifications)

### Setting up Telegram Notifications

The `web3-agent-browser` plugin can send reports to Telegram. To enable this:

1. Get a Telegram Bot Token from [@BotFather](https://t.me/botfather)
2. Get your Chat ID (your personal chat ID or channel ID)
3. Add the Telegram notification MCP server:

```bash
claude mcp add --transport stdio telegram-notification --scope user \
  --env TELEGRAM_BOT_TOKEN=YOUR_BOT_TOKEN \
  --env TELEGRAM_CHAT_ID=YOUR_CHAT_ID \
  -- npx -y telegram-notification-mcp
```

**Manual Configuration** (add to `~/.claude/settings.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "telegram-notification": {
      "command": "npx",
      "args": ["telegram-notification-mcp@latest"],
      "env": {
        "TELEGRAM_BOT_TOKEN": "YOUR_TELEGRAM_BOT_TOKEN",
        "TELEGRAM_CHAT_ID": "YOUR_TELEGRAM_CHAT_ID"
      }
    }
  }
}
```

Once configured, the `web3-report` skill will automatically send summaries to your Telegram.

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
    "browser-mcp@ritmex-marketplace": true,
    "remote-figma@ritmex-marketplace": true,
    "ide-status@ritmex-marketplace": true,
    "web3-agent-browser@ritmex-marketplace": true
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

## Plugin: ide-status

Displays IDE connection status and model information in Claude Code's status line.

### Features

- Shows connected IDE name (e.g., VS Code, Cursor)
- Displays current model name
- Shows session cost in USD
- Shows context window usage percentage

### Configuration

- **Hook wiring**: `ide-status/hooks/hooks.json`
- **Script**: `ide-status/scripts/statusline.sh`

### Output Format

```
VS Code · Claude 4 Sonnet · $0.15 · ctx 42%
```

When no IDE is connected:
```
Claude 4 Sonnet · $0.15 · ctx 42%
```

### Dependencies

- `jq` (required for JSON parsing)

## Files

- Marketplace definition: `.claude-plugin/marketplace.json`
- Plugin manifests:
  - `claude-code-notification/.claude-plugin/plugin.json`
  - `browser-mcp/.claude-plugin/plugin.json`
  - `remote-figma/.claude-plugin/plugin.json`
  - `ide-status/.claude-plugin/plugin.json`
  - `web3-agent-browser/.claude-plugin/plugin.json`
- Hooks config:
  - `claude-code-notification/hooks/hooks.json`
  - `ide-status/hooks/hooks.json`
- MCP configuration:
  - `browser-mcp/.mcp.json`
  - `remote-figma/.mcp.json`
- Commands: `browser-mcp/commands/google-search.md`
- Skills:
  - `browser-mcp/skills/rootdata-scraper/SKILL.md`
  - `remote-figma/skills/implement-design/SKILL.md`
  - `remote-figma/skills/code-connect-components/SKILL.md`
  - `remote-figma/skills/create-design-system-rules/SKILL.md`
  - `web3-agent-browser/skills/scrape-airdrops/SKILL.md`
  - `web3-agent-browser/skills/scrape-fundraising/SKILL.md`
  - `web3-agent-browser/skills/scrape-tokens/SKILL.md`
  - `web3-agent-browser/skills/web3-report/SKILL.md`
- Agents:
  - `web3-agent-browser/agents/web3-scraper.md`

## License

GPL-3.0 (see `LICENSE`).
