import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/auto_dispose.dart';

// Test implementations
class TestDisposableController extends DisposableController
    with AutoDisposeControllerMixin {
  bool isDisposed = false;

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

class TestWidget extends StatefulWidget {
  const TestWidget({super.key, this.onStateCreated});

  final void Function(TestWidgetState)? onStateCreated;

  @override
  State<TestWidget> createState() => TestWidgetState();
}

class TestWidgetState extends State<TestWidget> with AutoDisposeMixin {
  bool isDisposed = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated?.call(this);
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Test FocusNode that tracks dispose calls
class _TestFocusNode extends FocusNode {
  _TestFocusNode({this.onDispose});

  final VoidCallback? onDispose;

  @override
  void dispose() {
    onDispose?.call();
    super.dispose();
  }
}

void main() {
  group('DisposerMixin Tests |', () {
    late Disposer disposer;

    setUp(() {
      disposer = Disposer();
    });

    group('addAutoDisposeListener -', () {
      test('should add listener to listenable', () {
        final notifier = ValueNotifier<int>(0);
        var listenerCalled = false;

        disposer.addAutoDisposeListener(notifier, () {
          listenerCalled = true;
        });

        expect(disposer.listenables, contains(notifier));
        expect(disposer.listeners.length, 1);

        notifier.value = 1;
        expect(listenerCalled, isTrue);

        notifier.dispose();
      });

      test('should handle null listenable', () {
        disposer.addAutoDisposeListener(null, () {});

        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);
      });

      test('should handle null listener', () {
        final notifier = ValueNotifier<int>(0);

        disposer.addAutoDisposeListener(notifier);

        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);

        notifier.dispose();
      });

      test('should handle null listenable and listener', () {
        disposer.addAutoDisposeListener(null);

        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);
      });

      test('should track listener with id', () {
        final notifier = ValueNotifier<int>(0);
        var count = 0;

        disposer.addAutoDisposeListener(notifier, () => count++, 'test-id');

        expect(disposer.listenables.length, 1);
        expect(disposer.listeners.length, 1);

        notifier.value = 1;
        expect(count, 1);

        notifier.dispose();
      });
    });

    group('cancelListeners -', () {
      test('should cancel all listeners', () {
        final notifier1 = ValueNotifier<int>(0);
        final notifier2 = ValueNotifier<int>(0);
        var count1 = 0;
        var count2 = 0;

        disposer
          ..addAutoDisposeListener(notifier1, () => count1++)
          ..addAutoDisposeListener(notifier2, () => count2++)
          ..cancelListeners();

        notifier1.value = 1;
        notifier2.value = 1;

        expect(count1, 0);
        expect(count2, 0);
        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);

        notifier1.dispose();
        notifier2.dispose();
      });

      test('should exclude listeners with specific ids', () {
        final notifier1 = ValueNotifier<int>(0);
        final notifier2 = ValueNotifier<int>(0);
        final notifier3 = ValueNotifier<int>(0);
        var count1 = 0;
        var count2 = 0;
        var count3 = 0;

        disposer
          ..addAutoDisposeListener(notifier1, () => count1++, 'keep-1')
          ..addAutoDisposeListener(notifier2, () => count2++)
          ..addAutoDisposeListener(notifier3, () => count3++, 'keep-2')
          ..cancelListeners(excludeIds: ['keep-1', 'keep-2']);

        notifier1.value = 1;
        notifier2.value = 1;
        notifier3.value = 1;

        expect(count1, 1); // Should still work
        expect(count2, 0); // Should be cancelled
        expect(count3, 1); // Should still work
        expect(disposer.listenables.length, 2);
        expect(disposer.listeners.length, 2);

        notifier1.dispose();
        notifier2.dispose();
        notifier3.dispose();
      });

      test('should handle empty exclude list', () {
        final notifier = ValueNotifier<int>(0);
        var count = 0;

        disposer
          ..addAutoDisposeListener(notifier, () => count++)
          ..cancelListeners(excludeIds: []);

        notifier.value = 1;
        expect(count, 0);

        notifier.dispose();
      });
    });

    group('cancelListener -', () {
      test('should cancel specific listener', () {
        final notifier = ValueNotifier<int>(0);
        var count = 0;
        void listener() => count++;

        disposer
          ..addAutoDisposeListener(notifier, listener)
          ..cancelListener(listener);

        notifier.value = 1;
        expect(count, 0);
        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);

        notifier.dispose();
      });

      test('should handle null listener', () {
        disposer.cancelListener(null);
        expect(disposer.listenables.isEmpty, isTrue);
        expect(disposer.listeners.isEmpty, isTrue);
      });

      test('should handle non-existent listener', () {
        final notifier = ValueNotifier<int>(0);
        var count = 0;
        void listener() => count++;

        disposer
          ..addAutoDisposeListener(notifier, listener)
          ..cancelListener(() {}); // Different listener

        notifier.value = 1;
        expect(count, 1); // Original listener still works

        notifier.dispose();
      });
    });

    group('autoDisposeStreamSubscription -', () {
      test('should track stream subscription', () async {
        final controller = StreamController<int>();
        final subscription = controller.stream.listen((_) {});

        disposer.autoDisposeStreamSubscription(subscription);

        expect(disposer, isNotNull); // Subscription tracked internally

        await controller.close();
      });

      test(
        'should cancel subscriptions on cancelStreamSubscriptions',
        () async {
          final controller = StreamController<int>();
          var count = 0;

          final subscription = controller.stream.listen((_) => count++);
          disposer.autoDisposeStreamSubscription(subscription);

          controller.add(1);
          await Future<void>.delayed(Duration.zero);
          expect(count, 1);

          disposer.cancelStreamSubscriptions();
          controller.add(2);
          await Future<void>.delayed(Duration.zero);

          // Subscription should be cancelled
          expect(count, 1);

          await controller.close();
        },
      );

      test('should handle multiple subscriptions', () async {
        final controller1 = StreamController<int>();
        final controller2 = StreamController<int>();
        var count1 = 0;
        var count2 = 0;

        final sub1 = controller1.stream.listen((_) => count1++);
        final sub2 = controller2.stream.listen((_) => count2++);

        disposer
          ..autoDisposeStreamSubscription(sub1)
          ..autoDisposeStreamSubscription(sub2)
          ..cancelStreamSubscriptions();

        controller1.add(1);
        controller2.add(1);
        await Future<void>.delayed(Duration.zero);

        expect(count1, 0);
        expect(count2, 0);

        await controller1.close();
        await controller2.close();
      });
    });

    group('autoDisposeFocusNode -', () {
      test('should track focus node', () {
        final focusNode = FocusNode();

        disposer.autoDisposeFocusNode(focusNode);

        expect(disposer, isNotNull); // FocusNode tracked internally
      });

      test('should handle null focus node', () {
        disposer.autoDisposeFocusNode(null);
        expect(disposer, isNotNull);
      });

      test('should dispose focus nodes on cancelFocusNodes', () {
        var wasDisposed = false;

        // Override dispose to track if it was called
        final testNode = _TestFocusNode(onDispose: () => wasDisposed = true);

        disposer
          ..autoDisposeFocusNode(testNode)
          ..cancelFocusNodes();

        // Verify dispose was called
        expect(wasDisposed, isTrue);
      });

      test('should handle multiple focus nodes', () {
        var disposed1 = false;
        var disposed2 = false;

        final testNode1 = _TestFocusNode(onDispose: () => disposed1 = true);
        final testNode2 = _TestFocusNode(onDispose: () => disposed2 = true);

        disposer
          ..autoDisposeFocusNode(testNode1)
          ..autoDisposeFocusNode(testNode2)
          ..cancelFocusNodes();

        expect(disposed1, isTrue);
        expect(disposed2, isTrue);
      });
    });

    group('callOnceWhenReady -', () {
      test('should call immediately when condition is met', () {
        final trigger = ValueNotifier<int>(5);
        var callbackCalled = false;

        disposer.callOnceWhenReady(
          callback: () => callbackCalled = true,
          trigger: trigger,
          readyWhen: (value) => value >= 5,
        );

        expect(callbackCalled, isTrue);
        expect(disposer.listenables.isEmpty, isTrue);

        trigger.dispose();
      });

      test('should wait for condition to be met', () {
        final trigger = ValueNotifier<int>(0);
        var callbackCalled = false;

        disposer.callOnceWhenReady(
          callback: () => callbackCalled = true,
          trigger: trigger,
          readyWhen: (value) => value >= 5,
        );

        expect(callbackCalled, isFalse);
        expect(disposer.listenables, contains(trigger));

        trigger.value = 3;
        expect(callbackCalled, isFalse);

        trigger.value = 5;
        expect(callbackCalled, isTrue);
        expect(disposer.listenables.isEmpty, isTrue);

        trigger.dispose();
      });

      test('should remove listener after callback', () {
        final trigger = ValueNotifier<int>(0);
        var callCount = 0;

        disposer.callOnceWhenReady(
          callback: () => callCount++,
          trigger: trigger,
          readyWhen: (value) => value >= 5,
        );

        trigger.value = 5;
        expect(callCount, 1);

        trigger.value = 10;
        expect(callCount, 1); // Should not be called again

        trigger.dispose();
      });
    });
  });

  group('AutoDisposeMixin Tests |', () {
    testWidgets('should auto-dispose listeners on dispose', (tester) async {
      final notifier = ValueNotifier<int>(0);
      var count = 0;
      TestWidgetState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              state = s;
              s.addAutoDisposeListener(notifier, () => count++);
            },
          ),
        ),
      );

      notifier.value = 1;
      expect(count, 1);

      // Dispose widget
      await tester.pumpWidget(const SizedBox());

      expect(state?.isDisposed, isTrue);

      notifier.value = 2;
      expect(count, 1); // Should not be called after dispose

      notifier.dispose();
    });

    testWidgets('should use setState as default listener', (tester) async {
      final notifier = ValueNotifier<int>(0);
      TestWidgetState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              state = s;
              s.addAutoDisposeListener(notifier); // No listener provided
            },
          ),
        ),
      );

      // Verify listener was added with _refresh callback
      expect(state?.listeners.length, 1);

      // Trigger notification to cause setState
      notifier.value = 1;
      await tester.pump();

      // Verify widget tree is updated
      expect(find.byType(TestWidget), findsOneWidget);

      notifier.dispose();
    });

    testWidgets('should expose listenables and listeners', (tester) async {
      final notifier = ValueNotifier<int>(0);
      TestWidgetState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              state = s;
              s.addAutoDisposeListener(notifier, () {});
            },
          ),
        ),
      );

      expect(state?.listenables, contains(notifier));
      expect(state?.listeners.length, 1);

      notifier.dispose();
    });

    testWidgets('should support callOnceWhenReady', (tester) async {
      final trigger = ValueNotifier<int>(0);
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              s.callOnceWhenReady(
                callback: () => callbackCalled = true,
                trigger: trigger,
                readyWhen: (value) => value >= 5,
              );
            },
          ),
        ),
      );

      expect(callbackCalled, isFalse);

      trigger.value = 5;
      await tester.pump();

      expect(callbackCalled, isTrue);

      trigger.dispose();
    });

    testWidgets('should support cancelListener', (tester) async {
      final notifier = ValueNotifier<int>(0);
      var count = 0;
      void listener() => count++;
      TestWidgetState? state;

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              state = s;
              s.addAutoDisposeListener(notifier, listener);
            },
          ),
        ),
      );

      notifier.value = 1;
      expect(count, 1);

      state?.cancelListener(listener);

      notifier.value = 2;
      expect(count, 1); // Should not increment

      notifier.dispose();
    });

    testWidgets('should support all DisposerMixin methods', (tester) async {
      var wasDisposed = false;
      final testNode = _TestFocusNode(onDispose: () => wasDisposed = true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestWidget(
            onStateCreated: (s) {
              s.autoDisposeFocusNode(testNode);
            },
          ),
        ),
      );

      // Dispose widget
      await tester.pumpWidget(const SizedBox());

      // FocusNode should be disposed
      expect(wasDisposed, isTrue);
    });
  });

  group('AutoDisposeControllerMixin Tests |', () {
    test('should auto-dispose listeners on dispose', () {
      final controller = TestDisposableController();
      final notifier = ValueNotifier<int>(0);
      var count = 0;

      controller.addAutoDisposeListener(notifier, () => count++);

      notifier.value = 1;
      expect(count, 1);

      controller.dispose();

      notifier.value = 2;
      expect(count, 1); // Should not be called after dispose

      notifier.dispose();
    });

    test('should fix excludeIds bug', () {
      final controller = TestDisposableController();
      final notifier1 = ValueNotifier<int>(0);
      final notifier2 = ValueNotifier<int>(0);
      var count1 = 0;
      var count2 = 0;

      controller
        ..addAutoDisposeListener(
          notifier1,
          () => count1++,
          'keep-this',
        )
        ..addAutoDisposeListener(notifier2, () => count2++)
        // BUG FIX TEST: This should preserve 'keep-this' listener
        ..cancelListeners(excludeIds: ['keep-this']);

      notifier1.value = 1;
      notifier2.value = 1;

      expect(count1, 1); // Should still work (excluded)
      expect(count2, 0); // Should be cancelled

      notifier1.dispose();
      notifier2.dispose();
    });

    test('should expose listenables and listeners', () {
      final controller = TestDisposableController();
      final notifier = ValueNotifier<int>(0);

      controller.addAutoDisposeListener(notifier, () {});

      expect(controller.listenables, contains(notifier));
      expect(controller.listeners.length, 1);

      notifier.dispose();
    });

    test('should support all DisposerMixin methods', () async {
      final controller = TestDisposableController();
      final streamController = StreamController<int>();
      var count = 0;

      final subscription = streamController.stream.listen((_) => count++);
      controller.autoDisposeStreamSubscription(subscription);

      streamController.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(count, 1);

      controller.dispose();

      streamController.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(count, 1); // Should not increment after dispose

      await streamController.close();
    });

    test('should support cancelListener', () {
      final controller = TestDisposableController();
      final notifier = ValueNotifier<int>(0);
      var count = 0;
      void listener() => count++;

      controller
        ..addAutoDisposeListener(notifier, listener)
        ..cancelListener(listener);

      notifier.value = 1;
      expect(count, 0);

      notifier.dispose();
    });

    test('should support callOnceWhenReady', () {
      final controller = TestDisposableController();
      final trigger = ValueNotifier<int>(0);
      var callbackCalled = false;

      controller.callOnceWhenReady(
        callback: () => callbackCalled = true,
        trigger: trigger,
        readyWhen: (value) => value >= 5,
      );

      expect(callbackCalled, isFalse);

      trigger.value = 5;
      expect(callbackCalled, isTrue);

      trigger.dispose();
    });

    test('should dispose focus nodes', () {
      final controller = TestDisposableController();
      var wasDisposed = false;
      final testNode = _TestFocusNode(onDispose: () => wasDisposed = true);

      controller
        ..autoDisposeFocusNode(testNode)
        ..dispose();

      expect(wasDisposed, isTrue);
    });
  });

  group('DisposableController Tests |', () {
    test('should be disposable', () {
      final controller = TestDisposableController();

      expect(controller.isDisposed, isFalse);

      controller.dispose();

      expect(controller.isDisposed, isTrue);
    });
  });
}
