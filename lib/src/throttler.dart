/// @docImport 'debouncer.dart';
library;

import 'dart:async';

import 'package:flutter/material.dart';

class _ThrottlerOperation {
  _ThrottlerOperation(this.interval, this.onComplete);

  final Duration interval;
  final VoidCallback onComplete;
  VoidCallback? action;
  Timer? timer;

  bool get isBusy => timer != null;

  void call(VoidCallback newAction, {bool immediateCall = true}) {
    action = newAction;
    if (timer == null) {
      if (immediateCall) _executeAction();
      timer = Timer(interval, _onTimerComplete);
    }
  }

  void _executeAction() {
    action?.call();
    action = null;
  }

  void _onTimerComplete() {
    _executeAction();
    timer = null;
    onComplete();
  }

  void cancel() {
    action = null;
    timer?.cancel();
    timer = null;
  }
}

/// {@template mz_core.Throttler}
/// Static utility class for throttling function calls.
///
/// [Throttler] limits how often a function can be called. Unlike debouncing
/// (which delays execution until calls stop), throttling ensures a function
/// is called at most once per interval.
///
/// Similar to [Debouncer], `Throttler` uses string tags to identify throttled
/// operations, making it easy to throttle, check status, and cancel specific
/// operations.
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
/// ElevatedButton(
///   onPressed: () {
///     Throttler.throttle(
///       'save',
///       const Duration(seconds: 2),
///       () => saveData(),
///     );
///   },
///   child: const Text('Save'),
/// )
/// ```
/// {@end-tool}
///
/// ## Scroll Event Throttling
///
/// {@tool snippet}
/// Throttle scroll position updates:
///
/// ```dart
/// void _onScroll() {
///   Throttler.throttle(
///     'scroll',
///     const Duration(milliseconds: 100),
///     () => print('Scroll position: ${_scrollController.offset}'),
///   );
/// }
///
/// @override
/// void dispose() {
///   Throttler.cancel('scroll');
///   super.dispose();
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
/// // Execute immediately, then throttle (default)
/// Throttler.throttle('action', duration, () => print('Immediate'));
///
/// // Queue for execution after interval
/// Throttler.throttle(
///   'action',
///   duration,
///   () => print('Delayed'),
///   immediateCall: false,
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Debouncer], which delays execution until calls stop
/// {@endtemplate}
abstract class Throttler {
  static final Map<String, _ThrottlerOperation> _operations = {};

  /// Throttles execution of [action] for the given [tag].
  ///
  /// {@macro mz_core.Throttler}
  ///
  /// The [tag] parameter uniquely identifies this throttle operation.
  ///
  /// The [duration] parameter specifies the throttle interval. The action
  /// can only execute once per this duration.
  ///
  /// If [immediateCall] is true (default), the action executes immediately
  /// on the first call and subsequent calls are throttled. If multiple calls
  /// occur during the throttle period, only the last action is queued for
  /// execution when the period ends.
  ///
  /// If [immediateCall] is false, the action is queued and will execute
  /// after the throttle interval expires.
  ///
  /// {@tool snippet}
  /// Basic throttling:
  ///
  /// ```dart
  /// // First call executes immediately
  /// Throttler.throttle('test', Duration(seconds: 1), () => print('1'));
  ///
  /// // Subsequent calls within 1 second are throttled
  /// Throttler.throttle('test', Duration(seconds: 1), () => print('2')); // Queued
  /// Throttler.throttle('test', Duration(seconds: 1), () => print('3')); // Replaces
  ///
  /// // After 1 second: prints '3'
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Rate-limiting API calls:
  ///
  /// ```dart
  /// void updateData(Map<String, dynamic> data) {
  ///   Throttler.throttle(
  ///     'api-update',
  ///     const Duration(seconds: 5),
  ///     () async {
  ///       await api.update(data);
  ///       print('Data updated');
  ///     },
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  static void throttle(
    String tag,
    Duration duration,
    VoidCallback action, {
    bool immediateCall = true,
  }) {
    _operations.putIfAbsent(
      tag,
      () {
        return _ThrottlerOperation(duration, () => _operations.remove(tag));
      },
    ).call(action, immediateCall: immediateCall);
  }

  /// Cancels the throttle operation for [tag].
  ///
  /// Clears any queued action and stops the throttle timer.
  /// Future calls with this tag will work normally.
  ///
  /// {@tool snippet}
  /// Cancel throttle operations:
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   Throttler.cancel('scroll');
  ///   super.dispose();
  /// }
  /// ```
  /// {@end-tool}
  static void cancel(String tag) {
    _operations[tag]?.cancel();
    _operations.remove(tag);
  }

  /// Cancels all active throttle operations.
  ///
  /// {@tool snippet}
  /// Cancel all operations:
  ///
  /// ```dart
  /// @override
  /// void dispose() {
  ///   Throttler.cancelAll();
  ///   super.dispose();
  /// }
  /// ```
  /// {@end-tool}
  static void cancelAll() {
    for (final operation in _operations.values) {
      operation.cancel();
    }
    _operations.clear();
  }

  /// Returns the number of active throttle operations.
  static int count() => _operations.length;

  /// Returns whether a throttle operation with [tag] is currently active.
  ///
  /// Returns `true` if there is an active throttle timer for this tag.
  ///
  /// {@tool snippet}
  /// Check if throttle is active:
  ///
  /// ```dart
  /// if (Throttler.isActive('save')) {
  ///   print('Throttling save...');
  /// }
  /// ```
  /// {@end-tool}
  static bool isActive(String tag) => _operations.containsKey(tag);

  /// Returns whether the throttle for [tag] is currently in a throttling
  /// period.
  ///
  /// Returns `true` if the throttle timer is running (calls are being blocked).
  static bool isBusy(String tag) => _operations[tag]?.isBusy ?? false;
}
