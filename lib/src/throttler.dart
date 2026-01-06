import 'dart:async';

import 'package:flutter/material.dart';

/// A void callback function type.
///
/// This is equivalent to [VoidCallback] but defined here to avoid importing
/// dart:ui just for the type definition.
typedef DebouncerCallback = void Function();

/// A debounce-able function that takes a parameter and returns a Future.
///
/// Used by [AdvanceDebouncer] for type-safe async debouncing operations.
typedef Debounceable<S, T> = Future<S?> Function(T parameter);

class _DebouncerOperation {
  _DebouncerOperation(this.callback, this.timer);
  DebouncerCallback callback;
  Timer timer;
}

/// {@template mz_utils.Debouncer}
/// Static utility class for debouncing function calls.
///
/// [Debouncer] delays function execution until calls stop for a specified
/// duration. If another call happens before the duration expires, the timer
/// resets.
///
/// ## When to Use Debouncing
///
/// Use debouncing when you want to:
/// * Wait for user input to stop before acting (search-as-you-type)
/// * Batch rapid-fire events into single actions
/// * Avoid excessive API calls during user interaction
/// * Auto-save after editing stops
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Debounce search input:
///
/// ```dart
/// TextField(
///   onChanged: (query) {
///     Debouncer.debounce(
///       'search',
///       const Duration(milliseconds: 500),
///       () => performSearch(query),
///     );
///   },
/// )
/// ```
/// {@end-tool}
///
/// ## Multiple Debounce Operations
///
/// {@tool snippet}
/// Use different tags for independent operations:
///
/// ```dart
/// // Search debouncer
/// Debouncer.debounce('search', duration, () => search());
///
/// // Save debouncer (independent)
/// Debouncer.debounce('save', duration, () => save());
/// ```
/// {@end-tool}
///
/// ## Cleanup
///
/// {@tool snippet}
/// Cancel operations when widgets are disposed:
///
/// ```dart
/// @override
/// void dispose() {
///   Debouncer.cancel('search');
///   // Or cancel all
///   Debouncer.cancelAll();
///   super.dispose();
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Throttler], which limits execution frequency instead of delaying
/// * [AdvanceDebouncer], which provides type-safe async debouncing
/// {@endtemplate}
abstract class Debouncer {
  static final Map<String, _DebouncerOperation> _operations = {};

  /// Delays execution of [onExecute] until calls stop for [duration].
  ///
  /// {@macro mz_utils.Debouncer}
  ///
  /// Each call with the same [tag] cancels any previous pending operation and
  /// starts a new timer. The callback only executes after [duration] passes
  /// without any new calls.
  ///
  /// The [tag] parameter uniquely identifies this debounce operation. Use the
  /// same tag for related calls that should cancel each other.
  ///
  /// The [duration] parameter specifies how long to wait after the last call.
  /// If `Duration.zero`, [onExecute] executes immediately (synchronously).
  ///
  /// {@tool snippet}
  /// Debounce API calls:
  ///
  /// ```dart
  /// void onSearchChanged(String query) {
  ///   Debouncer.debounce(
  ///     'api-search',
  ///     const Duration(milliseconds: 300),
  ///     () async {
  ///       final results = await api.search(query);
  ///       setState(() => _results = results);
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  static void debounce(
    String tag,
    Duration duration,
    DebouncerCallback onExecute,
  ) {
    _operations[tag]?.timer.cancel();
    if (duration == Duration.zero) {
      _operations.remove(tag);
      onExecute();
    } else {
      _operations[tag] = _DebouncerOperation(
        onExecute,
        Timer(duration, () {
          _operations[tag]?.timer.cancel();
          _operations.remove(tag);
          onExecute();
        }),
      );
    }
  }

  /// Fires the callback for [tag] immediately without canceling the timer.
  ///
  /// Executes the callback associated with [tag] right away, but leaves the
  /// debounce timer active. To both execute and cancel, call [fire] followed
  /// by [cancel].
  ///
  /// Does nothing if no operation exists for [tag].
  static void fire(String tag) {
    _operations[tag]?.callback();
  }

  /// Cancels any active debounce operation with [tag].
  ///
  /// Stops the timer and removes the operation. The callback will not execute.
  ///
  /// {@tool snippet}
  /// Cancel debounce operations:
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   Debouncer.cancel('search');
  ///   super.dispose();
  /// }
  /// ```
  /// {@end-tool}
  static void cancel(String tag) {
    _operations[tag]?.timer.cancel();
    _operations.remove(tag);
  }

  /// Cancels all active debounce operations.
  ///
  /// Stops all timers and clears all pending callbacks. Use when cleaning up
  /// multiple operations at once.
  ///
  /// {@tool snippet}
  /// Cancel all operations:
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   Debouncer.cancelAll();
  ///   super.dispose();
  /// }
  /// ```
  /// {@end-tool}
  static void cancelAll() {
    for (final operation in _operations.values) {
      operation.timer.cancel();
    }
    _operations.clear();
  }

  /// Returns the number of active debounce operations.
  ///
  /// Useful for debugging or testing debounce behavior.
  static int count() {
    return _operations.length;
  }

  /// Returns whether a debounce operation with [tag] is currently active.
  ///
  /// Returns `true` if there is an active debounce timer for this tag,
  /// `false` otherwise.
  ///
  /// {@tool snippet}
  /// Check if debounce is active:
  ///
  /// ```dart
  /// if (Debouncer.isActive('save')) {
  ///   showIndicator('Saving...');
  /// }
  /// ```
  /// {@end-tool}
  static bool isActive(String tag) {
    return _operations.containsKey(tag);
  }
}

/// {@template mz_utils.Throttler}
/// A throttler that limits how often a function can be called.
///
/// Unlike debouncing (which delays execution until calls stop), throttling
/// ensures a function is called at most once per [interval]. The first call
/// executes immediately (by default), then subsequent calls are throttled
/// until the interval expires.
///
/// ## When to Use Throttling
///
/// Use throttling when you want to:
/// * Limit execution frequency for continuous events (scroll, resize)
/// * Rate-limit button presses to prevent double-submission
/// * Control API call frequency
/// * Throttle UI updates for performance
///
/// ## Throttling vs Debouncing
///
/// * **Throttle**: Execute immediately, then block for duration
/// * **Debounce**: Wait for calls to stop, then execute once
///
/// Use throttle for continuous events, debounce for user input.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Throttle button presses:
///
/// ```dart
/// class SaveButton extends StatefulWidget {
///   @override
///   State<SaveButton> createState() => _SaveButtonState();
/// }
///
/// class _SaveButtonState extends State<SaveButton> {
///   final _throttler = Throttler(const Duration(seconds: 2));
///
///   @override
///   void dispose() {
///     _throttler.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ElevatedButton(
///       onPressed: () {
///         // Can only execute once every 2 seconds
///         _throttler.call(() => saveData());
///       },
///       child: const Text('Save'),
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Scroll Event Throttling
///
/// {@tool snippet}
/// Throttle scroll position updates:
///
/// ```dart
/// class ScrollTracker extends StatefulWidget {
///   const ScrollTracker({super.key});
///
///   @override
///   State<ScrollTracker> createState() => _ScrollTrackerState();
/// }
///
/// class _ScrollTrackerState extends State<ScrollTracker> {
///   final _scrollController = ScrollController();
///   final _throttler = Throttler(const Duration(milliseconds: 100));
///
///   @override
///   void initState() {
///     super.initState();
///     _scrollController.addListener(_onScroll);
///   }
///
///   void _onScroll() {
///     _throttler.call(() {
///       print('Scroll position: ${_scrollController.offset}');
///     });
///   }
///
///   @override
///   void dispose() {
///     _scrollController.dispose();
///     _throttler.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListView.builder(
///       controller: _scrollController,
///       itemCount: 100,
///       itemBuilder: (context, index) => ListTile(
///         title: Text('Item $index'),
///       ),
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Immediate vs Delayed Execution
///
/// {@tool snippet}
/// Control when throttled actions execute:
///
/// ```dart
/// final throttler = Throttler(const Duration(milliseconds: 500));
///
/// // Execute immediately, then throttle
/// throttler.call(
///   () => print('Immediate'),
///   immediateCall: true, // Default
/// );
///
/// // Queue for execution after interval
/// throttler.call(
///   () => print('Delayed'),
///   immediateCall: false,
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Debouncer], which delays execution until calls stop
/// * [AdvanceDebouncer], which provides type-safe async debouncing
/// {@endtemplate}
class Throttler {
  /// Creates a throttler with the specified [interval].
  ///
  /// The [interval] determines the minimum time between function executions.
  Throttler(this.interval);

  /// The minimum duration between throttled function calls.
  final Duration interval;

  VoidCallback? _action;
  Timer? _timer;

  /// Whether the throttler is currently in a throttling period.
  ///
  /// Returns `true` if a timer is active and calls are being throttled,
  /// `false` otherwise.
  bool get isBusy => _timer != null;

  /// Throttles the given [action].
  ///
  /// {@template mz_utils.Throttler.call}
  /// If [immediateCall] is true (default), the action executes immediately
  /// on the first call and subsequent calls are throttled. If multiple calls
  /// occur during the throttle period, only the last action is queued for
  /// execution when the period ends.
  ///
  /// If [immediateCall] is false, the action is queued and will execute
  /// after the throttle interval expires.
  /// {@endtemplate}
  ///
  /// {@tool snippet}
  /// Basic throttling with immediate execution:
  ///
  /// ```dart
  /// final throttler = Throttler(const Duration(seconds: 1));
  ///
  /// // First call executes immediately
  /// throttler.call(() => print('1')); // Prints immediately
  ///
  /// // Subsequent calls within 1 second are throttled
  /// throttler.call(() => print('2')); // Queued
  /// throttler.call(() => print('3')); // Replaces queued action
  ///
  /// // After 1 second: prints '3'
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Delayed execution mode:
  ///
  /// ```dart
  /// final throttler = Throttler(const Duration(milliseconds: 500));
  ///
  /// // Action queued for execution after 500ms
  /// throttler.call(
  ///   () => print('Delayed'),
  ///   immediateCall: false,
  /// );
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Rate-limiting API calls:
  ///
  /// ```dart
  /// class DataService {
  ///   final _updateThrottler = Throttler(const Duration(seconds: 5));
  ///
  ///   void updateData(Map<String, dynamic> data) {
  ///     _updateThrottler.call(() async {
  ///       await api.update(data);
  ///       print('Data updated');
  ///     });
  ///   }
  ///
  ///   void dispose() {
  ///     _updateThrottler.dispose();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  void call(VoidCallback action, {bool immediateCall = true}) {
    // Let the latest action override whatever was there before
    _action = action;
    // If no timer is running, we want to start one
    if (_timer == null) {
      //  If immediateCall is true, we handle the action now
      if (immediateCall) _callAction();
      // Start a timer that will temporarily throttle subsequent calls,
      // and eventually make a call to whatever _action is (if anything)
      _timer = Timer(interval, _callAction);
    }
  }

  void _callAction() {
    // If we have an action queued up, complete it.
    _action?.call();
    // Once an action is called, do not call the same action again
    // unless another action is queued.
    _action = null;
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels any pending throttled action.
  ///
  /// This clears the queued action and stops the throttle timer, returning
  /// the throttler to an idle state. Future calls to [call] will work
  /// normally.
  ///
  /// {@tool snippet}
  /// Cancel a throttled action:
  ///
  /// ```dart
  /// final throttler = Throttler(const Duration(seconds: 1));
  ///
  /// throttler.call(() => print('This will execute'));
  /// throttler.call(() => print('This is queued'));
  ///
  /// // Cancel the queued action
  /// throttler.cancel();
  ///
  /// // New calls work normally
  /// throttler.call(() => print('New action'));
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Conditionally cancel based on state:
  ///
  /// ```dart
  /// void handleNavigation() {
  ///   if (shouldCancelThrottle) {
  ///     _throttler.cancel();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  void cancel() {
    _action = null;
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes of the throttler and cancels any pending action.
  ///
  /// After calling dispose, the throttler should not be used again.
  /// Always call [dispose] when the throttler is no longer needed to
  /// prevent memory leaks from active timers.
  ///
  /// This is functionally equivalent to [cancel] but signals permanent
  /// disposal rather than temporary cancellation.
  ///
  /// {@tool snippet}
  /// Dispose throttler in widget:
  ///
  /// ```dart
  /// class MyWidget extends StatefulWidget {
  ///   @override
  ///   State<MyWidget> createState() => _MyWidgetState();
  /// }
  ///
  /// class _MyWidgetState extends State<MyWidget> {
  ///   final _throttler = Throttler(const Duration(seconds: 1));
  ///
  ///   @override
  ///   void dispose() {
  ///     _throttler.dispose(); // Clean up resources
  ///     super.dispose();
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return ElevatedButton(
  ///       onPressed: () => _throttler.call(() => handlePress()),
  ///       child: const Text('Press Me'),
  ///     );
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Dispose in service class:
  ///
  /// ```dart
  /// class DataService {
  ///   final _throttler = Throttler(const Duration(seconds: 5));
  ///
  ///   void updateData(String data) {
  ///     _throttler.call(() => _performUpdate(data));
  ///   }
  ///
  ///   void dispose() {
  ///     _throttler.dispose();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  void dispose() {
    _action = null;
    _timer?.cancel();
    _timer = null;
  }
}

/// {@template mz_utils.AdvanceDebouncer}
/// Advanced debouncer with type-safe async support.
///
/// Provides type-safe debouncing for async operations with generic type
/// parameters. Unlike [Debouncer], which works with void callbacks,
/// [AdvanceDebouncer] handles async functions that return values and
/// maintains full type safety throughout.
///
/// ## When to Use AdvanceDebouncer
///
/// Use [AdvanceDebouncer] instead of [Debouncer] when you need:
/// * **Type-safe async operations** with return values
/// * **Cancellation of in-flight requests** when new calls arrive
/// * **Null return values** when operations are cancelled
/// * **Generic type parameters** for compile-time safety
///
/// Use [Debouncer] for simple void callbacks without return values.
///
/// ## Key Features
///
/// * **Type Safety**: Generic `<S, T>` parameters ensure type checking
/// * **Async Support**: Handles `Future`-based operations naturally
/// * **Automatic Cancellation**: Cancels pending operations on new calls
/// * **Null on Cancel**: Returns `null` when operation is cancelled
/// * **Tag-based**: Manage multiple independent debounce operations
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Type-safe API search with debouncing:
///
/// ```dart
/// class SearchService {
///   final _api = ApiClient();
///   late final Debounceable<List<String>, String> _debouncedSearch;
///
///   SearchService() {
///     _debouncedSearch = AdvanceDebouncer.debounce<List<String>, String>(
///       'search',
///       (query) async {
///         final response = await _api.search(query);
///         return response.results;
///       },
///       duration: const Duration(milliseconds: 300),
///     );
///   }
///
///   Future<List<String>?> search(String query) async {
///     return _debouncedSearch(query);
///   }
///
///   void dispose() {
///     AdvanceDebouncer.cancel('search');
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Cancellation Behavior
///
/// {@tool snippet}
/// Automatic cancellation of previous requests:
///
/// ```dart
/// final debouncer = AdvanceDebouncer.debounce<String, int>(
///   'compute',
///   (value) async {
///     await Future.delayed(const Duration(seconds: 1));
///     return 'Result: $value';
///   },
///   duration: const Duration(milliseconds: 500),
/// );
///
/// // First call
/// final result1 = debouncer(1); // Will be cancelled
///
/// // Second call within 500ms - cancels first
/// final result2 = debouncer(2); // Will be cancelled
///
/// // Third call within 500ms - cancels second
/// final result3 = await debouncer(3); // Executes after 500ms
///
/// print(await result1); // null (cancelled)
/// print(await result2); // null (cancelled)
/// print(result3); // 'Result: 3'
/// ```
/// {@end-tool}
///
/// ## Multiple Debounce Operations
///
/// {@tool snippet}
/// Use different tags for independent operations:
///
/// ```dart
/// class MultiSearchService {
///   final _userSearch = AdvanceDebouncer.debounce<List<User>, String>(
///     'user-search',
///     (query) async => api.searchUsers(query),
///     duration: const Duration(milliseconds: 300),
///   );
///
///   final _productSearch = AdvanceDebouncer.debounce<List<Product>, String>(
///     'product-search',
///     (query) async => api.searchProducts(query),
///     duration: const Duration(milliseconds: 300),
///   );
///
///   Future<List<User>?> searchUsers(String query) => _userSearch(query);
///   Future<List<Product>?> searchProducts(String query) {
///     return _productSearch(query);
///   }
///
///   void dispose() {
///     AdvanceDebouncer.cancel('user-search');
///     AdvanceDebouncer.cancel('product-search');
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Error Handling
///
/// {@tool snippet}
/// Handle errors in debounced functions:
///
/// ```dart
/// final debouncedFetch = AdvanceDebouncer.debounce<String, String>(
///   'fetch',
///   (id) async {
///     try {
///       return await api.fetchData(id);
///     } catch (e) {
///       print('Error: $e');
///       return null;
///     }
///   },
///   duration: const Duration(milliseconds: 300),
/// );
///
/// final result = await debouncedFetch('123');
/// if (result != null) {
///   print('Data: $result');
/// } else {
///   print('Failed or cancelled');
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Debouncer], for simple void callback debouncing
/// * [Throttler], which limits execution frequency instead of delaying
/// * [Debounceable], the function type used by this debouncer
/// {@endtemplate}
abstract class AdvanceDebouncer {
  static final Map<String, _DebounceTimer<dynamic, dynamic>> _operations = {};

  /// Returns a new function that is a debounced version of [function].
  ///
  /// {@template mz_utils.AdvanceDebouncer.debounce}
  /// The returned function delays execution of [function] until calls stop for
  /// the specified [duration]. Each new call cancels any pending operation and
  /// resets the timer.
  ///
  /// The [tag] uniquely identifies this debounce operation. Use the same tag
  /// for related calls that should cancel each other, and different tags for
  /// independent operations.
  ///
  /// The [duration] specifies how long to wait after the last call before
  /// executing [function]. If `Duration.zero`, [function] executes without
  /// debouncing.
  ///
  /// **Type Parameters**:
  /// * `S` - The return type of the async function
  /// * `T` - The parameter type passed to the function
  ///
  /// **Returns**:
  /// * A `Future<S?>` that resolves to the function result or `null` if
  ///   cancelled
  /// {@endtemplate}
  ///
  /// {@tool snippet}
  /// Create a debounced API call:
  ///
  /// ```dart
  /// final debouncedSearch = AdvanceDebouncer.debounce<List<Result>, String>(
  ///   'api-search',
  ///   (query) async {
  ///     final response = await http.get(
  ///       Uri.parse('https://api.example.com/search?q=$query'),
  ///     );
  ///     return parseResults(response.body);
  ///   },
  ///   duration: const Duration(milliseconds: 300),
  /// );
  ///
  /// // Use the debounced function
  /// final results = await debouncedSearch('flutter');
  /// if (results != null) {
  ///   displayResults(results);
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Zero duration - no debouncing:
  ///
  /// ```dart
  /// final instant = AdvanceDebouncer.debounce<String, int>(
  ///   'instant',
  ///   (value) async => 'Value: $value',
  ///   duration: Duration.zero,
  /// );
  ///
  /// // Executes immediately without debouncing
  /// final result = await instant(42);
  /// print(result); // 'Value: 42'
  /// ```
  /// {@end-tool}
  static Debounceable<S, T> debounce<S, T>(
    String tag,
    Debounceable<S?, T> function, {
    Duration? duration,
  }) {
    if (duration == Duration.zero) {
      _operations[tag]?.cancel();
      _operations.remove(tag);
      return function;
    }

    return (T parameter) async {
      final existing = _operations[tag];
      if (existing != null && !existing.isCompleted) {
        existing.cancel();
      }

      final debounceTimer = _operations[tag] = _DebounceTimer<S, T>(
        function,
        duration: duration,
      );
      _operations[tag] = debounceTimer;
      try {
        await debounceTimer.future;
      } on _CancelException {
        return null;
      }
      return function(parameter);
    };
  }

  /// Executes the callback associated with [tag] immediately.
  ///
  /// This returns a function that, when called with a parameter, immediately
  /// executes the original debounced function without waiting for the debounce
  /// timer. The debounce timer is NOT cancelled, so if you want to both fire
  /// and cancel, call `fire(tag)` first, then `cancel(tag)`.
  ///
  /// Returns a function that resolves to the function result, or `null` if no
  /// operation with [tag] exists.
  ///
  /// {@tool snippet}
  /// Immediately execute a debounced operation:
  ///
  /// ```dart
  /// final debouncer = AdvanceDebouncer.debounce<String, int>(
  ///   'compute',
  ///   (value) async => 'Result: $value',
  ///   duration: const Duration(seconds: 1),
  /// );
  ///
  /// // Queue debounced operation
  /// final future = debouncer(42);
  ///
  /// // Fire immediately without waiting
  /// final fireFunc = AdvanceDebouncer.fire<String, int>('compute');
  /// final result = await fireFunc(42);
  /// print(result); // 'Result: 42' (immediate)
  ///
  /// // Original operation still pending
  /// AdvanceDebouncer.cancel('compute'); // Cancel if needed
  /// ```
  /// {@end-tool}
  static Debounceable<S, T> fire<S, T>(String tag) {
    return (T parameter) async {
      if (_operations[tag] case final _DebounceTimer<S, T> timer) {
        return timer._function(parameter);
      }
      return null;
    };
  }

  /// Cancels any active debounce operation with [tag].
  ///
  /// Stops the timer and removes the operation. Any pending futures from this
  /// operation will resolve to `null`.
  ///
  /// {@tool snippet}
  /// Cancel a specific debounce operation:
  ///
  /// ```dart
  /// final debouncer = AdvanceDebouncer.debounce<String, String>(
  ///   'fetch',
  ///   (id) async => fetchData(id),
  ///   duration: const Duration(milliseconds: 500),
  /// );
  ///
  /// final result = debouncer('123'); // Starts debouncing
  ///
  /// // Cancel before it executes
  /// AdvanceDebouncer.cancel('fetch');
  ///
  /// print(await result); // null (cancelled)
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Cancel in cleanup methods:
  ///
  /// ```dart
  /// class SearchService {
  ///   late final Debounceable<List<String>, String> _search;
  ///
  ///   SearchService() {
  ///     _search = AdvanceDebouncer.debounce(
  ///       'search',
  ///       (query) async => performSearch(query),
  ///       duration: const Duration(milliseconds: 300),
  ///     );
  ///   }
  ///
  ///   void dispose() {
  ///     AdvanceDebouncer.cancel('search');
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  static void cancel(String tag) {
    _operations[tag]?.cancel();
    _operations.remove(tag);
  }

  /// Cancels all active debounce operations.
  ///
  /// Stops all timers and removes all operations. Any pending futures will
  /// resolve to `null`. Use when cleaning up multiple operations at once.
  ///
  /// {@tool snippet}
  /// Cancel all operations on cleanup:
  ///
  /// ```dart
  /// class MultiSearchService {
  ///   late final Debounceable<List<User>, String> _userSearch;
  ///   late final Debounceable<List<Product>, String> _productSearch;
  ///
  ///   MultiSearchService() {
  ///     _userSearch = AdvanceDebouncer.debounce(
  ///       'users',
  ///       (q) async => searchUsers(q),
  ///       duration: const Duration(milliseconds: 300),
  ///     );
  ///     _productSearch = AdvanceDebouncer.debounce(
  ///       'products',
  ///       (q) async => searchProducts(q),
  ///       duration: const Duration(milliseconds: 300),
  ///     );
  ///   }
  ///
  ///   void dispose() {
  ///     // Cancel all at once instead of individual cancel calls
  ///     AdvanceDebouncer.cancelAll();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  static void cancelAll() {
    for (final operation in _operations.values) {
      operation.cancel();
    }
    _operations.clear();
  }

  /// Returns the number of active debounce operations.
  ///
  /// An operation is considered active if it has a pending timer that hasn't
  /// completed or been cancelled yet.
  ///
  /// Useful for debugging or monitoring debounce state.
  ///
  /// {@tool snippet}
  /// Monitor active operations:
  ///
  /// ```dart
  /// print('Active operations: ${AdvanceDebouncer.count()}');
  ///
  /// final search1 = AdvanceDebouncer.debounce<String, String>(
  ///   'search1',
  ///   (q) async => performSearch(q),
  ///   duration: const Duration(milliseconds: 300),
  /// );
  ///
  /// final search2 = AdvanceDebouncer.debounce<String, String>(
  ///   'search2',
  ///   (q) async => performSearch(q),
  ///   duration: const Duration(milliseconds: 300),
  /// );
  ///
  /// print('Active operations: ${AdvanceDebouncer.count()}'); // 2
  ///
  /// AdvanceDebouncer.cancel('search1');
  /// print('Active operations: ${AdvanceDebouncer.count()}'); // 1
  /// ```
  /// {@end-tool}
  static int count() {
    return _operations.length;
  }

  /// Returns whether a debounce operation with [tag] is currently active.
  ///
  /// Returns `true` if there is an active debounce timer for this tag,
  /// `false` otherwise.
  ///
  /// {@tool snippet}
  /// Check if debounce is active:
  ///
  /// ```dart
  /// final debouncer = AdvanceDebouncer.debounce<String, String>(
  ///   'save',
  ///   (data) async => saveData(data),
  ///   duration: const Duration(seconds: 1),
  /// );
  ///
  /// print(AdvanceDebouncer.isActive('save')); // false
  ///
  /// debouncer('data');
  /// print(AdvanceDebouncer.isActive('save')); // true
  ///
  /// await Future.delayed(const Duration(seconds: 2));
  /// print(AdvanceDebouncer.isActive('save')); // false (completed)
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Show UI indicator when debouncing:
  ///
  /// ```dart
  /// class SearchWidget extends StatefulWidget {
  ///   @override
  ///   State<SearchWidget> createState() => _SearchWidgetState();
  /// }
  ///
  /// class _SearchWidgetState extends State<SearchWidget> {
  ///   late final Debounceable<List<String>, String> _search;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     _search = AdvanceDebouncer.debounce(
  ///       'search',
  ///       (q) async => performSearch(q),
  ///       duration: const Duration(milliseconds: 300),
  ///     );
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return TextField(
  ///       onChanged: (query) {
  ///         _search(query);
  ///         setState(() {}); // Update UI
  ///       },
  ///       decoration: InputDecoration(
  ///         suffixIcon: AdvanceDebouncer.isActive('search')
  ///             ? const CircularProgressIndicator()
  ///             : null,
  ///       ),
  ///     );
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  static bool isActive(String tag) {
    return _operations.containsKey(tag);
  }
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer<S, T> {
  _DebounceTimer(
    Debounceable<S?, T> function, {
    Duration? duration,
  }) : _function = function {
    _timer = Timer(
      duration ?? const Duration(milliseconds: 500),
      _onComplete,
    );
  }

  final Debounceable<S?, T> _function;
  late final Timer _timer;
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    if (!_completer.isCompleted) {
      _completer.completeError(const _CancelException());
    }
  }
}

// An exception indicating that the timer was canceled.
class _CancelException implements Exception {
  const _CancelException();
}
