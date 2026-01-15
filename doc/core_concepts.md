# Core Concepts

This guide explains the key architectural patterns and concepts used in mz_core.

## Table of Contents

- [Controllers and State Management](#controllers-and-state-management)
- [Listeners and Notifications](#listeners-and-notifications)
- [Auto-Disposal Pattern](#auto-disposal-pattern)
- [Listenable Collections](#listenable-collections)
- [Structured Logging](#structured-logging)
- [Rate Limiting (Debounce/Throttle)](#rate-limiting-debouncethrottle)
- [Memoization](#memoization)
- [Event Queue System](#event-queue-system)

## Controllers and State Management

### What is a Controller?

A **Controller** is a state management object that:

1. Holds a value of type `T`
2. Notifies listeners when the value changes
3. Manages its own lifecycle (initialization and disposal)
4. Supports multiple listener patterns

### Controller Hierarchy

```dart
Controller (base mixin class)
└── Custom controllers using the Controller mixin
```

### When to Use Controllers

Use controllers when you need:

- **State management**: Managing application state with notifications
- **Selective rebuilds**: Notify specific listeners with key-based filtering
- **Computed values**: Deriving values from state
- **Lifecycle management**: Automatic cleanup of resources
- **Type safety**: Strong typing for state and listeners

```dart
// Simple counter controller
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

  // Computed property
  bool get isEven => _count % 2 == 0;
}
```

### Controller Lifecycle

1. **Creation**: Initialize with default value
2. **Usage**: Update value, add/remove listeners
3. **Disposal**: Clean up resources automatically

```dart
final controller = CounterController();  // 1. Create

controller.addListener(() {});           // 2. Use
controller.increment();

controller.dispose();                    // 3. Dispose
```

**Important**: Always dispose controllers when done to prevent memory leaks.

### Accessing Controllers in Widget Tree

Use `Controller.ofType<T>()` to access controllers from the widget tree:

```dart
// Get controller - throws if not found
final controller = Controller.ofType<TodoController>(context);

// Get controller - returns null if not found
final controller = Controller.maybeOfType<TodoController>(context);
```

#### The `listen` Parameter

Both methods accept an optional `listen` parameter (default: `true`):

| Parameter | Behavior |
| --------- | -------- |
| `listen: true` (default) | Widget rebuilds when controller is replaced in tree |
| `listen: false` | Widget does not rebuild; use in callbacks |

**Important:** Always use `listen: false` when accessing the controller from
callbacks such as `onPressed`, `onTap`, `onChanged`, or other event handlers.
This avoids unnecessary widget rebuilds and follows the same pattern as
`Provider.of`.

```dart
// In build method - use listen: true (default)
final controller = Controller.ofType<TodoController>(context);

// In callbacks - use listen: false
ElevatedButton(
  onPressed: () {
    final ctrl = Controller.ofType<TodoController>(
      context,
      listen: false,
    );
    ctrl.addTodo('New Item');
  },
  child: const Text('Add'),
)
```

## Listeners and Notifications

### Listener Types

mz_core supports four listener signatures:

#### 1. VoidCallback - No Parameters

Use when you only need to know "something changed":

```dart
controller.addListener(() {
  print('Value changed to: ${controller.value}');
});
```

**Use case**: Simple UI updates, refreshing displays

#### 2. ValueCallback - Value Only

Use when you need the new value but not what changed:

```dart
controller.addListener((value) {
  print('New value: $value');
});
```

**Use case**: Logging, analytics, simple transformations

#### 3. KvCallback - Key and Value

Use when you need to know which property changed:

```dart
controller.addListener((key, value) {
  print('Property $key changed to $value');
});
```

**Use case**: Multi-property controllers, targeted updates

#### 4. KvcCallback - Key, Value, and Controller

Use when you need full context:

```dart
controller.addListener((key, value, ctrl) {
  print('Property $key changed on ${ctrl.runtimeType}');
  // Access other controller properties
});
```

**Use case**: Complex coordination, cross-controller logic

### Advanced Listener Features

#### Priority Listeners

Execute listeners in specific order (higher priority first):

```dart
controller.addListener(
  () => print('High priority'),
  priority: 10,
);

controller.addListener(
  () => print('Low priority'),
  priority: 1,
);

controller.notify(); // Prints high priority first
```

**Use case**: Ensure critical updates happen before UI updates

#### Filtered Listeners

Only receive notifications for specific changes:

```dart
controller.addListener(
  (key, value) => print('Score changed: $value'),
  predicate: (key, value) => key == 'score',
);
```

**Use case**: Performance optimization, targeted reactions

### Notification Behavior

Controllers use **synchronous notification**:

```dart
var callbackExecuted = false;
controller.addListener(() => callbackExecuted = true);

controller.value = 42;
print(callbackExecuted); // true - executed immediately
```

This ensures UI consistency and predictable state updates.

## Auto-Disposal Pattern

### The Problem

Manual resource cleanup is error-prone:

```dart
class BadExample {
  late final StreamSubscription _sub;
  late final Timer _timer;

  BadExample() {
    _sub = stream.listen((_) {});
    _timer = Timer.periodic(duration, (_) {});
  }

  // Easy to forget one
  void dispose() {
    _sub.cancel();
    // Forgot to cancel timer! Memory leak!
  }
}
```

### The Solution: AutoDispose

`AutoDispose` automatically tracks and cleans up resources:

```dart
class GoodExample with AutoDispose {
  late final StreamSubscription _sub;
  late final Timer _timer;

  GoodExample() {
    _sub = stream.listen((_) {});
    autoDispose(_sub.cancel);  // Register cleanup

    _timer = Timer.periodic(duration, (_) {});
    autoDispose(_timer.cancel);  // Register cleanup
  }

  // dispose() inherited from AutoDispose
  // Automatically calls all registered cleanup functions
}
```

### How It Works

1. Resources are created
2. Cleanup functions are registered via `autoDispose()`
3. When `dispose()` is called, all cleanups execute in **reverse order** (LIFO)

```dart
class ResourceManager with AutoDispose {
  ResourceManager() {
    autoDispose(() => print('Cleanup 1'));
    autoDispose(() => print('Cleanup 2'));
    autoDispose(() => print('Cleanup 3'));
  }
}

final manager = ResourceManager();
manager.dispose();
// Prints:
// Cleanup 3
// Cleanup 2
// Cleanup 1
```

### Best Practices

**DO**: Register cleanup immediately after creating resources

```dart
final sub = stream.listen((_) {});
autoDispose(sub.cancel);  // Register right away
```

**DO**: Use `autoDispose()` for all resources that need cleanup

```dart
autoDispose(_controller.dispose);
autoDispose(_timer.cancel);
autoDispose(() => _file.close());
```

**DON'T**: Try to manually track disposal state

```dart
// Bad - unnecessary complexity
var _disposed = false;
void dispose() {
  if (_disposed) return;
  _disposed = true;
  // cleanup
}

// Good - AutoDispose handles this
class MyClass with AutoDispose {
  // cleanup registered via autoDispose()
}
```

## Listenable Collections

### Concept

`ListenableList` and `ListenableSet` are observable collections that notify when modified.

### Key Characteristics

1. **Full List/Set API**: All standard methods work
2. **Automatic Notification**: Every modification triggers listeners
3. **Efficient**: Minimal overhead for non-listener usage

### When to Use

Use listenable collections when:

- UI needs to react to collection changes
- Multiple widgets depend on the same data
- You want automatic updates without manual `setState()`

### ListenableList Example

```dart
class TodoService {
  final todos = ListenableList<Todo>();

  void addTodo(String title) {
    todos.add(Todo(title: title));
    // Listeners notified automatically
  }

  void removeTodo(int index) {
    todos.removeAt(index);
    // Listeners notified automatically
  }
}
```

### Integration with Flutter

```dart
class TodoWidget extends StatefulWidget {
  const TodoWidget({super.key, required this.todos});

  final ListenableList<Todo> todos;

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  @override
  void initState() {
    super.initState();
    widget.todos.addListener(_onTodosChanged);
  }

  void _onTodosChanged() {
    setState(() {}); // Trigger rebuild
  }

  @override
  void dispose() {
    widget.todos.removeListener(_onTodosChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.todos.length,
      itemBuilder: (context, index) {
        return Text(widget.todos[index].title);
      },
    );
  }
}
```

### Performance Considerations

- Listeners are notified on **every** modification
- For bulk operations, consider batching:

```dart
// Less efficient - notifies 100 times
for (var i = 0; i < 100; i++) {
  list.add(i);
}

// More efficient - build then assign
final newItems = [for (var i = 0; i < 100; i++) i];
list.clear();
list.addAll(newItems); // Notifies twice instead of 100 times
```

## Structured Logging

### Log Levels

Six severity levels from lowest to highest:

| Level | Purpose | When to Use |
| ------- | --------- | ------------- |
| `trace` | Fine-grained debug info | Detailed flow tracing |
| `debug` | Debug information | Development debugging |
| `info` | Informational messages | Normal operations |
| `warning` | Warning messages | Potential issues |
| `error` | Error messages | Recoverable errors |
| `fatal` | Fatal errors | Unrecoverable errors |

### Log Filtering

Control what gets logged:

```dart
final logger = SimpleLogger(
  minimumLevel: LogLevel.info,  // Only info and above
);

logger.trace('Not logged');
logger.debug('Not logged');
logger.info('Logged');        // ✓
logger.error('Logged');       // ✓
```

### Log Sampling

Probabilistically log messages to reduce volume:

```dart
final logger = SimpleLogger(
  sampleRate: 0.1,  // Log 10% of messages
);
```

**Use case**: High-frequency logs in production

### Log Groups

Organize related log entries:

```dart
// Manual grouping
logger.startGroup(const LogGroup(
  id: 'operation-123',
  title: 'Data Processing',
  description: 'ETL pipeline',
));

logger.logEntry(entry1, groupId: 'operation-123');
logger.logEntry(entry2, groupId: 'operation-123');

logger.completeGroup('operation-123');
```

```dart
// Automatic grouping with scope
await logger.group('operation', 'Title', () async {
  logger.info('Step 1');
  await process();
  logger.info('Step 2');
  return result;
});
```

### Group Timeout

Groups auto-complete after a timeout to prevent memory leaks:

```dart
final logger = SimpleLogger(
  groupTimeout: const Duration(minutes: 5),
);
```

If `completeGroup()` isn't called within 5 minutes, the group automatically completes.

### Log Outputs

Multiple output implementations:

- `ConsoleOutput`: Formatted console logging with colors
- `FileOutput`: Write to a file
- `JsonOutput`: JSON format for log aggregation
- `RotatingFileOutput`: Rotating log files with size/count limits

```dart
// Rotating file logs
final output = RotatingFileOutput(
  directory: Directory('/var/log/myapp'),
  baseFileName: 'app.log',
  maxFileSize: 10 * 1024 * 1024,  // 10 MB
  maxFileCount: 5,                 // Keep 5 files
);
```

## Rate Limiting (Debounce/Throttle)

### Debouncing

**Debouncing** delays execution until calls stop for a specified duration.

**Mental Model**: "Wait for things to calm down, then act"

```dart
Debouncer.debounce(
  'search',
  const Duration(milliseconds: 500),
  () => performSearch(query),
);
```

Timeline:

```dart
User types: h|e|l|l|o|_____[500ms]_____[EXECUTE]
            ↑ ↑ ↑ ↑ ↑     (waiting)   (search for "hello")
```

**Use cases**:

- Search as you type
- Form validation on input change
- Auto-save after editing stops

### Throttling

**Throttling** limits execution frequency - allows one call per duration.

**Mental Model**: "Do it now, but wait before allowing it again"

```dart
final throttler = Throttler(const Duration(seconds: 1));
throttler.call(() => updateUI());
```

Timeline:

```dart
Calls:     1|_|_|2|_|_|3|_|_|
Execute:   ✓|_|_|✓|_|_|✓|_|_|
           ↑ (1s) ↑ (1s) ↑
```

**Use cases**:

- Button press limits
- Scroll event handling
- API rate limiting
- UI update throttling

### Choosing Between Them

| Feature | Debounce | Throttle |
| --------- | ---------- | ---------- |
| **When executes** | After calls stop | Immediately, then blocks |
| **Frequency** | Variable (depends on pauses) | Fixed (e.g., max once per second) |
| **Typical use** | User input | Continuous events |
| **Example** | Search as you type | Scroll position updates |

### Advanced: Async Debouncing

For async operations with results:

```dart
final debouncer = Debouncer.debounceAsync<SearchResults, String>(
  'api-search',
  (query) async {
    final response = await http.get(
      Uri.parse('https://api.example.com/search?q=$query'),
    );
    return SearchResults.fromJson(response.body);
  },
  duration: const Duration(milliseconds: 300),
);

// Later
final results = await debouncer('flutter');
if (results != null) {
  displayResults(results);
}
```

**Benefits**:

- Type-safe async operations
- Cancellation of in-flight requests
- Null return when cancelled

## Memoization

### What is Memoization?

**Memoization** caches the results of expensive computations so subsequent calls
with the same inputs return instantly from cache.

`Memoizer` provides a tag-based caching API consistent with `Debouncer`:

```dart
// Cache API calls with tags
Future<User> getCurrentUser() => Memoizer.run(
  'current-user',
  () => api.fetchCurrentUser(),
);
```

### Key Features

| Feature | Description |
| ------- | ----------- |
| **Tag-based** | Cache entries identified by string tags |
| **TTL support** | Automatic cache expiration |
| **Request deduplication** | Concurrent calls share the same computation |
| **Force refresh** | Bypass cache when needed |
| **Dynamic tags** | Key-based caching with `'product-$id'` |

### Basic Usage

```dart
// Simple caching
final user = await Memoizer.run(
  'current-user',
  () => api.fetchCurrentUser(),
);

// With TTL (time-to-live)
final products = await Memoizer.run(
  'product-list',
  () => api.fetchProducts(),
  ttl: const Duration(minutes: 10),
);

// Dynamic tags for key-based caching
Future<Product> getProduct(String id) => Memoizer.run(
  'product-$id',
  () => api.fetchProduct(id),
);
```

### Cache Management

```dart
// Check cache state
if (Memoizer.hasValue('current-user')) {
  final cached = Memoizer.getValue<User>('current-user');
}

// Check if computation is in progress
if (Memoizer.isPending('current-user')) {
  // Request already in flight
}

// Force refresh (bypass cache)
final fresh = await Memoizer.run(
  'current-user',
  () => api.fetchCurrentUser(),
  forceRefresh: true,
);

// Invalidate specific cache
Memoizer.clear('current-user');

// Invalidate all caches
Memoizer.clearAll();
```

### Request Deduplication

When multiple calls happen concurrently, only one computation runs:

```dart
// These three calls share a single API request
final results = await Future.wait([
  Memoizer.run('user', () => api.fetchUser()),
  Memoizer.run('user', () => api.fetchUser()),
  Memoizer.run('user', () => api.fetchUser()),
]);
// results[0] == results[1] == results[2]
```

### When to Use Memoization

| Use Case | Example |
| -------- | ------- |
| **API responses** | Cache user profile, product details |
| **Expensive computations** | Image processing, data transformation |
| **Configuration** | App settings, feature flags |
| **Pull-to-refresh** | Use `forceRefresh: true` |

### Memoizer vs Other Patterns

| Pattern | Best For |
| ------- | -------- |
| **Memoizer** | Async operations, API calls, expensive computations |
| **Debouncer** | User input, search-as-you-type |
| **Throttler** | Rate limiting, scroll events |

## Design Principles

mz_core follows these principles:

### 1. Zero Dependencies

Pure Dart/Flutter - no external dependencies except the Flutter SDK.

**Benefit**: Reduced version conflicts, smaller bundle size

### 2. Composition Over Inheritance

Mixins (`AutoDispose`) instead of deep class hierarchies.

**Benefit**: Flexible, reusable components

### 3. Explicit Resource Management

Resources are managed explicitly with clear lifecycle:

```dart
create() → use() → dispose()
```

### 4. Type Safety

Strong typing everywhere, minimal `dynamic` usage.

**Benefit**: Catch errors at compile-time

### 5. Performance Awareness

- O(1) listener removal with Sets
- Lazy initialization where possible
- Minimal allocations in hot paths

### 6. Developer Experience

- Intuitive APIs that match mental models
- Comprehensive documentation
- Helpful error messages

## Common Patterns

### Pattern: Service + Controller

Separate business logic (service) from state management (controller):

```dart
// Service - business logic
class UserService {
  Future<User> fetchUser(String id) async {
    // API calls, data processing
  }
}

// Controller - state management
class UserController with Controller {
  UserController(this._service);

  final UserService _service;
  User? _user;
  User? get user => _user;

  Future<void> loadUser(String id) async {
    _user = await _service.fetchUser(id);
    notifyListeners();
  }
}
```

### Pattern: Dispose Chain

Chain disposals in correct order:

```dart
class AppState with AutoDispose {
  late final UserController _userController;
  late final TodoController _todoController;

  AppState() {
    _userController = UserController();
    autoDispose(_userController.dispose);

    // TodoController depends on UserController
    _todoController = TodoController(_userController);
    autoDispose(_todoController.dispose);
    // Will dispose in reverse: todo first, then user
  }
}
```

### Pattern: Guarded Operations

Use `guard()` to conditionally execute based on logger state:

```dart
if (logger.guard(() {
  // Expensive operation only if logging enabled
  final data = computeExpensiveData();
  logger.debug('Data: $data');
})) {
  print('Logged');
} else {
  print('Logging disabled');
}
```

## Event Queue System

### Overview

`EventManager` is a high-performance event queue system that handles ordered execution of async operations with features like cancellation, retry, undo/redo, and progress reporting.

### Why EventManager?

Traditional state management handles UI state well, but falls short when applications need:

- **Ordered execution** of async operations (API calls, database writes)
- **Cancellable operations** with token-based group cancellation
- **Undo/Redo support** for user actions
- **Automatic retry** with configurable backoff strategies
- **Progress reporting** for UI feedback during execution

### Core Components

| Component | Purpose |
| --------- | ------- |
| `EventManager<T>` | Main queue processor with configurable execution modes |
| `BaseEvent<T>` | Base class for defining events |
| `UndoableEvent<T>` | Events with undo/redo capability |
| `BatchEvent<T>` | Process multiple events as a unit |
| `EventToken` | Token for pausing/cancelling groups of events |
| `UndoRedoManager` | Manages undo/redo history |
| `EventLogger` | Event lifecycle logging |

### Event Lifecycle

Events progress through these states:

```text
Created → Pending → Running → Complete/Error/Cancel
                      ↓
                   Progress (0.0 - 1.0)
                      ↓
                   Retry (if failed with RetryPolicy)
```

### Execution Modes

```dart
// Sequential (default) - one event at a time
final manager = EventManager<AppState>();

// Concurrent - parallel processing
final manager = EventManager<AppState>(
  executionMode: ExecutionMode.concurrent(maxConcurrency: 3),
);

// Rate limited - N events per time window
final manager = EventManager<AppState>(
  executionMode: ExecutionMode.rateLimited(
    limit: 10,
    window: Duration(seconds: 1),
  ),
);
```

### Creating Events

```dart
class FetchUserEvent extends BaseEvent<AppState> {
  FetchUserEvent(this.userId);

  final String userId;

  @override
  Duration? get timeout => const Duration(seconds: 30);

  @override
  int get priority => 10; // Higher = processed first

  @override
  RetryPolicy? get retryPolicy => RetryPolicy(
    maxAttempts: 3,
    backoff: RetryBackoff.exponential(
      initial: Duration(seconds: 1),
    ),
  );

  @override
  Future<User> buildAction(EventManager<AppState> manager) async {
    reportProgress(0.0, message: 'Connecting...');
    final user = await api.fetchUser(userId);
    reportProgress(1.0, message: 'Done');
    return user;
  }
}
```

### Dispatching Events

```dart
manager.addEventToQueue(
  FetchUserEvent('123'),
  onDone: (event, user) => print('Got: $user'),
  onError: (error) => print('Failed: $error'),
);
```

### Token-Based Cancellation

Group related events for collective control:

```dart
final token = EventToken();

manager.addEventToQueue(FetchUserEvent('1', token: token));
manager.addEventToQueue(FetchUserEvent('2', token: token));
manager.addEventToQueue(FetchUserEvent('3', token: token));

// Cancel all events with this token
token.cancel(reason: 'User navigated away');

// Or pause/resume
token.pause();
token.resume();
```

### Undo/Redo Support

```dart
class UpdateNameEvent extends UndoableEvent<AppState> {
  UpdateNameEvent(this.newName);

  final String newName;
  String? _previousName;

  @override
  void captureState(EventManager<AppState> manager) {
    _previousName = manager.state.name;
  }

  @override
  Future<void> buildAction(EventManager<AppState> manager) async {
    manager.state.name = newName;
  }

  @override
  Future<void> undo(EventManager<AppState> manager) async {
    manager.state.name = _previousName!;
  }

  @override
  String get undoDescription => 'Change name to "$newName"';
}

// Usage
manager.addEventToQueue(UpdateNameEvent('John'));

// Undo/redo
await manager.undoManager?.undo(manager);
await manager.undoManager?.redo(manager);
```

### Backpressure Control

Prevent memory issues with queue limits:

```dart
final manager = EventManager<AppState>(
  maxQueueSize: 1000,
  overflowPolicy: OverflowPolicy.dropOldest, // or .dropNewest, .error
);
```

| Policy | Behavior |
| ------ | -------- |
| `dropNewest` | New events discarded when queue is full |
| `dropOldest` | Oldest events removed to make room |
| `error` | Throws `QueueOverflowError` when full |

### Retry Strategies

```dart
// Exponential backoff: 1s, 2s, 4s, 8s...
RetryBackoff.exponential(
  initial: Duration(seconds: 1),
  maxDelay: Duration(seconds: 30),
)

// Linear backoff: 1s, 2s, 3s, 4s...
RetryBackoff.linear(
  initial: Duration(seconds: 1),
  increment: Duration(seconds: 1),
)

// Constant delay: 1s, 1s, 1s...
RetryBackoff.constant(Duration(seconds: 1))
```

### When to Use EventManager

| Use Case | Example |
| -------- | ------- |
| **Ordered operations** | Database writes that must execute in order |
| **Cancellable workflows** | Multi-step processes user can abort |
| **Undo/redo features** | Text editors, drawing apps, form builders |
| **Retry-sensitive operations** | Network requests with transient failures |
| **Progress-tracked tasks** | File uploads, batch processing |

### EventManager vs Other Patterns

| Pattern | Best For |
| ------- | -------- |
| **Controller** | UI state, simple value changes |
| **EventManager** | Async operations, workflows, undo/redo |
| **Debouncer** | User input, search-as-you-type |
| **Memoizer** | Caching expensive computations |

## Next Steps

- Review [Getting Started](getting_started.md) for practical examples
- See [Troubleshooting](troubleshooting.md) for common issues
- Explore the API documentation for detailed reference
