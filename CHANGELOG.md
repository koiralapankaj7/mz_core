# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-06

### Changed

**BREAKING CHANGE: Renamed `EasyDebounce` to `Debouncer`**

- `EasyDebounce` class renamed to `Debouncer` for better naming consistency with `AdvanceDebouncer` and `Throttler`
- `EasyDebouncerCallback` typedef renamed to `DebouncerCallback`
- All documentation and examples updated to use new naming

**Migration Guide:**

Replace all occurrences of `EasyDebounce` with `Debouncer` in your code:

```dart
// Before (v0.0.1)
EasyDebounce.debounce('tag', duration, callback);
EasyDebounce.cancel('tag');
EasyDebounce.cancelAll();

// After (v1.0.0)
Debouncer.debounce('tag', duration, callback);
Debouncer.cancel('tag');
Debouncer.cancelAll();
```

## [0.0.1] - 2025-01-05

### Added

**State Management**
- `Controller` mixin for type-safe state management with automatic lifecycle handling
- `ControllerBuilder` widget for reactive UI updates
- `ControllerProvider` widget for dependency injection
- `.watch()` extension on `Controller` for simplified widget rebuilds
- Key-based selective notifications for granular UI updates
- Priority listeners for ordered notification execution
- Predicate-based filtering for conditional notifications

**Auto-Disposal**
- `AutoDispose` mixin for automatic resource cleanup
- LIFO (last-in-first-out) cleanup order
- Support for Stream, Timer, and custom resource disposal

**Observable Collections**
- `ListenableList<T>` - observable list with full `List` API
- `ListenableSet<T>` - observable set with full `Set` API
- Automatic listener notification on collection modifications
- Direct replacement for standard Dart collections

**Structured Logging**
- `SimpleLogger` with six severity levels (trace, debug, info, warning, error, fatal)
- Log groups for organizing related entries
- Multiple output formats: Console, File, JSON, Rotating files
- Customizable log formatting with color support
- Sampling and filtering capabilities
- Minimum level controls for production filtering

**Rate Limiting**
- `Debouncer` for simple debouncing (search-as-you-type)
- `Throttler` for limiting execution frequency (scroll events, button presses)
- `AdvanceDebouncer` for type-safe async debouncing with cancellation
- Configurable durations and immediate execution options

**Extension Methods**
- `IterableMZX`: `toMap()`, `toIndexedMap()`, `firstWhereWithIndexOrNull()`, and more
- `ListMZX`: `removeFirstWhere()`, `removeLastWhere()`, `swap()`
- `SetMZX`: `toggle()`, `replaceAll()`
- `StringMZX`: `toCapitalizedWords()`, `toCamelCase()`, `toSnakeCase()`, `isValidEmail()`
- `IntMZX`: `isEven`, `isOdd`, `isBetween()`
- `NumMZX`: `clampToInt()`, `roundToPlaces()`
- `WidgetMZX`: `padding()`, `center()`, `expanded()`, `visible()`

**Documentation**
- Comprehensive README with quick start guide
- Getting Started guide with step-by-step integration
- Core Concepts documentation explaining architecture
- Troubleshooting guide for common issues
- Full API documentation with examples
- Contributing guidelines

**Example App**
- Interactive demos for all features
- State management examples with multiple controllers
- Logging system with multiple output formats
- Rate limiting demonstrations
- Observable collections examples
- Extension method showcases

### Infrastructure
- 100% test coverage with unit and widget tests
- Very Good Analysis lint rules compliance
- BSD-3-Clause License
- GitHub repository and issue tracker
- pub.dev integration

[1.0.0]: https://github.com/koiralapankaj7/mz_utils/releases/tag/v1.0.0
[0.0.1]: https://github.com/koiralapankaj7/mz_utils/releases/tag/v0.0.1
