# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.2] - 2026-02-06

### Fixed in 1.3.2

- Fix `LogFormatter.detectTerminalWidth()` and `LogFormatter.detectColorSupport()` to catch `UnsupportedError` on web platforms by using `on Object catch` instead of `on Exception catch`

## [1.3.1] - 2026-02-05

### Fixed in 1.3.1

- Export `event_manager.dart` which was missing from the public API

## [1.3.0] - 2026-01-14

### Added in 1.3.0

#### EventManager - High-Performance Event Queue System

A comprehensive event queue system for Flutter applications that combines features typically requiring 5-6 separate packages into a unified solution.

**Core Features:**

- `EventManager<T>` - type-safe event queue with configurable execution modes
- `Event<T>` - base class for defining events with optional timeout, retry, and progress support
- `UndoableEvent<T>` - events with automatic undo/redo capability
- `BatchEvent<T>` - process multiple events as a single unit

**Execution Modes:**

- `ExecutionMode.sequential` - process events one at a time (default)
- `ExecutionMode.concurrent(maxConcurrency)` - parallel processing with concurrency limit
- `ExecutionMode.rateLimited(limit, window)` - rate-limited processing

**Event Lifecycle:**

- `EventPending` → `EventRunning` → `EventComplete`/`EventError`/`EventCancel`
- Automatic retry with configurable backoff strategies (exponential, linear, constant)
- Token-based cancellation for groups of related events
- Real-time progress reporting during execution

**Backpressure Control:**

- Configurable `maxQueueSize` to prevent memory issues
- `OverflowPolicy.dropNewest` - reject new events when queue is full
- `OverflowPolicy.dropOldest` - remove oldest events to make room
- `OverflowPolicy.error` - throw exception when queue is full

**Undo/Redo Support:**

- Full undo/redo stack with `undo()` and `redo()` methods
- Event merging for combining related operations
- `canUndo` and `canRedo` getters for UI state

**Logging Integration:**

- Built-in `EventLogger` with colored output
- Configurable log levels (none, error, warning, info, debug)
- Full event lifecycle logging for debugging

**Example:**

```dart
final manager = EventManager<String>();

// Define an event
class FetchUserEvent extends Event<String> {
  final String userId;
  FetchUserEvent(this.userId);

  @override
  Future<String> execute(EventContext context) async {
    final user = await api.fetchUser(userId);
    return user.name;
  }
}

// Listen to events
manager.stream.listen((state) {
  switch (state) {
    case EventComplete(:final data): print('Got: $data');
    case EventError(:final error): print('Error: $error');
    case EventCancel(:final reason): print('Cancelled: $reason');
  }
});

// Add events
manager.add(FetchUserEvent('123'));
```

## [1.2.0] - 2026-01-09

### Added in 1.2.0

#### Memoization Utilities

- `Memoizer` static class for tag-based caching of async results (consistent with `Debouncer` API)
  - `Memoizer.run(tag, computation)` - cache async results by tag
  - `Memoizer.getValue(tag)` / `hasValue(tag)` / `isPending(tag)` - check cache state
  - `Memoizer.clear(tag)` / `clearAll()` - invalidate cache
  - TTL (time-to-live) support for automatic cache expiration
  - In-flight request deduplication using `Completer` (concurrent calls share the same computation)
  - `forceRefresh` parameter to bypass cache
  - Dynamic tags for key-based caching: `Memoizer.run('product-$id', ...)`

#### Debouncer Async API

- `Debouncer.debounceAsync<S, T>()` for typed async debouncing with return values
- `Debouncer.fireAsync<S, T>()` for immediate execution of async debounced functions
- Merged functionality from AdvanceDebouncer into Debouncer

#### Controller Lookup Enhancements

- `listen` parameter added to `Controller.ofType()` and `Controller.maybeOfType()`
  - `listen: true` (default) - widget rebuilds when controller is replaced
  - `listen: false` - use in callbacks (`onPressed`, `onTap`) to avoid unnecessary rebuilds
  - Follows the same pattern as `Provider.of(context, listen: false)`

### Removed in 1.2.0

- **AdvanceDebouncer** class removed - use `Debouncer.debounceAsync()` instead
- **`batch()` method** removed from Controller - batch updates feature removed

### Changed in 1.2.0

- `Debouncer.cancel()`, `cancelAll()`, `count()`, `isActive()` now handle both sync and async operations
- Renamed `simple_logger.dart` to `logger.dart` for better naming consistency
- Renamed `controller_watcher.dart` to `watcher.dart` for brevity

## [1.1.0] - 2026-01-06

### Added

#### Controller Extensions

- `derive()` method on `Controller` for creating derived `ValueController` instances
  - Automatically updates when source controller changes
  - `distinct` parameter to control notification behavior (default: true)
  - `autoDispose` parameter for automatic cleanup when listeners are removed (default: true)
  - Safe to use with `ValueListenableBuilder` - auto-cleans up on widget unmount

#### ListenableNum Improvements

- `ListenableNum` class for observable numeric values with arithmetic operations
- Arithmetic operators (`+`, `-`, `*`, `/`, `~/`, `%`, unary `-`) now return the computed value `T` for easier chaining

### Changed

#### Controller Extension Renaming

- Renamed `ControllerWatchSimpleExtension` to `ControllerMZX` for consistency
- Improved documentation for `watch()`, `select()`, and `derive()` methods with `{@tool snippet}` directives

#### Listenables

- Renamed `listenable_iterables.dart` to `listenables.dart` for better naming
- Enhanced `ValueController` documentation with Flutter SDK standard patterns

## [1.0.0] - 2026-01-06

### Changed in 1.0.0

#### BREAKING CHANGE: Renamed `EasyDebounce` to `Debouncer`

- `EasyDebounce` class renamed to `Debouncer` for better naming consistency with `AdvanceDebouncer` and `Throttler`
- `EasyDebouncerCallback` typedef renamed to `DebouncerCallback`
- All documentation and examples updated to use new naming

#### Migration Guide

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

### Added in 0.0.1

#### State Management

- `Controller` mixin for type-safe state management with automatic lifecycle handling
- `ControllerBuilder` widget for reactive UI updates
- `ControllerProvider` widget for dependency injection
- `.watch()` extension on `Controller` for simplified widget rebuilds
- Key-based selective notifications for granular UI updates
- Priority listeners for ordered notification execution
- Predicate-based filtering for conditional notifications

#### Auto-Disposal

- `AutoDispose` mixin for automatic resource cleanup
- LIFO (last-in-first-out) cleanup order
- Support for Stream, Timer, and custom resource disposal

#### Observable Collections

- `ListenableList<T>` - observable list with full `List` API
- `ListenableSet<T>` - observable set with full `Set` API
- Automatic listener notification on collection modifications
- Direct replacement for standard Dart collections

#### Structured Logging

- `SimpleLogger` with six severity levels (trace, debug, info, warning, error, fatal)
- Log groups for organizing related entries
- Multiple output formats: Console, File, JSON, Rotating files
- Customizable log formatting with color support
- Sampling and filtering capabilities
- Minimum level controls for production filtering

#### Rate Limiting

- `Debouncer` for simple debouncing (search-as-you-type)
- `Throttler` for limiting execution frequency (scroll events, button presses)
- `AdvanceDebouncer` for type-safe async debouncing with cancellation
- Configurable durations and immediate execution options

#### Extension Methods

- `IterableMZX`: `toMap()`, `toIndexedMap()`, `firstWhereWithIndexOrNull()`, and more
- `ListMZX`: `removeFirstWhere()`, `removeLastWhere()`, `swap()`
- `SetMZX`: `toggle()`, `replaceAll()`
- `StringMZX`: `toCapitalizedWords()`, `toCamelCase()`, `toSnakeCase()`, `isValidEmail()`
- `IntMZX`: `isEven`, `isOdd`, `isBetween()`
- `NumMZX`: `clampToInt()`, `roundToPlaces()`
- `WidgetMZX`: `padding()`, `center()`, `expanded()`, `visible()`

#### Documentation

- Comprehensive README with quick start guide
- Getting Started guide with step-by-step integration
- Core Concepts documentation explaining architecture
- Troubleshooting guide for common issues
- Full API documentation with examples
- Contributing guidelines

#### Example App

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

[1.3.2]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.3.2
[1.3.1]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.3.1
[1.3.0]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.3.0
[1.2.0]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.2.0
[1.1.0]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.1.0
[1.0.0]: https://github.com/koiralapankaj7/mz_core/releases/tag/v1.0.0
[0.0.1]: https://github.com/koiralapankaj7/mz_core/releases/tag/v0.0.1
