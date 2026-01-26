---
name: scrape-tokens
description: This skill should be used when the user asks to "scrape tokens", "get token prices", "check crypto prices", "track token data", "get market cap", or mentions CoinGecko or CoinMarketCap data. Automates token market data collection using agent-browser CLI.
---

# Scrape Tokens

Automate token market data collection from CoinGecko and CoinMarketCap using the agent-browser CLI.

## Prerequisites

- `agent-browser` CLI installed and accessible
- Run `agent-browser --help` to verify installation

## Core Workflow

### Step 1: Scrape CoinGecko

Navigate to CoinGecko:

```bash
agent-browser open https://www.coingecko.com/
```

Take snapshot to identify elements:

```bash
agent-browser snapshot -i
```

**CoinGecko provides:**
- Top cryptocurrencies by market cap
- 24h price changes
- Trading volume
- Market cap rankings

### Step 2: Extract Token Data (CoinGecko)

For the main token list, extract:

| Field | Description |
|-------|-------------|
| `rank` | Market cap ranking |
| `name` | Token name |
| `symbol` | Token symbol (BTC, ETH) |
| `price` | Current price in USD |
| `change_24h` | 24-hour price change % |
| `change_7d` | 7-day price change % |
| `market_cap` | Market capitalization |
| `volume_24h` | 24-hour trading volume |

**JavaScript extraction pattern:**
```javascript
const tokens = [];
document.querySelectorAll('table tbody tr').forEach(row => {
  const cells = row.querySelectorAll('td');
  if (cells.length > 5) {
    tokens.push({
      rank: cells[1]?.innerText,
      name: cells[2]?.querySelector('a')?.innerText,
      price: cells[4]?.innerText,
      change_24h: cells[5]?.innerText,
      market_cap: cells[8]?.innerText
    });
  }
});
return tokens;
```

### Step 3: Scrape CoinMarketCap

Navigate to CoinMarketCap:

```bash
agent-browser open https://coinmarketcap.com/
```

Take snapshot:

```bash
agent-browser snapshot -i
```

**CoinMarketCap provides:**
- Similar data to CoinGecko
- Fear & Greed Index
- Trending tokens
- Recently added tokens

### Step 4: Extract Token Data (CMC)

Extract similar fields from CoinMarketCap table.

**Note:** CMC may have different CSS selectors. Use snapshot to identify correct refs.

### Step 5: Extract Trending & New Tokens

Both platforms show trending/new tokens. Capture these separately:

**CoinGecko Trending:**
```bash
agent-browser open https://www.coingecko.com/en/discover
```

**CoinMarketCap Trending:**
```bash
agent-browser open https://coinmarketcap.com/trending-cryptocurrencies/
```

Extract:
- Trending tokens (most searched/traded)
- Recently added tokens
- Top gainers/losers

### Step 6: Compile Results

Merge and deduplicate data from both sources.

**Output format (JSON):**
```json
{
  "scraped_at": "2025-01-26T12:00:00Z",
  "sources": ["CoinGecko", "CoinMarketCap"],
  "market_overview": {
    "total_market_cap": "$3.2T",
    "btc_dominance": "52.3%",
    "fear_greed_index": 72
  },
  "top_tokens": [
    {
      "rank": 1,
      "name": "Bitcoin",
      "symbol": "BTC",
      "price": "$104,500",
      "change_24h": "+2.5%",
      "change_7d": "-1.2%",
      "market_cap": "$2.1T",
      "volume_24h": "$45B"
    }
  ],
  "trending": [
    {
      "name": "Token Name",
      "symbol": "TKN",
      "price": "$0.45",
      "change_24h": "+150%"
    }
  ],
  "new_listings": [
    {
      "name": "New Token",
      "symbol": "NEW",
      "listed_date": "2025-01-25",
      "price": "$0.01"
    }
  ]
}
```

### Step 7: Generate Report

**Markdown format:**
```markdown
# Token Market Report - Jan 26, 2025

## Market Overview

| Metric | Value |
|--------|-------|
| Total Market Cap | $3.2T |
| BTC Dominance | 52.3% |
| Fear & Greed | 72 (Greed) |

## Top 10 Tokens

| Rank | Name | Price | 24h | 7d | Market Cap |
|------|------|-------|-----|-----|------------|
| 1 | Bitcoin (BTC) | $104,500 | +2.5% | -1.2% | $2.1T |
| 2 | Ethereum (ETH) | $3,200 | +1.8% | +3.5% | $380B |

## 🔥 Trending

1. **TokenA** (TKA) - $0.45 (+150%)
2. **TokenB** (TKB) - $1.20 (+85%)

## 🆕 New Listings

- **NewToken** (NEW) - Listed Jan 25 - $0.01

---
*Data from CoinGecko & CoinMarketCap*
```

**Save files:**
- `tokens-YYYY-MM-DD.md`
- `tokens-YYYY-MM-DD.json`

### Step 8: Send Notification (Optional)

If telegram-notification MCP is configured:

```
Tool: mcp__telegram-notification__send_notification
Parameters:
  message: "📊 Market Report - Jan 26\n\n💰 BTC: $104,500 (+2.5%)\n💎 ETH: $3,200 (+1.8%)\n\n🔥 Trending: TokenA +150%"
  parse_mode: "Markdown"
```

## Specific Token Lookup

To get data for a specific token:

```bash
# CoinGecko
agent-browser open https://www.coingecko.com/en/coins/bitcoin

# CoinMarketCap
agent-browser open https://coinmarketcap.com/currencies/bitcoin/
```

Extract detailed token info:
- Price history
- All-time high/low
- Circulating/total supply
- Contract addresses
- Exchange listings

## agent-browser Quick Reference

| Command | Purpose |
|---------|---------|
| `agent-browser open <url>` | Navigate to page |
| `agent-browser snapshot -i` | Get interactive elements |
| `agent-browser click @e1` | Click element |
| `agent-browser evaluate "js"` | Execute JavaScript |
| `agent-browser screenshot` | Capture page image |

## Handling Pagination

For full token lists:

1. **Identify pagination controls:**
   ```bash
   agent-browser snapshot -i
   ```

2. **Click next page:**
   ```bash
   agent-browser click @e[next-button-ref]
   ```

3. **Extract data from each page**

4. **Repeat until desired amount collected**

## Error Handling

- If price data unavailable, show "N/A"
- Handle rate limiting with delays between requests
- Retry failed requests once
- Log errors but continue with available data

## Output Location

Save reports to current directory or specified path:
- Default: `./tokens-YYYY-MM-DD.{md,json}`
