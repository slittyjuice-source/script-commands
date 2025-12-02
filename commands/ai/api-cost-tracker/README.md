# API Cost Tracker & Optimizer

This Script Command surfaces AI API spending across providers, budgets, and optimization opportunities directly in Raycast.

## Features
- Month-to-date spend and projected month-end spend across providers.
- Per-project breakdown with budget thresholds and recent usage pace (calls or tokens, depending on the provider's unit).
- Provider budgets plus alerts when 90%+ of any budget is consumed.
- Optional web-scraped pricing (with manual fallbacks) so you stay aligned with current rates.
- Optimization hints when part of a workload can move to a cheaper alternative (e.g., Vertex AI to Claude Haiku).

## Setup
1. Run the command once to generate a starter configuration at `~/.config/raycast/api-cost-tracker/config.json`.
2. Edit the file to match your providers and usage. Key fields:
   - `currency`: Currency symbol to show in Raycast.
   - `overallMonthlyBudget`: Global budget for all providers.
   - `providers`: Map of providers with `pricing` (manual or `web` + `regex` + `fallbackPrice`), optional `monthlyBudget`, and an `optimization` block pointing to a cheaper `alternative`.
   - `projects`: Each entry tracks one workload with `provider`, `monthToDate` usage, optional `recent7Days` usage for better projections (set tokens for token-priced providers), and an optional `threshold.monthlyBudget` per project.
3. Rerun the command to view spend, projections, and optimization guidance.

### Pricing configuration
- **Manual pricing**
  ```json
  "pricing": { "type": "manual", "unit": "call", "price": 0.008 }
  ```
- **Web-scraped pricing with fallback**
  ```json
  "pricing": {
    "type": "web",
    "unit": "call",
    "url": "https://example.com/pricing",
    "regex": "\\$([0-9.]+) per call",
    "fallbackPrice": 0.012,
    "note": "Uses manual price if scraping fails"
  }
  ```

### Optimization guidance
Attach an optimization hint to a provider to project savings when part of a workload can migrate to a cheaper API:
```json
"optimization": {
  "alternative": "claude_haiku",
  "eligibleUsageRatio": 0.73,
  "note": "Chronology extraction can use Claude Haiku with similar quality"
}
```

The command will estimate savings by comparing the current provider's price with the alternative for the eligible share of projected usage.

If a project references a provider that is missing from the config, the command will flag it so you can fix the configuration before relying on the totals.
