#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title API Cost Tracker & Optimizer
// @raycast.mode fullOutput
// @raycast.packageName AI Cost Tracker
// @raycast.icon 💸
// @raycast.refreshTime 1h

// Optional parameters:
// @raycast.description Monitor AI API usage, spending projections, budgets, and optimization ideas
// @raycast.author Raycast Community
// @raycast.authorURL https://github.com/raycast/script-commands

const fs = require("fs");
const https = require("https");
const os = require("os");
const path = require("path");

const CONFIG_DIR = path.join(os.homedir(), ".config", "raycast", "api-cost-tracker");
const CONFIG_PATH = path.join(CONFIG_DIR, "config.json");

const today = new Date();
const daysInMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
const dayOfMonth = today.getDate();

function ensureConfigExists() {
  if (fs.existsSync(CONFIG_PATH)) {
    return;
  }

  fs.mkdirSync(CONFIG_DIR, { recursive: true });
  const sample = {
    currency: "£",
    overallMonthlyBudget: 500,
    providers: {
      vertex_ai: {
        displayName: "Vertex AI",
        pricing: {
          type: "web",
          unit: "call",
          url: "https://cloud.google.com/vertex-ai/pricing",
          regex: "\\$([0-9.]+) per document",
          fallbackPrice: 0.012,
          note: "Fallback uses a manual per-call price if scraping fails"
        },
        monthlyBudget: 120,
        optimization: {
          alternative: "claude_haiku",
          eligibleUsageRatio: 0.73,
          note: "Chronology extraction paths can use Claude Haiku at similar quality"
        }
      },
      claude_haiku: {
        displayName: "Claude Haiku",
        pricing: {
          type: "manual",
          unit: "call",
          price: 0.008,
          note: "Manual pricing per API call"
        },
        monthlyBudget: 80
      }
    },
    projects: [
      {
        name: "Chronology Extractor",
        provider: "vertex_ai",
        monthToDate: {
          calls: 620,
          tokens: 0
        },
        recent7Days: {
          calls: 140,
          tokens: 0
        },
        threshold: {
          monthlyBudget: 50
        }
      },
      {
        name: "Timeline QA",
        provider: "claude_haiku",
        monthToDate: {
          calls: 320
        },
        recent7Days: {
          calls: 75
        }
      }
    ]
  };

  fs.writeFileSync(CONFIG_PATH, `${JSON.stringify(sample, null, 2)}\n`);
  console.log(
    `Created a starter config at ${CONFIG_PATH}.\n` +
      "Edit it to match your providers, pricing, and usage before re-running the command."
  );
  process.exit(0);
}

function formatCurrency(currency, value) {
  return `${currency}${value.toFixed(2)}`;
}

function dailyProjection(amountToDate, recentWindowCount) {
  if (recentWindowCount?.days && recentWindowCount?.value) {
    return recentWindowCount.value / recentWindowCount.days;
  }
  return amountToDate && dayOfMonth > 0 ? amountToDate / dayOfMonth : 0;
}

function computeCost(usage, pricing) {
  const unit = pricing.unit || "call";
  const price = pricing.price ?? pricing.fallbackPrice ?? 0;
  let cost = 0;

  if (unit === "1k_tokens") {
    const tokens = usage.tokens || 0;
    cost += (tokens / 1000) * price;
  }

  const calls = usage.calls || 0;
  if (unit === "call") {
    cost += calls * price;
  }

  return cost;
}

function buildRecentWindow(entry, unit) {
  if (!entry) return undefined;

  const pickTokens = unit === "1k_tokens";
  const primary = pickTokens ? entry.tokens : entry.calls;
  const secondary = pickTokens ? entry.calls : entry.tokens;

  if (typeof primary === "number") {
    return { value: primary, days: 7 };
  }

  if (typeof secondary === "number") {
    return { value: secondary, days: 7 };
  }

  return undefined;
}

async function resolvePricing(pricing) {
  if (!pricing) return { price: 0, unit: "call", source: "unknown" };

  if (pricing.type === "manual") {
    return { price: pricing.price ?? 0, unit: pricing.unit, source: pricing.note || "manual" };
  }

  if (pricing.type === "web" && pricing.url && pricing.regex) {
    try {
      const body = await fetchText(pricing.url);
      const match = new RegExp(pricing.regex, "i").exec(body);
      if (match && match[1]) {
        return {
          price: Number(match[1]) || pricing.fallbackPrice || pricing.price || 0,
          unit: pricing.unit,
          source: pricing.url
        };
      }
    } catch (error) {
      // Fall back to manual price below
    }
  }

  return {
    price: pricing.fallbackPrice ?? pricing.price ?? 0,
    unit: pricing.unit,
    source: pricing.note || "manual fallback"
  };
}

async function fetchText(url) {
  if (typeof fetch === "function") {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }
    return response.text();
  }

  return new Promise((resolve, reject) => {
    const request = (currentUrl, redirectsRemaining) => {
      https
        .get(currentUrl, (res) => {
          if (
            res.statusCode &&
            res.statusCode >= 300 &&
            res.statusCode < 400 &&
            res.headers.location &&
            redirectsRemaining > 0
          ) {
            res.resume();
            request(res.headers.location, redirectsRemaining - 1);
            return;
          }

          if (res.statusCode && res.statusCode >= 400) {
            res.resume();
            reject(new Error(`Request failed with status ${res.statusCode}`));
            return;
          }

          let data = "";
          res.on("data", (chunk) => {
            data += chunk;
          });
          res.on("end", () => resolve(data));
        })
        .on("error", reject);
    };

    request(url, 3);
  });
}

async function main() {
  ensureConfigExists();

  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  const currency = config.currency || "$";

  const providers = config.providers || {};
  const resolvedPricing = {};

  for (const [key, provider] of Object.entries(providers)) {
    resolvedPricing[key] = await resolvePricing(provider.pricing);
  }

  const projects = config.projects || [];
  const providerTotals = {};
  let overallCost = 0;
  let projectedOverall = 0;

  const lines = [];
  lines.push(`API Cost Tracker — ${today.toLocaleString("default", { month: "long" })}`);
  lines.push("");

  for (const project of projects) {
    const providerKey = project.provider;
    const providerPricing = resolvedPricing[providerKey] || { price: 0, unit: "call", source: "unknown" };
    const providerDefinition = providers[providerKey];

    if (!providerDefinition) {
      lines.push(`${project.name} — Provider "${providerKey}" is missing from config.`);
      lines.push("");
      continue;
    }

    const usage = project.monthToDate || {};
    const recentWindow = buildRecentWindow(project.recent7Days, providerPricing.unit);
    const usageValue = providerPricing.unit === "1k_tokens" ? usage.tokens || 0 : usage.calls || 0;

    const spend = computeCost(usage, providerPricing);
    const dailyRate = dailyProjection(usageValue, recentWindow);
    const projectedUsage = dailyRate * daysInMonth;
    const projectedCost = computeCost(
      providerPricing.unit === "call" ? { calls: projectedUsage } : { tokens: projectedUsage },
      providerPricing
    );

    overallCost += spend;
    projectedOverall += projectedCost;

    providerTotals[providerKey] ||= {
      name: providers[providerKey]?.displayName || providerKey,
      cost: 0,
      projected: 0,
      monthlyBudget: providers[providerKey]?.monthlyBudget
    };

    providerTotals[providerKey].cost += spend;
    providerTotals[providerKey].projected += projectedCost;

    const budgetLine = project.threshold?.monthlyBudget
      ? ` | Budget: ${formatCurrency(currency, project.threshold.monthlyBudget)}`
      : "";

    lines.push(
      `${project.name} (${providers[providerKey]?.displayName || providerKey}) — ` +
        `${formatCurrency(currency, spend)} spent, projected ${formatCurrency(currency, projectedCost)}${budgetLine}`
    );

    if (recentWindow) {
      lines.push(
        `  Recent pace: ${(dailyRate || 0).toFixed(1)} ${
          providerPricing.unit === "call" ? "calls" : "tokens"
        }/day · Pricing via ${providerPricing.source}`
      );
    }

    if (project.threshold?.monthlyBudget) {
      const utilization = (spend / project.threshold.monthlyBudget) * 100;
      if (utilization >= 90) {
        lines.push(
          `  ⚠️ Project budget alert: ${utilization.toFixed(1)}% of monthly allocation used`
        );
      }
    }

    const optimization = providers[providerKey]?.optimization;
    if (optimization?.alternative && providers[optimization.alternative]) {
      const altPricing = resolvedPricing[optimization.alternative];
      if (altPricing?.price) {
        const eligibleUsage = projectedUsage * (optimization.eligibleUsageRatio || 0);
        const currentCost = computeCost(
          providerPricing.unit === "call" ? { calls: eligibleUsage } : { tokens: eligibleUsage },
          providerPricing
        );
        const altCost = computeCost(
          altPricing.unit === "call" ? { calls: eligibleUsage } : { tokens: eligibleUsage },
          altPricing
        );
        const savings = Math.max(0, currentCost - altCost);
        if (savings > 0) {
          const percent = (optimization.eligibleUsageRatio || 0) * 100;
          lines.push(
            `  💡 ${percent.toFixed(0)}% of this workload could move to ${
              providers[optimization.alternative].displayName
            } to save ~${formatCurrency(currency, savings)} this month (${optimization.note || ""}).`
          );
        }
      }
    }

    lines.push("");
  }

  lines.push("Provider overview:");
  for (const [key, totals] of Object.entries(providerTotals)) {
    const budget = totals.monthlyBudget;
    const budgetNote = budget ? ` of ${formatCurrency(currency, budget)} budget` : "";
    const alert = budget && totals.cost / budget >= 0.9 ? " ⚠️" : "";
    lines.push(
      `- ${totals.name}: ${formatCurrency(currency, totals.cost)} spent${budgetNote}, projected ${formatCurrency(
        currency,
        totals.projected
      )}${alert}`
    );
  }

  if (config.overallMonthlyBudget) {
    const utilization = (overallCost / config.overallMonthlyBudget) * 100;
    const alert = utilization >= 90 ? " ⚠️" : "";
    lines.push(
      `\nTotal month-to-date: ${formatCurrency(currency, overallCost)} of ${formatCurrency(
        currency,
        config.overallMonthlyBudget
      )} budget${alert}`
    );
  } else {
    lines.push(`\nTotal month-to-date: ${formatCurrency(currency, overallCost)}`);
  }

  lines.push(`Projected month-end spend: ${formatCurrency(currency, projectedOverall)}`);

  console.log(lines.join("\n"));
}

main().catch((error) => {
  console.error("Failed to generate cost report", error);
  process.exit(1);
});
