# Troubleshooting

Common issues and solutions when using mz_core.

## Table of Contents

- [Controllers](#controllers)
- [Listeners](#listeners)
- [Logging](#logging)
- [Debounce/Throttle](#debouncethrottle)
- [Listenable Collections](#listenable-collections)
- [EventManager](#eventmanager)
- [Memory and Performance](#memory-and-performance)

## Controllers

### Issue: "setState() called after dispose()"

**Symptom**: Flutter throws error when controller notifies after widget disposal.

**Cause**: Widget disposed but controller still has listeners.

**Solution**: Remove listeners in `dispose()`:

```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _controller = MyController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);  // ✓ Remove listener
    _controller.dispose();                              // ✓ Dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => /* ... */;
}
```

### Issue: Controller value not updating UI

**Symptom**: Change controller value but UI doesn't update.

**Cause 1**: Forgot to wrap with `ControllerBuilder`:

```dart
// ❌ Bad - UI won't update
@override
Widget build(BuildContext context) {
  return Text('${controller.count}');
}

// ✓ Good - UI updates when controller changes
@override
Widget build(BuildContext context) {
  return ControllerBuilder<CounterController>(
    controller: controller,
    builder: (context, ctrl) {
      return Text('${ctrl.count}');
    },
  );
}
```

**Cause 2**: Forgetting to call `notifyListeners()`:

```dart
// ❌ Bad - modifies state but doesn't notify
void increment() {
  _count++;
  // Missing notifyListeners()!
}

// ✓ Good - notifies listeners after state change
void increment() {
  _count++;
  notifyListeners();
}
```

### Issue: "Concurrent modification during iteration"

**Symptom**: Error when modifying listeners during notification.

**Cause**: Adding/removing listeners from within a listener callback.

**Solution**: Defer the modification:

```dart
void _onControllerChanged() {
  // ❌ Bad - modifies listener list during iteration
  controller.removeListener(_onControllerChanged);

  // ✓ Good - defer until after notification completes
  Future.microtask(() {
    controller.removeListener(_onControllerChanged);
  });
}
```

## Listeners

### Issue: Listener not being called

**Symptom**: Add listener but it never executes.

**Diagnostic checklist**:

1. **Is the value actually changing?**

   ```dart
   controller.addListener(() => print('Changed'));
   controller.value = 5;
   controller.value = 5;  // Won't trigger - same value
   ```

2. **Is the listener being removed prematurely?**

   ```dart
   controller.addListener(callback);
   controller.removeListener(callback);  // Removed!
   controller.value = 5;  // Won't trigger
   ```

3. **Is the controller disposed?**

   ```dart
   controller.dispose();
   controller.value = 5;  // Won't trigger - disposed
   ```

4. **Using wrong listener signature?**

   ```dart
   // If controller only supports VoidCallback:
   controller.addListener((value) => print(value));  // May not work
   ```

### Issue: Memory leak from listeners

**Symptom**: Memory usage grows over time.

**Cause**: Not removing listeners when objects are disposed.

**Solution**: Always pair `addListener` with `removeListener`:

```dart
class MyService {
  final Controller _controller;

  MyService(this._controller) {
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    // Handle change
  }

  void dispose() {
    _controller.removeListener(_onChanged);  // ✓ Clean up
  }
}
```

**Tip**: Use `AutoDispose` to automate this:

```dart
class MyService with AutoDispose {
  MyService(Controller controller) {
    final listener = () => print('changed');
    controller.addListener(listener);
    autoDispose(() => controller.removeListener(listener));
  }
}
```

### Issue: Listener priority not working

**Symptom**: High priority listener executes after low priority.

**Cause**: Using simple listener API instead of `CListener`:

```dart
// ❌ Bad - priority ignored
controller.addListener(() => print('High'), priority: 10);

// ✓ Good - use CListener for priority
controller.addListener(
  CListener(
    () => print('High'),
    priority: 10,
    predicate: null,
  ),
);
```

## Logging

### Issue: Logs not appearing

**Diagnostic checklist**:

1. **Check minimum level:**

   ```dart
   final logger = SimpleLogger(minimumLevel: LogLevel.warning);
   logger.info('Info');   // Won't appear
   logger.error('Error'); // Will appear
   ```

2. **Check sampling rate:**

   ```dart
   final logger = SimpleLogger(sampleRate: 0.1);
   // Only 10% of logs appear
   ```

3. **Check filter:**

   ```dart
   final logger = SimpleLogger(
     filter: (entry, group) => entry.name != 'ignored',
   );
   logger.logEntry(LogEntry(
     name: 'ignored',  // Won't appear
     level: LogLevel.info,
     timestamp: DateTime.now(),
   ));
   ```

4. **Is logging disabled?**

   ```dart
   logger.isEnabled = false;
   logger.info('Not logged');
   ```

### Issue: Log groups not completing

**Symptom**: Memory grows, group entries accumulate.

**Cause**: Forgetting to call `completeGroup()`.

**Solutions**:

1. **Always complete groups:**

   ```dart
   logger.startGroup(group);
   try {
     // Log entries
   } finally {
     logger.completeGroup(group.id);  // ✓ Always completes
   }
   ```

2. **Use `group()` helper:**

   ```dart
   // Automatically completes even on exceptions
   await logger.group('id', 'title', () async {
     // Log entries
   });
   ```

3. **Rely on timeout:**

   ```dart
   // Groups auto-complete after timeout
   final logger = SimpleLogger(
     groupTimeout: const Duration(minutes: 5),
   );
   ```

### Issue: File logging permission denied

**Symptom**: `FileOutput` throws permission error.

**Cause**: No write permission to directory.

**Solution**: Use app-specific directories:

```dart
import 'package:path_provider/path_provider.dart';

// ✓ Good - use app documents directory
final directory = await getApplicationDocumentsDirectory();
final file = File('${directory.path}/app.log');
final output = FileOutput(file.openWrite());
```

### Issue: Rotating logs not rotating

**Symptom**: Log files grow indefinitely.

**Diagnostic**:

1. **Check max file size:**

   ```dart
   final output = RotatingFileOutput(
     directory: dir,
     baseFileName: 'app.log',
     maxFileSize: 1024 * 1024,  // 1 MB - may be too large
     maxFileCount: 5,
   );
   ```

2. **Verify flush is called:**

   Rotation only happens after `flush()`:

   ```dart
   logger.info('Entry');
   await logger.output.flush();  // Rotation checked here
   ```

## Debounce/Throttle

### Issue: Debounce not waiting

**Symptom**: Function executes immediately instead of waiting.

**Cause**: Using different tags for each call:

```dart
// ❌ Bad - different tags = no debouncing
for (var i = 0; i < 10; i++) {
  Debouncer.debounce(
    'tag-$i',  // Different tag each time!
    duration,
    () => print(i),
  );
}

// ✓ Good - same tag = proper debouncing
for (var i = 0; i < 10; i++) {
  Debouncer.debounce(
    'search',  // Same tag
    duration,
    () => print(i),
  );
}
```

### Issue: Debounced callback never executes

**Symptom**: Debounce called but callback doesn't run.

**Cause**: Rapid-fire calls prevent execution:

```dart
// If calls happen faster than duration:
while (true) {
  Debouncer.debounce('tag', duration, callback);
  await Future.delayed(Duration(milliseconds: 100));
  // If duration is 500ms, callback never executes!
}
```

**Solution**: Ensure calls eventually stop, or use throttle instead.

### Issue: Memory leak from Debouncer

**Symptom**: Memory grows when using many tags.

**Cause**: Not canceling unused tags.

**Solution**: Cancel tags when done:

```dart
@override
void dispose() {
  Debouncer.cancel('my-tag');  // ✓ Clean up
  super.dispose();
}

// Or cancel all
@override
void dispose() {
  Debouncer.cancelAll();
  super.dispose();
}
```

### Issue: Throttler not throttling

**Symptom**: Function executes every call despite throttle.

**Cause**: Creating new `Throttler` instance each time:

```dart
// ❌ Bad - new throttler each time
void handleClick() {
  final throttler = Throttler(duration);  // New instance!
  throttler.call(() => print('Clicked'));
}

// ✓ Good - reuse same throttler
final _throttler = Throttler(duration);

void handleClick() {
  _throttler.call(() => print('Clicked'));
}
```

## Listenable Collections

### Issue: List modification not triggering listeners

**Symptom**: Modify list but listeners don't fire.

**Cause**: Modifying internal list directly:

```dart
final list = ListenableList<int>([1, 2, 3]);
list.addListener(() => print('Changed'));

// ❌ Bad - if you somehow access internal list
_internalList.add(4);  // Won't notify

// ✓ Good - use ListenableList methods
list.add(4);  // Notifies listeners
```

### Issue: Too many notifications

**Symptom**: Listeners fire excessively, performance degrades.

**Cause**: Many individual modifications:

```dart
// ❌ Bad - notifies 1000 times
for (var i = 0; i < 1000; i++) {
  list.add(i);
}

// ✓ Good - batch operations
final items = [for (var i = 0; i < 1000; i++) i];
list.addAll(items);  // Notifies once
```

### Issue: "Unsupported operation" error

**Symptom**: Certain list operations throw error.

**Cause**: Using view operations on ListenableList:

```dart
final list = ListenableList<int>([1, 2, 3]);
final sublist = list.sublist(0, 2);  // Returns regular List
sublist.add(4);  // May throw or not notify parent
```

**Solution**: Copy data if you need a separate list:

```dart
final copy = List<int>.from(list.sublist(0, 2));
copy.add(4);  // Independent list
```

## EventManager

### Issue: Event not executing

**Symptom**: Event added to queue but never executes.

**Diagnostic checklist**:

1. **Is the manager paused?**

   ```dart
   manager.pause();  // Events won't execute
   manager.resume(); // Resume processing
   ```

2. **Is the event's token cancelled or paused?**

   ```dart
   final token = EventToken();
   token.pause();  // Events with this token are skipped
   token.cancel(); // Events with this token are cancelled
   ```

3. **Is the queue full with `OverflowPolicy.dropNewest`?**

   ```dart
   // New events are silently dropped when queue is full
   final manager = EventManager(
     maxQueueSize: 10,
     overflowPolicy: OverflowPolicy.dropNewest,
   );
   ```

4. **Is another event blocking in sequential mode?**

   ```dart
   // In sequential mode, a stuck event blocks the queue
   // Consider using concurrent mode or adding timeouts
   ```

### Issue: Event timeout not working

**Symptom**: Event runs forever despite timeout setting.

**Cause**: Timeout only applies to `buildAction()`, not to setup code.

**Solution**: Ensure long-running code is inside `buildAction()`:

```dart
class MyEvent extends BaseEvent<AppState> {
  @override
  Duration? get timeout => const Duration(seconds: 10);

  @override
  Future<void> buildAction(EventManager<AppState> manager) async {
    // This code is subject to timeout
    await longRunningOperation();
  }
}
```

### Issue: Retry not working

**Symptom**: Event fails but doesn't retry.

**Diagnostic checklist**:

1. **Is RetryPolicy configured?**

   ```dart
   @override
   RetryPolicy? get retryPolicy => RetryPolicy(
     maxAttempts: 3,
     backoff: RetryBackoff.exponential(
       initial: const Duration(seconds: 1),
     ),
   );
   ```

2. **Did you reach maxAttempts?**

   Check logs for retry attempts. After `maxAttempts`, the event fails permanently.

3. **Is the error retryable?**

   Some errors (like validation errors) shouldn't be retried. Check your error handling.

### Issue: Undo/redo not working

**Symptom**: `undo()` or `redo()` has no effect.

**Diagnostic checklist**:

1. **Is UndoRedoManager configured?**

   ```dart
   final manager = EventManager<AppState>(
     undoManager: UndoRedoManager(maxHistorySize: 50),
   );
   ```

2. **Is the event an UndoableEvent?**

   ```dart
   // Regular BaseEvent - not undoable
   class MyEvent extends BaseEvent<AppState> { ... }

   // UndoableEvent - supports undo/redo
   class MyEvent extends UndoableEvent<AppState> { ... }
   ```

3. **Is `captureState()` implemented?**

   ```dart
   @override
   void captureState(EventManager<AppState> manager) {
     _previousValue = manager.state.value;  // Must capture state!
   }
   ```

4. **Check canUndo/canRedo:**

   ```dart
   if (manager.undoManager?.canUndo ?? false) {
     await manager.undoManager!.undo(manager);
   }
   ```

### Issue: QueueOverflowError thrown

**Symptom**: Exception when adding events.

**Cause**: Queue is full with `OverflowPolicy.error`.

**Solutions**:

1. **Increase queue size:**

   ```dart
   final manager = EventManager<AppState>(
     maxQueueSize: 10000,  // Increase limit
   );
   ```

2. **Change overflow policy:**

   ```dart
   final manager = EventManager<AppState>(
     maxQueueSize: 1000,
     overflowPolicy: OverflowPolicy.dropOldest,  // Or .dropNewest
   );
   ```

3. **Process events faster:**

   ```dart
   // Use concurrent mode for parallel processing
   final manager = EventManager<AppState>(
     executionMode: ExecutionMode.concurrent(maxConcurrency: 5),
   );
   ```

### Issue: Events executing out of order

**Symptom**: Lower priority events execute before higher priority.

**Cause 1**: Using concurrent execution mode:

```dart
// Concurrent mode doesn't guarantee order
final manager = EventManager<AppState>(
  executionMode: ExecutionMode.concurrent(maxConcurrency: 3),
);
```

**Solution**: Use sequential mode for strict ordering:

```dart
final manager = EventManager<AppState>(); // Sequential by default
```

**Cause 2**: Priority not set correctly:

```dart
// Higher priority = processed first
@override
int get priority => 100;  // High priority

@override
int get priority => 0;    // Default/low priority
```

### Issue: Token cancellation not immediate

**Symptom**: Events continue executing after `token.cancel()`.

**Cause**: Currently executing events complete before cancellation takes effect.

**Solution**: Check `token.isCancelled` in long-running operations:

```dart
@override
Future<void> buildAction(EventManager<AppState> manager) async {
  for (final item in items) {
    if (token?.isCancelled ?? false) {
      throw CancelledException('Operation cancelled');
    }
    await processItem(item);
  }
}
```

### Issue: Memory leak in EventManager

**Symptom**: Memory grows over time with EventManager.

**Diagnostic checklist**:

1. **Dispose the manager when done:**

   ```dart
   @override
   void dispose() {
     manager.dispose();
     super.dispose();
   }
   ```

2. **Limit undo history size:**

   ```dart
   final manager = EventManager<AppState>(
     undoManager: UndoRedoManager(maxHistorySize: 50),  // Limit history
   );
   ```

3. **Limit logger history:**

   ```dart
   final manager = EventManager<AppState>(
     logger: EventLogger(maxHistorySize: 100),  // Limit logs
   );
   ```

4. **Clear completed events:**

   Events in terminal states are automatically cleaned up, but check for stuck events.

## Memory and Performance

### Issue: High memory usage

**Diagnostic checklist**:

1. **Undisposed controllers:**

   Use Flutter DevTools to check for leaked controllers.

   ```dart
   // ✓ Good - dispose everything
   @override
   void dispose() {
     _controller.dispose();
     _listenableList.dispose();
     super.dispose();
   }
   ```

2. **Accumulating log groups:**

   Check if groups are completing:

   ```dart
   // Monitor group count
   print('Active groups: ${logger._activeGroups.length}');
   ```

3. **Listener leaks:**

   Ensure all listeners are removed:

   ```dart
   // Before: 100 listeners
   controller.removeAllListeners();
   // After: 0 listeners
   ```

### Issue: Slow notifications

**Symptom**: UI lags when controller changes.

**Cause**: Too many listeners or expensive listener callbacks.

**Solution 1**: Reduce listener count with ControllerBuilder:

```dart
// ❌ Bad - 10 listeners for same data
for (var i = 0; i < 10; i++) {
  controller.addListener(() => updateWidget(i));
}

// ✓ Good - 1 builder, multiple children rebuild
ControllerBuilder<MyController>(
  controller: controller,
  builder: (context, ctrl) {
    return Column(
      children: [
        for (var i = 0; i < 10; i++) ChildWidget(i),
      ],
    );
  },
)
```

**Solution 2**: Use filtered listeners:

```dart
// Only notify when specific property changes
controller.addListener(
  callback,
  predicate: (key, value) => key == 'count',
);
```

**Solution 3**: Debounce notifications:

```dart
controller.addListener(() {
  Debouncer.debounce(
    'ui-update',
    const Duration(milliseconds: 16),  // ~60fps
    () => setState(() {}),
  );
});
```

### Issue: Stack overflow in dispose chain

**Symptom**: `dispose()` causes stack overflow.

**Cause**: Circular disposal references.

**Solution**: Check for cycles:

```dart
// ❌ Bad - circular reference
class A with AutoDispose {
  A(B b) {
    autoDispose(b.dispose);
  }
}

class B with AutoDispose {
  B(A a) {
    autoDispose(a.dispose);  // Circular!
  }
}

// ✓ Good - clear ownership
class Owner with AutoDispose {
  late final A a;
  late final B b;

  Owner() {
    a = A();
    b = B();
    autoDispose(a.dispose);
    autoDispose(b.dispose);
  }
}
```

## Getting Help

If your issue isn't covered here:

1. **Check API documentation**: See detailed API docs for each class
2. **Search GitHub issues**: Similar issues may have solutions
3. **Create a minimal reproduction**: Isolate the problem
4. **File an issue**: Include:
   - mz_core version
   - Flutter/Dart version
   - Minimal reproduction code
   - Expected vs actual behavior

## Known Limitations

### SimpleLogger Limitations

- Single output per logger (no multi-output built-in)
- Synchronous output (async writes must be handled by output implementation)
- Group timeout is per-group, not global

### Controller Limitations

- Notification is synchronous (no async listener support)
- All listeners notified even if predicate filters them (predicate runs per-listener)

### Listenable Collection Limitations

- No granular change events (only "something changed")
- Not compatible with AnimatedList without additional wrapper

### Debounce/Throttle Limitations

- Debouncer uses static state (can't easily test in isolation)
- Throttler immediate mode executes synchronously (can't be async)

### EventManager Limitations

- Sequential mode blocks on slow events (use timeouts or concurrent mode)
- Token cancellation doesn't interrupt currently executing events
- Undo/redo requires explicit state capture in `captureState()`
- Event merging only works for consecutive events of the same type

## Performance Tips

1. **Dispose everything**: Memory leaks compound over time
2. **Batch collection operations**: Reduce notification count
3. **Use sampling for high-frequency logs**: Reduce I/O overhead
4. **Filter listeners**: Don't notify when unnecessary
5. **Throttle UI updates**: Don't rebuild faster than 60fps
6. **Monitor DevTools**: Check for memory leaks and jank
