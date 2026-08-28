# Contributing to MacDown

Thanks for your interest in contributing! This guide covers everything you need to build, test, and submit changes.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+ (via Xcode or the Swift toolchain)
- `make`

## Getting Started

```bash
git clone https://github.com/alissonpdc/macdown.git
cd macdown
```

The project is a Swift package with three targets:

| Target | Description |
|---|---|
| `MacDown` | The app executable (SwiftUI) |
| `MacDownCore` | Markdown parsing/rendering library (built on [swift-markdown](https://github.com/swiftlang/swift-markdown)) |
| `plistgen` | Helper that generates the app bundle's `Info.plist` |

## Build

```bash
make build
```

Produces `MacDown.app` in the repository root (release configuration, packaged and ad-hoc signed).

**Gate: zero warnings.** The build must complete with **no warnings** — the CI pipeline fails the build if any warning is emitted. Fix warnings before submitting.

To install the app locally in `/Applications`:

```bash
make install
```

## Tests

```bash
make test
```

Runs the full test suite (`swift test`). **All tests must pass** — failing tests block approval.

When adding features or fixing bugs, add or update tests in `Tests/MacDownCoreTests`.

## Pull Requests

1. Create a branch using the conventional prefix: `feat/**`, `fix/**`, `refactor/**`, `docs/**`, `test/**`, `chore/**`.
2. Make your changes following the gates above (zero warnings, all tests passing).
3. Open a PR against `main` — CI will build and test automatically.

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) spec:

```
<type>(<scope>): <short description>

[optional body]

[optional footer: fixes #<issue>]
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.

Commit history drives **automatic semver versioning** on release:

- `BREAKING CHANGE` (in the body) or `!:` → **major** bump
- `feat:` → **minor** bump
- anything else → **patch** bump

## Releases

Every push to `main` triggers an automated release pipeline:

1. Build with zero warnings + full test run
2. Package `MacDown.app` into a zip
3. Compute the next semver from commits since the last tag
4. Generate release notes from conventional commits
5. Publish a GitHub Release with the app zip attached

You don't need to bump versions or write release notes manually — just use conventional commits.

## Reporting Issues

Found a bug or have a feature request? Open a [GitHub issue](https://github.com/alissonpdc/macdown/issues).

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
