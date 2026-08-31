#!/usr/bin/env python3
"""Generate release notes via OpenRouter API with model fallback chain."""

import json
import re
import subprocess
import sys

BOILERPLATE = """
## 📦 Install

1. Download `MacDown.app.zip` from the assets below
2. Unzip and move `MacDown.app` to `/Applications`
3. If macOS blocks the first launch, run:

   ```bash
   xattr -cr /Applications/MacDown.app
   ```

Requires **macOS 14 (Sonoma)** or later.

---

💬 Feature requests are welcome — [open an issue](https://github.com/alissonpdc/macdown/issues)!

Licensed under the [Apache License 2.0](https://github.com/alissonpdc/macdown/blob/main/LICENSE).
"""


def safe_json(text):
    """Parse JSON stripping control characters that break parsers."""
    clean = re.sub(r'[\x00-\x1f\x7f]', ' ', text)
    return json.loads(clean)


def call_api(api_key, model, prompt):
    """Call OpenRouter chat completions endpoint."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 2000,
        "temperature": 0.3,
    })
    result = subprocess.run(
        ["curl", "-s", "--max-time", "45",
         "https://openrouter.ai/api/v1/chat/completions",
         "-H", f"Authorization: Bearer {api_key}",
         "-H", "Content-Type: application/json",
         "-d", body],
        capture_output=True, text=True,
    )
    return result.stdout


def extract_notes(resp_text):
    """Extract content from API response, return None on failure."""
    try:
        d = safe_json(resp_text)
        err = d.get("error")
        if err:
            code = err.get("code", "?")
            msg = err.get("message", "?")[:120]
            print(f"  API error ({code}): {msg}", file=sys.stderr)
            return None
        notes = d.get("choices", [{}])[0].get("message", {}).get("content", "")
        return notes if notes else None
    except Exception as e:
        print(f"  Parse error: {e}", file=sys.stderr)
        return None


SECTION_MAP = {
    "### Features": "## ✨ Features",
    "## Features": "## ✨ Features",
    "### Fixes": "## 🐛 Fixes",
    "## Fixes": "## 🐛 Fixes",
    "### Improvements": "## 🔧 Under the hood",
    "## Improvements": "## 🔧 Under the hood",
    "## Under the hood": "## 🔧 Under the hood",
    "### Under the hood": "## 🔧 Under the hood",
}


def polish(notes):
    """Normalize model output to the house style."""
    lines = notes.strip().splitlines()
    # Drop leading top-level titles (# ...), fences and blank lines,
    # but keep section headers (## ...)
    while lines and (re.match(r"^#(?!#)\s", lines[0])
                     or lines[0].strip() in {"```", "```markdown"}
                     or not lines[0].strip()):
        lines.pop(0)
    # Normalize section headers to house style
    lines = [SECTION_MAP.get(line.strip(), line) for line in lines]
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(lines).strip()


def awk_fallback(commits):
    """Classify commits into sections."""
    feats, fixes, improvements = [], [], []
    for line in commits.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("- feat"):
            feats.append(line)
        elif line.startswith("- fix"):
            fixes.append(line)
        else:
            improvements.append(line)

    sections = []
    if feats:
        sections.append("## ✨ Features\n" + "\n".join(feats))
    if fixes:
        sections.append("## 🐛 Fixes\n" + "\n".join(fixes))
    if improvements:
        sections.append("## 🔧 Under the hood\n" + "\n".join(improvements))
    return "\n\n".join(sections)


def main():
    api_key = open("/tmp/api_key.txt").read().strip()
    model = open("/tmp/model.txt").read().strip()
    commits = open("/tmp/commits.txt").read().strip()
    diff = open("/tmp/diff.txt").read().strip()

    prompt = f"""Generate release notes for MacDown (a native Markdown editor for macOS).
Write in EN-US. Follow EXACTLY this structure:

Start with ONE short paragraph (1-2 sentences) summarizing the release. No heading on it.

Then include ONLY the non-empty sections below, in this order:

## ✨ Features
- **Bold label**: description

## 🐛 Fixes
- **Bold label**: description

## 🔧 Under the hood
- **Bold label**: description

Rules:
- Classify CI, build, tooling, formatting, docs and dependency commits under "Under the hood"
- Each bullet starts with a short **bold label**, then ": " and the description
- Ignore merge commits
- Do NOT add: a top-level title, version numbers, install instructions, or any section after "Under the hood"

Version commits:
{commits}

File diff summary:
{diff}"""

    # Models to try in order: primary + fallbacks
    fallbacks = [
        "minimax/minimax-m3:free",
        "google/gemma-4-26b-a4b-it:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
    ]
    candidates = [model] + [m for m in fallbacks if m != model]

    body = None
    for m in candidates:
        print(f"Trying model: {m}", file=sys.stderr)
        resp = call_api(api_key, m, prompt)
        notes = extract_notes(resp)
        if notes:
            print(f"OK com {m} ({len(notes)} chars)", file=sys.stderr)
            body = polish(notes)
            break

        print(f"Falhou: {m}", file=sys.stderr)

    if not body:
        print("Todos os modelos falharam, usando fallback awk", file=sys.stderr)
        body = polish(awk_fallback(commits))

    with open("/tmp/release_notes.txt", "w") as f:
        f.write(body + "\n" + BOILERPLATE)


if __name__ == "__main__":
    main()
