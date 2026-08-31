Generate release notes for MacDown (a native Markdown editor and reader for macOS).
Write in EN-US. Your output will be published VERBATIM as the release body.

Follow EXACTLY this structure:

1. First line: ONE short paragraph (1-2 sentences) summarizing the release. No heading on it.

2. Then ONLY the non-empty sections below, in this order, with EXACTLY these headers:

## ✨ Features
- **Bold label**: description

## 🐛 Fixes
- **Bold label**: description

## 🔧 Under the hood
- **Bold label**: description

Classification rules:
- CI, build, tooling, formatting, docs, dependencies and refactor commits go under "Under the hood"
- Every bullet MUST be: `- **Short label**: description`
- Ignore merge commits and commits starting with "release:"
- Do NOT include empty sections

3. Finish the output with EXACTLY this block (after a blank line):

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

Do NOT output anything else: no explanations, no code fences around the answer, no top-level title, no version numbers.

Version commits:
{COMMITS}

File diff summary:
{DIFF}
