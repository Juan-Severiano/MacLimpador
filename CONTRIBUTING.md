# Contributing to MacLimpador

Thank you for your interest in contributing!

## Getting Started

1. Fork this repository
2. Clone your fork locally
3. Create a feature branch

## Development Setup

```bash
# Open in Xcode
open MacLimpador.xcodeproj

# Or build from command line
xcodebuild -project MacLimpador.xcodeproj -scheme MacLimpador -configuration Debug build
```

## Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation
- `refactor/` - Code refactoring

## Commit Messages

Use clear, descriptive commit messages:
- Start with verb: "Add", "Fix", "Update", "Remove"
- Keep first line under 50 characters
- Add body for details if needed

## Pull Requests

1. Update your branch with latest `main`
2. Ensure code builds successfully
3. Open a PR with clear description
4. Link related issues

## Code Style

- Follow Swift conventions
- Use SwiftLint if available
- Keep code consistent with existing style

## Reporting Issues

Use GitHub Issues to report bugs or request features. Include:
- macOS version
- Steps to reproduce
- Expected vs actual behavior