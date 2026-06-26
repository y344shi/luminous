#!/usr/bin/env node
/**
 * Generate docs/TIMELINE.md — a Notion-loadable project history from git.
 * Per branch: a summary (count + date span) and a table of every commit touching
 * the app (date · hash · subject), newest first. Drag the .md into Notion or
 * paste it. Run: npm run timeline  (or: node scripts/gen-timeline.mjs)
 */
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

// Resolve the repo toplevel so this works whether run from the repo root or the
// project dir (`npm run timeline`).
const PREFIX = "dreams/seize_the_day";
const ROOT = execSync("git rev-parse --show-toplevel", { encoding: "utf8" }).trim();
const sh = (cmd) => execSync(cmd, { cwd: ROOT, encoding: "utf8" }).trim();

let branches = [];
try {
  branches = sh("git branch --format='%(refname:short)'")
    .split("\n")
    .map((b) => b.replace(/^'|'$/g, "").trim())
    .filter(Boolean);
} catch {
  branches = [];
}
const wanted = branches.filter((b) => b.includes("luminous") || b.includes("seize"));
const list = wanted.length ? wanted : branches.slice(0, 1);

function commitsFor(branch) {
  try {
    const out = sh(
      `git log ${branch} --no-merges --date=short --pretty=format:'%h|%ad|%s' -- ${PREFIX}`
    );
    if (!out) return [];
    return out.split("\n").map((line) => {
      const [hash, date, ...rest] = line.replace(/^'|'$/g, "").split("|");
      return { hash, date, subject: rest.join("|") };
    });
  } catch {
    return [];
  }
}

const data = list.map((b) => ({ branch: b, commits: commitsFor(b) })).filter((d) => d.commits.length);
const allHashes = new Set();
let minDate = "9999-99-99";
let maxDate = "0000-00-00";
for (const d of data)
  for (const c of d.commits) {
    allHashes.add(c.hash);
    if (c.date < minDate) minDate = c.date;
    if (c.date > maxDate) maxDate = c.date;
  }

const L = [];
L.push("# Luminous — Project Timeline");
L.push("");
L.push("_Auto-generated from git (`npm run timeline`). Notion-loadable: import or paste this markdown._");
L.push("");
L.push(`Repo: \`git@github.com:y344shi/luminous.git\`  ·  app at \`${PREFIX}\``);
L.push("");
L.push("## Summary");
L.push("");
L.push(`- **${allHashes.size}** unique commits across **${data.length}** branches`);
L.push(`- span: **${minDate} → ${maxDate}**`);
L.push("- directions + plan: [`docs/overnight-plan.md`](overnight-plan.md) · gallery: [`docs/GALLERY.md`](GALLERY.md)");
L.push("");

for (const { branch, commits } of data) {
  const dates = commits.map((c) => c.date).sort();
  L.push(`## branch \`${branch}\` — ${commits.length} commits  ·  ${dates[0]} → ${dates[dates.length - 1]}`);
  L.push("");
  L.push("| date | commit | change |");
  L.push("| --- | --- | --- |");
  for (const c of commits) L.push(`| ${c.date} | \`${c.hash}\` | ${c.subject.replace(/\|/g, "\\|")} |`);
  L.push("");
}

writeFileSync(resolve(ROOT, PREFIX, "docs/TIMELINE.md"), L.join("\n") + "\n");
console.log(`wrote docs/TIMELINE.md (${allHashes.size} commits, ${data.length} branches)`);
