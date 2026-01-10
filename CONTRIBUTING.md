# Contributing to mz_core

Thank you for your interest in contributing to mz_core! This document provides guidelines for contributing to the project.

## Code of Conduct

We expect all contributors to be respectful, considerate, and professional. Harassment, discrimination, or abusive behavior will not be tolerated.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue on GitHub with:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Flutter/Dart version and platform (iOS, Android, Web, etc.)
- Minimal code sample that reproduces the issue

### Suggesting Features

We welcome feature suggestions! Please create an issue with:

- Clear description of the feature
- Use cases and benefits
- Example API (if applicable)
- Any implementation considerations

### Submitting Code

1. **Fork the repository** and create a new branch from `main`

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards (see below)

3. **Write tests** for any new functionality
   - Unit tests for utilities and logic
   - Widget tests for Flutter components
   - Aim for 100% code coverage

4. **Update documentation**
   - Add doc comments to public APIs
   - Update README.md if adding new features
   - Update relevant files in `doc/` directory

5. **Run all checks**

   ```bash
   # Format code
   dart format .

   # Analyze code
   dart analyze

   # Run tests
   flutter test

   # Check test coverage
   flutter test --coverage
   ```

6. **Commit your changes** with clear commit messages

   ```bash
   git commit -m "feat: add new debouncing feature"
   ```

7. **Push to your fork** and create a Pull Request

   ```bash
   git push origin feature/your-feature-name
   ```

## Coding Standards

### Dart Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` for all code (80 character line limit)
- Pass `very_good_analysis` lint rules without warnings

### Naming Conventions

- **lowerCamelCase**: variables, methods, parameters, constants
- **UpperCamelCase**: classes, enums, typedefs, type parameters
- **lowercase_with_underscores**: libraries, packages, directories, files

### Documentation

- All public APIs must have `///` doc comments
- Include code examples in documentation where helpful
- Document parameters, return values, and exceptions
- Follow the documentation style in existing code

### Testing

- Write comprehensive tests for all new code
- Tests should be isolated and repeatable
- Use descriptive test names: `'should [behavior] when [condition]'`
- Mock external dependencies
- Aim for 100% code coverage

### Git Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add new feature`
- `fix: resolve bug in throttling`
- `docs: update README examples`
- `test: add tests for Controller`
- `refactor: simplify debounce logic`
- `perf: optimize ListenableList notifications`
- `chore: update dependencies`

## Pull Request Process

1. **Ensure all tests pass** and code analysis shows no errors
2. **Update documentation** if your changes affect the public API
3. **Link related issues** in the PR description
4. **Describe your changes** clearly in the PR description
5. **Wait for review** - maintainers will review and provide feedback
6. **Address feedback** by pushing additional commits to your branch
7. **Merge** - Once approved, maintainers will merge your PR

## Development Setup

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Git

### Setup

1. Clone the repository

   ```bash
   git clone https://github.com/koiralapankaj7/mz_core.git
   cd mz_core
   ```

2. Install dependencies

   ```bash
   flutter pub get
   ```

3. Run tests to verify setup

   ```bash
   flutter test
   ```

4. Check the example app

   ```bash
   cd example
   flutter run
   ```

## Project Structure

```dart
mz_core/
├── lib/
│   ├── mz_core.dart          # Main export file
│   └── src/                   # Implementation files
│       ├── controller.dart
│       ├── auto_dispose.dart
│       ├── logger.dart
│       └── ...
├── test/                      # Test files
├── example/                   # Example Flutter app
├── doc/                       # Documentation
│   ├── getting_started.md
│   ├── core_concepts.md
│   └── troubleshooting.md
└── README.md
```

## Testing Guidelines

### Unit Tests

- Test all public methods and properties
- Test edge cases and error conditions
- Use descriptive test names

Example:

```dart
test('should notify listeners when value changes', () {
  final controller = CounterController();
  var notified = false;
  controller.addListener(() => notified = true);

  controller.increment();

  expect(notified, isTrue);
  expect(controller.count, equals(1));
});
```

### Widget Tests

- Test widget rendering
- Test user interactions
- Test state changes

Example:

```dart
testWidgets('should display count', (tester) async {
  await tester.pumpWidget(CounterWidget());

  expect(find.text('0'), findsOneWidget);

  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();

  expect(find.text('1'), findsOneWidget);
});
```

## Questions?

If you have questions about contributing:

- Open a [GitHub Discussion](https://github.com/koiralapankaj7/mz_core/discussions)
- Create an issue with the `question` label
- Review existing issues and discussions

## License

By contributing to mz_core, you agree that your contributions will be licensed under the BSD-3-Clause License.

Thank you for contributing to mz_core! 🎉
