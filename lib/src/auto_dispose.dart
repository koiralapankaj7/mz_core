// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Documentation lines exceed 80 chars for clarity of API examples
// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// {@template mz_core.AutoDisposeMixin}
/// Automatic resource cleanup for StatefulWidget State classes.
///
/// [AutoDisposeMixin] integrates [DisposerMixin]'s automatic cleanup
/// functionality directly into Flutter widgets. It handles listeners,
/// stream subscriptions, and focus nodes automatically when the widget
/// is disposed.
///
/// ## When to Use
///
/// Use [AutoDisposeMixin] when your StatefulWidget needs to:
/// * Listen to ValueNotifier or ChangeNotifier objects
/// * Subscribe to streams
/// * Manage FocusNodes
/// * Avoid manual cleanup in dispose()
///
/// ## Key Features
///
/// * **Automatic setState**: When no listener is provided, calling setState
/// * **Widget Lifecycle Integration**: Cleans up automatically on dispose
/// * **Stream Management**: Tracks and cancels stream subscriptions
/// * **Focus Management**: Tracks and disposes focus nodes
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Automatically rebuild widget when data changes:
///
/// ```dart
/// class CounterWidget extends StatefulWidget {
///   const CounterWidget({super.key, required this.counter});
///
///   final ValueNotifier<int> counter;
///
///   @override
///   State<CounterWidget> createState() => _CounterWidgetState();
/// }
///
/// class _CounterWidgetState extends State<CounterWidget>
///     with AutoDisposeMixin {
///   @override
///   void initState() {
///     super.initState();
///     // Auto-calls setState when counter changes
///     addAutoDisposeListener(widget.counter);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text('Count: ${widget.counter.value}');
///   }
///   // No need to override dispose - cleanup is automatic!
/// }
/// ```
/// {@end-tool}
///
/// ## Custom Listener Callbacks
///
/// {@tool snippet}
/// Provide custom listener logic:
///
/// ```dart
/// class DataWidget extends StatefulWidget {
///   const DataWidget({super.key, required this.data});
///
///   final ValueNotifier<String> data;
///
///   @override
///   State<DataWidget> createState() => _DataWidgetState();
/// }
///
/// class _DataWidgetState extends State<DataWidget>
///     with AutoDisposeMixin {
///   @override
///   void initState() {
///     super.initState();
///     // Custom callback instead of automatic setState
///     addAutoDisposeListener(widget.data, () {
///       print('Data changed: ${widget.data.value}');
///       setState(() {});
///     });
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Text(widget.data.value);
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Stream Subscription Management
///
/// {@tool snippet}
/// Automatically cancel stream subscriptions:
///
/// ```dart
/// class StreamWidget extends StatefulWidget {
///   const StreamWidget({super.key});
///
///   @override
///   State<StreamWidget> createState() => _StreamWidgetState();
/// }
///
/// class _StreamWidgetState extends State<StreamWidget>
///     with AutoDisposeMixin {
///   final _messages = <String>[];
///
///   @override
///   void initState() {
///     super.initState();
///     final subscription = messageStream.listen((msg) {
///       setState(() {
///         _messages.add(msg);
///       });
///     });
///     autoDisposeStreamSubscription(subscription);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListView.builder(
///       itemCount: _messages.length,
///       itemBuilder: (context, index) => Text(_messages[index]),
///     );
///   }
///   // Stream automatically cancelled on dispose!
/// }
/// ```
/// {@end-tool}
///
/// ## FocusNode Management
///
/// {@tool snippet}
/// Automatically dispose focus nodes:
///
/// ```dart
/// class FormWidget extends StatefulWidget {
///   const FormWidget({super.key});
///
///   @override
///   State<FormWidget> createState() => _FormWidgetState();
/// }
///
/// class _FormWidgetState extends State<FormWidget>
///     with AutoDisposeMixin {
///   final _nameFocus = FocusNode();
///   final _emailFocus = FocusNode();
///
///   @override
///   void initState() {
///     super.initState();
///     autoDisposeFocusNode(_nameFocus);
///     autoDisposeFocusNode(_emailFocus);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         TextField(focusNode: _nameFocus),
///         TextField(focusNode: _emailFocus),
///       ],
///     );
///   }
///   // Focus nodes automatically disposed!
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [AutoDisposeControllerMixin], for controller classes
/// * [DisposerMixin], the underlying cleanup implementation
/// {@endtemplate}
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T>
    implements DisposerMixin {
  final _delegate = Disposer();

  @override
  @visibleForTesting
  List<Listenable> get listenables => _delegate.listenables;
  @override
  @visibleForTesting
  List<VoidCallback> get listeners => _delegate.listeners;

  @override
  void dispose() {
    cancelStreamSubscriptions();
    cancelListeners();
    cancelFocusNodes();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Add a listener to a Listenable object that is automatically removed on
  /// the object disposal or when cancel is called.
  ///
  /// If listener is not provided, setState will be invoked.
  @override
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
    String? id,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener ?? _refresh, id);
  }

  @override
  // ignore: avoid_shadowing_type_parameters, false positive
  void callOnceWhenReady<T>({
    required VoidCallback callback,
    required ValueListenable<T> trigger,
    required bool Function(T triggerValue) readyWhen,
  }) {
    _delegate.callOnceWhenReady(
      callback: callback,
      trigger: trigger,
      readyWhen: readyWhen,
    );
  }

  // coverage:ignore-start
  @override
  void autoDisposeStreamSubscription(StreamSubscription<dynamic> subscription) {
    _delegate.autoDisposeStreamSubscription(subscription);
  }
  // coverage:ignore-end

  @override
  void autoDisposeFocusNode(FocusNode? node) {
    _delegate.autoDisposeFocusNode(node);
  }

  @override
  void cancelStreamSubscriptions() {
    _delegate.cancelStreamSubscriptions();
  }

  @override
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    _delegate.cancelListeners(excludeIds: excludeIds);
  }

  @override
  void cancelListener(VoidCallback? listener) {
    _delegate.cancelListener(listener);
  }

  @override
  void cancelFocusNodes() {
    _delegate.cancelFocusNodes();
  }
}

/// {@template mz_core.DisposerMixin}
/// Provides automatic resource cleanup for listeners, streams, and focus nodes.
///
/// [DisposerMixin] solves a common Flutter problem: forgetting to clean up
/// resources when objects are disposed. It automatically tracks all registered
/// resources and cleans them up in one call.
///
/// ## The Problem
///
/// Manual resource cleanup is error-prone:
/// * Easy to forget cleanup calls
/// * Memory leaks from forgotten listeners
/// * Crashes from dangling stream subscriptions
/// * Disposed FocusNodes that were never disposed
///
/// ## The Solution
///
/// [DisposerMixin] provides automatic tracking and cleanup of:
/// * **Listeners** on `Listenable` objects (ValueNotifier, ChangeNotifier)
/// * **Stream subscriptions** that need cancellation
/// * **FocusNodes** that need disposal
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Automatic listener cleanup:
///
/// ```dart
/// class DataService with DisposerMixin {
///   final _controller = ValueNotifier<int>(0);
///
///   DataService() {
///     // Add listener that auto-disposes
///     addAutoDisposeListener(
///       _controller,
///       () => print('Value: ${_controller.value}'),
///     );
///   }
///
///   void dispose() {
///     cancelListeners(); // Removes all listeners automatically
///     _controller.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Stream Subscription Cleanup
///
/// {@tool snippet}
/// Automatic stream subscription cancellation:
///
/// ```dart
/// class EventService with DisposerMixin {
///   final _events = Stream.periodic(
///     const Duration(seconds: 1),
///     (i) => 'Event $i',
///   );
///
///   EventService() {
///     final subscription = _events.listen((event) {
///       print(event);
///     });
///
///     // Register for automatic cancellation
///     autoDisposeStreamSubscription(subscription);
///   }
///
///   void dispose() {
///     cancelStreamSubscriptions(); // Cancels all subscriptions
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## FocusNode Cleanup
///
/// {@tool snippet}
/// Automatic FocusNode disposal:
///
/// ```dart
/// class FormService with DisposerMixin {
///   final _nameFocus = FocusNode();
///   final _emailFocus = FocusNode();
///
///   FormService() {
///     autoDisposeFocusNode(_nameFocus);
///     autoDisposeFocusNode(_emailFocus);
///   }
///
///   void dispose() {
///     cancelFocusNodes(); // Disposes all focus nodes
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Conditional Listener Execution
///
/// {@tool snippet}
/// Run callback when condition is met:
///
/// ```dart
/// class LoadingService with DisposerMixin {
///   final _isReady = ValueNotifier<bool>(false);
///
///   void onReady(VoidCallback callback) {
///     // Callback fires when isReady becomes true
///     callOnceWhenReady(
///       callback: callback,
///       trigger: _isReady,
///       readyWhen: (value) => value == true,
///     );
///   }
///
///   void markReady() {
///     _isReady.value = true; // Triggers callback
///   }
///
///   void dispose() {
///     cancelListeners();
///     _isReady.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [AutoDisposeControllerMixin], which integrates this with controllers
/// * [AutoDisposeMixin], which integrates this with StatefulWidget
/// * [DisposableController], base class for disposable controllers
/// {@endtemplate}
mixin DisposerMixin {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<FocusNode> _focusNodes = [];

  ///
  @protected
  @visibleForTesting
  List<Listenable> get listenables => _listenables;

  /// Not using VoidCallback because of
  /// https://github.com/dart-lang/mockito/issues/579
  @protected
  @visibleForTesting
  List<void Function()> get listeners => _listeners;

  final List<Listenable> _listenables = [];
  final List<VoidCallback> _listeners = [];

  /// An [Expando] that tracks listener ids when [addAutoDisposeListener] is
  /// called with a non-null `id` parameter.
  final _listenerIdExpando = Expando<String>();

  /// Track a stream subscription to be automatically cancelled on dispose.
  void autoDisposeStreamSubscription(StreamSubscription<dynamic> subscription) {
    _subscriptions.add(subscription);
  }

  /// Track a focus node that will be automatically disposed on dispose.
  void autoDisposeFocusNode(FocusNode? node) {
    if (node == null) return;
    _focusNodes.add(node);
  }

  /// Add a listener to a Listenable object that is automatically removed when
  /// cancel is called.
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
    String? id,
  ]) {
    if (listenable == null || listener == null) return;
    _listenables.add(listenable);
    _listeners.add(listener);
    listenable.addListener(listener);

    if (id != null) {
      _listenerIdExpando[listener] = id;
    }
  }

  /// Cancel all stream subscriptions added.
  ///
  /// It is fine to call this method and then add additional subscriptions.
  void cancelStreamSubscriptions() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  /// Cancel all listeners added.
  ///
  /// It is fine to call this method and then add additional listeners.
  ///
  /// If [excludeIds] is non-empty, any listeners that have an associated id
  /// from `_listenerIdExpando` will not be cancelled.
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    assert(_listenables.length == _listeners.length, '');
    final skipCancelIndices = <int>[];
    for (var i = 0; i < _listenables.length; ++i) {
      final listener = _listeners[i];
      final listenerId = _listenerIdExpando[listener];
      if (listenerId != null && excludeIds.contains(listenerId)) {
        skipCancelIndices.add(i);
        continue;
      }

      _listenables[i].removeListener(listener);
    }

    _listenables.removeAllExceptIndices(skipCancelIndices);
    _listeners.removeAllExceptIndices(skipCancelIndices);
  }

  /// Cancels a single listener, if present.
  void cancelListener(VoidCallback? listener) {
    if (listener == null) return;

    assert(_listenables.length == _listeners.length, '');
    final foundIndex = _listeners.indexWhere(
      (currentListener) => currentListener == listener,
    );
    if (foundIndex == -1) return;
    _listenables[foundIndex].removeListener(_listeners[foundIndex]);
    _listenables.removeAt(foundIndex);
    _listeners.removeAt(foundIndex);
  }

  /// Cancel all focus nodes added.
  ///
  /// It is fine to call this method and then add additional focus nodes.
  void cancelFocusNodes() {
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _focusNodes.clear();
  }

  /// Runs [callback] when [trigger]'s value satisfies the [readyWhen] function.
  ///
  /// When calling [callOnceWhenReady] :
  ///     - If [trigger]'s value satisfies [readyWhen], then the [callback] will
  ///       be immediately triggered.
  ///     - Otherwise, the [callback] will be triggered when [trigger]'s value
  ///       changes to equal [readyWhen].
  ///
  /// Any listeners set by [callOnceWhenReady] will auto dispose, or be removed after the callback is run.
  void callOnceWhenReady<T>({
    required VoidCallback callback,
    required ValueListenable<T> trigger,
    required bool Function(T triggerValue) readyWhen,
  }) {
    if (readyWhen(trigger.value)) {
      callback();
    } else {
      VoidCallback? triggerListener;
      triggerListener = () {
        if (readyWhen(trigger.value)) {
          callback();
          trigger.removeListener(triggerListener!);

          _listenables.remove(trigger);
          _listeners.remove(triggerListener);
        }
      };
      addAutoDisposeListener(trigger, triggerListener);
    }
  }
}

/// {@template mz_core.DisposableController}
/// Base class for controllers that need lifecycle management.
///
/// Provides a [dispose] method that should be called when the controller
/// is no longer needed. Subclasses should override [dispose] and call
/// `super.dispose()` to ensure proper cleanup.
///
/// Use [DisposableController] as a base class when creating controllers that:
/// * Manage resources that need cleanup
/// * Work with [AutoDisposeControllerMixin] for automatic cleanup
/// * Follow Flutter's disposal pattern
///
/// {@tool snippet}
/// Create a disposable controller:
///
/// ```dart
/// class UserController extends DisposableController {
///   final _user = ValueNotifier<User?>(null);
///
///   ValueNotifier<User?> get user => _user;
///
///   Future<void> loadUser(String id) async {
///     final userData = await api.fetchUser(id);
///     _user.value = userData;
///   }
///
///   @override
///   void dispose() {
///     _user.dispose();
///     super.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [AutoDisposeControllerMixin], which adds automatic cleanup to controllers
/// * [DisposerMixin], the underlying cleanup implementation
/// {@endtemplate}
abstract class DisposableController {
  /// Dispose of the controller and free any resources.
  ///
  /// Subclasses should override this and call super.dispose() to ensure
  /// proper cleanup in the inheritance chain.
  ///
  /// {@tool snippet}
  /// Override dispose in subclass:
  ///
  /// ```dart
  /// class MyController extends DisposableController {
  ///   final _data = ValueNotifier<String>('');
  ///
  ///   @override
  ///   void dispose() {
  ///     _data.dispose(); // Clean up resources
  ///     super.dispose();  // Call parent dispose
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  @mustCallSuper
  void dispose() {}
}

/// {@template mz_core.AutoDisposeControllerMixin}
/// Automatic resource cleanup for DisposableController classes.
///
/// [AutoDisposeControllerMixin] integrates [DisposerMixin]'s automatic cleanup
/// functionality into controller classes. It handles listeners, stream
/// subscriptions, and focus nodes automatically when the controller is disposed.
///
/// ## When to Use
///
/// Use [AutoDisposeControllerMixin] when your controller needs to:
/// * Listen to other ValueNotifier or ChangeNotifier objects
/// * Subscribe to streams
/// * Manage FocusNodes
/// * Avoid manual cleanup of multiple resources
///
/// ## Key Features
///
/// * **Automatic Cleanup**: All registered resources cleaned up on dispose
/// * **Stream Management**: Tracks and cancels stream subscriptions
/// * **Focus Management**: Tracks and disposes focus nodes
/// * **No Manual Tracking**: Never forget to remove listeners
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Controller with automatic listener cleanup:
///
/// ```dart
/// class UserController extends DisposableController
///     with AutoDisposeControllerMixin {
///   final _settings = ValueNotifier<Settings>(Settings.defaults());
///   final _user = ValueNotifier<User?>(null);
///
///   ValueNotifier<User?> get user => _user;
///
///   UserController() {
///     // Listen to settings changes automatically
///     addAutoDisposeListener(_settings, _onSettingsChanged);
///   }
///
///   void _onSettingsChanged() {
///     // React to settings changes
///     print('Settings updated: ${_settings.value}');
///   }
///
///   @override
///   void dispose() {
///     // Listeners automatically removed
///     _settings.dispose();
///     _user.dispose();
///     super.dispose(); // Calls AutoDisposeControllerMixin.dispose
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Stream Subscription Management
///
/// {@tool snippet}
/// Controller with automatic stream cleanup:
///
/// ```dart
/// class EventController extends DisposableController
///     with AutoDisposeControllerMixin {
///   final _events = <String>[];
///   final _eventStream = Stream.periodic(
///     const Duration(seconds: 1),
///     (i) => 'Event $i',
///   );
///
///   List<String> get events => List.unmodifiable(_events);
///
///   EventController() {
///     final subscription = _eventStream.listen((event) {
///       _events.add(event);
///     });
///     // Register for automatic cancellation
///     autoDisposeStreamSubscription(subscription);
///   }
///
///   @override
///   void dispose() {
///     // Stream automatically cancelled
///     super.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Multiple Resource Types
///
/// {@tool snippet}
/// Controller managing multiple resource types:
///
/// ```dart
/// class FormController extends DisposableController
///     with AutoDisposeControllerMixin {
///   final _nameFocus = FocusNode();
///   final _emailFocus = FocusNode();
///   final _formData = ValueNotifier<Map<String, String>>({});
///   final _validationStream = Stream<ValidationResult>.empty();
///
///   FormController() {
///     // Register focus nodes
///     autoDisposeFocusNode(_nameFocus);
///     autoDisposeFocusNode(_emailFocus);
///
///     // Register stream subscription
///     final sub = _validationStream.listen(_handleValidation);
///     autoDisposeStreamSubscription(sub);
///
///     // Register listener
///     addAutoDisposeListener(_formData, _onFormDataChanged);
///   }
///
///   void _handleValidation(ValidationResult result) {
///     // Handle validation
///   }
///
///   void _onFormDataChanged() {
///     // React to form changes
///   }
///
///   @override
///   void dispose() {
///     // All resources automatically cleaned up!
///     _formData.dispose();
///     super.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Conditional Callbacks
///
/// {@tool snippet}
/// Execute callback when condition is met:
///
/// ```dart
/// class LoadingController extends DisposableController
///     with AutoDisposeControllerMixin {
///   final _isReady = ValueNotifier<bool>(false);
///   final _data = ValueNotifier<String?>(null);
///
///   LoadingController() {
///     // Wait for ready state before loading data
///     callOnceWhenReady(
///       callback: _loadData,
///       trigger: _isReady,
///       readyWhen: (ready) => ready,
///     );
///   }
///
///   void _loadData() {
///     // Load data once ready
///     _data.value = 'Loaded!';
///   }
///
///   void markReady() {
///     _isReady.value = true; // Triggers callback
///   }
///
///   @override
///   void dispose() {
///     _isReady.dispose();
///     _data.dispose();
///     super.dispose();
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [AutoDisposeMixin], for StatefulWidget State classes
/// * [DisposerMixin], the underlying cleanup implementation
/// * [DisposableController], base class for disposable controllers
/// {@endtemplate}
mixin AutoDisposeControllerMixin on DisposableController
    implements DisposerMixin {
  final _delegate = Disposer();

  @override
  @visibleForTesting
  List<Listenable> get listenables => _delegate.listenables;

  /// Not using VoidCallback because of
  /// https://github.com/dart-lang/mockito/issues/579
  @override
  @visibleForTesting
  List<void Function()> get listeners => _delegate.listeners;

  @override
  void dispose() {
    cancelStreamSubscriptions();
    cancelListeners();
    cancelFocusNodes();
    super.dispose();
  }

  @override
  void addAutoDisposeListener(
    Listenable? listenable, [
    VoidCallback? listener,
    String? id,
  ]) {
    _delegate.addAutoDisposeListener(listenable, listener, id);
  }

  @override
  void autoDisposeStreamSubscription(StreamSubscription<dynamic> subscription) {
    _delegate.autoDisposeStreamSubscription(subscription);
  }

  @override
  void autoDisposeFocusNode(FocusNode? node) {
    _delegate.autoDisposeFocusNode(node);
  }

  @override
  void cancelStreamSubscriptions() {
    _delegate.cancelStreamSubscriptions();
  }

  @override
  void cancelListeners({List<String> excludeIds = const <String>[]}) {
    _delegate.cancelListeners(excludeIds: excludeIds);
  }

  @override
  void cancelListener(VoidCallback? listener) {
    _delegate.cancelListener(listener);
  }

  @override
  void cancelFocusNodes() {
    _delegate.cancelFocusNodes();
  }

  @override
  void callOnceWhenReady<T>({
    required VoidCallback callback,
    required ValueListenable<T> trigger,
    required bool Function(T triggerValue) readyWhen,
  }) {
    _delegate.callOnceWhenReady(
      callback: callback,
      trigger: trigger,
      readyWhen: readyWhen,
    );
  }
}

/// Internal disposer implementation for testing purposes.
///
/// This class provides a concrete implementation of [DisposerMixin] that can be
/// used in tests to verify disposal behavior.
@visibleForTesting
class Disposer with DisposerMixin {}

extension _AutoDisposeListExtension<T> on List<T> {
  /// Reduces the list content to include only elements at [indices].
  ///
  /// If any index in [indices] is out of range, an exception will be thrown.
  void removeAllExceptIndices(List<int> indices) {
    final tmp = [
      for (final index in indices) this[index],
    ];
    clear();
    addAll(tmp);
  }
}
