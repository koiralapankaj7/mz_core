# mz_core

A collection of production-ready Flutter and Dart utilities for state management, logging, collections, and rate limiting.

[![pub package](https://img.shields.io/pub/v/mz_core.svg)](https://pub.dev/packages/mz_core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![codecov](https://codecov.io/gh/koiralapankaj7/mz_core/branch/main/graph/badge.svg)](https://codecov.io/gh/koiralapankaj7/mz_core)
[![CI](https://github.com/koiralapankaj7/mz_core/workflows/CI/badge.svg)](https://github.com/koiralapankaj7/mz_core/actions)

## Features

| Feature | Description |
| --------- | ------------- |
| **🎮 Controllers** | Type-safe state management with automatic lifecycle handling |
| **📦 Auto-Disposal** | Automatic resource cleanup to prevent memory leaks |
| **🔍 Observable Collections** | `ListenableList` and `ListenableSet` with change notifications |
| **📝 Structured Logging** | Flexible logging system with groups, levels, and multiple outputs |
| **⏱️ Rate Limiting** | Debounce and throttle utilities for user input and events |
| **💾 Memoization** | Cache expensive async operations with TTL and key-based caching |
| **🔧 Extensions** | Useful extensions for `Iterable`, `List`, `Set`, `String`, `num`, and `Widget` |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mz_core: ^1.3.2
```

Then run:

```bash
flutter pub get
```

## Quick Start

### State Management with Controllers

```dart
import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

// 1. Create a controller
class CounterController with Controller {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// 2. Use in Flutter
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  final _controller = CounterController();

  @override
  void dispose() {
    _controller.dispose();  // Automatic cleanup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ControllerBuilder<CounterController>(
          controller: _controller,
          builder: (context, ctrl) => Text('Count: ${ctrl.count}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _controller.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### Automatic Resource Cleanup

```dart
class DataService with AutoDispose {
  late final StreamSubscription _subscription;
  late final Timer _timer;

  DataService() {
    _subscription = dataStream.listen(_onData);
    autoDispose(_subscription.cancel);  // Register cleanup

    _timer = Timer.periodic(duration, (_) => _refresh());
    autoDispose(_timer.cancel);  // Register cleanup
  }

  // dispose() automatically calls all registered cleanups
}
```

### Observable Collections

```dart
final todos = ListenableList<String>(['Buy milk', 'Walk dog']);

todos.addListener(() {
  print('Todos changed: ${todos.length} items');
});

todos.add('Write code');  // Triggers listener
todos.removeAt(0);        // Triggers listener
```

### Structured Logging

```dart
final logger = SimpleLogger(
  output: ConsoleOutput(
    formatter: LogFormatter(enableColors: true),
  ),
  minimumLevel: LogLevel.debug,
);

// Log different severity levels
logger.info('Application started');
logger.warning('Low memory');
logger.error('Network failure');

// Group related logs
await logger.group('user-auth', 'User Authentication', () async {
  logger.debug('Checking credentials');
  await authenticateUser();
  logger.info('User authenticated');
});
```

### Debounce User Input

```dart
class SearchWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (query) {
        // Only search after user stops typing for 500ms
        Debouncer.debounce(
          'search',
          const Duration(milliseconds: 500),
          () => performSearch(query),
        );
      },
    );
  }
}
```

### Throttle Button Presses

```dart
class SaveButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // Can only execute once every 2 seconds
        Throttler.throttle(
          'save_button',
          const Duration(seconds: 2),
          () => saveData(),
        );
      },
      child: const Text('Save'),
    );
  }
}
```

### Memoization

```dart
// Cache API calls with tags (like Debouncer)
Future<User> getCurrentUser() => Memoizer.run(
  'current-user',
  () => api.fetchCurrentUser(),
  ttl: const Duration(minutes: 30),
);

// Key-based caching with dynamic tags
Future<Product> getProduct(String id) => Memoizer.run(
  'product-$id',
  () => api.fetchProduct(id),
);

// Force refresh for pull-to-refresh
Future<User> refreshUser() => Memoizer.run(
  'current-user',
  () => api.fetchCurrentUser(),
  forceRefresh: true,
);

// Invalidate cache
void logout() => Memoizer.clear('current-user');
```

## Example App

A comprehensive example app demonstrating all features is included in the `/example` directory.

**Run the example:**

```bash
cd example
flutter run
```

The example app includes interactive demos for:

- **State Management**: Controllers with `.watch()`, key-based notifications, and priority listeners
- **Logging System**: Multiple output formats (Plain Text, JSON, Compact), log levels, and groups
- **Rate Limiting**: Debouncing search input, throttling button clicks, and async debouncing
- **Observable Collections**: ListenableList task manager and ListenableSet tag selector
- **Extension Methods**: Interactive demonstrations of all extension utilities

## Documentation

| Resource | Description |
| ---------- | ------------- |
| [Getting Started](doc/getting_started.md) | Step-by-step integration guide |
| [Core Concepts](doc/core_concepts.md) | Architecture and design patterns |
| [Troubleshooting](doc/troubleshooting.md) | Common issues and solutions |
| [API Reference](https://pub.dev/documentation/mz_core/latest/) | Complete API documentation |

## Features in Detail

### Controllers Overview

Type-safe state management with built-in lifecycle:

- `Controller` mixin for custom state management
- Automatic listener notification with `notifyListeners()`
- Multiple listener signatures (void, value, key-value)
- Priority and filtered listeners
- Integration with Flutter via `ControllerBuilder` and `.watch()`

**Use case**: Managing app state, form state, feature flags, user data

### Auto-Disposal Pattern

Automatic resource cleanup pattern:

- Mixin-based (`AutoDispose`)
- Register cleanup functions with `autoDispose()`
- LIFO cleanup order (last-in-first-out)
- Prevents memory leaks from forgotten disposals

**Use case**: Cleaning up streams, timers, controllers, file handles

### Observable Collections Details

Listenable versions of standard collections:

- `ListenableList<T>`: Observable list with full `List` API
- `ListenableSet<T>`: Observable set with full `Set` API
- Automatic listener notification on modifications
- Direct replacement for standard collections

**Use case**: Todo lists, shopping carts, real-time data displays

### Structured Logging Details

Production-ready logging system:

- Six severity levels (trace, debug, info, warning, error, fatal)
- Log groups for related entries
- Multiple outputs (console, file, JSON, rotating files)
- Sampling, filtering, and minimum level controls
- Colored console output with customizable formatting

**Use case**: Debug logs, error tracking, audit trails, analytics

### Rate Limiting Details

Control function execution frequency:

- **Debouncer**: Execute after calls stop (search-as-you-type)
- **Throttler**: Limit execution frequency (scroll events)
- **Debouncer.debounceAsync**: Type-safe async debouncing with cancellation

**Use case**: API rate limiting, UI event handling, auto-save

### Extensions Details

Convenient extension methods:

- **Iterable**: `toMap()`, `toIndexedMap()`, `firstWhereWithIndexOrNull()`
- **List**: `removeFirstWhere()`, `removeLastWhere()`
- **Set**: `toggle()`, `replaceAll()`
- **String**: `toCapitalizedWords()`, `toCamelCase()`, `toSnakeCase()`
- **num**: `clampToInt()`, `roundToPlaces()`
- **Widget**: `padding()`, `center()`, `expanded()`

## Examples

### Example 1: Search with Debouncing

Complete example showing debounced API search:

```dart
import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';
import 'package:http/http.dart' as http;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _results = ListenableList<String>();

  @override
  void initState() {
    super.initState();
    _results.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    Debouncer.cancel('search');
    _results.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      _results.clear();
      return;
    }

    final response = await http.get(
      Uri.parse('https://api.example.com/search?q=$query'),
    );

    if (response.statusCode == 200) {
      _results
        ..clear()
        ..addAll(parseResults(response.body));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (query) {
                Debouncer.debounce(
                  'search',
                  const Duration(milliseconds: 500),
                  () => _search(query),
                );
              },
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text(_results[index]));
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### Example 2: Multi-Controller State

Complete example with multiple controllers:

```dart
import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class UserController with Controller {
  User? _user;
  User? get user => _user;

  Future<void> login(String email, String password) async {
    _user = await authenticateUser(email, password);
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

class SettingsController with Controller {
  Settings _settings = Settings.defaults();
  Settings get settings => _settings;

  void updateTheme(ThemeMode mode) {
    _settings = _settings.copyWith(themeMode: mode);
    notifyListeners();
  }
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _userController = UserController();
  final _settingsController = SettingsController();

  @override
  void dispose() {
    _userController.dispose();
    _settingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ControllerProvider<UserController>(
      controller: _userController,
      child: ControllerProvider<SettingsController>(
        controller: _settingsController,
        child: ControllerBuilder<SettingsController>(
          controller: _settingsController,
          builder: (context, ctrl) {
            return MaterialApp(
              themeMode: ctrl.settings.themeMode,
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}
```

## Testing

mz_core is fully tested with comprehensive test coverage:

- Unit tests for all utilities
- Widget tests for Flutter integrations
- Integration tests for complex scenarios

Run tests:

```bash
flutter test
```

## Requirements

- **Flutter**: >=3.38.0
- **Dart**: >=3.0.0 (included with Flutter)

## Contributing

Contributions are welcome! Please:

1. Read the [contribution guidelines](CONTRIBUTING.md)
2. Fork the repository
3. Create a feature branch
4. Write tests for new features
5. Ensure all tests pass
6. Submit a pull request

## License

This package is released under the [MIT License](LICENSE).

## Credits

Developed and maintained by [Pankaj Koirala](https://github.com/koiralapankaj7).

## Support

- **Issues**: [GitHub Issues](https://github.com/koiralapankaj7/mz_core/issues)
- **Discussions**: [GitHub Discussions](https://github.com/koiralapankaj7/mz_core/discussions)
- **Repository**: [GitHub](https://github.com/koiralapankaj7/mz_core)

## Related Packages

- [provider](https://pub.dev/packages/provider) - State management
- [riverpod](https://pub.dev/packages/riverpod) - Advanced state management
- [logger](https://pub.dev/packages/logger) - Logging
- [rxdart](https://pub.dev/packages/rxdart) - Reactive extensions

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
