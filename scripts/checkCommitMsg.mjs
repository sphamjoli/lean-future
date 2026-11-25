// Fails a commit whose message does not follow this repository's Conventional
// Commits convention, already enforced on pull-request titles by
// `.github/workflows/pr-checks.yml` (the `amannn/action-semantic-pull-request`
// step) but never on the commit messages that make up those PRs. This gate
// closes that gap locally, at commit time, using the exact same type list,
// scope list, and subject pattern as that workflow, so a commit message and
// the PR title built from it are never validated against two different
// rules. Runs under bun or node. Reads the commit message from the file path
// lefthook's `commit-msg` hook passes as its one argument.

import { readFileSync } from "node:fs";

const TYPES = [
  "feat",
  "fix",
  "docs",
  "style",
  "refactor",
  "test",
  "chore",
  "ci",
  "perf",
  "revert",
];
const SCOPES = ["spec", "lean", "witnesses", "recorder", "lint", "docs", "ci", "deps"];
const SUBJECT_PATTERN = /^[a-zA-Z][-a-zA-Z0-9 .,():+/]+$/;

const HEADER_PATTERN = new RegExp(
  `^(?<type>${TYPES.join("|")})(\\((?<scope>[^)]+)\\))?: (?<subject>.+)$`,
);

function firstNonCommentLine(message) {
  for (const line of message.split("\n")) {
    if (line.trim() === "" || line.startsWith("#")) continue;
    return line;
  }
  return "";
}

function validate(message) {
  const header = firstNonCommentLine(message);
  const match = HEADER_PATTERN.exec(header);
  if (!match || !match.groups) {
    return `Commit message must read "type(scope): subject" or "type: subject".\nTypes: ${TYPES.join(", ")}\nScopes: ${SCOPES.join(", ")} (optional)\nGot: "${header}"`;
  }

  const { scope, subject } = match.groups;
  if (scope !== undefined && !SCOPES.includes(scope)) {
    return `Unknown scope "${scope}". Scopes: ${SCOPES.join(", ")}\nGot: "${header}"`;
  }
  if (!SUBJECT_PATTERN.test(subject)) {
    return `Subject must start with a letter and contain only letters, digits, spaces, and -.,():+/\nGot: "${subject}"`;
  }

  return null;
}

function main() {
  const path = process.argv[2];
  if (!path) {
    console.error("checkCommitMsg: no commit-message file path given");
    process.exit(1);
  }
  const message = readFileSync(path, "utf8");
  const error = validate(message);
  if (error) {
    console.error(`checkCommitMsg: ${error}`);
    console.error(
      '\nExample: "fix(lean): require the latest waker in WakesLatest"',
    );
    process.exit(1);
  }
}

main();

export { validate };
