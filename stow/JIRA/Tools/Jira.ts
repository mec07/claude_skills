#!/usr/bin/env bun
/**
 * Jira.ts — Issue Link CLI (fallback for Atlassian MCP gap)
 *
 * The Atlassian MCP Server handles most Jira operations. This CLI exists
 * solely for issue linking, which the MCP does not yet support.
 *
 * DEPRECATION NOTICE: Remove this tool once the Atlassian MCP adds a
 * createIssueLink or equivalent tool. Track:
 * https://community.atlassian.com/forums/Rovo-questions/MCP-Server-create-edit-work-item-links/qaq-p/3109569
 *
 * Reads credentials from ~/.claude/.env internally.
 *
 * Usage:
 *   bun ~/.claude/skills/JIRA/Tools/Jira.ts link DEV-5230 blocked_by DEV-6345
 *   bun ~/.claude/skills/JIRA/Tools/Jira.ts link DEV-6345 blocks DEV-5230
 *
 * Relationship enum:
 *   blocks | blocked_by | duplicates | duplicated_by | relates_to | tests | tested_by | split_to | split_from
 */

import { readFileSync } from "fs";
import { join } from "path";

const REST = "https://powerx.atlassian.net/rest/api/3";

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

async function cmdLink(ticketA: string, relationship: string, ticketB: string): Promise<void> {
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
  const direction = rel.aIsOutward
    ? `${ticketA} -> ${rel.typeName} -> ${ticketB}`
    : `${ticketB} -> ${rel.typeName} -> ${ticketA}`;
  console.log(`OK Linked: ${direction}`);
  console.log(`  ${ticketA} ${relationship.replace(/_/g, " ")} ${ticketB}`);
}

// ─── Main ────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  try {
    if (args[0] === "link") {
      await cmdLink(args[1], args[2], args[3]);
    } else {
      console.log(`Jira Issue Link CLI — Fallback for Atlassian MCP gap

Usage:
  bun Jira.ts link <TICKET_A> <RELATIONSHIP> <TICKET_B>

Examples:
  bun Jira.ts link DEV-5230 blocked_by DEV-6345
  bun Jira.ts link DEV-6345 blocks DEV-5230

Relationships:
  blocks | blocked_by | duplicates | duplicated_by | relates_to
  tests | tested_by | split_to | split_from

Note: All other Jira operations (get, search, create, comment,
transition, edit) should use the Atlassian MCP server tools.`);
    }
  } catch (err: any) {
    console.error("Error:", err.message);
    process.exit(1);
  }
}

main();
