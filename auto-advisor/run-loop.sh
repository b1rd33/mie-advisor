#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CLAUDE_FILE="$PROJECT_ROOT/CLAUDE.md"
PROGRAM_FILE="$PROJECT_ROOT/program.md"
STATE_FILE="$PROJECT_ROOT/state.json"
AGENTS_DIR="$PROJECT_ROOT/.claude/agents"
KNOWLEDGE_DIR="$PROJECT_ROOT/knowledge"
OUTPUT_ROOT="$PROJECT_ROOT/output"

MAX_ROUNDS=8
BUDGET_USD=5.00
CONVERGENCE_THRESHOLD=2
MIN_SCORE=85

# Model config — uses Gemini Flash for speed + tool use
# Override with OPENCODE_MODEL env var if desired
OPENCODE_MODEL="${OPENCODE_MODEL:-openrouter/google/gemini-3-flash-preview}"

PARALLEL_MODE=1
TMUX_SESSION="auto-advisor"
IDEA_INPUT=""
IDEA_TEXT=""
IDEA_NAME="idea"
IDEA_PREVIEW=""
RUN_ID=""
RUN_DIR=""
ROUNDS_DIR=""
SCORES_DIR=""
HISTORY_FILE=""
IMPROVEMENTS_FILE=""
ACTIVITY_LOG_FILE=""
CURRENT_ROUND=0
PREV_SCORE=0
BEST_SCORE=-1
BEST_REPORT=""
CURRENT_SCORE=0

usage() {
  cat <<'EOF'
Usage:
  ./run-loop.sh "Business idea text"
  ./run-loop.sh ideas/my-idea.md
  ./run-loop.sh ideas/my-idea.md --max-rounds 8
  ./run-loop.sh ideas/my-idea.md --budget 5.00
  ./run-loop.sh ideas/my-idea.md --sequential   # disable parallel tmux mode
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_assets() {
  local required=(
    "$CLAUDE_FILE"
    "$PROGRAM_FILE"
    "$AGENTS_DIR/00-orchestrator.md"
    "$AGENTS_DIR/99-critic.md"
    "$AGENTS_DIR/01-design-thinking-advisor.md"
    "$AGENTS_DIR/02-product-management-advisor.md"
    "$AGENTS_DIR/03-innovation-management-advisor.md"
    "$AGENTS_DIR/04-advanced-strategy-advisor.md"
    "$AGENTS_DIR/05-entrepreneurship-advisor.md"
    "$AGENTS_DIR/06-exploring-opportunity-advisor.md"
    "$AGENTS_DIR/07-business-society-advisor.md"
    "$AGENTS_DIR/08-silicon-valley-advisor.md"
    "$KNOWLEDGE_DIR/design-thinking.md"
    "$KNOWLEDGE_DIR/product-management.md"
    "$KNOWLEDGE_DIR/innovation-management.md"
    "$KNOWLEDGE_DIR/advanced-strategy.md"
    "$KNOWLEDGE_DIR/entrepreneurship.md"
    "$KNOWLEDGE_DIR/exploring-opportunity.md"
    "$KNOWLEDGE_DIR/business-in-society.md"
    "$KNOWLEDGE_DIR/silicon-valley-insights.md"
  )
  local missing=0
  for item in "${required[@]}"; do
    if [[ ! -f "$item" ]]; then
      echo "Missing required asset: $item" >&2
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    echo "Run ./analyze.sh extract or ./analyze.sh extract-cheap first." >&2
    exit 1
  fi
}

slugify() {
  python3 - "$1" <<'PY'
import re
import sys

text = sys.argv[1].strip().lower()
text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
print(text or "idea")
PY
}

parse_args() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
  esac
  IDEA_INPUT="$1"
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --max-rounds)
        MAX_ROUNDS="$2"
        shift 2
        ;;
      --budget)
        BUDGET_USD="$2"
        shift 2
        ;;
      --sequential)
        PARALLEL_MODE=0
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

load_idea() {
  if [[ -f "$IDEA_INPUT" ]]; then
    IDEA_TEXT="$(<"$IDEA_INPUT")"
    IDEA_NAME="$(basename "$IDEA_INPUT")"
    IDEA_NAME="${IDEA_NAME%.*}"
  else
    IDEA_TEXT="$IDEA_INPUT"
    IDEA_NAME="$(slugify "$IDEA_INPUT")"
  fi
  IDEA_PREVIEW="$(python3 - "$IDEA_TEXT" <<'PY'
import sys
text = " ".join(sys.argv[1].split())
print(text[:200])
PY
)"
  IDEA_NAME="$(slugify "$IDEA_NAME")"
}

append_activity() {
  local level="$1"
  local message="$2"
  python3 - "$ACTIVITY_LOG_FILE" "$level" "$message" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

path = Path(sys.argv[1])
level = sys.argv[2]
message = sys.argv[3]
if path.exists():
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = []
else:
    data = []
data.insert(0, {
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "level": level,
    "message": message,
})
data = data[:50]
path.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY
}

write_state() {
  local phase="$1"
  local status="$2"
  local detail="$3"
  local active_agent="$4"
  local score="$5"
  python3 - "$STATE_FILE" "$RUN_ID" "$IDEA_PREVIEW" "$CURRENT_ROUND" "$MAX_ROUNDS" "$phase" "$active_agent" "$score" "$MIN_SCORE" "$CONVERGENCE_THRESHOLD" "$status" "$detail" "$BUDGET_USD" "$HISTORY_FILE" "$IMPROVEMENTS_FILE" "$ACTIVITY_LOG_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

state_file = Path(sys.argv[1])
history_file = Path(sys.argv[14])
improvements_file = Path(sys.argv[15])
activity_file = Path(sys.argv[16])

def read_json(path):
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return []
    return []

state = {
    "run_id": sys.argv[2],
    "idea": sys.argv[3],
    "current_round": int(sys.argv[4]),
    "max_rounds": int(sys.argv[5]),
    "phase": sys.argv[6],
    "active_agent": sys.argv[7],
    "current_score": float(sys.argv[8]),
    "target_score": float(sys.argv[9]),
    "convergence_threshold": float(sys.argv[10]),
    "status": sys.argv[11],
    "detail": sys.argv[12],
    "budget_max_usd": float(sys.argv[13]),
    "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "scores_history": read_json(history_file),
    "improvements": read_json(improvements_file),
    "activity_log": read_json(activity_file),
}
state_file.write_text(json.dumps(state, indent=2), encoding="utf-8")
PY
}

update_history() {
  local score_file="$1"
  python3 - "$HISTORY_FILE" "$score_file" <<'PY'
import json
import sys
from pathlib import Path

history_path = Path(sys.argv[1])
score_path = Path(sys.argv[2])
history = []
if history_path.exists():
    try:
        history = json.loads(history_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        history = []
score = json.loads(score_path.read_text(encoding="utf-8"))
history.append({
    "round": score["round"],
    "overall_score": score["overall_score"],
    "dimensions": score["dimensions"],
})
history_path.write_text(json.dumps(history, indent=2), encoding="utf-8")
PY
}

update_improvements() {
  local score_file="$1"
  local improvement="$2"
  python3 - "$IMPROVEMENTS_FILE" "$score_file" "$improvement" <<'PY'
import json
import sys
from pathlib import Path

improvements_path = Path(sys.argv[1])
score_path = Path(sys.argv[2])
improvement_value = float(sys.argv[3])
data = []
if improvements_path.exists():
    try:
        data = json.loads(improvements_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = []
score = json.loads(score_path.read_text(encoding="utf-8"))
data.append({
    "round": score["round"],
    "score": score["overall_score"],
    "improvement": improvement_value,
    "focus": score.get("weakest_dimension", "unknown"),
})
improvements_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY
}

extract_json_object() {
  local raw_file="$1"
  local output_file="$2"
  python3 - "$raw_file" "$output_file" <<'PY'
import json
import sys
from json import JSONDecoder
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
decoder = JSONDecoder()
for index, char in enumerate(text):
    if char != "{":
        continue
    try:
        obj, end = decoder.raw_decode(text[index:])
        Path(sys.argv[2]).write_text(json.dumps(obj, indent=2), encoding="utf-8")
        raise SystemExit(0)
    except json.JSONDecodeError:
        continue
raise SystemExit(1)
PY
}

json_value() {
  local json_file="$1"
  local expression="$2"
  python3 - "$json_file" "$expression" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expression = sys.argv[2]
value = data
for part in expression.split("."):
    if part:
        value = value[part]
if isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

ensure_git_ready() {
  # Skip git branching — outputs go to output/ dir, no branch needed
  true
}

make_run_dirs() {
  RUN_ID="$(date -u +%Y-%m-%d_%H-%M-%S)"
  RUN_DIR="$OUTPUT_ROOT/run-$RUN_ID"
  ROUNDS_DIR="$RUN_DIR/rounds"
  SCORES_DIR="$RUN_DIR/scores"
  HISTORY_FILE="$SCORES_DIR/history.json"
  IMPROVEMENTS_FILE="$RUN_DIR/improvements.json"
  ACTIVITY_LOG_FILE="$RUN_DIR/activity-log.json"

  mkdir -p "$ROUNDS_DIR" "$SCORES_DIR"
  printf '[]\n' >"$HISTORY_FILE"
  printf '[]\n' >"$IMPROVEMENTS_FILE"
  printf '[]\n' >"$ACTIVITY_LOG_FILE"
}

claude_prompt_file() {
  local prompt_file="$1"
  local output_file="$2"
  if ! opencode run \
    -m "$OPENCODE_MODEL" \
    -- "$(< "$prompt_file")" \
    > "$output_file" 2>/dev/null; then
    echo "OpenCode run failed" >&2
    return 1
  fi
}

run_advisor() {
  local slug="$1"
  local label="$2"
  local persona_file="$3"
  local knowledge_file="$4"
  local output_file="$5"
  local previous_outputs="$6"
  local summary="$7"
  local prompt_file raw_output

  write_state "analyzing" "running" "Round $CURRENT_ROUND — $label analyzing with web research" "$slug" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: started $label"

  prompt_file="$(mktemp)"
  raw_output="$output_file.raw"
  cat >"$prompt_file" <<EOF
You are writing one advisor report for the auto-advisor system.

Project rules:
$(<"$PROGRAM_FILE")

Persona:
$(<"$persona_file")

Knowledge:
$(<"$knowledge_file")

Business idea:
$IDEA_TEXT

Previous advisor outputs from this round:
$previous_outputs

Compressed previous-round context:
$summary

Instructions:
- Use 2 to 5 real web searches if search tools are available.
- If search tools are not available, say that explicitly and continue.
- Engage with the previous advisors directly.
- Reference specific frameworks from the knowledge section.
- Return markdown only, following the persona's Output Format exactly.
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_output"; then
    cat >"$output_file" <<EOF
### ${label}'s Assessment
**Verdict**: 🔴 Fundamental concerns
**Key Insight**: The advisor run failed before producing a valid assessment.
**Analysis**: Claude invocation failed for $label during round $CURRENT_ROUND.
**Challenges to Address**:
1. Re-run the analysis once Claude access is restored.
**Questions for the Founder**:
1. What evidence is still missing because this advisor did not complete?
**Recommendation**: Restore the advisor run and repeat this round.
EOF
    append_activity "error" "Round $CURRENT_ROUND: $label failed to run"
  else
    mv "$raw_output" "$output_file"
    append_activity "info" "Round $CURRENT_ROUND: completed $label"
  fi

  rm -f "$prompt_file" "$raw_output"
}

# ── Parallel tmux-based advisor execution ──

ADVISOR_SLUGS=("design-thinking" "product-mgmt" "innovation" "strategy" "entrepreneurship" "exploring-opportunity" "business-society" "silicon-valley")
ADVISOR_LABELS=("Design Thinking" "Product Management" "Innovation Mgmt" "Strategy" "Entrepreneurship" "Exploring Opp." "Business & Society" "Silicon Valley")
ADVISOR_PERSONAS=("01-design-thinking-advisor" "02-product-management-advisor" "03-innovation-management-advisor" "04-advanced-strategy-advisor" "05-entrepreneurship-advisor" "06-exploring-opportunity-advisor" "07-business-society-advisor" "08-silicon-valley-advisor")
ADVISOR_KNOWLEDGE=("design-thinking" "product-management" "innovation-management" "advanced-strategy" "entrepreneurship" "exploring-opportunity" "business-in-society" "silicon-valley-insights")
ADVISOR_COLORS_ANSI=("\033[38;5;208m" "\033[34m" "\033[32m" "\033[38;5;124m" "\033[35m" "\033[36m" "\033[33m" "\033[31m")

write_advisor_prompt() {
  local idx="$1"
  local round_dir="$2"
  local previous_summary="$3"
  local prompt_file="$round_dir/.prompt-${ADVISOR_SLUGS[$idx]}"

  cat >"$prompt_file" <<EOF
You are writing one advisor report for the auto-advisor system.

Project rules:
$(<"$PROGRAM_FILE")

Persona:
$(<"$AGENTS_DIR/${ADVISOR_PERSONAS[$idx]}.md")

Knowledge:
$(<"$KNOWLEDGE_DIR/${ADVISOR_KNOWLEDGE[$idx]}.md")

Business idea:
$IDEA_TEXT

Previous advisor outputs from this round:
This is a parallel analysis round. All 8 advisors are analyzing simultaneously. You do not see other advisors' work yet — focus on YOUR discipline's unique perspective. In the next phase you will read and respond to all other advisors.

Compressed previous-round context:
$previous_summary

Instructions:
- Use 2 to 5 real web searches if search tools are available.
- If search tools are not available, say that explicitly and continue.
- Reference specific frameworks from the knowledge section.
- Be opinionated — your unique disciplinary lens is what matters.
- Return markdown only, following the persona's Output Format exactly.
EOF
  echo "$prompt_file"
}

run_parallel_advisors_tmux() {
  local round_dir="$1"
  local previous_summary="$2"

  write_state "analyzing" "running" "Round $CURRENT_ROUND — launching 8 advisors in parallel" "all-advisors" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: launching all 8 advisors in parallel (tmux)"

  # Kill existing session if any
  tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

  # Write all prompts first
  local prompt_files=()
  for i in {0..7}; do
    prompt_files+=("$(write_advisor_prompt "$i" "$round_dir" "$previous_summary")")
  done

  # Create tmux session with first advisor
  local num="01"
  local label="${ADVISOR_LABELS[0]}"
  local output_file="$round_dir/${ADVISOR_SLUGS[0]}.md"
  local done_marker="$round_dir/.done-${ADVISOR_SLUGS[0]}"

  tmux new-session -d -s "$TMUX_SESSION" -x 200 -y 60

  # Create 8 panes with tiled layout
  for i in {1..7}; do
    tmux split-window -t "$TMUX_SESSION"
    tmux select-layout -t "$TMUX_SESSION" tiled
  done

  # Send commands to each pane
  for i in {0..7}; do
    local num
    num=$(printf "%02d" $((i + 1)))
    label="${ADVISOR_LABELS[$i]}"
    output_file="$round_dir/${ADVISOR_SLUGS[$i]}.md"
    done_marker="$round_dir/.done-${ADVISOR_SLUGS[$i]}"
    local color="${ADVISOR_COLORS_ANSI[$i]}"

    # Each pane: print header, run opencode, touch done marker
    tmux send-keys -t "$TMUX_SESSION:0.$i" "printf '${color}━━━ ${num} ${label} ━━━\033[0m\n\n' && opencode run -m \"$OPENCODE_MODEL\" -- \"\$(cat '${prompt_files[$i]}')\" > '${output_file}' 2>/dev/null && printf '\n\033[32m✓ ${label} complete\033[0m\n' && touch '${done_marker}' || (printf '\n\033[31m✗ ${label} FAILED\033[0m\n' && touch '${done_marker}')" Enter
  done

  # Wait for all advisors to complete
  local timeout=600  # 10 min max
  local elapsed=0
  while (( elapsed < timeout )); do
    local all_done=true
    for i in {0..7}; do
      if [[ ! -f "$round_dir/.done-${ADVISOR_SLUGS[$i]}" ]]; then
        all_done=false
        # Update state with currently running advisors
        local running=""
        for j in {0..7}; do
          if [[ ! -f "$round_dir/.done-${ADVISOR_SLUGS[$j]}" ]]; then
            running="${running}${ADVISOR_SLUGS[$j]} "
          fi
        done
        write_state "analyzing" "running" "Round $CURRENT_ROUND — waiting on: $running" "parallel" "$CURRENT_SCORE"
        break
      fi
    done
    if $all_done; then break; fi
    sleep 3
    elapsed=$(( elapsed + 3 ))
  done

  # Log results
  local completed=0 failed=0
  for i in {0..7}; do
    local of="$round_dir/${ADVISOR_SLUGS[$i]}.md"
    if [[ -f "$of" && -s "$of" ]]; then
      (( completed++ ))
      append_activity "info" "Round $CURRENT_ROUND: completed ${ADVISOR_LABELS[$i]}"
    else
      (( failed++ ))
      # Write fallback output
      cat >"$of" <<EOF
### ${ADVISOR_LABELS[$i]}'s Assessment
**Verdict**: 🔴 Fundamental concerns
**Key Insight**: The advisor run failed or timed out.
**Analysis**: Parallel execution failed for ${ADVISOR_LABELS[$i]} during round $CURRENT_ROUND.
**Challenges to Address**:
1. Re-run the analysis.
**Questions for the Founder**:
1. N/A
**Recommendation**: Retry.
EOF
      append_activity "error" "Round $CURRENT_ROUND: ${ADVISOR_LABELS[$i]} failed"
    fi
  done

  # Clean up prompt files and done markers
  rm -f "$round_dir"/.prompt-* "$round_dir"/.done-*

  append_activity "info" "Round $CURRENT_ROUND: parallel phase done ($completed ok, $failed failed)"

  # Keep tmux session alive so user can review — it auto-dies when they close it
}

run_sequential_advisors() {
  local round_dir="$1"
  local previous_summary="$2"

  local accumulated_outputs="No previous advisors have contributed in this round yet."
  for i in {0..7}; do
    run_advisor "${ADVISOR_SLUGS[$i]}-advisor" "${ADVISOR_LABELS[$i]} Advisor" \
      "$AGENTS_DIR/${ADVISOR_PERSONAS[$i]}.md" \
      "$KNOWLEDGE_DIR/${ADVISOR_KNOWLEDGE[$i]}.md" \
      "$round_dir/${ADVISOR_SLUGS[$i]}.md" \
      "$accumulated_outputs" \
      "$previous_summary"
    if [[ -f "$round_dir/${ADVISOR_SLUGS[$i]}.md" ]]; then
      accumulated_outputs="$accumulated_outputs"$'\n\n'"$(<"$round_dir/${ADVISOR_SLUGS[$i]}.md")"
    fi
  done
}

compress_advisor_output() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "(no output)"
    return
  fi
  # Extract Key Insight, Verdict, and Challenges only
  python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
sections = []

for pattern in [
    r"\*\*Verdict\*\*:.*",
    r"\*\*Key Insight\*\*:.*",
    r"\*\*Challenges to Address\*\*:.*?(?=\n\*\*|\n##|\Z)",
]:
    match = re.search(pattern, text, re.DOTALL)
    if match:
        sections.append(match.group(0).strip())

if sections:
    print("\n".join(sections))
else:
    # Fallback: first 500 chars
    print(text[:500])
PY
}

run_debate() {
  local round_dir="$1"
  local previous_summary="$2"
  local prompt_file raw_output

  # Compress all advisor outputs for debate context
  local compressed=""
  local advisor_labels=("Lena Voss (Design Thinking)" "Adrian Vale (Product Mgmt)" "Helena Mora (Innovation)" "Victor Hale (Strategy)" "Maya Chen (Entrepreneurship)" "Nico Ferran (Exploring Opp)" "Nadia Soler (Business & Society)" "Cole Mercer (Silicon Valley)")
  local advisor_files=("design-thinking.md" "product-mgmt.md" "innovation.md" "strategy.md" "entrepreneurship.md" "exploring-opportunity.md" "business-society.md" "silicon-valley.md")

  for i in "${!advisor_files[@]}"; do
    compressed="${compressed}### ${advisor_labels[$i]}
$(compress_advisor_output "$round_dir/${advisor_files[$i]}")

"
  done

  # --- Turn 1: Challengers (odd-numbered: Lena, Helena, Maya, Nadia) ---
  write_state "debating" "running" "Round $CURRENT_ROUND — debate Turn 1: challengers" "debate-challengers" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: debate Turn 1 — challengers started"

  prompt_file="$(mktemp)"
  raw_output="$round_dir/debate-turn-1.md"
  cat >"$prompt_file" <<EOF
You are facilitating a structured debate between business advisors.

Debate moderator instructions:
$(<"$AGENTS_DIR/10-debate-moderator.md")

Business idea:
$IDEA_TEXT

Compressed advisor outputs:
$compressed

Previous round context:
$previous_summary

TURN 1 — CHALLENGERS
The following advisors must each challenge the most questionable claim from an even-numbered advisor:

1. **Lena Voss** (Design Thinking, advisor #1) — challenge Adrian Vale (#2) OR Victor Hale (#4) OR Nico Ferran (#6) OR Cole Mercer (#8)
2. **Helena Mora** (Innovation Management, advisor #3) — challenge a DIFFERENT even-numbered advisor
3. **Maya Chen** (Entrepreneurship, advisor #5) — challenge a DIFFERENT even-numbered advisor
4. **Nadia Soler** (Business & Society, advisor #7) — challenge a DIFFERENT even-numbered advisor

Rules:
- Each challenger picks ONE specific claim to dispute
- Must cite a specific framework from their discipline
- Keep each challenge to 3-5 sentences
- Be specific, not generic

Format your output as:
## Debate Turn 1: Challenges

### Lena Voss challenges [advisor name]
[challenge text]

### Helena Mora challenges [advisor name]
[challenge text]

### Maya Chen challenges [advisor name]
[challenge text]

### Nadia Soler challenges [advisor name]
[challenge text]
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_output"; then
    cat >"$raw_output" <<EOF
## Debate Turn 1: Challenges
Debate turn 1 failed to generate. Challengers could not produce output.
EOF
    append_activity "error" "Round $CURRENT_ROUND: debate Turn 1 failed"
  else
    append_activity "info" "Round $CURRENT_ROUND: debate Turn 1 completed"
  fi
  rm -f "$prompt_file"

  # --- Turn 2: Defenders (even-numbered: Adrian, Victor, Nico, Cole) ---
  write_state "debating" "running" "Round $CURRENT_ROUND — debate Turn 2: defenders" "debate-defenders" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: debate Turn 2 — defenders started"

  prompt_file="$(mktemp)"
  raw_output="$round_dir/debate-turn-2.md"
  cat >"$prompt_file" <<EOF
You are facilitating a structured debate between business advisors.

Debate moderator instructions:
$(<"$AGENTS_DIR/10-debate-moderator.md")

Business idea:
$IDEA_TEXT

Compressed advisor outputs:
$compressed

Turn 1 challenges:
$(<"$round_dir/debate-turn-1.md")

TURN 2 — DEFENDERS
The even-numbered advisors respond to challenges AND counter-challenge odd-numbered advisors:

1. **Adrian Vale** (Product Management, advisor #2) — respond to any challenge directed at him, then counter-challenge Lena (#1) OR Helena (#3) OR Maya (#5) OR Nadia (#7)
2. **Victor Hale** (Strategy, advisor #4) — respond + counter-challenge a DIFFERENT odd-numbered advisor
3. **Nico Ferran** (Exploring Opportunity, advisor #6) — respond + counter-challenge a DIFFERENT odd-numbered advisor
4. **Cole Mercer** (Silicon Valley, advisor #8) — respond + counter-challenge a DIFFERENT odd-numbered advisor

Rules:
- Acknowledge the challenge specifically (no strawmanning)
- Defend with evidence or concede the point
- Counter-challenge must cite a specific framework
- Keep each response + counter to 5-8 sentences total

Format your output as:
## Debate Turn 2: Defenses & Counter-Challenges

### Adrian Vale responds & counter-challenges [advisor name]
[response + counter text]

### Victor Hale responds & counter-challenges [advisor name]
[response + counter text]

### Nico Ferran responds & counter-challenges [advisor name]
[response + counter text]

### Cole Mercer responds & counter-challenges [advisor name]
[response + counter text]
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_output"; then
    cat >"$raw_output" <<EOF
## Debate Turn 2: Defenses & Counter-Challenges
Debate turn 2 failed to generate. Defenders could not produce output.
EOF
    append_activity "error" "Round $CURRENT_ROUND: debate Turn 2 failed"
  else
    append_activity "info" "Round $CURRENT_ROUND: debate Turn 2 completed"
  fi
  rm -f "$prompt_file"

  # --- Turn 3: Synthesis (Alex Chen) ---
  write_state "debating" "running" "Round $CURRENT_ROUND — debate Turn 3: synthesis" "debate-synthesis" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: debate synthesis started"

  prompt_file="$(mktemp)"
  raw_output="$round_dir/debate-synthesis.md"
  cat >"$prompt_file" <<EOF
You are Alex Chen, the startup orchestrator.

Orchestrator persona:
$(<"$AGENTS_DIR/00-orchestrator.md")

Business idea:
$IDEA_TEXT

Compressed advisor outputs:
$compressed

Debate Turn 1 (Challenges):
$(<"$round_dir/debate-turn-1.md")

Debate Turn 2 (Defenses & Counter-Challenges):
$(<"$round_dir/debate-turn-2.md")

Synthesize the debate into a structured summary. Output markdown with these exact sections:

## Debate Synthesis

### Consensus Points
[Claims that survived challenge — these have higher confidence now]

### Unresolved Disagreements
[Where advisors could not reconcile — flag for the founder with both sides]

### New Insights
[Ideas that emerged only through the debate, not in individual reports]

### Impact on Recommendations
[How the debate should change the founder's priorities or next steps]

Be specific. Reference advisor names and their actual arguments. Do not write generic meta-commentary.
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_output"; then
    cat >"$raw_output" <<EOF
## Debate Synthesis
Debate synthesis failed to generate. Review Turn 1 and Turn 2 directly.
EOF
    append_activity "error" "Round $CURRENT_ROUND: debate synthesis failed"
  else
    append_activity "info" "Round $CURRENT_ROUND: debate synthesis completed"
  fi
  rm -f "$prompt_file"
}

run_critic() {
  local round_dir="$1"
  local previous_score_summary="$2"
  local output_file="$round_dir/score.json"
  local prompt_file raw_file

  write_state "scoring" "running" "Round $CURRENT_ROUND — critic scoring the analysis" "critic" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: critic scoring started"

  prompt_file="$(mktemp)"
  raw_file="$round_dir/critic.raw.txt"
  cat >"$prompt_file" <<EOF
You are the scoring critic for auto-advisor.

Project rules:
$(<"$PROGRAM_FILE")

Critic persona:
$(<"$AGENTS_DIR/99-critic.md")

Business idea:
$IDEA_TEXT

Previous score summary:
$previous_score_summary

Advisor outputs for this round:
$(<"$round_dir/design-thinking.md")

$(<"$round_dir/product-mgmt.md")

$(<"$round_dir/innovation.md")

$(<"$round_dir/strategy.md")

$(<"$round_dir/entrepreneurship.md")

$(<"$round_dir/exploring-opportunity.md")

$(<"$round_dir/business-society.md")

$(<"$round_dir/silicon-valley.md")

Debate synthesis (if available):
$(cat "$round_dir/debate-synthesis.md" 2>/dev/null || echo "No debate this round.")

Return valid JSON only using the required schema from CLAUDE.md.
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_file"; then
    rm -f "$prompt_file"
    return 1
  fi
  rm -f "$prompt_file"

  if ! extract_json_object "$raw_file" "$output_file"; then
    rm -f "$raw_file"
    return 1
  fi

  rm -f "$raw_file"
  append_activity "info" "Round $CURRENT_ROUND: critic scoring completed"
  return 0
}

write_fallback_score() {
  local output_file="$1"
  cat >"$output_file" <<EOF
{
  "round": $CURRENT_ROUND,
  "overall_score": 0,
  "dimensions": {
    "problem_validation": 0,
    "market_research": 0,
    "competitive_analysis": 0,
    "product_definition": 0,
    "business_model": 0,
    "strategy_depth": 0,
    "actionability": 0,
    "cross_advisor_engagement": 0
  },
  "weakest_dimension": "scoring_failure",
  "gaps": [
    "Critic output was missing or invalid after retry."
  ],
  "what_improved": "unable to score",
  "next_round_focus": "Restore critic execution and rerun the analysis.",
  "summary_for_next_round": "Previous round scoring failed. Re-run from the existing advisor outputs and focus on producing valid JSON."
}
EOF
}

run_orchestrator_report() {
  local round_dir="$1"
  local score_file="$2"
  local report_file="$round_dir/report.md"
  local prompt_file raw_file

  write_state "synthesizing" "running" "Round $CURRENT_ROUND — orchestrator synthesizing report" "orchestrator" "$CURRENT_SCORE"
  append_activity "info" "Round $CURRENT_ROUND: orchestrator synthesis started"

  prompt_file="$(mktemp)"
  raw_file="$report_file.raw"
  cat >"$prompt_file" <<EOF
You are synthesizing the final founder-facing report for this round of auto-advisor.

Project rules:
$(<"$PROGRAM_FILE")

Orchestrator persona:
$(<"$AGENTS_DIR/00-orchestrator.md")

Business idea:
$IDEA_TEXT

Critic score:
$(<"$score_file")

Advisor outputs:
$(<"$round_dir/design-thinking.md")

$(<"$round_dir/product-mgmt.md")

$(<"$round_dir/innovation.md")

$(<"$round_dir/strategy.md")

$(<"$round_dir/entrepreneurship.md")

$(<"$round_dir/exploring-opportunity.md")

$(<"$round_dir/business-society.md")

$(<"$round_dir/silicon-valley.md")

Debate synthesis (if available):
$(cat "$round_dir/debate-synthesis.md" 2>/dev/null || echo "No debate this round.")

Return markdown only. Follow the final report template from CLAUDE.md.
EOF

  if ! claude_prompt_file "$prompt_file" "$raw_file"; then
    cat >"$report_file" <<EOF
# Business Idea Analysis: $IDEA_NAME
Date: $RUN_ID | Rounds: $CURRENT_ROUND | Final Score: $CURRENT_SCORE/100

## Executive Summary
Synthesis failed, so this report contains the raw advisor outputs from the round.

## Detailed Analysis by Advisor

$(<"$round_dir/design-thinking.md")

$(<"$round_dir/product-mgmt.md")

$(<"$round_dir/innovation.md")

$(<"$round_dir/strategy.md")

$(<"$round_dir/entrepreneurship.md")

$(<"$round_dir/exploring-opportunity.md")

$(<"$round_dir/business-society.md")

$(<"$round_dir/silicon-valley.md")
EOF
    append_activity "warning" "Round $CURRENT_ROUND: orchestrator fallback report used"
  else
    mv "$raw_file" "$report_file"
    append_activity "info" "Round $CURRENT_ROUND: report synthesis completed"
  fi

  rm -f "$prompt_file" "$raw_file"
}

commit_round() {
  # Skip auto-commits — user manages git manually
  true
}

main() {
  parse_args "$@"
  require_command python3
  require_command opencode
  require_command git
  if (( PARALLEL_MODE )); then
    require_command tmux
  fi
  load_idea
  require_assets
  make_run_dirs
  ensure_git_ready

  append_activity "info" "Initialized run $RUN_ID for $IDEA_NAME"
  write_state "initializing" "running" "Preparing analysis run" "orchestrator" 0

  local previous_summary="This is round 1. No previous summary exists."
  local previous_score_summary="This is round 1."

  for (( round=1; round<=MAX_ROUNDS; round++ )); do
    CURRENT_ROUND="$round"
    local round_dir="$ROUNDS_DIR/round-$round"
    mkdir -p "$round_dir"

    write_state "analyzing" "running" "Round $CURRENT_ROUND — orchestrating advisors" "orchestrator" "$PREV_SCORE"

    if (( PARALLEL_MODE )); then
      run_parallel_advisors_tmux "$round_dir" "$previous_summary"
    else
      run_sequential_advisors "$round_dir" "$previous_summary"
    fi

    run_debate "$round_dir" "$previous_summary"

    if ! run_critic "$round_dir" "$previous_score_summary"; then
      append_activity "warning" "Round $CURRENT_ROUND: critic failed, retrying once"
      if ! run_critic "$round_dir" "$previous_score_summary"; then
        append_activity "error" "Round $CURRENT_ROUND: critic failed twice, using fallback score"
        write_fallback_score "$round_dir/score.json"
      fi
    fi

    CURRENT_SCORE="$(json_value "$round_dir/score.json" "overall_score")"
    local weakest_dimension improvement
    weakest_dimension="$(json_value "$round_dir/score.json" "weakest_dimension")"
    improvement="$(python3 - "$CURRENT_SCORE" "$PREV_SCORE" <<'PY'
import sys
print(round(float(sys.argv[1]) - float(sys.argv[2]), 2))
PY
)"

    update_history "$round_dir/score.json"
    update_improvements "$round_dir/score.json" "$improvement"
    write_state "scored" "running" "Round $CURRENT_ROUND scored at $CURRENT_SCORE" "$weakest_dimension" "$CURRENT_SCORE"

    run_orchestrator_report "$round_dir" "$round_dir/score.json"

    if python3 - "$CURRENT_SCORE" "$BEST_SCORE" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)
PY
    then
      BEST_SCORE="$CURRENT_SCORE"
      BEST_REPORT="$round_dir/report.md"
    fi

    local improvement_label="$improvement"
    if python3 - "$improvement" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) > 0 else 1)
PY
    then
      improvement_label="+$improvement"
    fi

    commit_round "Round $CURRENT_ROUND: score $CURRENT_SCORE/100 ($improvement_label) - improved $weakest_dimension"

    previous_summary="$(json_value "$round_dir/score.json" "summary_for_next_round")"
    previous_score_summary="$(<"$round_dir/score.json")"

    if python3 - "$CURRENT_SCORE" "$MIN_SCORE" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)
PY
    then
      append_activity "info" "Target reached at round $CURRENT_ROUND"
      break
    fi

    if (( CURRENT_ROUND > 2 )) && python3 - "$improvement" "$CONVERGENCE_THRESHOLD" <<'PY'
import sys
raise SystemExit(0 if abs(float(sys.argv[1])) < float(sys.argv[2]) else 1)
PY
    then
      append_activity "info" "Convergence detected at round $CURRENT_ROUND"
      break
    fi

    if python3 - "$CURRENT_SCORE" "$PREV_SCORE" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) < float(sys.argv[2]) else 1)
PY
    then
      append_activity "warning" "Round $CURRENT_ROUND regressed from $PREV_SCORE to $CURRENT_SCORE"
    fi

    PREV_SCORE="$CURRENT_SCORE"
  done

  if [[ -n "$BEST_REPORT" && -f "$BEST_REPORT" ]]; then
    cp "$BEST_REPORT" "$RUN_DIR/FINAL-REPORT-score-${BEST_SCORE%.*}.md"
  fi

  write_state "complete" "complete" "Analysis complete" "orchestrator" "$BEST_SCORE"
  append_activity "info" "Run complete. Best score: $BEST_SCORE"

  echo "Run complete: $RUN_DIR"
  echo "Best score: $BEST_SCORE"
  if [[ -n "$BEST_REPORT" ]]; then
    echo "Best report: $BEST_REPORT"
  fi
}

main "$@"
