# mz_lints

[![pub package](https://img.shields.io/pub/v/mz_lints.svg)](https://pub.dev/packages/mz_lints)
[![CI](https://github.com/koiralapankaj7/mz_core/actions/workflows/mz_lints_ci.yml/badge.svg)](https://github.com/koiralapankaj7/mz_core/actions/workflows/mz_lints_ci.yml)
[![codecov](https://codecov.io/gh/koiralapankaj7/mz_core/branch/main/graph/badge.svg?flag=mz_lints)](https://codecov.io/gh/koiralapankaj7/mz_core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Custom Dart lint rules for Flutter applications. Helps catch common mistakes with ChangeNotifier disposal, listener cleanup, and Controller lookup patterns.

## Available Rules

| Rule | Description | Quick Fixes |
| ---- | ----------- | ----------- |
| `dispose_notifier` | ChangeNotifier subclasses created in State must be disposed | Add dispose method, Add dispose call |
| `remove_listener` | Listeners added to Listenables must be removed in dispose | Add removeListener call |
| `controller_listen_in_callback` | Controller lookups in callbacks should use `listen: false` | Add 'listen: false' |

## Installation

Add `mz_lints` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  mz_lints: ^0.1.0
```

Then enable the plugin in your `analysis_options.yaml`:

```yaml
# Requires Dart 3.10+ / Flutter 3.38+
plugins:
  mz_lints: ^0.1.0
```

## Rule Details

### dispose_notifier

Ensures `ChangeNotifier` subclasses created in StatefulWidget State classes are disposed:

- `TextEditingController`, `ScrollController`, `AnimationController`
- `TabController`, `PageController`, `FocusNode`
- `ValueNotifier`, and any custom `ChangeNotifier` subclass

**BAD:**

```dart
class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController(); // LINT: not disposed
  
  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

**GOOD:**

```dart
class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

### remove_listener

Ensures listeners added in `initState`, `didChangeDependencies`, or `didUpdateWidget` are removed in `dispose`:

**BAD:**

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged); // LINT: never removed
  }
  
  void _onChanged() {}
}
```

**GOOD:**

```dart
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }
  
  void _onChanged() {}
}
```

### controller_listen_in_callback

Warns when using `Controller.ofType()` or similar lookup methods inside event handlers without `listen: false`:

**BAD:**

```dart
void _onButtonPressed() {
  // Will cause unnecessary rebuilds
  final controller = Controller.ofType<MyController>(context);
  controller.doSomething();
}
```

**GOOD:**

```dart
void _onButtonPressed() {
  final controller = Controller.ofType<MyController>(context, listen: false);
  controller.doSomething();
}
```

## Suppressing Rules

You can suppress rules using standard Dart ignore comments:

**Suppress for entire file:**

```dart
// ignore_for_file: dispose_notifier, remove_listener

class MyWidget extends StatefulWidget {
  // ...
}
```

**Suppress for a single line:**

```dart
class _MyWidgetState extends State<MyWidget> {
  // ignore: dispose_notifier
  final _controller = TextEditingController();
}
```

## Requirements

- Dart SDK 3.10.0 or later
- Flutter 3.38.0 or later (for Flutter projects)

## Related

This package is part of the [mz_utils](https://pub.dev/packages/mz_utils) ecosystem.

## License

MIT License - see the [LICENSE](../../LICENSE) file for details.
