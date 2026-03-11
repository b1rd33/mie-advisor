# Auto-Advisor

Auto-Advisor is an autonomous business analysis system for entrepreneurship coursework and idea evaluation. It turns course materials into advisor personas, runs business ideas through a multi-advisor waterfall, scores quality with a strict critic, and iterates until the analysis converges. The system is designed to work with Claude Code directly or cheaper external models for extraction.

## Requirements

- Claude Code CLI installed and authenticated for autonomous runs
- Python 3 with `requests` installed for standalone extraction
- Git available on the command line
- Optional: Brave Search MCP or another search-capable Claude setup
- Optional: local HTTP server for live dashboard mode

## Quick Start

1. Put your course exports in the folders under `courses/`.
2. Build knowledge docs and advisors:
   - `./analyze.sh extract`
   - or `./analyze.sh extract-cheap`
3. Add an idea file under `ideas/` or pass idea text directly.
4. Run a one-shot analysis:
   - `./analyze.sh ideas/example-idea.md`
5. Run the convergence loop:
   - `./run-loop.sh ideas/example-idea.md`
6. Open `dashboard.html` directly for demo mode or serve the folder for live mode:
   - `python3 -m http.server 8000`

## Commands

| Command | Purpose |
| --- | --- |
| `./analyze.sh extract` | Use Claude Code to scan `courses/` and generate knowledge + advisors |
| `./analyze.sh extract-cheap` | Use `extract_standalone.py` with an external API |
| `./analyze.sh "idea text"` | Run one round of idea analysis |
| `./analyze.sh ideas/file.md` | Run one round from a Markdown idea file |
| `./analyze.sh deep "topic"` | Generate a focused deep dive from existing knowledge docs |
| `./analyze.sh compare ideas/a.md ideas/b.md` | Compare two idea files side by side |
| `./run-loop.sh ideas/file.md --max-rounds 8 --budget 5.00` | Run the autonomous convergence loop |

## Workflow

### Phase 1: Knowledge Extraction

- Read every course folder recursively.
- Distill each course into a practical knowledge document.
- Generate one advisor persona per course.
- Create the orchestrator and critic personas.

### Phase 2: Analysis

- Design Thinking evaluates the problem and user pain.
- Product Management defines MVP, priorities, and sequencing.
- Innovation Management evaluates novelty and defensibility.
- Advanced Strategy examines competition, market structure, and economics.
- Entrepreneurship focuses on go-to-market and execution.
- The critic scores the output on eight dimensions.

### Phase 3: Iteration

- The loop uses the critic's compressed summary rather than replaying every prior report.
- Weak dimensions become the next-round focus.
- The run stops when it reaches the target score, plateaus, or hits the max round count.

## Token-Saving Options

### OpenRouter for standalone extraction

```bash
export LLM_PROVIDER="openrouter"
export LLM_API_KEY="sk-or-v1-your-key"
export LLM_MODEL="google/gemini-2.5-flash"
./analyze.sh extract-cheap
```

### Claude Code Router

```bash
npm install -g @musistudio/claude-code-router
ccr start
ccr code
```

### Direct OpenRouter env vars for Claude Code

```bash
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="sk-or-v1-your-key"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_MODEL="google/gemini-2.5-flash"
```

## Cost Expectations

- Extraction on a cheap model: about $0.05
- One-shot analysis: about $0.50 to $2.00 depending on model and search usage
- Web research through Brave MCP: usually free

## Configuration

`CLAUDE.md` defines the expected operating contract for:

- `ADVISOR_INTENSITY`
- `ANALYSIS_DEPTH`
- `OUTPUT_LANGUAGE`
- `MAX_SEARCHES_PER_ADVISOR`

`run-loop.sh` defines runtime defaults for:

- `MAX_ROUNDS`
- `BUDGET_USD`
- `CONVERGENCE_THRESHOLD`
- `MIN_SCORE`

## Customizing Advisors

- Edit the generated knowledge docs in `knowledge/` if you want to sharpen a discipline.
- Edit the generated persona files under `.claude/agents/` if you want stronger personalities.
- Keep the output format and engagement rules intact so the loop stays machine-readable.

## Live Dashboard

- Directly opening `dashboard.html` gives you demo mode if the browser blocks `file://` fetches.
- For live polling of `state.json`, serve the project root with a local HTTP server.
- The dashboard refreshes every 2 seconds and switches from demo to live mode automatically when real state becomes available.

## File Structure

```text
auto-advisor/
├── CLAUDE.md
├── program.md
├── run-loop.sh
├── analyze.sh
├── extract_standalone.py
├── dashboard.html
├── state.json
├── README.md
├── .gitignore
├── courses/
├── knowledge/
├── .claude/agents/
├── ideas/
├── output/
└── logs/
```

## Notes

- All scripts resolve paths relative to their own location, so cloning the project elsewhere is safe.
- The parent folder name can contain spaces; all shell scripts are written with quoted paths.
- The project initializes its own git repository inside `auto-advisor/` when the loop runs in a non-git folder.

## License

MIT
