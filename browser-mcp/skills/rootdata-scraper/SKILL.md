---
name: rootdata-scraper
description: Using Browser MCP, scrape rootdata fundraising data (Token Issuance = No Token) from https://www.rootdata.com/Fundraising
---

# Rootdata Scraper Skill

## Instructions

### Step 1: Get Current Date
First, get the current date to filter today's projects:

```python
from datetime import datetime

now = datetime.now()
today_date = now.strftime("%b %d")  # Format: "Dec 24"
print(f"Today's date: {today_date}")
```

### Step 2: Navigate to Fundraising Page
Open the RootData fundraising page using Browser MCP:

- Use `browser_navigate` action with URL: `https://www.rootdata.com/Fundraising`
- Wait for the page to fully load using `browser_wait_for` (wait for text "Project" or table element to appear)

### Step 2.5: Select "No Token" in Token Issuance Filter
After the page loads, ensure the **Token Issuance** filter is set to **No Token** so that only non-token fundraising projects are shown:

1. Use `browser_evaluate` to run JavaScript that:
   - Locates the active **Token Issuance** collapse section.
   - Finds the radio/label whose text includes `"No Token"`.
   - Clicks that radio input or its label to apply the filter.

2. Example JavaScript:
```javascript
(function () {
  // Ensure the Token Issuance collapse section is open (defensive, in case UI changes)
  const headers = Array.from(
    document.querySelectorAll('.el-collapse-item__header')
  );
  const tokenIssuanceHeader = headers.find(h =>
    h.textContent.trim().includes('Token Issuance')
  );
  if (tokenIssuanceHeader && !tokenIssuanceHeader.classList.contains('is-active')) {
    tokenIssuanceHeader.click();
  }

  // Find the "No Token" radio within the Token Issuance section
  const radioLabels = Array.from(
    document.querySelectorAll('label.el-radio')
  );
  const noTokenLabel = radioLabels.find(label =>
    label.textContent.trim().includes('No Token')
  );

  if (!noTokenLabel) {
    return { success: false, reason: '"No Token" radio not found' };
  }

  const input = noTokenLabel.querySelector('input[type="radio"]');
  if (input) {
    input.click();
  } else {
    noTokenLabel.click();
  }

  return { success: true };
})();
```

3. After clicking **No Token**, use `browser_wait_for` to wait until the table finishes reloading (e.g., wait for a row with today's date to appear, or for the loading spinner to disappear) before proceeding to table extraction.

### Step 3: Capture Page Snapshot
Take a snapshot to understand the page structure:

- Use `browser_snapshot` to get the accessibility tree and identify the table element
- Look for the table with `role="table"` and class containing "table" or "b-table"
- The table should have columns: Project, Round, Amount, Valuation, Date, Source, Investors

### Step 4: Extract Today's Projects from Table
Extract all project links that match today's date:

1. Use `browser_evaluate` to execute JavaScript that:
   - Finds all table rows (`<tr role="row">`)
   - For each row, checks the Date column (5th column, `aria-colindex="5"`)
   - Extracts the date text and compares it with today's date format
   - If date matches, extracts the project link from the Project column (1st column)
   - The link is in format: `/Projects/detail/{ProjectName}?k={encodedId}`

2. JavaScript extraction code:
```javascript
(function() {
  const today = new Date();
  const todayStr = today.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const rows = document.querySelectorAll('table tbody tr[role="row"]');
  const projects = [];
  
  rows.forEach(row => {
    const dateCell = row.querySelector('td[aria-colindex="5"]');
    if (dateCell) {
      const dateText = dateCell.textContent.trim();
      if (dateText === todayStr) {
        const projectLink = row.querySelector('td[aria-colindex="1"] a[href*="/Projects/detail/"]');
        if (projectLink) {
          const href = projectLink.getAttribute('href');
          const projectName = projectLink.textContent.trim();
          projects.push({
            name: projectName,
            url: 'https://www.rootdata.com' + href
          });
        }
      }
    }
  });
  
  return projects;
})();
```

3. Store the list of project URLs for later processing

### Step 5: Extract Project Details
For each project URL found in Step 4, perform the following:

#### 5.1 Navigate to Project Detail Page
- Use `browser_navigate` to open each project URL
- Wait for page load using `browser_wait_for` (wait for project name in `<h1 class="name">`)

#### 5.2 Extract Project Name
- Use `browser_evaluate` to extract text from `<h1 class="name">` element
- Store as `project_name`

#### 5.3 Extract Official Website
- Use `browser_evaluate` to find link in `<div class="links">` section
- Look for `<a>` tag with `href` starting with `http://` or `https://` (excluding X/Twitter and LinkedIn)
- Extract the `href` attribute, store as `official_website`

#### 5.4 Extract X (Twitter) Address
- Use `browser_evaluate` to find link in `<div class="links">` section
- Look for `<a>` tag with `href` containing `x.com` or `twitter.com`
- Extract the `href` attribute, store as `twitter_url`

#### 5.5 Extract Total Raised
- Use `browser_evaluate` to find `<div class="rank_container">` section
- Look for `<div class="rank_item">` containing "Total Raised:"
- Extract the value from `<span class="rank_value">` element
- Store as `total_raised` (format: "$XXM" or "--")

#### 5.6 Extract Core Investors
- Use `browser_evaluate` to find `<div class="comparison_table_tr">` containing "Core Investors"
- Extract all investor names from `<a class="investor_item_name">` elements
- Store as array `investors`

#### 5.7 Extract Tags
- Use `browser_evaluate` to find `<div class="side_bar_info">` section
- Look for `<div class="tag_item">` containing "Tags:"
- Extract all tag text from `<a class="chips">` elements
- Store as array `tags`

#### 5.8 Extract Founded Year
- Use `browser_evaluate` to find `<div class="side_bar_info">` section
- Look for `<div class="item">` containing "Founded:"
- Extract the year from `<span class="info_text">` element
- Store as `founded_year`

#### 5.9 Check for Premium Investors
Compare the `investors` list against the following premium investor list:
- Coinbase Ventures
- Galaxy
- VanEck
- Y Combinator
- Polychain Capital
- YZi Labs (Prev. Binance Labs)
- Pantera Capital
- Blockchain Capital
- Anatoly Yakovenko
- Delphi Ventures
- Multicoin Capital
- Santiago Roel Santos
- HashKey Capital
- Paradigm
- Balaji Srinivasan
- Sequoia Capital
- Andreessen Horowitz (a16z crypto)
- Dragonfly
- Sandeep Nailwal
- ConsenSys
- a16z CSX
- Stani Kulechov
- BlackRock
- Bryan Pellegrino
- Raj Gokal
- The Spartan Group
- Circle
- Paul Veradittakit
- Vitalik Buterin
- Alex Svanevik
- Arthur Hayes

- If any investor matches (case-insensitive, partial match allowed for variations like "Galaxy Ventures" matching "Galaxy"), add `is_premium: true` flag
- Otherwise, `is_premium: false`

### Step 6: Compile Results
After processing all projects, compile the data into a structured format:

```python
projects_data = [
    {
        "name": "Project Name",
        "official_website": "https://...",
        "twitter_url": "https://x.com/...",
        "total_raised": "$XXM",
        "investors": ["Investor1", "Investor2", ...],
        "tags": ["Tag1", "Tag2", ...],
        "founded_year": "2022",
        "is_premium": True/False
    },
    ...
]
```

### Step 7: Generate Markdown Table
Format the results as a beautiful markdown table:

```markdown
# Today's Crypto Fundraising Projects

| Project | Website | Twitter | Total Raised | Investors | Tags | Founded | Premium |
|---------|---------|---------|---------------|-----------|------|----------|---------|
| Project Name ⭐ | [Link](url) | [@handle](url) | $XXM | Investor1, Investor2 | Tag1, Tag2 | 2022 | ⭐ |
```

**Table Formatting Rules:**
- Add ⭐ emoji after project name if `is_premium: true`
- Website column: Show domain name as link text, full URL as link target
- Twitter column: Show "@handle" format, extract handle from URL
- Investors column: List all investors separated by commas, max 3 visible with "+X more" if needed
- Tags column: List all tags separated by commas
- Premium column: Show ⭐ if premium, empty otherwise

### Step 8: Handle Edge Cases
- If a project detail page fails to load, skip it and continue with next project
- If any field is missing (shows "--" or empty), display "N/A" in the table
- If multiple official websites exist, use the first non-social-media link
- Handle date format variations (e.g., "Dec 24" vs "Dec 24, 2024")

### Step 9: Error Handling
- If no projects found for today, display: "No new fundraising projects found for today."
- If browser navigation fails, retry once before skipping
- Log any errors but continue processing remaining projects

### Step 10: Final Output
Present the final markdown table with all today's projects, sorted by total raised amount (descending), with premium projects highlighted.