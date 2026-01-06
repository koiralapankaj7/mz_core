/// Widget utilities for watching and reacting to controller changes.
///
/// Provides internal watcher classes for integrating controllers with
/// Flutter's widget tree and lifecycle.
library;

import 'dart:async' show scheduleMicrotask;
import 'package:flutter/widgets.dart';
import 'package:mz_utils/src/controller.dart';

/// Internal watcher that uses [WeakReference] to hold the [Element].
///
/// Using [WeakReference] provides automatic memory management - the Element
/// can be garbage collected even if cleanup logic misses it.
class _ControllerWatcher<T extends Controller> {
  _ControllerWatcher(BuildContext context)
      : _elementRef = WeakReference(context as Element);

  final WeakReference<Element> _elementRef;
  T? _controller;
  Object? _watchKey;
  ListenerPredicate? _predicate;
  int _priority = 0;
  VoidCallback? _listener;

  Element? get _element => _elementRef.target;

  bool get mounted {
    final element = _element;
    return element != null && element.mounted;
  }

  void _markNeedsBuild() {
    final element = _element;
    if (element != null && element.mounted) {
      element.markNeedsBuild();
    }
  }

  void attach(
    T controller, {
    Object? key,
    ListenerPredicate? predicate,
    int priority = 0,
  }) {
    if (!mounted) return;
    if (_controller == controller &&
        _watchKey == key &&
        _predicate == predicate &&
        _priority == priority) {
      return; // Already attached with same config
    }

    // Detach old listener
    detach();

    // Setup new listener
    _controller = controller;
    _watchKey = key;
    _predicate = predicate;
    _priority = priority;

    // Create listener callback
    _listener = _markNeedsBuild;

    // Add listener to controller
    controller.addListener(
      _listener!,
      key: key,
      predicate: predicate,
      priority: priority,
    );
  }

  void detach() {
    if (_controller != null && _listener != null && !_controller!.isDisposed) {
      _controller!.removeListener(_listener!, key: _watchKey);
    }
    _controller = null;
    _listener = null;
    _watchKey = null;
    _predicate = null;
    _priority = 0;
  }
}

/// Global registry for controller watchers
///
/// This uses static storage to track watchers without requiring
/// wrapper widgets. Cleanup happens automatically using:
/// - WeakReference for garbage collection safety
/// - scheduleMicrotask for safe async cleanup
/// - mounted checks during notifications
class _WatcherRegistry {
  // Map<Controller, Map<Element, Watcher>>
  static final _watchers = <Controller, Map<Element, _ControllerWatcher>>{};

  // Map<Element, dynamic> - stores previous selected values for select()
  static final _selectedValues = <Element, dynamic>{};

  /// Register a watcher for a controller
  static T watch<T extends Controller>(
    T controller,
    BuildContext context, {
    Object? key,
    ListenerPredicate? predicate,
    int priority = 0,
  }) {
    assert(context.mounted, 'Context must be mounted');

    final element = context as Element;
    final group = _watchers.putIfAbsent(controller, () => {});

    // Get or create watcher for this element and attach to controller
    (group.putIfAbsent(element, () {
      return _ControllerWatcher<T>(context);
    }) as _ControllerWatcher<T>)
        .attach(
      controller,
      key: key,
      predicate: predicate,
      priority: priority,
    );

    // Schedule cleanup check
    scheduleMicrotask(() => _cleanupDeadWatchers(controller));

    return controller;
  }

  /// Clean up watchers for unmounted elements
  static void _cleanupDeadWatchers(Controller controller) {
    final group = _watchers[controller];
    if (group == null || group.isEmpty) return;

    final deadElements = <Element>[];

    for (final entry in group.entries) {
      if (!entry.value.mounted) {
        entry.value.detach();
        deadElements.add(entry.key);
      }
    }

    for (final element in deadElements) {
      group.remove(element);
      _selectedValues.remove(element); // Cleanup selected values too
    }

    // Remove empty groups
    // coverage:ignore-start
    if (group.isEmpty) {
      _watchers.remove(controller);
    }
    // coverage:ignore-end
  }

  /// Get debug info about watchers
  static String debugDescribe() {
    final buffer = StringBuffer('Watcher Registry:\n');
    for (final entry in _watchers.entries) {
      final controller = entry.key;
      final watchers = entry.value;
      final mounted = watchers.values.where((w) => w.mounted).length;
      buffer.writeln(
        '  ${controller.runtimeType}: ${watchers.length} watchers '
        '($mounted mounted)',
      );
    }
    return buffer.toString();
  }

  /// Reset registry (for testing only)
  static void resetForTesting() {
    for (final group in _watchers.values) {
      for (final watcher in group.values) {
        watcher.detach();
      }
    }
    _watchers.clear();
    _selectedValues.clear();
  }
}

/// Internal controller for derived values with auto-dispose support.
///
/// When `autoDispose` is true, this controller automatically disposes itself
/// when all listeners are removed, cleaning up the listener on the source
/// controller.
class _DerivedController<R> extends ValueController<R> {
  _DerivedController(
    super.value, {
    required VoidCallback onDispose,
    required bool autoDispose,
  })  : _onDispose = onDispose,
        _autoDispose = autoDispose;

  final VoidCallback _onDispose;
  final bool _autoDispose;

  @override
  void removeListener(Function listener, {Object? key}) {
    super.removeListener(listener, key: key);
    if (_autoDispose && !hasListeners) {
      // Defer disposal to avoid issues during notification iteration
      // Re-check hasListeners in case a new listener was added before microtask
      scheduleMicrotask(() {
        if (!isDisposed && !hasListeners) dispose();
      });
    }
  }

  @override
  void dispose() {
    if (!isDisposed) _onDispose();
    super.dispose();
  }
}

/// {@template mz_utils.ControllerMZX}
/// Extension on [Controller] providing watch, select, and derive capabilities.
///
/// [ControllerMZX] provides a clean syntax for watching controllers directly
/// in build methods without ControllerBuilder widgets, and for creating
/// derived controllers. Cleanup is automatic using WeakReference.
///
/// ## When to Use
///
/// Use this extension when you want:
/// * Simpler syntax than ControllerBuilder
/// * Automatic cleanup without manual listener management
/// * Key-based selective rebuilds
/// * Predicate-filtered notifications
/// * Derived listenables for state composition
///
/// ## Key Features
///
/// * **No Wrapper Widgets**: Direct controller access in build method
/// * **Automatic Cleanup**: Uses WeakReference for memory safety
/// * **Key Filtering**: Only rebuild for specific keys
/// * **Predicate Support**: Conditional rebuilds
/// * **Priority Control**: Execution order control
/// * **Select Support**: Rebuild only when specific values change
/// * **Derive Support**: Create derived controllers from source state
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Simple watch for automatic rebuilds:
///
/// ```dart
/// class CounterWidget extends StatelessWidget {
///   const CounterWidget({super.key, required this.controller});
///
///   final CounterController controller;
///
///   @override
///   Widget build(BuildContext context) {
///     // Watch controller - rebuilds on any notification
///     final count = controller.watch(context).count;
///     return Text('Count: $count');
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Key-Based Filtering
///
/// {@tool snippet}
/// Only rebuild for specific keys:
///
/// ```dart
/// Widget build(BuildContext context) {
///   // Only rebuilds when 'name' key is notified
///   final name = controller.watch(context, key: 'name').name;
///   return Text('Name: $name');
/// }
/// ```
/// {@end-tool}
///
/// ## Selective Value Updates
///
/// {@tool snippet}
/// Only rebuild when selected value changes:
///
/// ```dart
/// Widget build(BuildContext context) {
///   // Only rebuilds if count value actually changes
///   final count = controller.select(context, (c) => c.count);
///   return Text('Count: $count');
/// }
/// ```
/// {@end-tool}
///
/// ## Predicate Filtering
///
/// {@tool snippet}
/// Conditional rebuilds based on value:
///
/// ```dart
/// Widget build(BuildContext context) {
///   // Only rebuilds when count > 10
///   final data = controller.watch(
///     context,
///     predicate: (key, value) => value is int && value > 10,
///   );
///   return Text('High count: ${data.count}');
/// }
/// ```
/// {@end-tool}
///
/// ## Derived Controllers
///
/// {@tool snippet}
/// Create derived controllers for state composition:
///
/// ```dart
/// final userController = UserController();
/// final nameController = userController.derive((c) => c.user.name);
///
/// // Listen to name changes only
/// nameController.addListener(() {
///   print('Name: ${nameController.value}');
/// });
/// ```
/// {@end-tool}
///
/// ## Performance Tips
///
/// 1. **Use select()** when you only care about specific values in build
/// 2. **Use derive()** when you need a listenable outside build methods
/// 3. **Use key filtering** to reduce unnecessary rebuilds
/// 4. **Use predicates** for conditional logic
/// 5. **Don't mix watch() with ControllerBuilder** in the same widget
///
/// See also:
///
/// * [Controller], the base controller class
/// * [ControllerBuilder], alternative widget-based approach
/// * [ValueController], the type returned by derive()
/// {@endtemplate}
extension ControllerMZX<T extends Controller> on T {
  /// Watch this controller and rebuild the widget when it notifies.
  ///
  /// The widget will automatically rebuild whenever the controller notifies.
  /// Cleanup is automatic using [WeakReference] and mounted checks.
  ///
  /// The [key] parameter filters notifications to only rebuild when that
  /// specific key is notified. The [predicate] parameter provides custom
  /// filtering logic. The [priority] parameter controls the order of listener
  /// execution (higher priority executes first).
  ///
  /// {@tool snippet}
  /// Basic usage - rebuild on any notification:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final count = counterController.watch(context).count;
  ///   return Text('Count: $count');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// With key filtering - only rebuild for specific keys:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   // Only rebuilds when 'count' key is notified
  ///   final value = controller.watch(context, key: 'count').value;
  ///   return Text('Value: $value');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// With predicate - only rebuild when condition is true:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final value = controller.watch(
  ///     context,
  ///     predicate: (key, value) => value is int && value > 10,
  ///   ).value;
  ///   return Text('High value: $value');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// With priority - control rebuild order:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   // Higher priority listeners are notified first
  ///   final value = controller.watch(context, priority: 10).value;
  ///   return Text('Value: $value');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [select], for rebuilding only when a specific value changes
  /// * [derive], for creating a derived [ValueController]
  T watch(
    BuildContext context, {
    Object? key,
    ListenerPredicate? predicate,
    int priority = 0,
  }) {
    return _WatcherRegistry.watch<T>(
      this,
      context,
      key: key,
      predicate: predicate,
      priority: priority,
    );
  }

  /// Watch and select a specific value, rebuilding only when it changes.
  ///
  /// Unlike [watch], which rebuilds on every notification, `select` only
  /// triggers a rebuild when the selected value actually changes. This is
  /// useful for optimizing performance when you only care about a specific
  /// piece of state.
  ///
  /// The [selector] function extracts the value you care about from the
  /// controller. The widget only rebuilds when this value changes.
  ///
  /// The optional [key] parameter filters which notifications are considered.
  /// If provided, only notifications with that key will trigger the selector
  /// comparison.
  ///
  /// {@tool snippet}
  /// Basic usage - only rebuild when count changes:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final count = controller.select(context, (c) => c.count);
  ///   return Text('Count: $count');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// With complex selector - derived value:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   // Only rebuilds when the computed value changes
  ///   final isEven = controller.select(
  ///     context,
  ///     (c) => c.count % 2 == 0,
  ///   );
  ///   return Text(isEven ? 'Even' : 'Odd');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// With key filtering:
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   // Only considers 'user' key notifications
  ///   final userName = controller.select(
  ///     context,
  ///     (c) => c.user.name,
  ///     key: 'user',
  ///   );
  ///   return Text('User: $userName');
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// **Note:** Use [derive] instead if you need a `ValueListenable` outside
  /// of build methods.
  ///
  /// See also:
  ///
  /// * [watch], for rebuilding on every notification
  /// * [derive], for creating a derived [ValueController]
  R select<R>(
    BuildContext context,
    R Function(T controller) selector, {
    Object? key,
  }) {
    final element = context as Element;
    final current = selector(this);

    // Check if we have a stored value
    final isFirst = !_WatcherRegistry._selectedValues.containsKey(element);

    // Watch with predicate that compares against stored value
    watch(
      context,
      key: key,
      predicate: (k, v) {
        final newValue = selector(this);
        // Check if value exists in storage (don't capture isFirst!)
        final hadValue = _WatcherRegistry._selectedValues.containsKey(element);
        final oldValue =
            hadValue ? _WatcherRegistry._selectedValues[element] as R? : null;
        final shouldRebuild = !hadValue || oldValue != newValue;
        _WatcherRegistry._selectedValues[element] = newValue;
        return shouldRebuild;
      },
    );

    // Store initial value
    if (isFirst) {
      _WatcherRegistry._selectedValues[element] = current;
    }

    return current;
  }

  /// Creates a derived [ValueController] that updates when selected value
  /// changes.
  ///
  /// The derived controller automatically updates its value whenever the
  /// result of [selector] applied to this controller changes.
  ///
  /// The [selector] function is called:
  /// - Once immediately to get the initial value
  /// - Every time this controller notifies listeners
  ///
  /// The [distinct] parameter controls when the derived controller notifies:
  /// - `true` (default): Only when the selected value actually changes
  /// - `false`: On every source notification, even if value is the same
  ///
  /// The [autoDispose] parameter controls automatic cleanup:
  /// - `true` (default): Automatically disposes when all listeners are removed
  /// - `false`: User must manually dispose the derived controller
  ///
  /// {@tool snippet}
  /// Use in build methods with autoDispose (default):
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final count = controller.derive((c) => c.count);
  ///   return ValueListenableBuilder<int>(
  ///     valueListenable: count,
  ///     builder: (context, value, _) => Text('$value'),
  ///   );
  /// }
  /// // Auto-disposes when widget unmounts
  /// ```
  /// {@end-tool}
  ///
  /// {@tool snippet}
  /// Manual lifecycle management with autoDispose: false:
  ///
  /// ```dart
  /// class _MyState extends State<MyWidget> {
  ///   late final ValueController<String> emailController;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     emailController = userController.derive(
  ///       (c) => c.user.email,
  ///       autoDispose: false,
  ///     );
  ///   }
  ///
  ///   @override
  ///   void dispose() {
  ///     emailController.dispose();
  ///     super.dispose();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// **vs select():**
  ///
  /// Use derive() when you need a ValueListenable:
  /// ```dart
  /// final derived = controller.derive((c) => c.value);
  /// return ValueListenableBuilder(valueListenable: derived, ...);
  /// ```
  ///
  /// Use select() for direct value access in build:
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   final value = controller.select(context, (c) => c.value);
  ///   return Text('$value');
  /// }
  /// ```
  ///
  /// See also:
  ///
  /// * [select], for optimized rebuilds in build methods
  /// * [ValueController], the returned type
  ValueController<R> derive<R>(
    R Function(T controller) selector, {
    bool distinct = true,
    bool autoDispose = true,
  }) {
    // Create listener that updates derived value
    late final VoidCallback listener;
    late final _DerivedController<R> derived;

    listener = () {
      if (derived.isDisposed) return;
      final newValue = selector(this);
      if (distinct) {
        // Only update if value changed (uses ValueController's comparison)
        derived.onChanged(newValue);
      } else {
        // Force update even if same value
        final oldValue = derived.value;
        if (oldValue != newValue) {
          derived.value = newValue;
        } else {
          // Value is same but we want to notify anyway
          derived.notifyListeners();
        }
      }
    };

    // Create derived controller with cleanup callback
    derived = _DerivedController<R>(
      selector(this),
      onDispose: () => removeListener(listener),
      autoDispose: autoDispose,
    );

    // Add listener to source controller
    addListener(listener);

    return derived;
  }
}

/// Debug utilities for the watcher system
abstract final class WatcherDebug {
  /// Print current state of all watchers (debug mode only)
  static void printWatchers() {
    assert(
      () {
        // Debug output showing all active watchers for troubleshooting
        // ignore: avoid_print
        print(_WatcherRegistry.debugDescribe());
        return true;
      }(),
      'Debug assertion for watcher state output',
    );
  }

  /// Get watcher count for a specific controller
  static int getWatcherCount(Controller controller) {
    final group = _WatcherRegistry._watchers[controller];
    return group?.values.where((w) => w.mounted).length ?? 0;
  }

  /// Get total watcher count across all controllers
  static int getTotalWatcherCount() {
    var count = 0;
    for (final group in _WatcherRegistry._watchers.values) {
      count += group.values.where((w) => w.mounted).length;
    }
    return count;
  }

  /// Get total controller count being watched
  static int getControllerCount() {
    return _WatcherRegistry._watchers.length;
  }

  /// Reset registry - for testing only
  static void resetForTesting() {
    _WatcherRegistry.resetForTesting();
  }
}
