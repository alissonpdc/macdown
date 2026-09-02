# AGENTS.md

Swift Package (no Xcode project) macOS app for **reading** Markdown. macOS 14+, Swift 5.9.

## Targets

- `Sources/MacDown` — SwiftUI app executable
- `Sources/MacDownCore` — parsing/rendering library (swift-markdown). **All logic and all tests live here** (`Tests/MacDownCoreTests`); the SwiftUI layer has no tests.
- `Sources/plistgen` — generates the app bundle's `Info.plist`

## Commands

```bash
make build          # release build + package MacDown.app (root), ad-hoc signed
make test           # swift test
make lint           # swiftformat --lint Sources/
make install        # build + copy to /Applications + CLI `macdown`
```

- Single test: `swift test --filter SomeTestName`
- CI order: **lint → test → build**; keep it when verifying.

## Gates (CI enforces)

- **Zero warnings**: `swift build -c release` must emit no `warning:` — CI greps the build log and fails. Don't dismiss with "it compiles".
- `swiftformat --lint` on `Sources/` must pass.
- All tests must pass.
- Run `swiftformat Sources/` before committing if formatting is off.

## Workflow quirks (unusual)

- **Never push directly to `main`.** Push to a feature branch (`feat/**`, `fix/**`, `refactor/**`, `docs/**`, `test/**`, `chore/**`); CI auto-opens a PR to `main` after lint/test/build pass.
- Merging a PR to `main` triggers an **automatic release**: semver computed from conventional commits (`feat:` → minor, `fix:`/other → patch, `BREAKING CHANGE`/`!:` → major) + release notes + zip attached. So commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/) — they drive versioning.

## Gotchas

- After replacing the binary inside an already-signed `MacDown.app`, macOS **kills** the app on launch. `make build` handles this via `xattr -cr` + `codesign --force --deep -s -`; replicate if packaging manually.
- `plistgen` requires an **absolute** output path (doesn't accept relative `..` paths).
- Dev/testing the CLI without touching `/Applications`: `MACDOWN_APP=/path/to/MacDown.app Scripts/macdown file.md` (the shell script just wraps `open -a`; a running instance opens items as new tabs).
- `mermaid.min.js` and `AppIcon.icns` in `Resources/` are copied into the bundle at build time — keep them in sync if the app expects them.
