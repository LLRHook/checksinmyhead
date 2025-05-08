# Contributing to Checkmate

Thank you for your interest in contributing to Checkmate! This document outlines the process for contributing to the project and helps ensure a smooth collaboration experience for everyone involved.

## Code of Conduct

By participating in this project, you agree to uphold our Code of Conduct. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) to understand the expectations for all contributors.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
3. **Set up the development environment** by following the instructions in [mobile/README.md](mobile/README.md)
4. **Create a feature branch** (`git checkout -b feature/amazing-feature`)

## Development Workflow

### 1. Find or Create an Issue

Before starting work:

- Check the Issues to see if your contribution is already being discussed
- If not, create a new issue describing the feature or bug
- Wait for approval or feedback from maintainers before investing significant time

### 2. Implementation

When writing code:

- Follow the [Dart Style Guide](#dart-style-guide)
- Write tests for your changes
- Keep your changes focused and limited to the scope of the issue
- Commit regularly with clear, descriptive commit messages ([see Commit Guidelines](#commit-guidelines))
- Make sure the application runs without errors

### 3. Pull Request Process

When your changes are ready:

1. Update the README.md or documentation with details of changes if appropriate
2. Ensure all tests are passing
3. Push your branch to your fork
4. Submit a pull request to the `main` branch of the original repository

### 4. Code Review

After submitting your pull request:

- At least one maintainer will review your code
- Address any requested changes or questions
- Your PR will be merged once it meets quality standards and passes all checks

## Dart Style Guide

Checkmate follows the [official Dart style guide](https://dart.dev/guides/language/effective-dart/style) and the [Flutter style guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo). Key points include:

- Use `lowerCamelCase` for variables, methods, and named parameters
- Use `UpperCamelCase` for classes, enums, typedefs, and extensions
- Prefer single quotes for strings
- Use trailing commas for better formatting and diffs
- Keep lines under 80 characters when possible
- Organize code with the following structure:
  1. Imports (organized by type)
  2. Class/type declarations
  3. Static variables/methods
  4. Instance variables
  5. Constructors
  6. Methods grouped by functionality

Run `flutter analyze` before submitting code to catch style and quality issues.

## Commit Guidelines

We follow a simplified version of [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>: <short description>

[optional body]

[optional footer]
```

Types include:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation-only changes
- `style`: Changes that don't affect code behavior (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding or modifying tests
- `chore`: Changes to build process or auxiliary tools

Examples:
- `feat: add participant selection screen`
- `fix: correct tax calculation formula` 
- `docs: update setup instructions`

## Testing Guidelines

- Write unit tests for utilities and business logic
- Write widget tests for UI components
- Aim for high test coverage on core functionality
- Run the test suite with `flutter test` before submitting

## Documentation Guidelines

- Update documentation alongside code changes
- Write clear, concise comments
- Document public APIs with dartdoc comments
- Keep the README up-to-date

## Branch Organization

- `main` - production-ready state, always stable
- `dev` - development branch, all feature branches merge here first
- `feature/*` - feature development branches
- `fix/*` - bug fix branches
- `docs/*` - documentation update branches

## Issue and Pull Request Labels

We use labels to categorize issues and pull requests:

- `bug` - Confirmed bugs or reports likely to be bugs
- `enhancement` - Feature requests
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `priority:high` - Urgent issues that need quick resolution

## Release Process

Checkmate follows [Semantic Versioning](https://semver.org/) for releases.

For maintainers:
1. Update version in pubspec.yaml
2. Update CHANGELOG.md
3. Create a tagged release on GitHub
4. Update release notes with key changes

## Questions?

If you have questions about the contribution process, please open an issue with the label `question` or reach out to the maintainers at checkmateapp@duck.com.

Thank you for contributing to Checkmate!