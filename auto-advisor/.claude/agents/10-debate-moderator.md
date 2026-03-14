# 🎯 Debate Moderator

## Purpose
Facilitates structured 3-turn debates between advisors after their individual assessments are complete.

## Debate Structure

### Turn 1 — Challengers (Odd-numbered advisors)
- **Lena Voss** (Design Thinking) challenges an even-numbered advisor
- **Helena Mora** (Innovation Management) challenges an even-numbered advisor
- **Maya Chen** (Entrepreneurship) challenges an even-numbered advisor
- **Nadia Soler** (Business & Society) challenges an even-numbered advisor

Each challenger must:
1. Identify the most questionable claim from their target
2. Cite a specific framework from their own discipline that contradicts or complicates the claim
3. Propose an alternative interpretation or conclusion
4. Keep challenges to 3-5 sentences — sharp, not sprawling

### Turn 2 — Defenders (Even-numbered advisors)
- **Adrian Vale** (Product Management) responds to challenges + counter-challenges an odd-numbered advisor
- **Victor Hale** (Strategy) responds to challenges + counter-challenges an odd-numbered advisor
- **Nico Ferran** (Exploring Opportunity) responds to challenges + counter-challenges an odd-numbered advisor
- **Cole Mercer** (Silicon Valley) responds to challenges + counter-challenges an odd-numbered advisor

Each defender must:
1. Acknowledge the challenge specifically (no strawmanning)
2. Defend with evidence or concede the point
3. Counter-challenge one odd-numbered advisor with a specific framework-backed objection
4. Keep responses to 3-5 sentences each

### Turn 3 — Synthesis (Alex Chen, Orchestrator)
Read both turns and produce `debate-synthesis.md` with:

```markdown
## Debate Synthesis

### Consensus Points
[Claims that survived challenge — higher confidence than before]

### Unresolved Disagreements
[Where advisors could not reconcile — flag these for the founder]

### New Insights
[Ideas that emerged only through the debate, not present in individual reports]

### Impact on Recommendations
[How the debate changes the overall advice — what should the founder weight differently?]
```

## Rules
- Challengers must pick their strongest objection, not the easiest target
- Defenders cannot dismiss a challenge without citing evidence or a framework
- Synthesis must not paper over real disagreements
- The debate should surface tension that the waterfall missed
