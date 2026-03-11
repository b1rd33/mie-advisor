#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CLAUDE_FILE="$PROJECT_ROOT/CLAUDE.md"
PROGRAM_FILE="$PROJECT_ROOT/program.md"
RUN_LOOP="$PROJECT_ROOT/run-loop.sh"
EXTRACT_SCRIPT="$PROJECT_ROOT/extract_standalone.py"
OUTPUT_DIR="$PROJECT_ROOT/output"

usage() {
  cat <<'EOF'
Usage:
  ./analyze.sh extract
  ./analyze.sh extract-cheap
  ./analyze.sh "idea text"
  ./analyze.sh ideas/file.md
  ./analyze.sh deep "topic"
  ./analyze.sh compare ideas/a.md ideas/b.md
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_extracted_assets() {
  local missing=0
  for path in \
    "$PROJECT_ROOT/.claude/agents/00-orchestrator.md" \
    "$PROJECT_ROOT/.claude/agents/99-critic.md" \
    "$PROJECT_ROOT/.claude/agents/01-design-thinking-advisor.md" \
    "$PROJECT_ROOT/knowledge/design-thinking.md"
  do
    if [[ ! -f "$path" ]]; then
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    echo "Knowledge docs and advisor personas are missing. Run ./analyze.sh extract or ./analyze.sh extract-cheap first." >&2
    exit 1
  fi
}

run_claude_prompt_to_file() {
  local prompt="$1"
  local output_file="$2"
  local temp_file
  temp_file="$(mktemp)"
  if ! (
    cd "$PROJECT_ROOT"
    claude -p \
      --dangerously-skip-permissions \
      --permission-mode bypassPermissions \
      "$prompt"
  ) >"$temp_file"; then
    rm -f "$temp_file"
    echo "Claude invocation failed." >&2
    exit 1
  fi
  mv "$temp_file" "$output_file"
}

run_extract_with_claude() {
  require_command claude
  local prompt
  prompt="$(cat <<EOF
You are operating inside the auto-advisor project.
Read CLAUDE.md and follow PHASE 1 — KNOWLEDGE EXTRACTION exactly.
Read every course folder recursively, generate knowledge docs under knowledge/, generate advisor personas under .claude/agents/, and ensure the orchestrator and critic personas exist.
Preserve the exact file contracts in CLAUDE.md.
If a course folder is empty, report it in your response but continue.
Use the repository directly and finish with a concise summary of what was generated.
EOF
)"
  (
    cd "$PROJECT_ROOT"
    claude -p \
      --dangerously-skip-permissions \
      --permission-mode bypassPermissions \
      "$prompt"
  )
}

run_extract_cheap() {
  require_command python3
  if [[ -z "${LLM_API_KEY:-}" ]]; then
    echo "LLM_API_KEY is required for extract-cheap." >&2
    echo "Set LLM_PROVIDER, LLM_API_KEY, and optionally LLM_MODEL, then rerun." >&2
    exit 1
  fi
  python3 "$EXTRACT_SCRIPT"
}

run_deep_dive() {
  require_command claude
  require_extracted_assets
  local topic="$1"
  mkdir -p "$OUTPUT_DIR"
  local stamp output_file prompt
  stamp="$(date -u +%Y-%m-%d_%H-%M-%S)"
  output_file="$OUTPUT_DIR/deep-dive-$stamp.md"
  prompt="$(cat <<EOF
You are creating a focused deep dive for the auto-advisor project.

Project rules:
$(<"$PROGRAM_FILE")

Operating instructions:
$(<"$CLAUDE_FILE")

Topic:
$topic

Use the existing knowledge docs under knowledge/ as the foundation.
Return only markdown with:
# Deep Dive: [Topic]
## Why This Topic Matters
## Strategic Questions
## Cross-Disciplinary Analysis
## Risks and Failure Modes
## What To Validate Next
EOF
)"
  run_claude_prompt_to_file "$prompt" "$output_file"
  echo "Wrote deep dive to $output_file"
}

run_compare() {
  require_command claude
  require_extracted_assets
  local idea_a="$1"
  local idea_b="$2"
  if [[ ! -f "$idea_a" || ! -f "$idea_b" ]]; then
    echo "Both compare arguments must be readable files." >&2
    exit 1
  fi
  mkdir -p "$OUTPUT_DIR"
  local stamp output_file prompt
  stamp="$(date -u +%Y-%m-%d_%H-%M-%S)"
  output_file="$OUTPUT_DIR/compare-$stamp.md"
  prompt="$(cat <<EOF
You are comparing two business ideas using the auto-advisor knowledge base.

Project rules:
$(<"$PROGRAM_FILE")

Idea A:
$(<"$idea_a")

Idea B:
$(<"$idea_b")

Produce a founder-facing comparison with:
# Comparative Analysis
## Headline Verdict
## Where Idea A Wins
## Where Idea B Wins
## Key Risks Side by Side
## Which Idea Should Be Tested First
## Recommended Experiments
EOF
)"
  run_claude_prompt_to_file "$prompt" "$output_file"
  echo "Wrote comparison to $output_file"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    extract)
      run_extract_with_claude
      ;;
    extract-cheap)
      run_extract_cheap
      ;;
    deep)
      shift
      [[ $# -ge 1 ]] || { usage; exit 1; }
      run_deep_dive "$1"
      ;;
    compare)
      shift
      [[ $# -eq 2 ]] || { usage; exit 1; }
      run_compare "$1" "$2"
      ;;
    -h|--help)
      usage
      ;;
    *)
      "$RUN_LOOP" "$1" --max-rounds 1
      ;;
  esac
}

main "$@"
