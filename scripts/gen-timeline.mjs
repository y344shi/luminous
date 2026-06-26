#!/usr/bin/env node
/**
 * Generate docs/TIMELINE.md — a Notion-loadable project history from git.
 * Lists every commit touching the app, grouped by branch, newest first, with
 * dates + short hashes. Notion imports this markdown cleanly (drag the .md in,
 * or paste). Run: node scripts/gen-timeline.mjs
 */
import { execSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

const ROOT = resolve(process.cwd());
const PREFIX = "dreams/seize_the_day";

function sh(cmd) {
  return execSync(cmd, { cwd: ROOT, encoding: "utf8" }).trim();
}

// branches that touch the app (local)
let branches = [];
try {
  branches = sh("git branch --format='%(refname:short)'")
    .split("\n")
    .map((b) => b.replace(/^'|'$/g, "").trim())
    .filter(Boolean);
} catch {
  branches = [];
}

const wanted = branches.filter(
  (b) => b.includes("luminous") || b.includes("seize")
);
const list = wanted.length ? wanted : branches.slice(0, 1);

const SEP = "";
function commitsFor(branch) {
  try {
    const out = sh(
      `git log ${branch} --no-merges --date=short --pretty=format:'%h${SEP}%ad${SEP}%s' -- ${PREFIX}`
    );
    if (!out) return [];
    return out.split("\n").map((line) => {
      const [hash, date, subject] = line.replace(/^'|'$/g, "").split(SEP);
      return { hash, date, subject };
    });
  } catch {
    return [];
  }
}

const lines = [];
lines.push("# Luminous — Project Timeline");
lines.push("");
lines.push(
  "_Auto-generated from git (`scripts/gen-timeline.mjs`). Notion-loadable: import or paste this markdown._"
);
lines.push("");
lines.push(`Repo: \`git@github.com:y344shi/luminous.git\`  ·  app at \`${PREFIX}\``);
lines.push("");

for (const branch of list) {
  const commits = commitsFor(branch);
  if (!commits.length) continue;
  lines.push(`## branch \`${branch}\` — ${commits.length} commits`);
  lines.push("");
  lines.push("| date | commit | change |");
  lines.push("| --- | --- | --- |");
  for (const c of commits) {
    const subj = c.subject.replace(/\|/g, "\\|");
    lines.push(`| ${c.date} | \`${c.hash}\` | ${subj} |`);
  }
  lines.push("");
}

writeFileSync(resolve(ROOT, PREFIX, "docs/TIMELINE.md"), lines.join("\n") + "\n");
console.log("wrote docs/TIMELINE.md");
