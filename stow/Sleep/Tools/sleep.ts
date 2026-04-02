#!/usr/bin/env bun

/**
 * sleep.ts — Sleep for a specified duration, then output any remaining arguments.
 *
 * Usage: bun run sleep.ts <duration> [follow-up...]
 *
 * Duration formats:
 *   3600   → 3600 seconds (plain number = seconds)
 *   10s    → 10 seconds
 *   30m    → 30 minutes
 *   1h     → 1 hour
 *   2d     → 2 days
 *
 * After sleeping, prints any remaining arguments to stdout for the caller to act on.
 */

const MULTIPLIERS: Record<string, number> = {
  s: 1,
  m: 60,
  h: 3600,
  d: 86400,
};

function parseDuration(input: string): number {
  const match = input.match(/^(\d+(?:\.\d+)?)([smhd])?$/i);
  if (!match) {
    console.error(`Invalid duration: "${input}"`);
    console.error("Formats: 3600, 10s, 30m, 1h, 2d");
    process.exit(1);
  }

  const value = parseFloat(match[1]);
  const unit = (match[2] ?? "s").toLowerCase();
  return value * MULTIPLIERS[unit];
}

function humanDuration(totalSeconds: number): string {
  if (totalSeconds < 60) return `${totalSeconds} second${totalSeconds !== 1 ? "s" : ""}`;

  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = Math.round(totalSeconds % 60);

  const parts: string[] = [];
  if (days > 0) parts.push(`${days} day${days !== 1 ? "s" : ""}`);
  if (hours > 0) parts.push(`${hours} hour${hours !== 1 ? "s" : ""}`);
  if (minutes > 0) parts.push(`${minutes} minute${minutes !== 1 ? "s" : ""}`);
  if (seconds > 0) parts.push(`${seconds} second${seconds !== 1 ? "s" : ""}`);

  return parts.join(" and ");
}

async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error("Usage: sleep <duration> [follow-up...]");
    console.error("  duration: 3600, 10s, 30m, 1h, 2d");
    process.exit(1);
  }

  const durationArg = args[0];
  const followUp = args.slice(1).join(" ").trim();
  const seconds = parseDuration(durationArg);
  const human = humanDuration(seconds);

  console.error(`Sleeping for ${human}...`);
  if (followUp) {
    console.error(`After waking, will pass back: ${followUp}`);
  }

  await Bun.sleep(seconds * 1000);

  console.error(`Awake after ${human}.`);

  if (followUp) {
    // Print follow-up to stdout so the caller can act on it
    console.log(followUp);
  }
}

main();
