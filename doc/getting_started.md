# Getting Started with mz_core

This guide helps you integrate and use mz_core in your Flutter or Dart project.

## Installation

Add mz_core to your `pubspec.yaml`:

```yaml
dependencies:
  mz_core: ^1.3.2
```

Run:

```bash
flutter pub get
```

## Import

Import the package in your Dart files:

```dart
import 'package:mz_core/mz_core.dart';
```

## Quick Start

### 1. Create Your First Controller

Controllers manage state and notify listeners when values change:

```dart
import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

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
import 'package:mz_core/mz_core.dart';

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
class SaveButton extends StatelessWidget {
  const SaveButton({super.key});

  void _handleSave() {
    Throttler.throttle(
      'save_button',
      const Duration(seconds: 2),
      () {
        print('Saving data...');
        // Save operation - can only run once every 2 seconds
      },
    );
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
- Explore the [API documentation](https://pub.dev/documentation/mz_core/latest/)

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

Both `ofType` and `maybeOfType` accept an optional `listen` parameter (default: `true`):

| Parameter | Behavior |
| ----------- | ---------- |
| `listen: true` (default) | Widget rebuilds when controller is replaced in tree |
| `listen: false` | Widget does not rebuild; use in callbacks |

**Important:** Always use `listen: false` when accessing the controller from
callbacks such as `onPressed`, `onTap`, `onChanged`, or other event handlers.
This avoids unnecessary widget rebuilds and follows the same pattern as
`Provider.of`.

```dart
class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // In build method - use listen: true (default)
    // Widget will rebuild if controller is replaced
    final controller = Controller.ofType<TodoController>(context);

    return Column(
      children: [
        // Display todos - needs to listen for updates
        Expanded(
          child: ControllerBuilder<TodoController>(
            controller: controller,
            builder: (context, ctrl) {
              return ListView.builder(
                itemCount: ctrl.todos.length,
                itemBuilder: (context, index) {
                  return ListTile(title: Text(ctrl.todos[index].title));
                },
              );
            },
          ),
        ),

        // Button with callback - use listen: false
        ElevatedButton(
          onPressed: () {
            final ctrl = Controller.ofType<TodoController>(
              context,
              listen: false, // No rebuild needed in callback
            );
            ctrl.addTodo('New Item');
          },
          child: const Text('Add Todo'),
        ),

        // Text field with onChanged - use listen: false
        TextField(
          onChanged: (value) {
            final ctrl = Controller.ofType<TodoController>(
              context,
              listen: false, // No rebuild needed in callback
            );
            ctrl.updateSearchQuery(value);
          },
          decoration: const InputDecoration(hintText: 'Search...'),
        ),
      ],
    );
  }
}
```

### Async Debouncing Pattern

```dart
final searchDebouncer = Debouncer.debounceAsync<List<Result>, String>(
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

### Memoization Pattern

```dart
// Cache API calls with tags (similar to Debouncer)
Future<User> getCurrentUser() {
  return Memoizer.run(
    'current-user',
    () => api.fetchCurrentUser(),
    ttl: const Duration(minutes: 30),
  );
}

// Key-based caching with dynamic tags
Future<Product> getProduct(String id) {
  return Memoizer.run(
    'product-$id',
    () => api.fetchProduct(id),
    ttl: const Duration(minutes: 10),
  );
}

// Force refresh for pull-to-refresh
Future<User> refreshUser() {
  return Memoizer.run(
    'current-user',
    () => api.fetchCurrentUser(),
    forceRefresh: true,
  );
}

// Invalidate specific cache
void logout() {
  Memoizer.clear('current-user');
}

// Invalidate all product caches
void clearProductCache() {
  for (final tag in Memoizer.tags.where((t) => t.startsWith('product-'))) {
    Memoizer.clear(tag);
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

### 9. Event Queue with EventManager

For complex async operations with retry, cancellation, and undo/redo:

```dart
import 'package:mz_core/mz_core.dart';

// Define an event
class FetchDataEvent extends BaseEvent<MyAppState> {
  FetchDataEvent(this.itemId);

  final String itemId;

  @override
  Duration? get timeout => const Duration(seconds: 30);

  @override
  RetryPolicy? get retryPolicy => RetryPolicy(
    maxAttempts: 3,
    backoff: RetryBackoff.exponential(
      initial: const Duration(seconds: 1),
    ),
  );

  @override
  Future<Data> buildAction(EventManager<MyAppState> manager) async {
    reportProgress(0.0, message: 'Fetching...');
    final data = await api.fetchData(itemId);
    reportProgress(1.0, message: 'Done');
    return data;
  }
}

// Create manager and dispatch
final manager = EventManager<MyAppState>();

manager.addEventToQueue(
  FetchDataEvent('123'),
  onDone: (event, data) => print('Success: $data'),
  onError: (error) => print('Error: $error'),
);
```

### 10. Cancellable Operations with Tokens

Group related events for collective cancellation:

```dart
final token = EventToken();

// Add multiple events with same token
manager.addEventToQueue(FetchDataEvent('1', token: token));
manager.addEventToQueue(FetchDataEvent('2', token: token));

// Cancel all events with this token
token.cancel(reason: 'User cancelled');
```

### 11. Undo/Redo Support

Create undoable events for user actions:

```dart
class UpdateTitleEvent extends UndoableEvent<MyAppState> {
  UpdateTitleEvent(this.newTitle);

  final String newTitle;
  String? _previousTitle;

  @override
  void captureState(EventManager<MyAppState> manager) {
    _previousTitle = manager.state.title;
  }

  @override
  Future<void> buildAction(EventManager<MyAppState> manager) async {
    manager.state.title = newTitle;
  }

  @override
  Future<void> undo(EventManager<MyAppState> manager) async {
    manager.state.title = _previousTitle!;
  }

  @override
  String get undoDescription => 'Change title to "$newTitle"';
}

// Setup manager with undo support
final manager = EventManager<MyAppState>(
  undoManager: UndoRedoManager(maxHistorySize: 50),
);

// Dispatch undoable event
manager.addEventToQueue(UpdateTitleEvent('New Title'));

// Undo/redo
await manager.undoManager?.undo(manager);
await manager.undoManager?.redo(manager);
```

## Tips

- **Controllers**: Always call `dispose()` when done with controllers
- **Debouncing**: Use unique tags for different debounce operations
- **Throttling**: Choose appropriate durations based on use case
- **Memoization**: Use TTL for data that may become stale; use `forceRefresh` for pull-to-refresh
- **Logging**: Use appropriate log levels (trace/debug for development, info/warning/error for production)
- **Listenable Collections**: Remember to remove listeners in `dispose()`
- **Auto-disposal**: Register cleanup functions immediately after creating resources
- **EventManager**: Use tokens to group related events for cancellation; dispose manager when done

## FAQ

**Q: When should I use debounce vs throttle?**

A: Use **debounce** when you want to wait for user input to stop (e.g., search as you type). Use **throttle** when you want to limit how often something runs while it's happening (e.g., scroll events, button presses).

**Q: How do I cache multiple items with Memoizer?**

A: Use dynamic tags like `'product-$id'`. This is similar to how Debouncer uses tags. Call `Memoizer.clear('product-$id')` to invalidate specific entries.

**Q: How do I choose between Controller and ChangeNotifier?**

A: Use `Controller` from mz_core when you need additional features like lifecycle management, priority listeners, or filtered notifications. Use Flutter's `ChangeNotifier` for simple value changes.

**Q: Can I use multiple outputs with SimpleLogger?**

A: Currently, SimpleLogger supports one output at a time. To log to multiple destinations, you can create a custom `LogOutput` that delegates to multiple outputs.

**Q: Do ListenableList and ListenableSet work with Flutter's AnimatedList?**

A: No, they notify on any change but don't provide the granular insert/remove callbacks needed for AnimatedList. For animated lists, use Flutter's built-in solutions or wrap the listenable collections with custom logic.
