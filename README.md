# MIE Business Advisor

8 AI business advisors that stress-test your startup ideas using real frameworks from ESADE's MIE program. Built as a skill for Claude Code, Codex, and similar AI coding tools.

> Hey MIE folks — if you have a business idea for class, run it through this before your pitch. It will find the holes your professors will find. Use it, fork it, improve it.

## Install

### Claude Code

```bash
git clone https://github.com/b1rd33/mie-advisor.git
cd mie-advisor
claude
```

The skill loads automatically. Type `/mie-advisor` and go.

### OpenAI Codex CLI

```bash
git clone https://github.com/b1rd33/mie-advisor.git
cd mie-advisor
codex exec -m gpt-5.4 --full-auto 'Run /mie-advisor challenge "my assumption here"'
```

### Other AI Tools (Cursor, Windsurf, etc.)

Clone the repo and open it in your tool. If it reads `.claude/skills/` markdown files, it will pick up the skill automatically. If not, copy the content of `.claude/skills/mie-advisor.md` into your system prompt or custom instructions.

## What It Does

You give it a business idea. It runs 8 expert advisors — each with a different discipline and real course frameworks — then they debate each other and score the result.

### Three Commands

```
/mie-advisor analyze "An app that helps freelancers optimize tax deductions"
```
Full analysis: 8 advisors + debate + scoring + action plan. Takes a few minutes.

```
/mie-advisor challenge "Restaurants will pay $99/month for this"
```
Quick stress-test: 3 advisors attack your assumption. Under 2 minutes.

```
/mie-advisor consult strategy "Is there a real moat here?"
```
Single advisor deep dive. Pick the lens you want.

## The 8 Advisors

| # | Name | Discipline | What they look for |
|---|------|-----------|-------------------|
| 01 | Lena Voss | Design Thinking | User empathy, Jobs To Be Done, behavioral assumptions |
| 02 | Adrian Vale | Product Management | MVP definition, prioritization, product-market fit |
| 03 | Helena Mora | Innovation Management | Innovation type, S-curves, disruption patterns |
| 04 | Kevin Coyne | Advanced Strategy | Competitive advantage, moats, wedge analysis |
| 05 | Maya Chen | Entrepreneurship | Validation, unit economics, lean experiments |
| 06 | Nico Ferran | Exploring Opportunity | Market sizing, beachhead, GTM, pricing |
| 07 | Nadia Soler | Business in Society | Stakeholder mapping, externalities, ESG |
| 08 | Cole Mercer | Silicon Valley Insights | VC lens, kill price math, distribution, scaling |

Each advisor uses real named frameworks from ESADE courses — not generic advice. They cite specific models like the Three-Leg Test, Beer Zone pricing, Empathy Maps, and Customer Development.

## How `analyze` Works

```
Phase 1  All 8 advisors analyze your idea independently
Phase 2  Structured debate — odd-numbered advisors challenge even, defenders respond
Phase 3  Harsh scoring on 8 dimensions (0-100, anti-inflation rules apply)
Phase 4  Final report with executive summary, verdicts, and action plan
```

The debate surfaces risks no single perspective catches. In testing, it found things like "the JUICER/Wendy's pricing backlash means your category has a trust problem" — insights that only emerged from advisors arguing with each other.

## What You Get

A `/mie-advisor analyze` run produces:
- Executive summary with go/no-go recommendation
- 8 individual assessments with verdicts (green/yellow/red)
- Debate synthesis: consensus, unresolved disagreements, new insights
- Score breakdown across 8 dimensions
- Action plan: this week / this month / this quarter
- Top 10 critical questions ranked by importance

## Advisor Names for `consult`

`design-thinking` · `product-mgmt` · `innovation` · `strategy` · `entrepreneurship` · `opportunity` · `society` · `silicon-valley`

## Adding New Advisors

When new courses are completed:
1. Add a knowledge file in `auto-advisor/knowledge/[course-name].md`
2. Add a persona file in `auto-advisor/.claude/agents/[NN]-[name]-advisor.md`
3. Update the advisor table in `.claude/skills/mie-advisor.md`

Planned:
- Finance & Accounting
- Marketing & Customer Acquisition
- Operations & Supply Chain
- Legal & IP Strategy

## Requirements

- [Claude Code](https://claude.com/claude-code) or [Codex CLI](https://github.com/openai/codex) or any AI tool that reads skill files
- The advisors use web search for real market data — works best with internet access enabled

## License

MIT — built for MIE students at ESADE. Use it, share it, improve it.
