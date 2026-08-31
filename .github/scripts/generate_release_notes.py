#!/usr/bin/env python3
"""Generate release notes via OpenRouter API with model fallback chain.

The prompt lives in .github/prompt/prompt.md and the model output is
used verbatim as the release body — no post-processing.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

PROMPT_FILE = Path(__file__).resolve().parent.parent / "prompt" / "prompt.md"


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


def main():
    api_key = open("/tmp/api_key.txt").read().strip()
    model = open("/tmp/model.txt").read().strip()
    commits = open("/tmp/commits.txt").read().strip()
    diff = open("/tmp/diff.txt").read().strip()

    prompt = PROMPT_FILE.read_text()
    prompt = prompt.replace("{COMMITS}", commits).replace("{DIFF}", diff)

    # Models to try in order: primary + fallbacks
    fallbacks = [
        "minimax/minimax-m3:free",
        "google/gemma-4-26b-a4b-it:free",
        "nvidia/nemotron-3-super-120b-a12b:free",
    ]
    candidates = [model] + [m for m in fallbacks if m != model]

    notes = None
    for m in candidates:
        print(f"Trying model: {m}", file=sys.stderr)
        resp = call_api(api_key, m, prompt)
        notes = extract_notes(resp)
        if notes:
            print(f"OK com {m} ({len(notes)} chars)", file=sys.stderr)
            break

        print(f"Falhou: {m}", file=sys.stderr)

    if not notes:
        # Last resort: raw commit list, used verbatim
        print("Todos os modelos falharam, usando lista de commits", file=sys.stderr)
        notes = commits

    with open("/tmp/release_notes.txt", "w") as f:
        f.write(notes)


if __name__ == "__main__":
    main()
