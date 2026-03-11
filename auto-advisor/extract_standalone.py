#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable

import requests

PROJECT_ROOT = Path(__file__).resolve().parent
COURSES_DIR = PROJECT_ROOT / "courses"
KNOWLEDGE_DIR = PROJECT_ROOT / "knowledge"
AGENTS_DIR = PROJECT_ROOT / ".claude" / "agents"
PROGRAM_FILE = PROJECT_ROOT / "program.md"

TEXT_EXTENSIONS = {".md", ".txt", ".html", ".csv", ".json"}
COURSE_ORDER = [
    ("design-thinking", 1),
    ("product-management", 2),
    ("innovation-management", 3),
    ("advanced-strategy", 4),
    ("entrepreneurship", 5),
]


def log(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(f"WARNING: {message}", file=sys.stderr, flush=True)


def load_env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None or value == "":
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def read_text_file(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def extract_pdf(path: Path) -> str:
    if not shutil_which("pdftotext"):
        raise RuntimeError("pdftotext not installed")
    result = subprocess.run(
        ["pdftotext", str(path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def extract_docx(path: Path) -> str:
    if not shutil_which("pandoc"):
        raise RuntimeError("pandoc not installed")
    result = subprocess.run(
        ["pandoc", str(path), "-t", "plain"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def shutil_which(command: str) -> str | None:
    for directory in os.getenv("PATH", "").split(os.pathsep):
        candidate = Path(directory) / command
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


def iter_course_files(course_dir: Path) -> Iterable[Path]:
    for path in sorted(course_dir.rglob("*")):
        if path.is_file() and not path.name.startswith("."):
            yield path


def read_source_file(path: Path) -> str | None:
    suffix = path.suffix.lower()
    try:
        if suffix in TEXT_EXTENSIONS:
            return read_text_file(path)
        if suffix == ".pdf":
            return extract_pdf(path)
        if suffix == ".docx":
            return extract_docx(path)
    except Exception as exc:  # noqa: BLE001
        warn(f"Failed to read {path.relative_to(PROJECT_ROOT)}: {exc}")
        return None
    return None


def gather_course_content(course_dir: Path) -> tuple[str, list[str]]:
    chunks: list[str] = []
    warnings: list[str] = []
    for path in iter_course_files(course_dir):
        content = read_source_file(path)
        if content is None:
            if path.suffix.lower() not in TEXT_EXTENSIONS | {".pdf", ".docx"}:
                warnings.append(f"Skipped unsupported file: {path.name}")
            else:
                warnings.append(f"Unreadable file: {path.name}")
            continue
        content = content.strip()
        if not content:
            warnings.append(f"Empty file: {path.name}")
            continue
        relative = path.relative_to(course_dir)
        chunks.append(f"\n\n===== SOURCE: {relative} =====\n{content}\n")
    joined = "".join(chunks)
    if len(joined) > 100_000:
        joined = joined[:100_000]
        warnings.append("Content truncated at 100000 characters.")
    return joined, warnings


class LLMClient:
    def __init__(self, provider: str, api_key: str | None, model: str) -> None:
        self.provider = provider.lower()
        self.api_key = api_key
        self.model = model

    def complete(self, prompt: str) -> str:
        if self.provider == "anthropic":
            return self._anthropic(prompt)
        if self.provider in {"openrouter", "deepseek", "openai", "ollama"}:
            return self._chat_completions(prompt)
        raise RuntimeError(f"Unsupported provider: {self.provider}")

    def _chat_completions(self, prompt: str) -> str:
        url_map = {
            "openrouter": "https://openrouter.ai/api/v1/chat/completions",
            "deepseek": "https://api.deepseek.com/chat/completions",
            "openai": "https://api.openai.com/v1/chat/completions",
            "ollama": "http://localhost:11434/v1/chat/completions",
        }
        url = url_map[self.provider]
        headers = {"Content-Type": "application/json"}
        if self.provider != "ollama":
            if not self.api_key:
                raise RuntimeError("LLM_API_KEY is required for this provider")
            headers["Authorization"] = f"Bearer {self.api_key}"
        payload = {
            "model": self.model,
            "temperature": 0.3,
            "messages": [
                {"role": "system", "content": "You produce structured, implementation-grade business-analysis artifacts."},
                {"role": "user", "content": prompt},
            ],
        }
        response = requests.post(url, headers=headers, json=payload, timeout=120)
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"].strip()

    def _anthropic(self, prompt: str) -> str:
        if not self.api_key:
            raise RuntimeError("LLM_API_KEY is required for anthropic")
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }
        payload = {
            "model": self.model,
            "max_tokens": 4000,
            "temperature": 0.3,
            "messages": [{"role": "user", "content": prompt}],
        }
        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers=headers,
            json=payload,
            timeout=120,
        )
        response.raise_for_status()
        data = response.json()
        return data["content"][0]["text"].strip()


def knowledge_prompt(course_name: str, content: str) -> str:
    return f"""You are extracting practical business-analysis knowledge from course materials.

Follow the exact output structure below and do not add extra sections.
Use specific frameworks, real steps, and explicit anti-patterns.
Do not be generic.

Required structure:
# {course_name.replace('-', ' ').title()} — Distilled Knowledge

## Core Philosophy

## Key Frameworks & Models
### [Framework Name]
- **What it is**:
- **When to use it**:
- **How it works**:
- **Key questions it answers**:

## Mental Models & Principles

## Common Mistakes & Anti-Patterns

## How This Discipline Challenges Others

## Key Vocabulary & Concepts

## Decision Criteria for Business Ideas

Source material:
{content}
"""


def persona_prompt(course_name: str, knowledge_doc: str, number: int) -> str:
    return f"""Create a differentiated advisor persona for the {course_name.replace('-', ' ')} discipline.

Requirements:
- This is advisor number {number:02d}.
- The persona must feel like a real human expert with a distinct background, style, and intellectual bias.
- Keep the exact section structure below.
- Make disagreement with other disciplines feel natural.

Required structure:
# [Emoji] [Human Name] — [Title]

## Color

## Persona
[3 paragraphs]

## Expertise

## Core Frameworks

## Analysis Process
When given a business idea, I ALWAYS:
1. ...
2. ...
3. ...
4. ...
5. ...

## Engagement Rules
- When I AGREE with another advisor: I say why and ADD nuance
- When I DISAGREE: I cite which specific framework leads me to a different conclusion
- I push back on: ...
- I always ask: "..."

## Output Format
### [Name]'s Assessment
**Verdict**: [🟢 Strong / 🟡 Needs work / 🔴 Fundamental concerns]
**Key Insight**: ...
**Analysis**: ...
**Challenges to Address**: ...
**Questions for the Founder**: ...
**Recommendation**: ...

Knowledge base:
{knowledge_doc}
"""


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.rstrip() + "\n", encoding="utf-8")


def build_orchestrator() -> str:
    return """# 🧭 Alex Chen — Startup Orchestrator

## Color
cyan

## Persona
Alex Chen is a former operator turned startup mentor who has reviewed hundreds of early-stage ideas across SaaS, consumer, climate, and marketplace businesses. He has seen smart founders waste years on elegant but unnecessary products, and he has a habit of listening for the quiet assumptions that later become company-killing problems.

He thinks in terms of startup failure modes. He does not ask "is this interesting?" first. He asks "what breaks this?" first. He likes practical evidence, sequencing logic, and founders who can separate signal from hope.

He is warm, concise, and direct. He lets each specialist advisor do real specialist work, then forces the disagreement into the open so the founder can see where the true risks live.

## Responsibilities
- Read the business idea carefully before coordinating any work.
- Run advisors sequentially, not in parallel, so each sees the evolving argument.
- Preserve advisor disagreement instead of flattening it.
- Hand the final round to the critic for scoring.
- Synthesize the final report for founder use.
- In iterative runs, use the critic's compressed summary instead of replaying the full past report set.
"""


def build_critic() -> str:
    return """# 🧪 Dr. Sarah Okonkwo — Critic

## Color
red

## Persona
Dr. Sarah Okonkwo is a former McKinsey engagement manager who moved into academic evaluation and venture-program assessment. She has reviewed decks, incubator applications, and strategy memos long enough to spot the difference between real analytical progress and polished filler.

She is not here to encourage the founder. She is here to prevent self-deception. She scores harshly, documents the reasons, and refuses to reward pretty prose over evidence.

## Critical Rules
- Output valid JSON only.
- Round 1 cannot score above 60 overall.
- No dimension jumps by more than 20 points in one round.
- `competitive_analysis` cannot exceed 40 without named competitors.
- `market_research` cannot exceed 40 without numerical evidence.
- `business_model` cannot exceed 40 without unit economics.
- Score against strong associate-level strategy work, not generic chatbot output.

## Dimensions
- problem_validation
- market_research
- competitive_analysis
- product_definition
- business_model
- strategy_depth
- actionability
- cross_advisor_engagement
"""


def main() -> None:
    provider = os.getenv("LLM_PROVIDER", "openrouter")
    api_key = os.getenv("LLM_API_KEY")
    model = os.getenv("LLM_MODEL", "google/gemini-2.5-flash")
    client = LLMClient(provider, api_key, model)

    KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)
    AGENTS_DIR.mkdir(parents=True, exist_ok=True)

    program = PROGRAM_FILE.read_text(encoding="utf-8") if PROGRAM_FILE.exists() else ""
    if program:
        log("📋 Loaded program rules")

    successful_courses = 0
    for course_name, number in COURSE_ORDER:
        course_dir = COURSES_DIR / course_name
        if not course_dir.exists():
            warn(f"Course folder missing: {course_dir}")
            continue

        log(f"📚 Scanning {course_name}")
        combined, warnings = gather_course_content(course_dir)
        for item in warnings:
            warn(f"{course_name}: {item}")
        if not combined.strip():
            warn(f"{course_name}: no readable content found, skipping")
            continue

        try:
            log(f"🧠 Extracting knowledge for {course_name}")
            knowledge = client.complete(knowledge_prompt(course_name, combined))
            knowledge_path = KNOWLEDGE_DIR / f"{course_name}.md"
            write_file(knowledge_path, knowledge)

            log(f"🎭 Generating advisor persona for {course_name}")
            persona = client.complete(persona_prompt(course_name, knowledge, number))
            persona_path = AGENTS_DIR / f"{number:02d}-{course_name}-advisor.md"
            write_file(persona_path, persona)
            successful_courses += 1
        except requests.RequestException as exc:
            warn(f"{course_name}: API request failed: {exc}")
            continue
        except Exception as exc:  # noqa: BLE001
            warn(f"{course_name}: generation failed: {exc}")
            continue

    write_file(AGENTS_DIR / "00-orchestrator.md", build_orchestrator())
    write_file(AGENTS_DIR / "99-critic.md", build_critic())
    log("🧭 Wrote orchestrator persona")
    log("🧪 Wrote critic persona")

    if successful_courses == 0:
        raise SystemExit("No courses were successfully processed.")

    log(f"✅ Extraction complete for {successful_courses} course(s)")


if __name__ == "__main__":
    main()
