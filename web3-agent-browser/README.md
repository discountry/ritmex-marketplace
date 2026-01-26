# web3-agent-browser

Web3 data scraping automation plugin using `agent-browser` CLI. Collects airdrops, fundraising, and token market data from popular Web3 platforms.

## Features

- **Airdrop Tracking**: Scrape airdrop information from CryptoRank, DeFiLlama
- **Fundraising Data**: Collect fundraising/investment data from RootData
- **Token Market Data**: Gather token information from CoinGecko, CoinMarketCap
- **Automated Reports**: Generate comprehensive reports with Telegram notifications

## Prerequisites

- `agent-browser` CLI installed and configured
- Telegram notification MCP (optional, for notifications)

## Skills

| Skill | Description |
|-------|-------------|
| `/web3-agent-browser:scrape-airdrops` | Scrape airdrop data from CryptoRank and DeFiLlama |
| `/web3-agent-browser:scrape-fundraising` | Scrape fundraising data from RootData |
| `/web3-agent-browser:scrape-tokens` | Scrape token market data from CoinGecko and CoinMarketCap |
| `/web3-agent-browser:web3-report` | Generate comprehensive Web3 report with Telegram notification |

## Agent

- **web3-scraper**: Autonomous agent for complex multi-site scraping tasks

## Usage

```bash
# Scrape today's airdrops
/web3-agent-browser:scrape-airdrops

# Get fundraising data
/web3-agent-browser:scrape-fundraising

# Check token prices
/web3-agent-browser:scrape-tokens

# Generate full report
/web3-agent-browser:web3-report
```

## Output

All skills generate:
- **Markdown file**: Human-readable report saved locally
- **JSON file**: Structured data for programmatic use
- **Telegram notification** (optional): Summary sent to configured channel

## Installation

```bash
claude --plugin-dir /path/to/web3-agent-browser
```

Or copy to your project's `.claude-plugin/` directory.
