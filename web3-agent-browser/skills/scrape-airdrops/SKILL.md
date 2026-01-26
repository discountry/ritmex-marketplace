---
name: scrape-airdrops
description: This skill should be used when the user asks to "scrape airdrops", "get airdrop data", "find new airdrops", "track airdrops", "check airdrop updates", or mentions CryptoRank or DeFiLlama airdrops. Automates airdrop data collection using agent-browser CLI.
---

# Scrape Airdrops

Automate airdrop data collection from CryptoRank and DeFiLlama using the agent-browser CLI.

## Prerequisites

- `agent-browser` CLI installed and accessible
- Run `agent-browser --help` to verify installation

## Core Workflow

### Step 1: Initialize Browser

Open the target airdrop platform:

```bash
agent-browser open https://cryptorank.io/airdrops
```

Wait for page load, then take a snapshot:

```bash
agent-browser snapshot -i
```

### Step 2: Navigate and Filter (CryptoRank)

The CryptoRank airdrops page shows ongoing and upcoming airdrops.

1. **Take interactive snapshot** to identify filter elements:
   ```bash
   agent-browser snapshot -i
   ```

2. **Apply filters** if needed (e.g., status = Active):
   - Look for filter buttons with refs like `@e1`, `@e2`
   - Click to apply: `agent-browser click @e5`

3. **Wait for content update** after filtering:
   ```bash
   agent-browser snapshot -i
   ```

### Step 3: Extract Airdrop Data

For each airdrop entry visible, extract:

| Field | Description |
|-------|-------------|
| `name` | Project name |
| `status` | Active, Upcoming, Ended |
| `platform` | Blockchain (ETH, SOL, etc.) |
| `total_value` | Estimated airdrop value |
| `end_date` | Airdrop end date |
| `requirements` | Participation requirements |
| `link` | Official airdrop page |

**JavaScript extraction pattern:**
```bash
agent-browser evaluate "document.querySelectorAll('.airdrop-card').forEach(card => { console.log(card.innerText) })"
```

### Step 4: Scrape DeFiLlama Airdrops

Navigate to DeFiLlama:

```bash
agent-browser open https://defillama.com/airdrops
```

DeFiLlama provides a different data format focused on:
- Confirmed airdrops
- Potential airdrops (projects with no token yet)
- Historical airdrop data

Extract using similar snapshot and evaluate patterns.

### Step 5: Compile Results

Merge data from both sources, deduplicating by project name.

**Output format (JSON):**
```json
{
  "scraped_at": "2025-01-26T12:00:00Z",
  "sources": ["CryptoRank", "DeFiLlama"],
  "airdrops": [
    {
      "name": "Project Name",
      "status": "Active",
      "platform": "Ethereum",
      "estimated_value": "$500",
      "end_date": "2025-02-15",
      "requirements": ["Hold NFT", "Use protocol"],
      "source": "CryptoRank",
      "link": "https://..."
    }
  ]
}
```

### Step 6: Generate Report

Create both Markdown and JSON outputs.

**Markdown format:**
```markdown
# Airdrop Report - Jan 26, 2025

## Active Airdrops

### Project Name ⭐
- **Platform:** Ethereum
- **Estimated Value:** $500
- **End Date:** Feb 15, 2025
- **Requirements:** Hold NFT, Use protocol
- **Link:** [Official Page](https://...)

---
```

**Save files:**
- `airdrops-YYYY-MM-DD.md` - Human-readable report
- `airdrops-YYYY-MM-DD.json` - Structured data

### Step 7: Send Notification (Optional)

If telegram-notification MCP is configured, send summary:

```
Tool: mcp__telegram-notification__send_notification
Parameters:
  message: "🪂 Airdrop Report - Jan 26\n\n✅ 5 Active Airdrops\n⏳ 3 Upcoming\n\nTop: ProjectA ($1000), ProjectB ($500)"
  parse_mode: "Markdown"
```

## agent-browser Quick Reference

| Command | Purpose |
|---------|---------|
| `agent-browser open <url>` | Navigate to page |
| `agent-browser snapshot -i` | Get interactive elements with refs |
| `agent-browser click @e1` | Click element by ref |
| `agent-browser fill @e2 "text"` | Fill input field |
| `agent-browser evaluate "js"` | Execute JavaScript |
| `agent-browser screenshot` | Capture page image |

## Handling Dynamic Content

Many airdrop pages use infinite scroll or lazy loading:

1. **Scroll to load more:**
   ```bash
   agent-browser evaluate "window.scrollTo(0, document.body.scrollHeight)"
   ```

2. **Wait and re-snapshot:**
   ```bash
   agent-browser snapshot -i
   ```

3. **Repeat until all content loaded**

## Error Handling

- If page fails to load, retry once with increased timeout
- If element not found, re-take snapshot to refresh refs
- Skip individual airdrops that fail extraction, continue with others
- Log errors but don't stop the entire scrape

## Output Location

Save reports to user's current directory or specified output path:
- Default: `./airdrops-YYYY-MM-DD.{md,json}`
- Custom: Use path specified by user
