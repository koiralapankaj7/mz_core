/// @docImport 'throttler.dart';
library;

import 'dart:async';

/// A void callback function type.
///
/// This is equivalent to `VoidCallback` but defined here to avoid importing
/// dart:ui just for the type definition.
typedef DebouncerCallback = void Function();

/// A debounce-able function that takes a parameter and returns a Future.
///
/// Used by [Debouncer.debounceAsync] for type-safe async debouncing operations.
typedef Debounceable<S, T> = Future<S?> Function(T parameter);

class _DebouncerOperation {
  _DebouncerOperation(this.callback, this.timer);
  DebouncerCallback callback;
  Timer timer;
}

// A wrapper around Timer used for async debouncing.
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

/// {@template mz_core.Debouncer}
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
/// {@endtemplate}
abstract class Debouncer {
  static final Map<String, _DebouncerOperation> _operations = {};
  static final Map<String, _DebounceTimer<dynamic, dynamic>> _asyncOperations =
      {};

  /// Delays execution of [onExecute] until calls stop for [duration].
  ///
  /// {@macro mz_core.Debouncer}
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

  /// Returns a debounced async function with type-safe return values.
  ///
  /// Unlike [debounce] which takes a void callback, this returns a function
  /// that can be called with a parameter and returns a typed `Future`.
  ///
  /// The returned function delays execution until calls stop for [duration].
  /// Each new call cancels any pending operation and resets the timer.
  /// Cancelled operations return `null`.
  ///
  /// **Type Parameters**:
  /// * `S` - The return type of the async function
  /// * `T` - The parameter type passed to the function
  ///
  /// {@tool snippet}
  /// Type-safe API search with debouncing:
  ///
  /// ```dart
  /// class SearchService {
  ///   late final Debounceable<List<String>, String> _search;
  ///
  ///   SearchService() {
  ///     _search = Debouncer.debounceAsync<List<String>, String>(
  ///       'search',
  ///       (query) async {
  ///         final response = await api.search(query);
  ///         return response.results;
  ///       },
  ///       duration: const Duration(milliseconds: 300),
  ///     );
  ///   }
  ///
  ///   Future<List<String>?> search(String query) => _search(query);
  ///
  ///   void dispose() {
  ///     Debouncer.cancel('search');
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Cancellation behavior:
  ///
  /// ```dart
  /// final search = Debouncer.debounceAsync<String, int>(
  ///   'compute',
  ///   (value) async {
  ///     await Future.delayed(const Duration(seconds: 1));
  ///     return 'Result: $value';
  ///   },
  ///   duration: const Duration(milliseconds: 500),
  /// );
  ///
  /// final result1 = search(1); // Will be cancelled
  /// final result2 = search(2); // Will be cancelled
  /// final result3 = await search(3); // Executes after 500ms
  ///
  /// print(await result1); // null (cancelled)
  /// print(await result2); // null (cancelled)
  /// print(result3); // 'Result: 3'
  /// ```
  /// {@end-tool}
  static Debounceable<S, T> debounceAsync<S, T>(
    String tag,
    Debounceable<S?, T> function, {
    Duration? duration,
  }) {
    if (duration == Duration.zero) {
      _asyncOperations[tag]?.cancel();
      _asyncOperations.remove(tag);
      return function;
    }

    return (T parameter) async {
      final existing = _asyncOperations[tag];
      if (existing != null && !existing.isCompleted) {
        existing.cancel();
      }

      final debounceTimer = _asyncOperations[tag] = _DebounceTimer<S, T>(
        function,
        duration: duration,
      );
      _asyncOperations[tag] = debounceTimer;
      try {
        await debounceTimer.future;
      } on _CancelException {
        return null;
      }
      return function(parameter);
    };
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

  /// Fires the async function for [tag] immediately without canceling the
  /// timer.
  ///
  /// Returns a function that, when called with a parameter, immediately
  /// executes the original debounced function without waiting for the debounce
  /// timer.
  ///
  /// Returns a function that resolves to `null` if no operation with [tag]
  /// exists.
  ///
  /// {@tool snippet}
  /// Immediately execute a debounced operation:
  ///
  /// ```dart
  /// final debouncer = Debouncer.debounceAsync<String, int>(
  ///   'compute',
  ///   (value) async => 'Result: $value',
  ///   duration: const Duration(seconds: 1),
  /// );
  ///
  /// // Queue debounced operation
  /// final future = debouncer(42);
  ///
  /// // Fire immediately without waiting
  /// final fireFunc = Debouncer.fireAsync<String, int>('compute');
  /// final result = await fireFunc(42);
  /// print(result); // 'Result: 42' (immediate)
  /// ```
  /// {@end-tool}
  static Debounceable<S, T> fireAsync<S, T>(String tag) {
    return (T parameter) async {
      if (_asyncOperations[tag] case final _DebounceTimer<S, T> timer) {
        return timer._function(parameter);
      }
      return null;
    };
  }

  /// Cancels any active debounce operation with [tag].
  ///
  /// Stops the timer and removes the operation. The callback will not execute.
  /// Works for both [debounce] and [debounceAsync] operations.
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
    _asyncOperations[tag]?.cancel();
    _asyncOperations.remove(tag);
  }

  /// Cancels all active debounce operations.
  ///
  /// Stops all timers and clears all pending callbacks. Use when cleaning up
  /// multiple operations at once. Works for both [debounce] and [debounceAsync]
  /// operations.
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
    for (final operation in _asyncOperations.values) {
      operation.cancel();
    }
    _asyncOperations.clear();
  }

  /// Returns the number of active debounce operations.
  ///
  /// Includes both [debounce] and [debounceAsync] operations.
  /// Useful for debugging or testing debounce behavior.
  static int count() {
    return _operations.length + _asyncOperations.length;
  }

  /// Returns whether a debounce operation with [tag] is currently active.
  ///
  /// Returns `true` if there is an active debounce timer for this tag
  /// (from either [debounce] or [debounceAsync]), `false` otherwise.
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
    return _operations.containsKey(tag) || _asyncOperations.containsKey(tag);
  }
}
