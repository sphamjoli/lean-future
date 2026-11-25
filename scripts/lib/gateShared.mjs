// Shared plumbing for the diff-scoped source gates (dangling inline types,
// single-character identifiers, decorative separator comments). Each gate
// supplies its own AST rule; the file discovery, .vue script extraction, and
// "only fail on lines this change adds" diff scoping are identical across them
// and live here so a rule change never forks the scoping logic. Runs under bun
// or node.

import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(fileURLToPath(import.meta.url), "..", "..", "..");
// A single root entry, since `walk` already recurses: listing subdirectories
// separately would visit each of their files twice and double-report every
// finding in them.
const WORKSPACE_DIRS = ["."];
const EXCLUDED_SEGMENTS = new Set([
  "node_modules",
  "dist",
  "test-results",
  "playwright-report",
  "generated",
  "target",
  ".git",
]);

// The type-shaped gates scan TypeScript and Vue single-file components. A gate
// that also inspects plain JavaScript (the separator gate reads comments in any
// code file) passes its own wider set, so extension policy is per gate rather
// than baked into the discovery logic.
const DEFAULT_EXTENSIONS = [".ts", ".vue"];

function isCheckableFile(path, extensions = DEFAULT_EXTENSIONS) {
  return extensions.some((extension) => path.endsWith(extension));
}

function walk(dir, out, extensions) {
  for (const entry of readdirSync(dir)) {
    if (EXCLUDED_SEGMENTS.has(entry)) continue;
    const full = join(dir, entry);
    const stats = statSync(full);
    if (stats.isDirectory()) walk(full, out, extensions);
    else if (isCheckableFile(full, extensions) && !full.endsWith(".d.ts")) out.push(full);
  }
}

function collectDefaultFiles(extensions) {
  const files = [];
  for (const dir of WORKSPACE_DIRS) {
    const abs = join(REPO_ROOT, dir);
    try {
      walk(abs, files, extensions);
    } catch {
      // Directory absent in this checkout; skip.
    }
  }
  return files;
}

// A .vue file is not valid TS on its own. Extract each <script> block and parse
// it in isolation, remembering the line offset so reported lines map back to
// the .vue file.
function extractScripts(source, path) {
  if (!path.endsWith(".vue")) return [{ text: source, lineOffset: 0 }];
  const blocks = [];
  const scriptBlock = /<script[^>]*>([\s\S]*?)<\/script>/g;
  let match = scriptBlock.exec(source);
  while (match !== null) {
    const lineOffset = source.slice(0, match.index).split("\n").length - 1;
    blocks.push({ text: match[1], lineOffset });
    match = scriptBlock.exec(source);
  }
  return blocks;
}

function git(args) {
  return execFileSync("git", args, { encoding: "utf8" });
}

// Line numbers added or changed on the new side of a diff, so a diff-scoped
// gate blocks only violations being introduced now, never pre-existing debt on
// untouched lines. `range` selects the diff: ["--cached"] for the staged index,
// ["<base>...HEAD"] for a branch comparison. Empty set on any git error
// (treated as "nothing newly added", so the file cannot block).
function diffAddedLines(file, range) {
  const added = new Set();
  let diff;
  try {
    diff = git(["diff", ...range, "--unified=0", "--", file]);
  } catch {
    return added;
  }
  const hunkHeader = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/;
  for (const line of diff.split("\n")) {
    const match = hunkHeader.exec(line);
    if (!match) continue;
    const start = Number(match[1]);
    const count = match[2] === undefined ? 1 : Number(match[2]);
    for (let lineNumber = start; lineNumber < start + count; lineNumber += 1) added.add(lineNumber);
  }
  return added;
}

function changedFiles(range, extensions) {
  try {
    return git(["diff", ...range, "--name-only", "--diff-filter=ACM"])
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => isCheckableFile(line, extensions));
  } catch {
    return [];
  }
}

// Resolve the value of a `--base <ref>` / `--base=<ref>` flag, or null.
function baseRef(argv) {
  const eq = argv.find((arg) => arg.startsWith("--base="));
  if (eq) return eq.slice("--base=".length);
  const idx = argv.indexOf("--base");
  if (idx !== -1 && argv[idx + 1]) return argv[idx + 1];
  return null;
}

// Turn a gate's CLI arguments into the set of files to scan and the git range
// (or null) whose newly added lines a finding must fall on to count. Explicit
// checkable file arguments win; otherwise a diff mode lists its own changed
// files and a full run walks the workspace. `extensions` scopes which paths
// count as checkable, defaulting to the type-shaped gates' TypeScript and Vue.
function resolveScope(argv, extensions = DEFAULT_EXTENSIONS) {
  const staged = argv.includes("--staged");
  const base = baseRef(argv);
  const range = staged ? ["--cached"] : base ? [`${base}...HEAD`] : null;
  const explicit = argv.filter((arg) => isCheckableFile(arg, extensions));
  const files =
    explicit.length > 0
      ? explicit
      : range
        ? changedFiles(range, extensions)
        : collectDefaultFiles(extensions);
  return { range, files };
}

// Keep only findings on lines the change adds or modifies (diff modes); a full
// run has no range and keeps everything. Findings must carry `path` and `line`.
function filterToDiff(findings, range) {
  if (!range) return findings;
  const addedByFile = new Map();
  return findings.filter((finding) => {
    let added = addedByFile.get(finding.path);
    if (!added) {
      added = diffAddedLines(finding.path, range);
      addedByFile.set(finding.path, added);
    }
    return added.has(finding.line);
  });
}

// Run one gate end to end: resolve the scope from argv, scan each file's script
// blocks with the gate's `checkSource(text, path, lineOffset, findings)` visitor,
// keep only diff-scoped findings, and either exit 0 (clean) or print the gate's
// report and exit 1. `report.header(count)` and `report.footer` frame the list;
// `report.line(finding)` renders one finding (findings carry at least path/line).
// This is the half every gate shares; only `checkSource` and `report` differ.
// A gate may set `gate.extensions` to widen the file set, and `gate.wholeFile`
// to receive the raw file text once (rather than the extracted <script> blocks)
// when it inspects content outside script, such as Vue template comments.
function runGate(argv, gate) {
  const { range, files } = resolveScope(argv, gate.extensions);
  const findings = [];
  for (const file of files) {
    let source;
    try {
      source = readFileSync(file, "utf8");
    } catch {
      continue;
    }
    const blocks = gate.wholeFile ? [{ text: source, lineOffset: 0 }] : extractScripts(source, file);
    for (const block of blocks) {
      gate.checkSource(block.text, file, block.lineOffset, findings);
    }
  }

  const gated = filterToDiff(findings, range);
  if (gated.length === 0) process.exit(0);

  gated.sort((left, right) => left.path.localeCompare(right.path) || left.line - right.line);
  console.error(gate.report.header(gated.length));
  for (const finding of gated) console.error(gate.report.line(finding));
  console.error(gate.report.footer);
  process.exit(1);
}

export { REPO_ROOT, relative, isCheckableFile, extractScripts, resolveScope, filterToDiff, runGate };
