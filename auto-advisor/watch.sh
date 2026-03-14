#!/usr/bin/env bash
set -euo pipefail

# Auto-Advisor Live CLI Dashboard
# Usage: ./watch.sh              (watches latest run)
#        ./watch.sh run-ID        (watches specific run)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$SCRIPT_DIR/state.json"
OUTPUT_ROOT="$SCRIPT_DIR/output"
POLL_INTERVAL=2
FRAME=0
START_EPOCH=""

# ── ANSI (actual escape bytes via $'...' so display_width can strip them) ──
ESC=$'\033'
RST="${ESC}[0m"
B="${ESC}[1m"
DM="${ESC}[2m"
RED="${ESC}[31m"
GRN="${ESC}[32m"
YLW="${ESC}[33m"
BLU="${ESC}[34m"
MAG="${ESC}[35m"
CYN="${ESC}[36m"
WHT="${ESC}[37m"
GRY="${ESC}[90m"
ORG="${ESC}[38;5;208m"
BRG="${ESC}[38;5;124m"
SKY="${ESC}[38;5;117m"

SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

ADVISOR_COLORS=("$ORG" "$BLU" "$GRN" "$BRG" "$MAG" "$CYN" "$YLW" "$RED")
ADVISOR_NAMES=("Design Thinking" "Product Management" "Innovation Mgmt" "Strategy" "Entrepreneurship" "Exploring Opp." "Business & Society" "Silicon Valley")
ADVISOR_FILES=("design-thinking.md" "product-mgmt.md" "innovation.md" "strategy.md" "entrepreneurship.md" "exploring-opportunity.md" "business-society.md" "silicon-valley.md")

DEBATE_NAMES=("Challengers" "Defenders" "Synthesis")
DEBATE_FILES=("debate-turn-1.md" "debate-turn-2.md" "debate-synthesis.md")

# ── Helpers ───────────────────────────────────────────────────

cleanup() {
  printf '\033[?25h\033[0m\n'
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

find_run_dir() {
  if [[ -n "${1:-}" ]]; then
    for prefix in "" "run-"; do
      [[ -d "$OUTPUT_ROOT/${prefix}$1" ]] && { echo "$OUTPUT_ROOT/${prefix}$1"; return 0; }
    done
    echo "Run not found: $1" >&2; return 1
  fi
  local latest
  latest="$(ls -1d "$OUTPUT_ROOT"/run-* 2>/dev/null | sort | tail -1)"
  [[ -z "$latest" ]] && { echo "No runs found in $OUTPUT_ROOT" >&2; return 1; }
  echo "$latest"
}

json_val() {
  python3 -c "
import json,sys
try:
    d=json.loads(open(sys.argv[1]).read())
    v=d
    for k in sys.argv[2].split('.'):
        if isinstance(v,list): v=v[int(k)] if k.isdigit() and int(k)<len(v) else ''
        elif isinstance(v,dict): v=v.get(k,'')
        else: v=''
    print(v if not isinstance(v,(dict,list)) else json.dumps(v))
except: print('')
" "$1" "$2" 2>/dev/null
}

# Visible width: strip real ESC bytes, then count
vis_len() {
  local s="$1"
  # Strip actual escape sequences (ESC [ ... m)
  s="$(printf '%s' "$s" | sed $'s/\033\[[0-9;]*m//g')"
  # Now count chars — all remaining are single-width ASCII
  echo "${#s}"
}

score_bar() {
  local score="$1" width="${2:-20}"
  local filled=$(( score * width / 100 ))
  local empty=$(( width - filled ))
  local color="$RED"
  (( score >= 70 )) && color="$GRN"
  (( score >= 40 && score < 70 )) && color="$YLW"
  local bar="${color}"
  for (( i=0; i<filled; i++ )); do bar+="="; done
  bar+="${GRY}"
  for (( i=0; i<empty; i++ )); do bar+="-"; done
  bar+="${RST}"
  echo "$bar"
}

extract_key_insight() {
  local file="$1"
  [[ ! -f "$file" ]] && return
  python3 -c "
import re,sys
text=open(sys.argv[1]).read()
m=re.search(r'\*\*Key Insight\*\*:\s*(.*)',text)
if m: print(m.group(1).strip()[:38])
else:
    for l in text.splitlines():
        l=l.strip()
        if l and not l.startswith('#') and not l.startswith('**'):
            print(l[:38]);break
" "$file" 2>/dev/null
}

# ── Drawing (all ASCII box chars, no emoji, predictable widths) ──

BOX_W=70  # total chars between left ║ and right ║ (including 1 space padding each side)
CONTENT_W=68  # BOX_W - 2 (for the space after ║ and space before ║)

hline() {
  printf "${B}${CYN}%s" "$1"
  local i; for (( i=0; i<BOX_W; i++ )); do printf '%s' "$2"; done
  printf "%s${RST}\n" "$3"
}

# Print a line inside the box, right-padded to exact width
row() {
  local content="$1"
  local vlen
  vlen="$(vis_len "$content")"
  local pad=$(( CONTENT_W - vlen ))
  (( pad < 0 )) && pad=0
  printf "${B}${CYN}|${RST} %s%*s ${B}${CYN}|${RST}\n" "$content" "$pad" ""
}

emptyrow() {
  printf "${B}${CYN}|${RST}%*s${B}${CYN}|${RST}\n" $(( BOX_W )) ""
}

# ── Status icons (all exactly 6 visible chars) ──

icon_done="${GRN}[done]${RST}"    # 6
icon_wait="${GRY}[ -- ]${RST}"    # 6
icon_run() {
  local s="${SPINNER[$(( FRAME % ${#SPINNER[@]} ))]}"
  # spinner char + space + "run" + space = 5 visible... pad to 6
  printf "${YLW}[%s>  ]${RST}" "$s"  # 6: [ + spinner + > + 2spaces + ]
}

# ── Render ────────────────────────────────────────────────────

render() {
  local run_dir="$1"
  FRAME=$(( FRAME + 1 ))

  # Read state
  local run_id="" idea="" phase="" active_agent="" current_round=0
  local max_rounds=0 current_score=0 status="" timestamp=""
  if [[ -f "$STATE_FILE" ]]; then
    run_id="$(json_val "$STATE_FILE" run_id)"
    idea="$(json_val "$STATE_FILE" idea)"
    phase="$(json_val "$STATE_FILE" phase)"
    active_agent="$(json_val "$STATE_FILE" active_agent)"
    current_round="$(json_val "$STATE_FILE" current_round)"
    max_rounds="$(json_val "$STATE_FILE" max_rounds)"
    current_score="$(json_val "$STATE_FILE" current_score)"
    status="$(json_val "$STATE_FILE" status)"
    timestamp="$(json_val "$STATE_FILE" timestamp)"
  fi
  idea="${idea:0:60}"
  local score_int="${current_score%.*}"; score_int="${score_int:-0}"
  local round_dir="$run_dir/rounds/round-${current_round}"

  # Elapsed time
  if [[ -z "$START_EPOCH" && -n "$timestamp" ]]; then
    START_EPOCH="$(python3 -c "
from datetime import datetime
try:
    t=datetime.fromisoformat('$timestamp'.replace('Z','+00:00'))
    print(int(t.timestamp()))
except: print(0)
" 2>/dev/null || echo 0)"
  fi
  local elapsed="--"
  if [[ -n "$START_EPOCH" && "$START_EPOCH" != "0" ]]; then
    local now diff
    now="$(date +%s)"
    diff=$(( now - START_EPOCH ))
    if (( diff < 60 )); then elapsed="${diff}s"
    elif (( diff < 3600 )); then elapsed="$((diff/60))m $((diff%60))s"
    else elapsed="$((diff/3600))h $((diff%3600/60))m"
    fi
  fi

  # Score delta
  local delta_str=""
  if [[ -f "$run_dir/scores/history.json" ]]; then
    local prev
    prev="$(python3 -c "
import json
h=json.loads(open('$run_dir/scores/history.json').read())
print(int(h[-2]['overall_score']) if len(h)>1 else 0)
" 2>/dev/null || echo 0)"
    local pi="${prev%.*}"; pi="${pi:-0}"
    local d=$(( score_int - pi ))
    (( d > 0 )) && delta_str=" ${GRN}+${d}${RST}"
    (( d < 0 )) && delta_str=" ${RED}${d}${RST}"
  fi

  # Progress
  local total=13 done_n=0
  for f in "${ADVISOR_FILES[@]}"; do [[ -f "$round_dir/$f" ]] && (( done_n++ )); done
  for f in "${DEBATE_FILES[@]}"; do [[ -f "$round_dir/$f" ]] && (( done_n++ )); done
  [[ -f "$round_dir/score.json" ]] && (( done_n++ ))
  [[ -f "$round_dir/report.md" ]] && (( done_n++ ))
  local pct=$(( done_n * 100 / total ))

  # ── Draw ──
  printf '\033[H'

  hline "+" "-" "+"
  row "${B}${WHT}AUTO-ADVISOR${RST}  ${GRY}|${RST}  Run ${run_id}  ${GRY}|${RST}  ${DM}${elapsed}${RST}"
  row "${GRY}${idea}${RST}"
  hline "+" "-" "+"

  # Round + score
  local sbar; sbar="$(score_bar "$score_int" 16)"
  row "${B}Round ${current_round}/${max_rounds}${RST}   ${sbar}  ${B}${score_int}${RST}/100${delta_str}"
  hline "+" "-" "+"

  # Progress bar (ASCII only)
  local pw=45
  local pf=$(( pct * pw / 100 ))
  local pe=$(( pw - pf ))
  local pbar="${SKY}"
  for (( i=0; i<pf; i++ )); do pbar+="#"; done
  pbar+="${GRY}"
  for (( i=0; i<pe; i++ )); do pbar+="."; done
  pbar+="${RST}"
  row "Progress ${pbar} ${B}${pct}%%${RST}"
  hline "+" "-" "+"

  # ── Advisors ──
  row "${B}${WHT}ADVISORS${RST}"

  for i in "${!ADVISOR_NAMES[@]}"; do
    local num; num=$(printf "%02d" $((i+1)))
    local name="${ADVISOR_NAMES[$i]}"
    local file="${ADVISOR_FILES[$i]}"
    local color="${ADVISOR_COLORS[$i]}"
    local af="$round_dir/$file"

    local icon detail
    if [[ -f "$af" ]]; then
      icon="$icon_done"
      local ins; ins="$(extract_key_insight "$af")"
      detail="${DM}${ins:-complete}${RST}"
    elif [[ "$phase" == "analyzing" ]] && { [[ "$active_agent" == "parallel" ]] || [[ "$active_agent" == "all-advisors" ]] || echo "$active_agent" | grep -qi "${file%%.*}\|${name%% *}" 2>/dev/null; }; then
      icon="$(icon_run)"
      detail="${YLW}analyzing...${RST}"
    else
      icon="$icon_wait"
      detail="${GRY}waiting${RST}"
    fi

    local pn; pn="$(printf "%-20s" "$name")"
    row " ${icon} ${color}${num} ${pn}${RST} ${detail}"
  done

  emptyrow

  # ── Debate ──
  row "${B}${WHT}DEBATE${RST}"

  for i in "${!DEBATE_NAMES[@]}"; do
    local name="${DEBATE_NAMES[$i]}"
    local df="$round_dir/${DEBATE_FILES[$i]}"

    local icon detail
    if [[ -f "$df" ]]; then
      icon="$icon_done"; detail="${DM}complete${RST}"
    elif [[ "$phase" == "debating" ]] && echo "$active_agent" | grep -qi "${name%% *}\|debate" 2>/dev/null; then
      icon="$(icon_run)"; detail="${YLW}debating...${RST}"
    else
      icon="$icon_wait"; detail="${GRY}waiting${RST}"
    fi

    local pn; pn="$(printf "%-20s" "$name")"
    row " ${icon}    ${MAG}${pn}${RST} ${detail}"
  done

  emptyrow

  # ── Critic + Report ──
  local icon detail
  if [[ -f "$round_dir/score.json" ]]; then
    icon="$icon_done"; detail="${DM}scored${RST}"
  elif [[ "$phase" == "scoring" ]]; then
    icon="$(icon_run)"; detail="${YLW}scoring...${RST}"
  else
    icon="$icon_wait"; detail="${GRY}waiting${RST}"
  fi
  row " ${icon}    ${RED}$(printf "%-20s" "Critic")${RST} ${detail}"

  if [[ -f "$round_dir/report.md" ]]; then
    icon="$icon_done"; detail="${DM}complete${RST}"
  elif [[ "$phase" == "synthesizing" ]]; then
    icon="$(icon_run)"; detail="${YLW}writing...${RST}"
  else
    icon="$icon_wait"; detail="${GRY}waiting${RST}"
  fi
  row " ${icon}    ${CYN}$(printf "%-20s" "Report")${RST} ${detail}"

  hline "+" "-" "+"

  # ── Score history ──
  row "${B}${WHT}SCORE HISTORY${RST}"
  if [[ -f "$run_dir/scores/history.json" ]]; then
    local scores
    scores="$(python3 -c "
import json
h=json.loads(open('$run_dir/scores/history.json').read())
for e in h[-6:]: print(f'{e[\"round\"]}:{int(e[\"overall_score\"])}')
" 2>/dev/null || true)"
    if [[ -n "$scores" ]]; then
      while IFS=: read -r r s; do
        local bar; bar="$(score_bar "$s" 30)"
        row " Round ${r}  ${bar} ${B}${s}${RST}"
      done <<< "$scores"
    else
      row " ${GRY}No completed rounds yet${RST}"
    fi
  else
    row " ${GRY}No completed rounds yet${RST}"
  fi

  hline "+" "-" "+"

  # ── Activity log ──
  row "${B}${WHT}ACTIVITY LOG${RST}"
  if [[ -f "$STATE_FILE" ]]; then
    local acts
    acts="$(python3 -c "
import json
d=json.loads(open('$STATE_FILE').read())
for e in d.get('activity_log',[])[:6]:
    ts=e.get('timestamp','')
    t=ts[11:16] if len(ts)>16 else ts[:5]
    lv=e.get('level','info')
    msg=e.get('message','')[:50]
    ic='ok' if lv=='info' else '!!' if lv=='warning' else 'xx'
    print(f'{t}|{ic}|{msg}')
" 2>/dev/null || true)"
    if [[ -n "$acts" ]]; then
      while IFS='|' read -r ts ic msg; do
        local ic_c="$GRN"
        [[ "$ic" == "!!" ]] && ic_c="$YLW"
        [[ "$ic" == "xx" ]] && ic_c="$RED"
        row " ${GRY}${ts}${RST}  ${ic_c}${ic}${RST}  ${msg}"
      done <<< "$acts"
    else
      row " ${GRY}No activity yet${RST}"
    fi
  fi

  hline "+" "-" "+"

  # Footer
  if [[ "$status" == "complete" ]]; then
    printf " ${GRN}${B}Run complete${RST} -- Final score: ${B}${score_int}/100${RST}\n"
  else
    local s="${SPINNER[$(( FRAME % ${#SPINNER[@]} ))]}"
    printf " ${CYN}${s}${RST} ${GRY}Refreshing every ${POLL_INTERVAL}s | Ctrl+C to exit${RST}\n"
  fi

  printf '\033[J'  # clear below
}

# ── Main ──────────────────────────────────────────────────────

main() {
  local run_dir
  run_dir="$(find_run_dir "${1:-}")"

  printf '\033[?25l\033[2J'  # hide cursor + clear

  while true; do
    render "$run_dir"

    if [[ -f "$STATE_FILE" ]]; then
      local st; st="$(json_val "$STATE_FILE" status)"
      [[ "$st" == "complete" ]] && { printf '\033[?25h'; exit 0; }

      if [[ -z "${1:-}" ]]; then
        local latest
        latest="$(ls -1d "$OUTPUT_ROOT"/run-* 2>/dev/null | sort | tail -1)"
        [[ -n "$latest" && "$latest" != "$run_dir" ]] && { run_dir="$latest"; START_EPOCH=""; }
      fi
    fi

    sleep "$POLL_INTERVAL"
  done
}

main "$@"
