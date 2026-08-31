#!/usr/bin/env python3
"""Generate release notes via OpenRouter API with model fallback chain."""

import json
import re
import subprocess
import sys


def safe_json(text):
    """Parse JSON stripping control characters that break parsers."""
    clean = re.sub(r'[\x00-\x1f\x7f]', ' ', text)
    return json.loads(clean)


def call_api(api_key, model, prompt):
    """Call OpenRouter chat completions endpoint."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 1500,
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
        sections.append("### Features\n" + "\n".join(feats))
    if fixes:
        sections.append("### Fixes\n" + "\n".join(fixes))
    if improvements:
        sections.append("### Improvements\n" + "\n".join(improvements))
    return "\n\n".join(sections)


def main():
    api_key = open("/tmp/api_key.txt").read().strip()
    model = open("/tmp/model.txt").read().strip()
    commits = open("/tmp/commits.txt").read().strip()
    diff = open("/tmp/diff.txt").read().strip()

    prompt = f"""Generate release notes for MacDown (a native Markdown editor for macOS).
Write in EN-US. Use EXACTLY this format with these sections:

### Features
(bullet points with - )

### Fixes
(bullet points with - )

### Improvements
(bullet points with - . Improvements are changes that enhance performance, UX, code quality, or dependencies — but are not new features or bug fixes.)

IMPORTANT: Only include a section header if there are items for it. Do NOT output empty sections.

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

    for m in candidates:
        print(f"Trying model: {m}", file=sys.stderr)
        resp = call_api(api_key, m, prompt)
        notes = extract_notes(resp)
        if notes:
            print(f"OK com {m} ({len(notes)} chars)", file=sys.stderr)
            with open("/tmp/release_notes.txt", "w") as f:
                f.write(notes)
            return

        print(f"Falhou: {m}", file=sys.stderr)

    print("Todos os modelos falharam, usando fallback awk", file=sys.stderr)
    with open("/tmp/release_notes.txt", "w") as f:
        f.write(awk_fallback(commits))


if __name__ == "__main__":
    main()
