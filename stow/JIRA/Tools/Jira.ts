#!/usr/bin/env bun
/**
 * Jira.ts — Jira CLI for PAI
 *
 * Reads credentials from ~/.claude/.env internally.
 * No tokens or raw API responses appear in conversation.
 *
 * Usage:
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts get DEV-6255
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts board 361
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts search "project=DEV AND status=New"
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts create --payload /tmp/payload.json
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts comment DEV-6255 "Phase 1 complete"
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts transition DEV-6255 "In Development"
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts update DEV-6255 --append /tmp/nodes.json
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts link DEV-5230 blocked_by DEV-6345
 *   bun ~/.claude/skills/_JIRA/Tools/Jira.ts link DEV-6345 blocks DEV-5230
 *   Add --json to any command for raw JSON output
 *
 * Relationship enum (for the link command):
 *   blocks | blocked_by | duplicates | duplicated_by | relates_to | tests | tested_by | split_to | split_from
 */

import { readFileSync } from "fs";
import { join } from "path";

const JIRA_HOST = "https://powerx.atlassian.net";
const REST = `${JIRA_HOST}/rest/api/3`;
const AGILE = `${JIRA_HOST}/rest/agile/1.0`;

// ─── Env ────────────────────────────────────────────────────────────────────

function loadEnv(): Record<string, string> {
  const content = readFileSync(join(process.env.HOME!, ".claude/.env"), "utf-8");
  const env: Record<string, string> = {};
  for (const line of content.split("\n")) {
    const idx = line.indexOf("=");
    if (idx > 0 && !line.startsWith("#")) {
      env[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
    }
  }
  return env;
}

function authHeader(): string {
  const env = loadEnv();
  const token = env.JIRA_API_TOKEN;
  const email = env.JIRA_EMAIL;
  if (!token || !email) throw new Error("JIRA_API_TOKEN or JIRA_EMAIL missing from ~/.claude/.env");
  return "Basic " + Buffer.from(`${email}:${token}`).toString("base64");
}

// ─── HTTP ────────────────────────────────────────────────────────────────────

async function jiraFetch(url: string, opts: RequestInit = {}): Promise<any> {
  const res = await fetch(url, {
    ...opts,
    headers: {
      Authorization: authHeader(),
      "Content-Type": "application/json",
      Accept: "application/json",
      ...((opts.headers as Record<string, string>) || {}),
    },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Jira ${res.status}: ${text}`);
  return text ? JSON.parse(text) : null;
}

// ─── ADF → Markdown ──────────────────────────────────────────────────────────

function adfToMd(node: any, indent = 0): string {
  if (!node) return "";
  const t = node.type;
  const kids: any[] = node.content || [];

  switch (t) {
    case "doc":
      return kids.map((c) => adfToMd(c, indent)).join("").trim();

    case "paragraph": {
      const text = kids.map((c) => adfToMd(c, indent)).join("");
      return text.trim() ? text.trim() + "\n" : "";
    }

    case "heading": {
      const level = node.attrs?.level || 2;
      const text = kids.map((c) => adfToMd(c)).join("");
      return "\n" + "#".repeat(level) + " " + text.trim() + "\n";
    }

    case "text": {
      let text = node.text || "";
      for (const mark of node.marks || []) {
        if (mark.type === "strong") text = `**${text}**`;
        else if (mark.type === "em") text = `_${text}_`;
        else if (mark.type === "code") text = `\`${text}\``;
        else if (mark.type === "strike") text = `~~${text}~~`;
        else if (mark.type === "link") text = `[${text}](${mark.attrs?.href})`;
      }
      return text;
    }

    case "hardBreak":
      return "\n";

    case "rule":
      return "\n---\n";

    case "bulletList":
      return kids
        .map((item) => {
          const inner = (item.content || [])
            .map((c: any) => adfToMd(c, indent + 1))
            .join("")
            .trim();
          return "  ".repeat(indent) + "- " + inner;
        })
        .join("\n") + "\n";

    case "orderedList":
      return kids
        .map((item, i) => {
          const inner = (item.content || [])
            .map((c: any) => adfToMd(c, indent + 1))
            .join("")
            .trim();
          return "  ".repeat(indent) + `${i + 1}. ` + inner;
        })
        .join("\n") + "\n";

    case "codeBlock": {
      const lang = node.attrs?.language || "";
      const code = kids.map((c) => c.text || "").join("");
      return `\`\`\`${lang}\n${code}\n\`\`\`\n`;
    }

    case "blockquote": {
      const inner = kids.map((c) => adfToMd(c)).join("");
      return inner
        .trim()
        .split("\n")
        .map((l) => "> " + l)
        .join("\n") + "\n";
    }

    case "panel": {
      const panelType = (node.attrs?.panelType || "info").toUpperCase();
      const inner = kids.map((c) => adfToMd(c)).join("").trim();
      return `> **[${panelType}]** ${inner}\n`;
    }

    default:
      return kids.map((c) => adfToMd(c, indent)).join("");
  }
}

// ─── Formatting helpers ──────────────────────────────────────────────────────

function formatIssue(issue: any): string {
  const f = issue.fields;
  const key = issue.key;
  const summary = f.summary || "(no summary)";
  const status = f.status?.name || "?";
  const priority = f.priority?.name || "?";
  const assignee = f.assignee?.displayName || "Unassigned";
  const desc = f.description ? adfToMd(f.description) : "_No description_";

  return [
    `# ${key} — ${summary}`,
    `**Status:** ${status}  |  **Priority:** ${priority}  |  **Assignee:** ${assignee}`,
    "",
    "---",
    "",
    desc,
  ].join("\n");
}

function formatIssueList(issues: any[]): string {
  if (!issues.length) return "_(no results)_";
  return issues
    .map((i) => {
      const status = i.fields?.status?.name || "?";
      const summary = i.fields?.summary || "(no summary)";
      return `- **${i.key}** [${status}] ${summary}`;
    })
    .join("\n");
}

// ─── Commands ────────────────────────────────────────────────────────────────

async function cmdGet(key: string, json: boolean): Promise<void> {
  const issue = await jiraFetch(`${REST}/issue/${key}?fields=summary,description,status,priority,assignee`);
  if (json) {
    console.log(JSON.stringify(issue, null, 2));
  } else {
    console.log(formatIssue(issue));
  }
}

async function cmdBoard(boardId: string, fields: string, json: boolean): Promise<void> {
  const fieldList = fields || "summary,status";
  const data = await jiraFetch(
    `${AGILE}/board/${boardId}/issue?maxResults=100&fields=${fieldList}`
  );
  if (json) {
    console.log(JSON.stringify(data, null, 2));
  } else {
    const issues = data.issues || [];
    console.log(`**Board ${boardId}** — ${issues.length} issues\n`);
    console.log(formatIssueList(issues));
  }
}

async function cmdSearch(jql: string, json: boolean): Promise<void> {
  const data = await jiraFetch(
    `${REST}/search?jql=${encodeURIComponent(jql)}&fields=summary,status,priority&maxResults=50`
  );
  if (json) {
    console.log(JSON.stringify(data, null, 2));
  } else {
    const issues = data.issues || [];
    console.log(`**Search:** \`${jql}\`\n${issues.length} result(s)\n`);
    console.log(formatIssueList(issues));
  }
}

async function cmdCreate(payloadFile: string, json: boolean): Promise<void> {
  const payload = JSON.parse(readFileSync(payloadFile, "utf-8"));
  const result = await jiraFetch(`${REST}/issue`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
  if (json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(`✓ Created: **${result.key}**`);
    console.log(`  ${JIRA_HOST}/browse/${result.key}`);
  }
}

async function cmdComment(key: string, text: string, json: boolean): Promise<void> {
  const body = {
    body: {
      type: "doc",
      version: 1,
      content: [
        {
          type: "paragraph",
          content: [{ type: "text", text }],
        },
      ],
    },
  };
  const result = await jiraFetch(`${REST}/issue/${key}/comment`, {
    method: "POST",
    body: JSON.stringify(body),
  });
  if (json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log(`✓ Comment added to ${key}`);
  }
}

async function cmdTransition(key: string, targetName: string, json: boolean): Promise<void> {
  const { transitions } = await jiraFetch(`${REST}/issue/${key}/transitions`);
  const match = transitions.find(
    (t: any) => t.name.toLowerCase().includes(targetName.toLowerCase())
  );
  if (!match) {
    const available = transitions.map((t: any) => t.name).join(", ");
    throw new Error(`No transition matching "${targetName}". Available: ${available}`);
  }
  await jiraFetch(`${REST}/issue/${key}/transitions`, {
    method: "POST",
    body: JSON.stringify({ transition: { id: match.id } }),
  });
  if (!json) console.log(`✓ ${key} transitioned to "${match.name}"`);
}

// ─── Link types ──────────────────────────────────────────────────────────────

type Relationship =
  | "blocks" | "blocked_by"
  | "duplicates" | "duplicated_by"
  | "relates_to"
  | "tests" | "tested_by"
  | "split_to" | "split_from";

const RELATIONSHIP_MAP: Record<Relationship, { typeName: string; aIsOutward: boolean }> = {
  blocks:        { typeName: "Blocks",          aIsOutward: true  },
  blocked_by:    { typeName: "Blocks",          aIsOutward: false },
  duplicates:    { typeName: "Duplicate",       aIsOutward: true  },
  duplicated_by: { typeName: "Duplicate",       aIsOutward: false },
  relates_to:    { typeName: "Relates",         aIsOutward: true  },
  tests:         { typeName: "Test",            aIsOutward: true  },
  tested_by:     { typeName: "Test",            aIsOutward: false },
  split_to:      { typeName: "Work item split", aIsOutward: true  },
  split_from:    { typeName: "Work item split", aIsOutward: false },
};

async function cmdLink(ticketA: string, relationship: string, ticketB: string, json: boolean): Promise<void> {
  const rel = RELATIONSHIP_MAP[relationship as Relationship];
  if (!rel) {
    const valid = Object.keys(RELATIONSHIP_MAP).join(" | ");
    throw new Error(`Unknown relationship "${relationship}". Valid values: ${valid}`);
  }
  const body = {
    type: { name: rel.typeName },
    outwardIssue: { key: rel.aIsOutward ? ticketA : ticketB },
    inwardIssue:  { key: rel.aIsOutward ? ticketB : ticketA },
  };
  await jiraFetch(`${REST}/issueLink`, { method: "POST", body: JSON.stringify(body) });
  if (!json) {
    const direction = rel.aIsOutward ? `${ticketA} → ${rel.typeName} → ${ticketB}` : `${ticketB} → ${rel.typeName} → ${ticketA}`;
    console.log(`✓ Linked: ${direction}`);
    console.log(`  ${ticketA} ${relationship.replace(/_/g, " ")} ${ticketB}`);
  }
}

async function cmdUpdate(key: string, appendFile: string, json: boolean): Promise<void> {
  const nodes = JSON.parse(readFileSync(appendFile, "utf-8"));
  // Fetch existing description
  const issue = await jiraFetch(`${REST}/issue/${key}?fields=description`);
  const existing = issue.fields.description || { type: "doc", version: 1, content: [] };
  // Append nodes
  existing.content.push(...(Array.isArray(nodes) ? nodes : [nodes]));
  await jiraFetch(`${REST}/issue/${key}`, {
    method: "PUT",
    body: JSON.stringify({ fields: { description: existing } }),
  });
  if (!json) console.log(`✓ ${key} description updated`);
}

// ─── Main ────────────────────────────────────────────────────────────────────

function getFlag(args: string[], flag: string): string | undefined {
  const idx = args.indexOf(flag);
  return idx >= 0 ? args[idx + 1] : undefined;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0];
  const json = args.includes("--json");

  try {
    switch (command) {
      case "get":
        await cmdGet(args[1], json);
        break;

      case "board":
        await cmdBoard(args[1], getFlag(args, "--fields") || "summary,status", json);
        break;

      case "search":
        await cmdSearch(args[1], json);
        break;

      case "create":
        await cmdCreate(getFlag(args, "--payload")!, json);
        break;

      case "comment":
        await cmdComment(args[1], args[2], json);
        break;

      case "transition":
        await cmdTransition(args[1], args[2], json);
        break;

      case "update":
        await cmdUpdate(args[1], getFlag(args, "--append")!, json);
        break;

      case "link":
        // bun Jira.ts link DEV-5230 blocked_by DEV-6345
        await cmdLink(args[1], args[2], args[3], json);
        break;

      default:
        console.log(`Jira CLI — Usage:
  bun Jira.ts get DEV-6255
  bun Jira.ts board 361 [--fields summary,status]
  bun Jira.ts search "project=DEV AND status=New"
  bun Jira.ts create --payload /tmp/payload.json
  bun Jira.ts comment DEV-6255 "message"
  bun Jira.ts transition DEV-6255 "In Development"
  bun Jira.ts update DEV-6255 --append /tmp/nodes.json
  bun Jira.ts link DEV-5230 blocked_by DEV-6345
  Relationships: blocks | blocked_by | duplicates | duplicated_by | relates_to | tests | tested_by | split_to | split_from
  Add --json for raw JSON output`);
    }
  } catch (err: any) {
    console.error("Error:", err.message);
    process.exit(1);
  }
}

main();
