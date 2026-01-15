# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-14

### Added

#### New Lint Rule: `duplicate_listener`

Detects when the same listener is added multiple times without being removed first.

```dart
// BAD - Listener added twice
void initState() {
  super.initState();
  controller.addListener(_onChange);
  _setup();
}

void _setup() {
  controller.addListener(_onChange); // LINT: duplicate listener
}

// GOOD - Remove before re-adding
void didUpdateWidget(oldWidget) {
  super.didUpdateWidget(oldWidget);
  oldWidget.controller.removeListener(_onChange);
  widget.controller.addListener(_onChange); // OK
}
```

**Features:**
- Counter-based execution simulation for accurate detection
- Call graph analysis to track listeners across methods
- Detects duplicates in `initState`, `didChangeDependencies`, `didUpdateWidget`
- Skips dead code (private methods never called)
- Quick fix available to add `removeListener` call

### Improved

#### `remove_listener` Rule Enhancements

- **Transitive method tracing**: Now detects listeners added/removed in helper methods
  ```dart
  void initState() {
    _setupListeners(); // Now correctly traced
  }

  void _setupListeners() {
    widget.counter.addListener(_onChange); // Detected!
  }
  ```

#### Performance Optimizations

- **Single-pass AST collection**: Combined visitor collects listener operations and method calls in one traversal
- **Lazy `IgnoreInfo` evaluation**: Comment parsing deferred until violations need reporting
- **Pre-indexed data structures**: Operations indexed by method name for O(1) lookup
- **Pre-computed event sorting**: Events sorted once per method, not during simulation
- Reduced memory allocations and visitor instantiations

## [0.0.1] - 2026-01-09

### Added

- Initial release
- `dispose_notifier` lint rule - ensures ChangeNotifier instances are disposed in State classes
- `remove_listener` lint rule - ensures listeners are removed in dispose method
- `controller_listen_in_callback` lint rule - warns about Controller lookups without `listen: false`
- Quick fixes for all lint rules
- Support for `// ignore_for_file:` and `// ignore:` comments to suppress rules
- 100% test coverage on all lint rules

[0.1.0]: https://github.com/koiralapankaj7/mz_core/releases/tag/mz_lints-v0.1.0
[0.0.1]: https://github.com/koiralapankaj7/mz_core/releases/tag/mz_lints-v0.0.1
