#!/bin/bash
# Ralph: a long-running AI agent loop, one user story per iteration.
# Usage: ./scripts/ralph/ralph.sh [--system-prompt-file FILE] [--dry-run] [max_iterations]
#
# Based on snarktank/ralph (MIT, https://github.com/snarktank/ralph).
# Local changes, each marked "local change" below:
#   1. Fail fast when the agent binary is missing, instead of looping on nothing.
#   2. Archive the run on EXIT, not at startup (fixes upstream #99 and #125).
#   3. --system-prompt-file: inject a file into the system prompt, deterministically.
#   4. --dry-run: print the command and exit without touching anything.
#   5. Claude Code only (upstream also drives Amp).

set -e

TOOL="claude"
MAX_ITERATIONS=10
SYSTEM_PROMPT_FILE=""   # local change 3
DRY_RUN=0               # local change 4

while [[ $# -gt 0 ]]; do
  case $1 in
    --system-prompt-file)
      SYSTEM_PROMPT_FILE="$2"
      shift 2
      ;;
    --system-prompt-file=*)
      SYSTEM_PROMPT_FILE="${1#*=}"
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# --- local change 1: fail fast on a missing binary --------------------------
# The loop swallows per-iteration errors (|| true) on purpose: one crashed
# iteration must not stop the night. A missing binary is not a crashed
# iteration, it is a launch error: without this check, every iteration runs
# empty and the whole night is lost.
if [ "$DRY_RUN" = "0" ] && ! command -v "$TOOL" >/dev/null 2>&1; then
  echo "Error: '$TOOL' not found in PATH."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# --- local change 3: deterministic system prompt injection ------------------
# Asking for a skill in the prompt ("use the X skill") does not invoke it:
# measured on a real run, 156 messages, 0 Skill tool calls. The model obeys the
# text, not the rules file. Appending the file to the system prompt makes the
# behavior identical on every iteration.
CLAUDE_EXTRA=()
if [ -n "$SYSTEM_PROMPT_FILE" ]; then
  [ -f "$SYSTEM_PROMPT_FILE" ] || { echo "Error: system prompt file not found: $SYSTEM_PROMPT_FILE"; exit 1; }
  CLAUDE_EXTRA=(--append-system-prompt "$(cat "$SYSTEM_PROMPT_FILE")")
fi

# --- local change 4: dry run ------------------------------------------------
if [ "$DRY_RUN" = "1" ]; then
  echo "DRY RUN - max iterations: $MAX_ITERATIONS - no file touched, no model call"
  echo "  claude --dangerously-skip-permissions --print"
  if [ -n "$SYSTEM_PROMPT_FILE" ]; then
    echo "    --append-system-prompt <contents of $SYSTEM_PROMPT_FILE>"
  fi
  echo "    < $SCRIPT_DIR/CLAUDE.md"
  exit 0
fi

# Reset progress when the feature changes.
# local change 2: no archiving here. At this point the PRD has already been
# replaced by the next feature's one: archiving now would file the NEW PRD
# under the OLD feature's name (upstream #99, #125).
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    echo "New feature: $LAST_BRANCH -> $CURRENT_BRANCH, resetting progress.txt"
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph - max iterations: $MAX_ITERATIONS"

# --- local change 2: archive on exit ----------------------------------------
# On exit, prd.json and progress.txt both belong to the run that just ended,
# and the folder name comes from the branchName of that same prd.json: name and
# content match by construction. Idempotent: rerunning the same feature
# rewrites the same folder with a more advanced state.
archive_run() {
  [ -f "$PRD_FILE" ] || return 0
  ARCHIVE_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  [ -n "$ARCHIVE_BRANCH" ] || return 0
  ARCHIVE_DEST="$ARCHIVE_DIR/$(date +%Y-%m-%d)-${ARCHIVE_BRANCH#ralph/}"
  mkdir -p "$ARCHIVE_DEST"
  cp "$PRD_FILE" "$ARCHIVE_DEST/prd.json"
  [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_DEST/progress.txt"
  echo ""
  echo "Run archived: $ARCHIVE_DEST"
  return 0
}
trap archive_run EXIT INT TERM

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Ralph iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  # --dangerously-skip-permissions: run this ONLY in an isolated environment
  # (container or VM) that holds no production credential.
  OUTPUT=$(claude --dangerously-skip-permissions --print \
    ${CLAUDE_EXTRA[@]+"${CLAUDE_EXTRA[@]}"} \
    < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true

  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks at iteration $i of $MAX_ITERATIONS."
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
