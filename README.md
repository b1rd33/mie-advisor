# MIE Business Advisor

A Claude Code skill package that gives you 8 expert business advisors trained on frameworks from TU Wien's Management of Innovation & Entrepreneurship (MIE) program.

## Quick Start

```bash
git clone https://github.com/b1rd33/mie-advisor.git
cd MIE-advisor
```

Then in Claude Code:

```
/mie-advisor analyze "An app that helps freelancers track and optimize their tax deductions"
```

## Commands

| Command | What it does |
|---------|-------------|
| `/mie-advisor analyze "idea"` | Full 8-advisor analysis with debate, scoring, and report |
| `/mie-advisor consult strategy "question"` | Single advisor deep dive |
| `/mie-advisor challenge "assumption"` | 3-advisor stress test of a claim |

## The Advisors

| # | Name | Discipline | What they focus on |
|---|------|-----------|-------------------|
| 01 | Lena Voss | Design Thinking | User empathy, Jobs To Be Done, behavioral assumptions |
| 02 | Adrian Vale | Product Management | MVP definition, prioritization, product-market fit |
| 03 | Helena Mora | Innovation Management | Innovation type, S-curves, disruption patterns |
| 04 | Kevin Coyne | Advanced Strategy | Competitive advantage, moats, wedge analysis |
| 05 | Maya Chen | Entrepreneurship | Validation, unit economics, lean experiments |
| 06 | Nico Ferran | Exploring Opportunity | Market sizing, beachhead, GTM, pricing |
| 07 | Nadia Soler | Business in Society | Stakeholder mapping, externalities, ESG |
| 08 | Cole Mercer | Silicon Valley Insights | VC lens, kill price math, distribution, scaling |

## How `analyze` Works

```
Phase 1: All 8 advisors analyze your idea (each applying their specific frameworks)
Phase 2: Structured debate — odd advisors challenge even, then defenders respond
Phase 3: Harsh scoring on 8 dimensions (0-100)
Phase 4: Final report with action plan
```

The debate is where the magic happens — advisors argue with each other using competing frameworks, surfacing risks that no single perspective would catch.

## Example Output

A `/mie-advisor analyze` run produces:
- Executive summary with go/no-go recommendation
- 8 individual advisor assessments with verdicts
- Debate synthesis (consensus, disagreements, new insights)
- Scoring across 8 dimensions
- Concrete action plan (this week / this month / this quarter)
- Top 10 critical questions ranked by importance

## Advisor Names for `consult`

Use these with `/mie-advisor consult [name] "question"`:

`design-thinking` · `product-mgmt` · `innovation` · `strategy` · `entrepreneurship` · `opportunity` · `society` · `silicon-valley`

## Adding New Advisors

When new courses are completed, add:
1. A knowledge file in `auto-advisor/knowledge/[course-name].md`
2. A persona file in `auto-advisor/.claude/agents/[NN]-[name]-advisor.md`
3. Update the advisor table in `.claude/skills/mie-advisor.md`

Planned additions:
- Finance & Accounting
- Marketing & Customer Acquisition
- Operations & Supply Chain
- Legal & IP Strategy

## Requirements

- [Claude Code](https://claude.com/claude-code) CLI
- That's it. The skills work with Claude's built-in web search.

## License

MIT — built for MIE students at TU Wien. Use it, share it, improve it.
