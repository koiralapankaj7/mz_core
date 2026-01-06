# Getting Started with mz_utils

This guide helps you integrate and use mz_utils in your Flutter or Dart project.

## Installation

Add mz_utils to your `pubspec.yaml`:

```yaml
dependencies:
  mz_utils: ^0.0.1
```

Run:

```bash
flutter pub get
```

## Import

Import the package in your Dart files:

```dart
import 'package:mz_utils/mz_utils.dart';
```

## Quick Start

### 1. Create Your First Controller

Controllers manage state and notify listeners when values change:

```dart
import 'package:flutter/material.dart';
import 'package:mz_utils/mz_utils.dart';

class CounterController with Controller {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }

  void decrement() {
    _count--;
    notifyListeners();
  }
}

void main() {
  final controller = CounterController();

  // Listen to changes
  controller.addListener(() {
    print('Counter: ${controller.count}');
  });

  controller.increment(); // Prints: Counter: 1
  controller.increment(); // Prints: Counter: 2

  // Clean up when done
  controller.dispose();
}
```

### 2. Use in Flutter Widgets

Integrate controllers with Flutter using `ControllerBuilder`:

```dart
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  final _controller = CounterController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: ControllerBuilder<CounterController>(
          controller: _controller,
          builder: (context, ctrl) {
            return Text(
              '${ctrl.count}',
              style: const TextStyle(fontSize: 48),
            );
          },
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

### 3. Set Up Logging

Create a logger for debugging and monitoring:

```dart
final logger = SimpleLogger(
  output: ConsoleOutput(
    formatter: LogFormatter(
      enableColors: true,
      frameLength: 80,
    ),
  ),
  minimumLevel: LogLevel.debug,
);

// Log different severity levels
logger.trace('Trace message');
logger.debug('Debug message');
logger.info('Info message');
logger.warning('Warning message');
logger.error('Error message');
logger.fatal('Fatal error');
```

### 4. Organize Logs with Groups

Group related log entries together:

```dart
// Start a group
logger.startGroup(const LogGroup(
  id: 'user-login',
  title: 'User Login Flow',
  description: 'Authentication process',
));

// Add entries to the group
logger.logEntry(
  LogEntry(
    name: 'AuthStart',
    level: LogLevel.info,
    timestamp: DateTime.now(),
    message: 'Starting authentication',
  ),
  groupId: 'user-login',
);

logger.logEntry(
  LogEntry(
    name: 'AuthSuccess',
    level: LogLevel.info,
    timestamp: DateTime.now(),
    message: 'User authenticated successfully',
  ),
  groupId: 'user-login',
);

// Complete the group
logger.completeGroup('user-login');
```

Or use the convenience method:

```dart
await logger.group(
  'data-fetch',
  'Fetch User Data',
  () async {
    logger.info('Fetching user...');
    final user = await fetchUser();
    logger.info('User fetched: ${user.name}');
    return user;
  },
  description: 'User data loading',
);
```

### 5. Debounce User Input

Prevent rapid-fire function calls (e.g., search as you type):

```dart
import 'package:flutter/material.dart';
import 'package:mz_utils/mz_utils.dart';

class SearchWidget extends StatefulWidget {
  const SearchWidget({super.key});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  void _onSearchChanged(String query) {
    // Debounce: Only execute after user stops typing for 500ms
    Debouncer.debounce(
      'search-query',
      const Duration(milliseconds: 500),
      () {
        print('Searching for: $query');
        // Perform search
      },
    );
  }

  @override
  void dispose() {
    Debouncer.cancel('search-query');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: _onSearchChanged,
      decoration: const InputDecoration(
        hintText: 'Search...',
      ),
    );
  }
}
```

### 6. Throttle Button Presses

Limit how often a function can execute (e.g., save button):

```dart
class SaveButton extends StatefulWidget {
  const SaveButton({super.key});

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  final _throttler = Throttler(const Duration(seconds: 2));

  void _handleSave() {
    _throttler.call(() {
      print('Saving data...');
      // Save operation - can only run once every 2 seconds
    });
  }

  @override
  void dispose() {
    _throttler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _handleSave,
      child: const Text('Save'),
    );
  }
}
```

### 7. Use Listenable Collections

Observable lists and sets that notify when modified:

```dart
final items = ListenableList<String>(['Apple', 'Banana']);

items.addListener(() {
  print('Items changed: $items');
});

items.add('Cherry');     // Prints: Items changed: [Apple, Banana, Cherry]
items.remove('Banana');  // Prints: Items changed: [Apple, Cherry]
```

In Flutter widgets:

```dart
class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  final _todos = ListenableList<String>();

  @override
  void initState() {
    super.initState();
    _todos.addListener(_onTodosChanged);
  }

  void _onTodosChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _todos.removeListener(_onTodosChanged);
    _todos.dispose();
    super.dispose();
  }

  void _addTodo(String todo) {
    _todos.add(todo);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _todos.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(_todos[index]),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _todos.removeAt(index),
          ),
        );
      },
    );
  }
}
```

### 8. Automatic Resource Cleanup

Use `AutoDispose` to automatically clean up resources:

```dart
class DataService with AutoDispose {
  late final StreamSubscription<int> _subscription;
  late final Timer _timer;

  DataService() {
    // Register cleanup functions
    _subscription = dataStream.listen(_onData);
    autoDispose(_subscription.cancel);

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refresh(),
    );
    autoDispose(_timer.cancel);
  }

  void _onData(int value) {
    print('Data: $value');
  }

  void _refresh() {
    print('Refreshing...');
  }
}

void main() {
  final service = DataService();

  // Later, when done
  service.dispose(); // Automatically cancels subscription and timer
}
```

## Next Steps

- Read [Core Concepts](core_concepts.md) to understand key patterns
- See [Troubleshooting](troubleshooting.md) for common issues
- Explore the [API documentation](https://pub.dev/documentation/mz_utils/latest/)

## Common Patterns

### State Management Pattern

```dart
// 1. Create a controller
class TodoController with Controller {
  List<Todo> _todos = [];
  List<Todo> get todos => _todos;

  void addTodo(Todo todo) {
    _todos = [..._todos, todo];
    notifyListeners();
  }

  void removeTodo(String id) {
    _todos = _todos.where((t) => t.id != id).toList();
    notifyListeners();
  }
}

// 2. Provide it to the widget tree
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _controller = TodoController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ControllerProvider<TodoController>(
      controller: _controller,
      child: const MaterialApp(
        home: TodoScreen(),
      ),
    );
  }
}

// 3. Access it from descendants
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Controller.ofType<TodoController>(context);

    return ControllerBuilder<TodoController>(
      controller: controller,
      builder: (context, ctrl) {
        return ListView.builder(
          itemCount: ctrl.todos.length,
          itemBuilder: (context, index) {
            final todo = ctrl.todos[index];
            return ListTile(title: Text(todo.title));
          },
        );
      },
    );
  }
}
```

### Async Debouncing Pattern

```dart
final searchDebouncer = AdvanceDebouncer.debounce<List<Result>, String>(
  'search',
  (query) async {
    final response = await http.get(
      Uri.parse('https://api.example.com/search?q=$query'),
    );
    return parseResults(response.body);
  },
  duration: const Duration(milliseconds: 300),
);

// In your widget
void _onSearchChanged(String query) async {
  final results = await searchDebouncer(query);
  if (results != null) {
    setState(() {
      _searchResults = results;
    });
  }
}
```

### Structured Logging Pattern

```dart
class ApiService {
  final SimpleLogger _logger;

  ApiService(this._logger);

  Future<User> fetchUser(String id) async {
    return _logger.group(
      'fetch-user-$id',
      'Fetch User',
      () async {
        _logger.info('Starting API request');

        try {
          final response = await http.get(
            Uri.parse('https://api.example.com/users/$id'),
          );

          _logger.info('API response received: ${response.statusCode}');

          if (response.statusCode == 200) {
            _logger.debug('Parsing user data');
            return User.fromJson(jsonDecode(response.body));
          } else {
            _logger.error('API error: ${response.statusCode}');
            throw Exception('Failed to load user');
          }
        } catch (e, stackTrace) {
          _logger.fatal('Exception: $e');
          _logger.debug('Stack trace: $stackTrace');
          rethrow;
        }
      },
      description: 'User data fetch operation',
    );
  }
}
```

## Tips

- **Controllers**: Always call `dispose()` when done with controllers
- **Debouncing**: Use unique tags for different debounce operations
- **Throttling**: Choose appropriate durations based on use case
- **Logging**: Use appropriate log levels (trace/debug for development, info/warning/error for production)
- **Listenable Collections**: Remember to remove listeners in `dispose()`
- **Auto-disposal**: Register cleanup functions immediately after creating resources

## FAQ

**Q: When should I use debounce vs throttle?**

A: Use **debounce** when you want to wait for user input to stop (e.g., search as you type). Use **throttle** when you want to limit how often something runs while it's happening (e.g., scroll events, button presses).

**Q: How do I choose between Controller and ChangeNotifier?**

A: Use `Controller` from mz_utils when you need additional features like lifecycle management, priority listeners, or filtered notifications. Use Flutter's `ChangeNotifier` for simple value changes.

**Q: Can I use multiple outputs with SimpleLogger?**

A: Currently, SimpleLogger supports one output at a time. To log to multiple destinations, you can create a custom `LogOutput` that delegates to multiple outputs.

**Q: Do ListenableList and ListenableSet work with Flutter's AnimatedList?**

A: No, they notify on any change but don't provide the granular insert/remove callbacks needed for AnimatedList. For animated lists, use Flutter's built-in solutions or wrap the listenable collections with custom logic.
