---
name: scrape-fundraising
description: This skill should be used when the user asks to "scrape fundraising", "get funding data", "find new investments", "track crypto fundraising", "check RootData", or mentions Web3 fundraising rounds. Automates fundraising data collection from RootData using agent-browser CLI.
---

# Scrape Fundraising

Automate Web3 fundraising data collection from RootData using the agent-browser CLI.

## Prerequisites

- `agent-browser` CLI installed and accessible
- Run `agent-browser --help` to verify installation

## Core Workflow

### Step 1: Navigate to RootData Fundraising

```bash
agent-browser open https://www.rootdata.com/Fundraising
```

Wait for page load and take snapshot:

```bash
agent-browser snapshot -i
```

### Step 2: Apply Token Issuance Filter

Filter for projects without tokens (higher airdrop potential):

1. **Expand Token Issuance menu:**
   - Find and click the "Token Issuance" collapse button
   - Look for element with `role="tab"` containing "Token Issuance"
   ```bash
   agent-browser click @e[token-issuance-ref]
   ```

2. **Wait for menu expansion:**
   ```bash
   agent-browser snapshot -i
   ```

3. **Select "No Token" option:**
   - Find radio button with "No Token" label
   ```bash
   agent-browser click @e[no-token-ref]
   ```

4. **Wait for table reload:**
   ```bash
   agent-browser snapshot -i
   ```

### Step 3: Extract Today's Projects

Current date: Use `date` command to get today's date.

For each table row, check if the date matches today:

**JavaScript extraction:**
```javascript
const rows = document.querySelectorAll('tr[role="row"]');
const todayProjects = [];
rows.forEach(row => {
  const dateCell = row.querySelector('[aria-colindex="5"]');
  if (dateCell && dateCell.innerText.includes('Jan 26')) {
    const projectLink = row.querySelector('a[href*="/Projects/detail/"]');
    if (projectLink) {
      todayProjects.push(projectLink.href);
    }
  }
});
return todayProjects;
```

### Step 4: Extract Project Details

For each project URL found:

1. **Navigate to project page:**
   ```bash
   agent-browser open https://www.rootdata.com/Projects/detail/ProjectName?k=xxx
   ```

2. **Extract data fields:**

| Field | Selector | Description |
|-------|----------|-------------|
| `name` | `h1.name` | Project name |
| `official_website` | `.links a[href^="http"]` | Official website (exclude social) |
| `twitter_url` | `.links a[href*="x.com"]` | X/Twitter link |
| `total_raised` | `.rank_value` in "Total Raised" | Funding amount |
| `investors` | `.investor_item_name` | List of investors |
| `tags` | `.chips` in Tags section | Project categories |
| `founded_year` | `.info_text` in Founded section | Year founded |

### Step 5: Check Premium Investors

Compare investors against premium list:

**Premium Investors:**
- Coinbase Ventures, Galaxy, VanEck, Y Combinator
- Polychain Capital, YZi Labs, Pantera Capital
- Blockchain Capital, Paradigm, Sequoia Capital
- Andreessen Horowitz (a16z), Dragonfly
- BlackRock, Circle, ConsenSys
- Vitalik Buterin, Balaji Srinivasan

Mark `is_premium: true` if any investor matches (case-insensitive, partial match allowed).

### Step 6: Compile Results

**Output format (JSON):**
```json
{
  "scraped_at": "2025-01-26T12:00:00Z",
  "source": "RootData",
  "filter": "No Token",
  "projects": [
    {
      "name": "Project Name",
      "official_website": "https://project.com",
      "twitter_url": "https://x.com/project",
      "total_raised": "$5M",
      "investors": ["Investor1", "Investor2"],
      "tags": ["DeFi", "Infrastructure"],
      "founded_year": "2024",
      "is_premium": true
    }
  ]
}
```

### Step 7: Generate Report

**Markdown format:**
```markdown
# Today's Crypto Fundraising - Jan 26, 2025

---

## Project Name ⭐

**Website:** [project.com](https://project.com)
**Twitter:** [@project](https://x.com/project)
**Total Raised:** $5M
**Investors:** Investor1, Investor2
**Tags:** DeFi, Infrastructure
**Founded:** 2024
**Premium:** ⭐

---
```

**Formatting rules:**
- Add ⭐ after project name if `is_premium: true`
- Use `---` horizontal rule between projects
- Show website domain as link text
- Extract Twitter handle from URL

**Save files:**
- `fundraising-YYYY-MM-DD.md`
- `fundraising-YYYY-MM-DD.json`

### Step 8: Send Notification (Optional)

If telegram-notification MCP is configured:

```
Tool: mcp__telegram-notification__send_notification
Parameters:
  message: "💰 Fundraising Report - Jan 26\n\n📊 3 New Projects\n⭐ 1 Premium\n\nTop: ProjectA ($10M by a16z)"
  parse_mode: "Markdown"
```

## agent-browser Quick Reference

| Command | Purpose |
|---------|---------|
| `agent-browser open <url>` | Navigate to page |
| `agent-browser snapshot -i` | Get interactive elements |
| `agent-browser click @e1` | Click element |
| `agent-browser evaluate "js"` | Execute JavaScript |

## Error Handling

- If project page fails, skip and continue with next
- If field is missing, display "N/A"
- Handle date format variations (e.g., "Jan 26" vs "Jan 26, 2025")
- Retry navigation once on failure

## Output Location

Save reports to current directory or specified path:
- Default: `./fundraising-YYYY-MM-DD.{md,json}`
