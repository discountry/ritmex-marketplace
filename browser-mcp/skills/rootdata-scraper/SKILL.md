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
After the page loads, you need to **first expand the Token Issuance menu**, then select **No Token** filter. The "No Token" option is hidden until the menu is expanded:

1. **First, click the "Token Issuance" collapse button to expand the menu:**
   - Use `browser_click` or `browser_evaluate` to find and click the Token Issuance header button
   - Look for element with `role="tab"` containing text "Token Issuance" or element with `id="el-collapse-head-7949"` (or similar dynamic ID)
   - The button structure: `<div role="tab"><div role="button" class="el-collapse-item__header">Token Issuance</div></div>`
   - Wait for the menu to expand using `browser_wait_for` (wait for text "No Token" to appear)

2. **Then, select the "No Token" radio option:**
   - Use `browser_evaluate` to run JavaScript that finds and clicks the "No Token" radio button
   - The radio is inside the expanded panel: `<div role="tabpanel" id="el-collapse-content-7949">` (or similar dynamic ID)
   - Look for `<label role="radio">` containing text "No Token"

3. **JavaScript code to handle both steps:**
```javascript
(function () {
  // Step 1: Find and click Token Issuance header to expand the menu
  const headers = Array.from(
    document.querySelectorAll('.el-collapse-item__header')
  );
  const tokenIssuanceHeader = headers.find(h =>
    h.textContent.trim().includes('Token Issuance')
  );
  
  if (!tokenIssuanceHeader) {
    return { success: false, reason: 'Token Issuance header not found' };
  }

  // Check if already expanded (has is-active class on parent)
  const collapseItem = tokenIssuanceHeader.closest('.el-collapse-item');
  const isExpanded = collapseItem && collapseItem.classList.contains('is-active');
  
  if (!isExpanded) {
    // Click to expand
    tokenIssuanceHeader.click();
    // Wait a moment for the menu to expand
    return { success: true, action: 'expanded', needsWait: true };
  }

  // Step 2: Find and click "No Token" radio (menu is now expanded)
  const radioLabels = Array.from(
    document.querySelectorAll('label.el-radio')
  );
  const noTokenLabel = radioLabels.find(label =>
    label.textContent.trim().includes('No Token')
  );

  if (!noTokenLabel) {
    return { success: false, reason: '"No Token" radio not found. Menu may not be expanded yet.' };
  }

  // Check if already selected
  const isChecked = noTokenLabel.classList.contains('is-checked');
  if (isChecked) {
    return { success: true, action: 'already_selected' };
  }

  // Click the radio input or label
  const input = noTokenLabel.querySelector('input[type="radio"]');
  if (input) {
    input.click();
  } else {
    noTokenLabel.click();
  }

  return { success: true, action: 'selected' };
})();
```

4. **Important:** After expanding the menu, wait 500ms-1s using `browser_wait_for` (time-based wait) before trying to click "No Token", to ensure the menu animation completes.

5. After clicking **No Token**, use `browser_wait_for` to wait until the table finishes reloading (e.g., wait for a row with today's date to appear, or for the loading spinner to disappear) before proceeding to table extraction.

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

### Step 7: Generate Markdown Output
Format the results as beautiful markdown with project separators (avoid tables for better CLI rendering):

```markdown
# Today's Crypto Fundraising Projects (Dec 24, 2025)

---

## Project Name ⭐

**Website:** [project.com](https://project.com)  
**Twitter:** [@handle](https://x.com/handle)  
**Total Raised:** $52M  
**Investors:** Investor1, Investor2, Investor3  
**Tags:** Tag1, Tag2, Tag3  
**Founded:** 2022  
**Premium:** ⭐

---

## Another Project

**Website:** [another.com](https://another.com)  
**Twitter:** [@another](https://x.com/another)  
**Total Raised:** $2M  
**Investors:** InvestorA, InvestorB  
**Tags:** DeFi, DEX  
**Founded:** 2025  

---
```

**Formatting Rules:**
- Use `---` horizontal rule as separator between projects
- Add ⭐ emoji after project name in heading if `is_premium: true`
- Website: Show full URL as link, extract domain name for display
- Twitter: Extract handle from URL, show as `@handle` format with link
- Investors: List all investors separated by commas (no truncation)
- Tags: List all tags separated by commas
- Premium: Show "⭐" on a separate line if premium, omit the line if not premium
- Use bold labels (`**Label:**`) for field names
- Keep consistent spacing and formatting

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

### Step 11: Send to Telegram (Optional)
After generating the final markdown output, check if the user has configured the `telegram-notification` MCP server:

Tool name: send_notification

Full name: mcp__telegram-notification__send_notification 

Parameters:
- message (required): string - The message to send

3. **If telegram-notification is NOT configured:**

   - Skip this step and only display the results in the terminal/chat