#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Learning Snippet Manager
// @raycast.mode fullOutput

// Optional parameters:
// @raycast.icon 📚
// @raycast.packageName Developer Utilities
// @raycast.argument1 { "type": "text", "placeholder": "Action (save/search/insert)" }
// @raycast.argument2 { "type": "text", "placeholder": "Title or search query / metadata", "optional": true }
// @raycast.argument3 { "type": "text", "placeholder": "Tags or template variables (k=v, comma-separated)", "optional": true }

// Documentation:
// @raycast.description Save, search, and insert personal learning snippets with tagging, notes, and template substitution.
// @raycast.author OpenAI - GPT-5.1-Codex-Max

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execSync } = require("child_process");

const action = (process.argv[2] || "search").toLowerCase();
const input = process.argv[3] || "";
const extra = process.argv[4] || "";

const baseDir = path.join(os.homedir(), "Library", "Application Support", "RaycastLearningSnippets");
const fallbackDir = path.join(os.homedir(), ".raycast-learning-snippets");
const storageDir = ensureDirectory(baseDir) ? baseDir : ensureDirectory(fallbackDir) ? fallbackDir : null;

if (!storageDir) {
  console.error("Unable to create a storage directory for snippets.");
  process.exit(1);
}

const storagePath = path.join(storageDir, "snippets.json");
const notePath = process.env.LEARNING_SNIPPET_NOTEBOOK || process.env.LEARNING_SNIPPET_NOTEBOOK_PATH;

function ensureDirectory(dirPath) {
  try {
    fs.mkdirSync(dirPath, { recursive: true });
    return true;
  } catch (error) {
    return false;
  }
}

function loadSnippets() {
  if (!fs.existsSync(storagePath)) {
    return [];
  }

  try {
    const raw = fs.readFileSync(storagePath, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    console.error("Could not read snippets file. A new library will be created.");
    return [];
  }
}

function saveSnippets(snippets) {
  fs.writeFileSync(storagePath, JSON.stringify(snippets, null, 2));
}

function normalize(text) {
  return text.toLowerCase();
}

function parseTags(text) {
  if (!text) return [];
  return text
    .split(/[,#]/)
    .map((tag) => tag.trim())
    .filter(Boolean)
    .map((tag) => (tag.startsWith("#") ? tag.slice(1) : tag));
}

function parseVariables(text) {
  if (!text) return {};
  return text.split(/[,;]\s*/).reduce((vars, chunk) => {
    const [key, ...rest] = chunk.split("=");
    if (key && rest.length) {
      vars[key.trim()] = rest.join("=").trim();
    }
    return vars;
  }, {});
}

function extractTemplateVariables(content) {
  const matches = new Set();
  const regex = /{{\s*([\w.-]+)\s*}}/g;
  let match;
  while ((match = regex.exec(content))) {
    matches.add(match[1]);
  }
  return Array.from(matches);
}

function applyTemplate(content, variables) {
  const regex = /{{\s*([\w.-]+)\s*}}/g;
  return content.replace(regex, (_, key) => {
    if (Object.prototype.hasOwnProperty.call(variables, key)) {
      return variables[key];
    }
    return `{{${key}}}`;
  });
}

function copyToClipboard(text) {
  try {
    execSync("pbcopy", { input: text });
  } catch (error) {
    console.error("Could not copy the snippet to the clipboard.");
  }
}

function readClipboard() {
  try {
    return execSync("pbpaste").toString();
  } catch (error) {
    console.error("Could not read from the clipboard. Make sure pbpaste is available.");
    process.exit(1);
  }
}

function persistNote(snippet) {
  if (!notePath) return;

  const resolvedPath = path.isAbsolute(notePath) ? notePath : path.join(os.homedir(), notePath);
  const noteDir = path.extname(resolvedPath) ? path.dirname(resolvedPath) : resolvedPath;

  try {
    fs.mkdirSync(noteDir, { recursive: true });
  } catch (error) {
    console.error("Could not prepare the note directory.");
    return;
  }

  const targetFile = path.extname(resolvedPath)
    ? resolvedPath
    : path.join(resolvedPath, "learning-snippets.md");

  const lines = [
    `## ${snippet.title} (${snippet.language || "plain text"})`,
    `- Saved: ${snippet.createdAt}`,
    snippet.tags.length ? `- Tags: ${snippet.tags.join(", ")}` : "- Tags: none",
    snippet.notes ? `- Notes: ${snippet.notes}` : "- Notes: none",
    "",
    "```" + (snippet.language || "") + "\n" + snippet.content.trimEnd() + "\n```",
    "",
  ];

  try {
    fs.appendFileSync(targetFile, lines.join("\n"));
  } catch (error) {
    console.error("Could not write to the learning notebook file.");
  }
}

function describeUsage() {
  console.log(
    [
      "Learning Snippet Manager",
      "- save: Save clipboard content as a snippet. Format argument2 as 'Title | tags | language | notes'.",
      "- search: Find snippets by natural language query (titles, notes, tags, content).",
      "- insert: Insert best match and copy to clipboard. argument2 is the title/query, argument3 is 'var=value' pairs for templates.",
      "Environment: set LEARNING_SNIPPET_NOTEBOOK to sync entries into a Markdown notebook (file or folder path).",
    ].join("\n")
  );
}

function findBestMatches(snippets, query) {
  if (!query) return snippets.slice(0, 5);
  const normalizedQuery = normalize(query);
  const tokens = normalizedQuery.split(/\s+/).filter(Boolean);

  const scored = snippets
    .map((snippet) => {
      const haystack = [
        snippet.title,
        snippet.notes || "",
        snippet.language || "",
        snippet.tags.join(" "),
        snippet.content,
      ]
        .map(normalize)
        .join(" ");

      let score = 0;
      if (haystack.includes(normalizedQuery)) score += 3;
      tokens.forEach((token) => {
        if (!token) return;
        if (haystack.includes(token)) score += 1;
        if (normalize(snippet.title).includes(token)) score += 1;
        if (snippet.tags.some((tag) => normalize(tag) === token)) score += 2;
      });

      return { snippet, score };
    })
    .filter(({ score }) => score > 0 || !tokens.length)
    .sort((a, b) => b.score - a.score || a.snippet.title.localeCompare(b.snippet.title));

  return scored.slice(0, 5).map(({ snippet }) => snippet);
}

function formatSnippet(snippet) {
  return [
    `# ${snippet.title}`,
    `- Tags: ${snippet.tags.length ? snippet.tags.join(", ") : "none"}`,
    `- Language: ${snippet.language || "plain text"}`,
    `- Notes: ${snippet.notes || "(none)"}`,
    `- Template variables: ${snippet.templateVariables.length ? snippet.templateVariables.join(", ") : "(none)"}`,
    "",
    "```" + (snippet.language || "") + "\n" + snippet.content.trimEnd() + "\n```",
  ].join("\n");
}

function saveSnippet() {
  if (!input) {
    console.error("Provide metadata in argument2: 'Title | tags | language | notes'.");
    return;
  }

  const [rawTitle, rawTags = "", rawLanguage = "", rawNotes = ""] = input.split("|").map((part) => part.trim());
  const content = readClipboard();
  const snippets = loadSnippets();

  const snippet = {
    id: `${Date.now()}`,
    title: rawTitle || `Snippet ${snippets.length + 1}`,
    tags: parseTags(rawTags),
    language: rawLanguage || "",
    notes: rawNotes,
    content,
    templateVariables: extractTemplateVariables(content),
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  snippets.unshift(snippet);
  saveSnippets(snippets);
  persistNote(snippet);

  console.log("Saved snippet:\n" + formatSnippet(snippet));
}

function searchSnippets() {
  const snippets = loadSnippets();
  if (!snippets.length) {
    console.log("No snippets saved yet. Use the 'save' action first.");
    describeUsage();
    return;
  }

  const matches = findBestMatches(snippets, input);

  if (!matches.length) {
    console.log("No matches found for that query. Try different keywords or tags.");
    return;
  }

  console.log(matches.map(formatSnippet).join("\n\n"));
}

function insertSnippet() {
  const snippets = loadSnippets();
  if (!snippets.length) {
    console.log("No snippets to insert. Save something first.");
    return;
  }

  const matches = findBestMatches(snippets, input || extra || "");
  if (!matches.length) {
    console.log("No snippets found for that description.");
    return;
  }

  const selected = matches[0];
  const providedVariables = parseVariables(extra);
  const content = applyTemplate(selected.content, providedVariables);

  copyToClipboard(content);

  console.log(
    [
      `Inserted snippet: ${selected.title}`,
      selected.tags.length ? `Tags: ${selected.tags.join(", ")}` : "Tags: none",
      selected.templateVariables.length
        ? `Template variables: ${selected.templateVariables.join(", ")}`
        : "Template variables: (none)",
      "", 
      "Preview:",
      "```" + (selected.language || "") + "\n" + content.trimEnd() + "\n```",
    ].join("\n")
  );
}

switch (action) {
  case "save":
    saveSnippet();
    break;
  case "insert":
    insertSnippet();
    break;
  case "search":
  default:
    searchSnippets();
    break;
}
