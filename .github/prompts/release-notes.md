Generate release notes for ArchiDraw (a canvas-based webapp for architecture and system design diagrams).
Write in EN-US. Your output will be published VERBATIM as the release body.

Follow EXACTLY this structure:

1. First line: ONE short paragraph (1-2 sentences) summarizing the release. No heading on it.

2. Then ONLY the non-empty sections below, in this order, with EXACTLY these headers:

```
## ✨ Features
- **Bold label**: description

## 🔧 Improvements
- **Bold label**: description

## 🐛 Fixes
- **Bold label**: description
```

Classification rules:
- CI, build, tooling, formatting, docs and dependencies must be ignored.
- Every bullet MUST be: `- **Short label**: description`
- Ignore merge commits and commits starting with "release:"
- Do NOT include empty sections


Do NOT output anything else: no explanations, no code fences around the answer, no top-level title, no version numbers.

Version commits:
{COMMITS}

File diff summary:
{DIFF}
