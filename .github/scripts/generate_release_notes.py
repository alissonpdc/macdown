#!/usr/bin/env python3
"""Generate release notes via OpenRouter API, trying ALL free models.

The prompt lives in .github/templates/prompt.md and the model output is
used verbatim as the release body — no post-processing.
If every free model fails, the script exits non-zero and the pipeline fails.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

PROMPT_FILE = Path(__file__).resolve().parent.parent / "templates" / "prompt.md"
MODELS_URL = "https://openrouter.ai/api/v1/models"
CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"


def safe_json(text):
    """Parse JSON stripping control characters that break parsers."""
    clean = re.sub(r'[\x00-\x1f\x7f]', ' ', text)
    return json.loads(clean)


def curl_json(url, api_key):
    result = subprocess.run(
        ["curl", "-s", "--max-time", "45", url,
         "-H", f"Authorization: Bearer {api_key}"],
        capture_output=True, text=True,
    )
    return safe_json(result.stdout)


def free_models(api_key):
    """Return all free text->text model ids, best context first."""
    data = curl_json(MODELS_URL, api_key)
    free = []
    for m in data.get("data", []):
        p = m.get("pricing", {})
        if str(p.get("prompt", "1")) != "0" or str(p.get("completion", "1")) != "0":
            continue
        modality = m.get("architecture", {}).get("modality", "")
        if not (modality.endswith("->text") or modality == "text->text"):
            continue
        # Skip models restricted to agentic harnesses only
        if "inkling" in m["id"].lower():
            continue
        free.append(m)
    free.sort(key=lambda m: m.get("context_length") or 0, reverse=True)
    return [m["id"] for m in free]


def generate_notes(api_key, model, prompt):
    """Call OpenRouter chat completions endpoint."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 2000,
        "temperature": 0.3,
    })
    result = subprocess.run(
        ["curl", "-s", "--max-time", "45", CHAT_URL,
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
    primary = open("/tmp/model.txt").read().strip()
    commits = open("/tmp/commits.txt").read().strip()
    diff = open("/tmp/diff.txt").read().strip()

    prompt = PROMPT_FILE.read_text()
    prompt = prompt.replace("{COMMITS}", commits).replace("{DIFF}", diff)

    try:
        models = free_models(api_key)
    except Exception as e:
        print(f"Erro ao listar modelos free do OpenRouter: {e}", file=sys.stderr)
        sys.exit(1)

    # Primary (melhor modelo free do step de seleção) primeiro, depois todos
    candidates = [primary] + [m for m in models if m != primary] if primary else models
    print(f"{len(candidates)} modelos free disponíveis", file=sys.stderr)

    notes = None
    for m in candidates:
        print(f"Trying model: {m}", file=sys.stderr)
        resp = generate_notes(api_key, m, prompt)
        notes = extract_notes(resp)
        if notes:
            print(f"OK com {m} ({len(notes)} chars)", file=sys.stderr)
            break

        print(f"Falhou: {m}", file=sys.stderr)

    if not notes:
        print("::error::Todos os modelos free do OpenRouter falharam — release abortada", file=sys.stderr)
        sys.exit(1)

    with open("/tmp/release_notes.txt", "w") as f:
        f.write(notes)


if __name__ == "__main__":
    main()
