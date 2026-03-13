# Design Thinking — Distilled Knowledge

## Core Philosophy

Design thinking is a human-centered problem-solving discipline that insists you understand the user's actual experience before proposing solutions. It separates understanding from solving, generation from evaluation, and learning from shipping. The fundamental premise is that your assumptions about users are wrong until proven otherwise — what users say, what they do, and what they need are often three different things. The methodology is iterative: test results loop back to redefine the problem, not just forward to "build it."

## Key Frameworks & Models

### Stanford d.school 5-Stage Process
- **What it is**: The canonical design thinking process: Empathize → Define → Ideate → Prototype → Test.
- **When to use it**: Any time a team needs to deeply understand a problem before building a solution — especially when the problem is ambiguous or user needs are unclear.
- **How it works**:
  1. **Empathize** — observe and interview users to understand their actual behaviors, pains, and workarounds (20% of time)
  2. **Define** — synthesize empathy data into POV statements and How Might We questions (20%)
  3. **Ideate** — generate 80-100+ ideas using divergent methods before converging with structured voting (25%)
  4. **Prototype** — build low-fidelity, testable artifacts that answer specific questions about riskiest assumptions (20%)
  5. **Test** — get feedback from real users who have the actual problem, seeking disconfirmation not validation (15%)
- **Key questions it answers**:
  - Who is the real user and what do they actually experience?
  - What is the non-obvious insight hiding in the empathy data?
  - Which assumption, if wrong, would kill this idea?

### Empathy Map (Says / Does / Thinks / Feels)
- **What it is**: A four-quadrant framework for structuring user observations, separating direct evidence from inference.
- **When to use it**: After user interviews or observations, to synthesize what you learned before defining the problem.
- **How it works**:
  1. Fill SAYS quadrant with direct user quotes only
  2. Fill DOES with observable behaviors (not what they claim to do)
  3. Identify contradictions between SAYS and DOES — these are gold
  4. Fill THINKS and FEELS with inferences, clearly labeled as interpretation
  5. Flag any contradictions between quadrants as key insights
- **Key questions it answers**:
  - Where do user words and actions diverge?
  - What emotional undercurrents drive behavior?
  - What are users thinking but not saying?

### POV (Point of View) Statement
- **What it is**: A structured problem definition format: "[USER] needs [NEED] because [INSIGHT]."
- **When to use it**: After empathy synthesis, before ideation — to crystallize the problem worth solving.
- **How it works**:
  1. USER must be a specific person or archetype (not "people" or "users")
  2. NEED must be a verb — a functional, emotional, or social need (not a solution)
  3. INSIGHT must be non-obvious — the "because" should surprise
  4. Test: if removing the "because" leaves the statement still interesting, the insight is weak
  5. Generate 3+ POV statements to avoid premature convergence on one framing
- **Key questions it answers**:
  - What is the actual need behind the surface request?
  - What non-obvious insight reframes this problem?

### How Might We (HMW) Questions
- **What it is**: A reframing technique that converts problem statements into creative springboards for ideation.
- **When to use it**: After POV statements, as the bridge between Define and Ideate.
- **How it works**:
  1. Take each POV statement and reframe as "How might we..."
  2. Calibrate scope: broad enough for many solutions, narrow enough to be actionable
  3. Generate variations: amplify the positive, remove the negative, explore the opposite, question assumptions, go after adjacencies
  4. Test: if HMW contains a solution ("HMW build an app") it's too narrow; if it's vague ("HMW help people") it's too broad
  5. Select 3-5 strongest HMWs for ideation
- **Key questions it answers**:
  - How do we frame the problem as an invitation to solve?
  - What creative constraints focus ideation productively?

### Two-Wall Multi-Stakeholder Pain Mapping
- **What it is**: A method for mapping pain points of multiple stakeholders separately, then finding viable intersections.
- **When to use it**: When a project serves multiple stakeholders (e.g., client AND end-user, platform AND creator).
- **How it works**:
  1. Map Stakeholder A's pain points on one wall (one color)
  2. Map Stakeholder B's pain points on another wall (different color)
  3. Find intersections — pains appearing on both walls = viable concept territory
  4. Pains on only one wall = warning signs (solving for one side only)
  5. If 3+ strong intersections exist, proceed; 0 intersections = go back to Empathize
- **Key questions it answers**:
  - Where do multiple stakeholder needs overlap?
  - Are we solving for one side at the expense of another?

### Divergent / Convergent Thinking (Double Diamond)
- **What it is**: The discipline of separating idea generation from idea evaluation — never doing both simultaneously.
- **When to use it**: During every phase, but especially Ideate. Applies to problem space (understand broadly, then focus) and solution space (generate widely, then select).
- **How it works**:
  1. DIVERGENT: generate without judgment — "Yes, AND..." never "Yes, BUT..."
  2. Aim for 80-100+ ideas; best ideas typically emerge in the 40-80 range after obvious ones are exhausted
  3. CONVERGENT: evaluate with criteria derived from user needs, not gut feeling
  4. Use structured methods (dot voting, evaluation matrix) not loudest voice wins
  5. Never evaluate during generation; never generate during evaluation
- **Key questions it answers**:
  - Have we explored widely enough before narrowing?
  - Are we selecting based on evidence or personal preference?

### Concept Cards + Riskiest Assumption Testing
- **What it is**: A prototyping framework that forces teams to identify what must be true for a concept to work, then test that specific assumption.
- **When to use it**: When moving from ideation to prototyping — to ensure prototypes answer real questions.
- **How it works**:
  1. For each concept, create a card: Name, Insight, Idea, Why Different, Riskiest Assumption, Quick Sketch
  2. Identify the ONE thing that must be true for the concept to work
  3. Build a prototype that tests exactly that assumption
  4. If the riskiest assumption is invalidated, the concept needs fundamental rethinking
  5. Prototype the riskiest part first, not the easiest part
- **Key questions it answers**:
  - What is the single biggest risk in this concept?
  - Are we prototyping to learn or just to feel productive?

### Feedback Capture Grid (Likes / Wishes / Questions / Ideas)
- **What it is**: A structured format for capturing user testing feedback across four dimensions.
- **When to use it**: After each user testing session, and consolidated after 3-5 tests.
- **How it works**:
  1. LIKES (+): what worked, what excited them
  2. WISHES (Δ): what they would change
  3. QUESTIONS (?): what confused them, what we still don't know
  4. IDEAS (!): new ideas that emerged during testing
  5. After 3-5 tests, consolidate: consistent LIKES = validated, consistent WISHES = clear improvement areas, remaining QUESTIONS = loop back to Empathize
- **Key questions it answers**:
  - What patterns emerge across multiple user tests?
  - What do we still not understand?

### Pre-Mortem Analysis
- **What it is**: A prospective failure analysis that imagines the project has failed and works backward to identify why.
- **When to use it**: During the Test phase, before committing to a direction — to surface risks the team is not discussing.
- **How it works**:
  1. Prompt: "It's 6 months from now. This project has completely failed. Why?"
  2. Everyone writes failure scenarios silently (3 min)
  3. Share and cluster failure modes
  4. For top 3: identify early warning signals
  5. Define preventive actions to take NOW
- **Key questions it answers**:
  - What failure modes are we ignoring?
  - What early signals should we watch for?

## Ideation Techniques (Divergent Methods)

- **Brainwriting (6-3-5)**: 6 people, 3 ideas per round, 5 minutes, rotate — produces 108 ideas without groupthink
- **Crazy 8s**: 8 ideas in 8 minutes (1 per minute) — time pressure forces past obvious solutions
- **"What Would X Do?"**: Apply unexpected perspectives (Airbnb, a 5-year-old, 1950 vs 2050) — forces lateral thinking
- **Worst Possible Idea**: Generate terrible ideas then flip them — humor reboots energy and reveals innovation
- **SCAMPER**: Substitute, Combine, Adapt, Modify, Put to other use, Eliminate, Reverse — systematic idea modification
- **Random Input Stimulus**: Force connections between random words/objects and the problem

## Convergent Methods

- **Affinity Clustering**: Silent grouping of ideas into themes, then naming clusters
- **Dot Voting**: Limited votes per person, cast silently against user-need criteria (not preference)
- **Evaluation Matrix (2x2)**: Impact vs. Effort grid — Quick Wins, Big Bets, Fill-Ins, Money Pits
- **Now-Wow-How Sort**: NOW (easy, not novel), WOW (novel AND feasible — the stars), HOW (innovative but hard)

## Mental Models & Principles

- **You are NOT the user.** Your assumptions are wrong until proven otherwise.
- **Separate SAYS from DOES.** User words and actions often contradict — the contradiction is the insight.
- **Build to think, not to ship.** Prototypes are questions, not answers. If you're not embarrassed by your prototype, you waited too long.
- **A well-defined problem is half-solved.** Most teams define too broadly or too narrowly.
- **Quantity beats quality in ideation.** The best ideas come after the obvious ones are exhausted (ideas 40-80).
- **Test the problem, not the solution.** If people don't care about the problem, the solution is irrelevant.
- **Iterate, don't linear-march.** Test results loop back to Empathize/Define, not just forward to "ship."
- **Contradictions are gold.** Where users say one thing and do another, or where stakeholder needs conflict — that's where insight lives.
- **Emotional and social pains are more powerful than functional pains.** "I feel stupid when..." drives behavior more than "it takes too long."
- **The Mom Test**: Talk about their life, not your idea. Ask about specifics in the past, not hypotheticals about the future.

## Common Mistakes & Anti-Patterns

- **Solution as problem**: "The problem is we don't have an app" — that's a solution, not a need. Ask what need the app would fulfill.
- **Premature convergence**: Stopping at 10-15 ideas when you need 80+. The first ideas are obvious; the good ones come later.
- **Groupthink**: Everyone agrees immediately. If no one disagrees, the team hasn't looked hard enough.
- **Empathy theater**: "We understand our users" without specific evidence — no quotes, no observed behaviors, no surprises.
- **HMW too broad**: "How might we make everything better?" — useless for ideation.
- **HMW too narrow**: "How might we add a search button?" — that's already a solution.
- **Confirmation bias in testing**: "Users loved it!" — did anyone hate it? What would make this fail?
- **Skipping to pretty**: Spending hours polishing a prototype instead of testing the riskiest assumption.
- **Synthesis skipping**: Jumping from interviews straight to brainstorming without extracting insights.
- **Converging on gut**: "I just like idea #3 best" — liking an idea is not the same as it serving the user need.
- **Testing with friends**: Friends will be nice. Test with people who have the actual problem.
- **Defending the prototype during testing**: Observe and listen; never explain or defend.

## How This Discipline Challenges Others

Design thinking pushes back on other disciplines by insisting on:

- **Understanding before strategy**: Challenges strategy advisors who build competitive maps before understanding if the user even has the problem. "Your Five Forces analysis is meaningless if you're solving a problem nobody has."
- **Evidence over frameworks**: Challenges entrepreneurship advisors who score opportunities on paper without talking to users. "Your PoD scorecard says the market is big, but have you watched someone try to solve this problem?"
- **Problem before product**: Challenges product managers who define MVPs before validating the core need. "You're prioritizing features for a product that might be solving the wrong problem."
- **Divergence before convergence**: Challenges any discipline that jumps to a single solution too quickly. "You've committed to one approach after considering three options. That's not enough."
- **Emotional needs matter**: Challenges purely analytical approaches that ignore how users feel. "The numbers say this should work, but users feel anxious using it. That kills adoption."
- **Iteration is not failure**: Challenges linear planning disciplines. "Your 12-month roadmap assumes you got everything right on day one. When did that last happen?"

## Key Vocabulary & Concepts

- **Empathy Map**: Four-quadrant tool (Says/Does/Thinks/Feels) for structuring user observations
- **POV Statement**: "[User] needs [need] because [insight]" — the problem definition format
- **HMW (How Might We)**: Problem reframing technique that creates ideation springboards
- **Divergent Thinking**: Generating options without judgment — quantity over quality
- **Convergent Thinking**: Evaluating and selecting with criteria — structured, not gut-based
- **Double Diamond**: Two-phase expansion-contraction: first in problem space, then in solution space
- **Riskiest Assumption**: The one thing that must be true for a concept to work — prototype this first
- **Wizard of Oz Prototype**: Users interact with what looks automated, but a human operates behind the scenes
- **Concept Card**: Structured capture of a concept's essence: name, insight, idea, differentiator, riskiest assumption
- **Affinity Clustering**: Silent grouping of ideas by theme to find patterns
- **The Mom Test**: Interview methodology — talk about their life, not your idea; past specifics, not future hypotheticals
- **Pre-Mortem**: "It failed. Why?" — prospective failure analysis to surface hidden risks
- **Service Blueprint**: Maps customer actions, frontstage, backstage, and support processes for service design
- **Bodystorming**: Physical role-play of a service or experience to test how it feels in context

## Decision Criteria for Business Ideas

**STRONG signal (design thinking perspective):**
- Founder can describe specific user behaviors, quotes, and workarounds from direct observation
- The problem is validated with evidence of emotional or social pain, not just functional inconvenience
- The idea emerged from a genuine non-obvious insight ("We expected X but found Y")
- Multiple stakeholder needs have been mapped and intersections identified
- Riskiest assumptions have been explicitly named and at least partially tested
- Users describe the problem with frustration, resignation, or elaborate workarounds — strong emotional signals

**WEAK signal (needs more work):**
- Idea is based on what founder thinks users need, not what users demonstrated
- No contradictions found between user words and actions — empathy isn't deep enough
- Problem definition is either too broad ("improve healthcare") or too narrow ("add a button")
- Only one solution considered — premature convergence
- Testing was done with friends or colleagues, not people with the actual problem
- "Users loved it" without any critical feedback or invalidated assumptions

**RED FLAG (fundamental design thinking concerns):**
- Founder cannot name a specific user or describe their day
- Idea is a solution looking for a problem ("We built X, now who needs it?")
- No user research conducted — just market data and assumptions
- All validation is hypothetical ("Would you use this?" "Would you pay?")
- Team is emotionally attached to the solution and resistant to pivoting
- No iteration planned — the first version is expected to be right
