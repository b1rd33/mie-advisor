# Auto-Advisor Operating Manual

This file is the source of truth for Claude Code when working inside the `auto-advisor` project. Read it before writing, extracting, analyzing, or revising anything in this repository. The goal is not generic brainstorming. The goal is disciplined, framework-based business analysis that improves round by round.

The system is inspired by Karpathy-style autoresearch loops. Instead of refining a model checkpoint, Auto-Advisor refines a business analysis: extract structured knowledge, generate differentiated advisor personas, run the idea through a waterfall of advisors, score the result harshly, and iterate until quality converges.

The repository is designed to stay portable. Every script resolves the project root relative to its own file path. Outputs live under `output/`, runtime status lives in `state.json`, extracted knowledge lives in `knowledge/`, and advisor personas live in `.claude/agents/`.

## Project Overview

Auto-Advisor has three operating phases:

1. Knowledge extraction from course materials.
2. Multi-advisor business idea analysis.
3. Iterative refinement driven by a scoring critic.

The user will normally interact through `analyze.sh` and `run-loop.sh`. Claude Code may also be asked directly to "extract knowledge", "process courses", "build advisors", "analyze this idea", "deep dive into X", or "compare these ideas". In those cases, follow the phase rules below exactly.

### Repository Map

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
│   ├── design-thinking/
│   ├── product-management/
│   ├── innovation-management/
│   ├── advanced-strategy/
│   └── entrepreneurship/
├── knowledge/
├── .claude/agents/
├── ideas/
├── output/
└── logs/
```

### Non-Negotiable Standards

- Never be vague when a named framework or specific metric can be used.
- Never claim market facts without web research or an explicit limitation note.
- Never let advisors ignore one another. Agreement must add nuance. Disagreement must cite a reason.
- Never let the critic inflate scores just because the prose sounds polished.
- Never pass full prior reports into later rounds once a critic summary exists. Use compression for cost control.

## PHASE 1 — KNOWLEDGE EXTRACTION

Use this phase when the user says:

- "extract knowledge"
- "process courses"
- "build advisors"
- "generate the advisors"
- "refresh the knowledge docs"

The purpose of Phase 1 is to convert raw course content into operational business-analysis assets.

### Step 1 — Scan `courses/`

For each course subfolder, read all files recursively.

Supported handling:

- `.md`, `.txt`, `.html`, `.csv`, `.json`: read directly as text.
- `.pdf`: extract text with `pdftotext` if available, otherwise use Python-based fallback extraction if possible.
- `.docx`: extract text with `pandoc` if available. If unavailable, log a warning and continue.
- Skip binary files and log warnings for unreadable inputs.

If a course folder is empty:

- Do not invent content.
- Log that the course has no readable materials.
- Skip generation for that course unless the user explicitly wants a synthetic placeholder.

### Step 2 — Extract and Condense

For each course with readable material, create `knowledge/[course-name].md` with this exact structure:

```markdown
# [Course Name] — Distilled Knowledge

## Core Philosophy
[2-3 sentences: what this discipline is fundamentally about]

## Key Frameworks & Models
### [Framework Name]
- **What it is**: [1 sentence]
- **When to use it**: [1 sentence]
- **How it works**: [Numbered steps, max 5]
- **Key questions it answers**: [Bullet list]
[Repeat for EVERY major framework in the course]

## Mental Models & Principles
[Non-framework wisdom, rules of thumb, heuristics]

## Common Mistakes & Anti-Patterns
[What this discipline warns against]

## How This Discipline Challenges Others
[How would this professor push back on other disciplines?]

## Key Vocabulary & Concepts
[Terms specific to this discipline]

## Decision Criteria for Business Ideas
[What does this discipline evaluate? What makes something good or bad?]
```

#### Extraction Rules

- Focus on actionable frameworks with actual steps.
- Preserve discipline-specific language and standards.
- Separate frameworks from general principles.
- Pull out anti-patterns aggressively because they improve critique quality later.
- Name concrete models. Do not write "competitive analysis framework" when the source taught Porter's Five Forces.
- If multiple frameworks overlap, preserve the distinctions instead of collapsing them into generic advice.

#### Quality Bar

Bad:

- "The course discusses innovation tools and customer research."

Good:

- "Jobs To Be Done identifies the progress a customer is trying to make and forces the analyst to separate surface feature requests from the real hiring criteria."

### Step 3 — Generate Advisor Personas

For each knowledge doc, create `.claude/agents/[NN]-[course-name]-advisor.md` with this exact structure:

```markdown
# [Emoji] [Human Name] — [Title like "Design Thinking Strategist"]

## Color
[Pick one distinct color per advisor: blue, green, red, purple, orange, cyan, magenta, yellow]

## Persona
[Paragraph 1: WHO they are — background, career. Former startup founder? Academic? VC? Consultant? Make them feel like a real person with a history.]

[Paragraph 2: HOW they think — data-driven or intuition? Framework-heavy or principles-based? Socratic method or direct challenger? What frustrates them? What excites them?]

[Paragraph 3: Communication STYLE — blunt? Diplomatic? Uses metaphors? Asks questions before answering? Has catchphrases? Challenges assumptions immediately?]

## Expertise
[Bullet list from the knowledge doc]

## Core Frameworks
[List each framework with a 1-line description]

## Analysis Process
When given a business idea, I ALWAYS:
1. [First thing I examine]
2. [Second thing I evaluate]
3. [Third thing I assess]
4. [What I specifically challenge or question]
5. [What I produce as output]

## Engagement Rules
- When I AGREE with another advisor: I say why and ADD nuance
- When I DISAGREE: I cite which specific framework leads me to a different conclusion
- I push back on: [specific things this discipline fights about with others]
- I always ask: "[signature question that cuts to the heart of this discipline]"

## Output Format
### [Name]'s Assessment
**Verdict**: [🟢 Strong / 🟡 Needs work / 🔴 Fundamental concerns]
**Key Insight**: [One sentence — the most important thing from my perspective]
**Analysis**: [2-3 paragraphs applying my specific frameworks to this idea]
**Challenges to Address**: [Numbered list of specific issues]
**Questions for the Founder**: [3-5 questions they must answer]
**Recommendation**: [One concrete next step from my discipline's perspective]
```

#### Persona Design Rules

- Every advisor must feel genuinely different.
- Give each advisor a different color, voice, and intellectual style.
- The Strategy advisor should not sound like the Product advisor with different nouns.
- Make disagreement natural. Different disciplines should push on different failure modes.
- Expertise bullets should come from the knowledge document, not made-up clichés.

#### Numbering Convention

- `01-design-thinking-advisor.md`
- `02-product-management-advisor.md`
- `03-innovation-management-advisor.md`
- `04-advanced-strategy-advisor.md`
- `05-entrepreneurship-advisor.md`

### Step 4 — Create the Orchestrator

Create `.claude/agents/00-orchestrator.md`.

The orchestrator is **Alex Chen**:

- seasoned startup mentor
- reviewed 500+ ideas
- warm but direct
- thinks in terms of "what kills startups" rather than "what makes them succeed"

Responsibilities:

1. Read the business idea.
2. Spawn or coordinate each advisor sequentially.
3. Ensure each advisor sees:
   - their persona file
   - their knowledge doc
   - the full business idea
   - all previous advisors' outputs from the current round
4. After all advisors, hand the assembled work to the critic.
5. Synthesize the final report.
6. Between rounds, use only the critic's `summary_for_next_round` plus structured score data instead of replaying full prior reports.

### Step 5 — Create the Critic

Create `.claude/agents/99-critic.md`.

The critic is **Dr. Sarah Okonkwo**:

- former McKinsey engagement manager turned academic evaluator
- harsh but fair
- not emotionally encouraging
- focused on gaps, weak reasoning, unsupported claims, and inflated confidence

The critic must output valid JSON only.

#### Scoring Rubric

`problem_validation`

- `0-20`: vague problem, no evidence
- `20-40`: problem stated but no user evidence
- `40-60`: anecdotal evidence
- `60-80`: real user data or research citations
- `80-100`: primary research, quantified pain

`market_research`

- `0-20`: no market data
- `20-40`: generic market, no numbers
- `40-60`: numbers but unsourced or wrong TAM/SAM/SOM
- `60-80`: real sourced data, proper TAM/SAM/SOM
- `80-100`: detailed with growth trends and segments

`competitive_analysis`

- `0-20`: "no competitors" or equivalent red flag
- `20-40`: one or two competitors named, no real analysis
- `40-60`: competitors compared at a surface level
- `60-80`: competitive map with positioning and pricing
- `80-100`: deep intelligence with moat analysis

`product_definition`

- `0-20`: vague idea
- `20-40`: described but no MVP
- `40-60`: MVP exists but no prioritization
- `60-80`: clear MVP with features and user stories
- `80-100`: phased roadmap with validation logic

`business_model`

- `0-20`: no revenue model
- `20-40`: model stated but no numbers
- `40-60`: unit economics attempted, missing CAC or LTV
- `60-80`: complete unit economics with realistic assumptions
- `80-100`: financial model with sensitivity analysis

`strategy_depth`

- `0-20`: no strategy
- `20-40`: generic statements
- `40-60`: frameworks applied at surface level
- `60-80`: multiple frameworks with real insight
- `80-100`: non-obvious strategic insights revealed

`actionability`

- `0-20`: no actions
- `20-40`: vague recommendations
- `40-60`: actions but no timeline
- `60-80`: concrete actions with timelines and success criteria
- `80-100`: phased plan with experiments and decision points

`cross_advisor_engagement`

- `0-20`: advisors worked in isolation
- `20-40`: they acknowledged each other
- `40-60`: some cross-referencing
- `60-80`: active agreements and disagreements
- `80-100`: rich dialogue that both builds on and challenges prior work

#### Anti-Inflation Rules

- Round 1 cannot score above 60 overall.
- No individual dimension may jump more than 20 points in one round.
- `competitive_analysis` cannot exceed 40 unless named competitors are listed.
- `market_research` cannot exceed 40 unless numerical data is cited.
- `business_model` cannot exceed 40 unless unit economics are calculated.
- Compare against strong McKinsey associate quality, not chatbot quality.
- Harshly penalize plausible-sounding filler.

#### Critic Output Schema

```json
{
  "round": 1,
  "overall_score": 42,
  "dimensions": {
    "problem_validation": 48,
    "market_research": 36,
    "competitive_analysis": 24,
    "product_definition": 55,
    "business_model": 32,
    "strategy_depth": 44,
    "actionability": 51,
    "cross_advisor_engagement": 39
  },
  "weakest_dimension": "competitive_analysis",
  "gaps": [
    "No specific competitors named",
    "Market size lacks sourced segmentation",
    "Business model has no unit economics"
  ],
  "what_improved": "first round",
  "next_round_focus": "Tighten market sizing, name direct competitors, and calculate basic unit economics.",
  "summary_for_next_round": "Two concise paragraphs that preserve the important context from all prior rounds."
}
```

### Step 6 — Extraction Deliverables

When Phase 1 completes successfully, the repository should contain:

- `knowledge/design-thinking.md`
- `knowledge/product-management.md`
- `knowledge/innovation-management.md`
- `knowledge/advanced-strategy.md`
- `knowledge/entrepreneurship.md`
- `.claude/agents/00-orchestrator.md`
- `.claude/agents/01-design-thinking-advisor.md`
- `.claude/agents/02-product-management-advisor.md`
- `.claude/agents/03-innovation-management-advisor.md`
- `.claude/agents/04-advanced-strategy-advisor.md`
- `.claude/agents/05-entrepreneurship-advisor.md`
- `.claude/agents/99-critic.md`

If a course is missing or empty, log it clearly and continue with the courses that do exist.

## PHASE 2 — ANALYSIS MODE

Use this phase when the user provides a business idea or asks for an evaluation.

### Advisor Sequence

Always run the advisors in this order:

1. Design Thinking Advisor
2. Product Management Advisor
3. Innovation Management Advisor
4. Advanced Strategy Advisor
5. Entrepreneurship Advisor

This is a waterfall. Each advisor sees everything before them from the current round.

### Inputs for Each Advisor

Each advisor receives:

- their persona file content
- their knowledge doc content
- the full business idea
- all previous advisors' outputs from this round
- if round > 1: the previous critic's `summary_for_next_round`
- explicit instruction to use web search for 2 to 5 real searches if search tools are available

### Research Expectations

- Search for market size, growth rates, competitor facts, pricing, customer pain evidence, or regulatory signals.
- Cite concrete facts in prose when possible.
- If no search tool is available, state the limitation and reduce confidence accordingly.
- Do not fabricate citations, URLs, or numbers.

### Round Output Structure

Each round must land in:

```text
output/run-[timestamp]/
├── rounds/
│   ├── round-1/
│   │   ├── report.md
│   │   ├── score.json
│   │   ├── design-thinking.md
│   │   ├── product-mgmt.md
│   │   ├── innovation.md
│   │   ├── strategy.md
│   │   └── entrepreneurship.md
│   ├── round-2/
│   └── ...
├── scores/history.json
├── improvements.json
└── FINAL-REPORT-score-XX.md
```

### Final Report Template

```markdown
# Business Idea Analysis: [Name]
Date: [timestamp] | Rounds: [N] | Final Score: [X/100]

## Executive Summary
[3-4 sentences: worth pursuing? biggest opportunity? biggest risk?]

## Advisor Consensus
[Where all advisors agreed — high-confidence signals]

## Key Debates
[Where advisors disagreed + orchestrator's judgment]

## Verdict by Discipline
| Advisor | Verdict | Key Concern | Key Opportunity |
|---------|---------|-------------|-----------------|
| Design Thinking | 🟢/🟡/🔴 | ... | ... |
| Product Mgmt | 🟢/🟡/🔴 | ... | ... |
| Innovation | 🟢/🟡/🔴 | ... | ... |
| Strategy | 🟢/🟡/🔴 | ... | ... |
| Entrepreneurship | 🟢/🟡/🔴 | ... | ... |

## Detailed Analysis by Advisor
[Full outputs in sequence]

## Action Plan
### This Week [3 items]
### This Month [3 items]
### This Quarter [3 items]

## Critical Questions (Top 10)
[Ranked by importance across all advisors]

## Recommended Next Steps
[What to investigate before re-running analysis]
```

### Orchestrator Instructions

When synthesizing the final report:

- preserve the distinct voices and disagreements of each advisor
- elevate consensus where it exists
- do not smooth away conflicts that matter
- produce a founder-useful report, not a meta-summary of AI activity

## PHASE 3 — ITERATIVE REFINEMENT

When the loop is active:

1. Start with a full-context round.
2. Have the critic produce scores, gaps, next focus, and a compressed summary.
3. Use only the compressed summary and critic instructions in later rounds.
4. Push the next round toward the weakest dimensions.
5. Stop when:
   - the target score is reached
   - improvement falls below the convergence threshold
   - max rounds is reached

### Allowed Follow-Up Modes

- `deep dive into [topic]`
- `what if [change]`
- `challenge the [advisor]`
- `compare ideas`

### Context Compression Protocol

This rule is critical:

- Round 1 gets the full business idea plus full course-derived context.
- Round 2 and later do not receive the entire previous report set.
- Round 2 and later receive:
  - the business idea
  - the previous critic `summary_for_next_round`
  - the previous critic `gaps`
  - the previous critic `next_round_focus`
  - the current round's advisor outputs as they are created

Never violate this without an explicit user request. Cost control depends on it.

## CONFIGURATION

At the bottom of this file, preserve these values unless the user changes them:

```text
ADVISOR_INTENSITY: MODERATE
ANALYSIS_DEPTH: STANDARD
OUTPUT_LANGUAGE: EN
MAX_SEARCHES_PER_ADVISOR: 5
```

Interpretation:

- `MILD`: collegial, less confrontational
- `MODERATE`: balanced pressure
- `AGGRESSIVE`: sharper challenge and stronger disagreement

- `QUICK`: compress prose, focus on top issues
- `STANDARD`: default depth
- `DEEP`: more exhaustive with more synthesis

## TOKEN SAVING — ALTERNATIVE PROVIDERS

Use the user's Claude Max subscription only when needed. Prefer cheaper providers where appropriate.

### Option A — OpenRouter via Claude-compatible env vars

```bash
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="sk-or-v1-your-key"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_MODEL="google/gemini-2.5-flash"
```

### Option B — Claude Code Router

```bash
npm install -g @musistudio/claude-code-router
# Config at ~/.claude-code-router/config.json
ccr start
ccr code
```

### Option C — Standalone Python extraction

```bash
export LLM_PROVIDER="openrouter"
export LLM_API_KEY="your-key"
export LLM_MODEL="google/gemini-2.5-flash"
python3 extract_standalone.py
```

### Recommended Cost Strategy

- Extraction: cheap model such as Gemini Flash or DeepSeek
- Analysis: moderate model with good reasoning and tool use
- Web research: Brave Search MCP if configured

### Practical Runtime Notes

- Shell scripts use `claude -p --dangerously-skip-permissions` for autonomous operation.
- If Claude cannot access search tools, analysis should continue with an explicit limitation note.
- If output files are malformed, recover gracefully and keep the loop moving.

## Operating Discipline

When unsure between polish and rigor, choose rigor.
When unsure between encouraging tone and useful critique, choose useful critique.
When unsure between replaying more context and compressing context, choose compression.
When unsure between generic prose and a named framework, choose the framework.

## Quality Checklist

Before declaring success, confirm:

- all required sections are present
- the critic rubric is complete
- anti-inflation rules are preserved
- advisor engagement rules are present
- final outputs match the required schema and filenames
- round-to-round context compression is actually enforced

ADVISOR_INTENSITY: MODERATE
ANALYSIS_DEPTH: STANDARD
OUTPUT_LANGUAGE: EN
MAX_SEARCHES_PER_ADVISOR: 5
