import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mz_utils/src/controller.dart';
import 'package:mz_utils/src/controller_watcher.dart';

class TestController extends Controller {
  int count = 0;

  void increment() {
    count++;
    notifyListeners();
  }

  void incrementWithKey(String key) {
    count++;
    notifyListeners(key: key);
  }
}

void main() {
  group('Controller Watcher Tests |', () {
    group('Basic Watch Functionality -', () {
      testWidgets('should rebuild widget when controller notifies', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context);
                buildCount++;
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        expect(buildCount, 1);
        expect(find.text('Count: 0'), findsOneWidget);

        // Notify controller
        controller.increment();
        await tester.pump();

        expect(buildCount, 2);
        expect(find.text('Count: 1'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('should not rebuild after widget disposal', (tester) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context);
                buildCount++;
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Remove widget
        await tester.pumpWidget(const SizedBox());

        // Notify should not cause rebuild (widget disposed)
        final initialBuildCount = buildCount;
        controller.increment();
        await tester.pump();

        expect(buildCount, initialBuildCount);

        controller.dispose();
      });

      testWidgets('should handle multiple watchers on same controller', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount1 = 0;
        var buildCount2 = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    controller.watch(context);
                    buildCount1++;
                    return Text('Widget 1: ${controller.count}');
                  },
                ),
                Builder(
                  builder: (context) {
                    controller.watch(context);
                    buildCount2++;
                    return Text('Widget 2: ${controller.count}');
                  },
                ),
              ],
            ),
          ),
        );

        expect(buildCount1, 1);
        expect(buildCount2, 1);

        controller.increment();
        await tester.pump();

        expect(buildCount1, 2);
        expect(buildCount2, 2);

        controller.dispose();
      });
    });

    group('Watch with Key -', () {
      testWidgets('should only rebuild when matching key is notified', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context, key: 'count');
                buildCount++;
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Notify with wrong key
        controller.notifyListeners(key: 'other');
        await tester.pump();

        expect(buildCount, 1); // No rebuild

        // Notify with matching key
        controller.incrementWithKey('count');
        await tester.pump();

        expect(buildCount, 2); // Rebuilt

        controller.dispose();
      });

      testWidgets('should handle key change', (tester) async {
        final controller = TestController();
        var buildCount = 0;
        var currentKey = 'key1';

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                controller.watch(context, key: currentKey);
                buildCount++;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentKey = 'key2';
                    });
                  },
                  child: Text('Count: ${controller.count}'),
                );
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Notify with key1
        controller.incrementWithKey('key1');
        await tester.pump();

        expect(buildCount, 2);

        // Change key to key2
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(buildCount, 3); // Rebuild due to setState

        // Notify with key1 (old key) - should not rebuild
        controller.incrementWithKey('key1');
        await tester.pump();

        expect(buildCount, 3); // No rebuild

        // Notify with key2 (new key) - should rebuild
        controller.incrementWithKey('key2');
        await tester.pump();

        expect(buildCount, 4); // Rebuilt

        controller.dispose();
      });
    });

    group('Watch with Predicate -', () {
      testWidgets('should only rebuild when predicate returns true', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(
                  context,
                  predicate: (key, value) => controller.count > 2,
                );
                buildCount++;
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // count = 1 (predicate false)
        controller.increment();
        await tester.pump();

        expect(buildCount, 1); // No rebuild

        // count = 2 (predicate false)
        controller.increment();
        await tester.pump();

        expect(buildCount, 1); // No rebuild

        // count = 3 (predicate true)
        controller.increment();
        await tester.pump();

        expect(buildCount, 2); // Rebuilt!

        controller.dispose();
      });
    });

    group('Watch with Priority -', () {
      testWidgets('should respect priority order', (tester) async {
        final controller = TestController();
        final callOrder = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    controller.watch(context, priority: 10);
                    callOrder.add('high');
                    return const Text('High');
                  },
                ),
                Builder(
                  builder: (context) {
                    controller.watch(context);
                    callOrder.add('normal');
                    return const Text('Normal');
                  },
                ),
                Builder(
                  builder: (context) {
                    controller.watch(context, priority: -10);
                    callOrder.add('low');
                    return const Text('Low');
                  },
                ),
              ],
            ),
          ),
        );

        callOrder.clear();

        controller.increment();
        await tester.pump();

        // Priority order: high (10), normal (0), low (-10)
        expect(callOrder, ['high', 'normal', 'low']);

        controller.dispose();
      });
    });

    group('Select -', () {
      testWidgets('should only rebuild when selected value changes', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;
        var selectedValue = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                selectedValue = controller.select(context, (c) => c.count ~/ 2);
                buildCount++;
                return Text('Selected: $selectedValue');
              },
            ),
          ),
        );

        expect(buildCount, 1);
        expect(selectedValue, 0);

        // count = 1, selected = 0 (no change)
        controller.increment();
        await tester.pump();

        expect(buildCount, 1); // No rebuild
        expect(selectedValue, 0);

        // count = 2, selected = 1 (changed!)
        controller.increment();
        await tester.pump();

        expect(buildCount, 2); // Rebuilt
        expect(selectedValue, 1);

        // count = 3, selected = 1 (no change)
        controller.increment();
        await tester.pump();

        expect(buildCount, 2); // No rebuild
        expect(selectedValue, 1);

        controller.dispose();
      });

      testWidgets('should work with complex selector', (tester) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final isEven = controller.select(
                  context,
                  (c) => c.count.isEven,
                );
                buildCount++;
                return Text('Is Even: $isEven');
              },
            ),
          ),
        );

        expect(buildCount, 1);
        expect(find.text('Is Even: true'), findsOneWidget);

        // count = 1 (odd, changed)
        controller.increment();
        await tester.pump();

        expect(buildCount, 2);
        expect(find.text('Is Even: false'), findsOneWidget);

        // count = 2 (even, changed)
        controller.increment();
        await tester.pump();

        expect(buildCount, 3);
        expect(find.text('Is Even: true'), findsOneWidget);

        controller.dispose();
      });
    });

    group('Cleanup and Memory -', () {
      testWidgets('should cleanup watchers when widget is removed', (
        tester,
      ) async {
        final controller = TestController();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context);
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        // Widget exists
        expect(find.byType(Text), findsOneWidget);

        // Remove widget
        await tester.pumpWidget(const SizedBox());

        // Allow microtask cleanup
        await tester.pump(Duration.zero);

        // Controller should still work without crashes
        controller
          ..increment()
          ..dispose();
      });

      testWidgets('should handle rapid mount/unmount cycles', (tester) async {
        final controller = TestController();

        for (var i = 0; i < 10; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) {
                  controller.watch(context);
                  return Text('Count: ${controller.count}');
                },
              ),
            ),
          );

          await tester.pumpWidget(const SizedBox());
          await tester.pump(Duration.zero);
        }

        // Should not crash
        controller
          ..increment()
          ..dispose();
      });
    });

    group('WatcherDebug -', () {
      test('should track watcher count', () {
        // Reset registry before this test to ensure clean state
        WatcherDebug.resetForTesting();

        final controller = TestController();

        expect(WatcherDebug.getWatcherCount(controller), 0);
        expect(WatcherDebug.getTotalWatcherCount(), 0);
        expect(WatcherDebug.getControllerCount(), 0);

        // Note: Can't test watch() without BuildContext in unit test
        // These methods are tested in widget tests above

        controller.dispose();
      });

      test('should print watchers in debug mode', WatcherDebug.printWatchers);

      testWidgets('should track watchers with mounted widgets', (tester) async {
        WatcherDebug.resetForTesting();
        final controller = TestController();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context);
                return const Text('Test');
              },
            ),
          ),
        );

        // Watcher should be tracked
        expect(WatcherDebug.getWatcherCount(controller), 1);
        expect(WatcherDebug.getTotalWatcherCount(), 1);
        expect(WatcherDebug.getControllerCount(), 1);

        // Call printWatchers to test debugDescribe with actual watchers
        // This should cover lines 158-162
        WatcherDebug.printWatchers();

        controller.dispose();
      });

      testWidgets('should cleanup dead watchers', (tester) async {
        WatcherDebug.resetForTesting();
        final controller1 = TestController();

        // Add multiple watchers
        await tester.pumpWidget(
          MaterialApp(
            home: Column(
              children: [
                Builder(
                  builder: (context) {
                    controller1.watch(context);
                    return const Text('Test1A');
                  },
                ),
                Builder(
                  builder: (context) {
                    controller1.watch(context);
                    return const Text('Test1B');
                  },
                ),
              ],
            ),
          ),
        );

        expect(WatcherDebug.getWatcherCount(controller1), 2);

        // Remove all widgets
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();

        // Watchers should still be tracked but unmounted
        // Cleanup happens when watch() is called again
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller1.watch(context);
                return const Text('Test2');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Old watchers should be cleaned up, only new one remains
        expect(WatcherDebug.getWatcherCount(controller1), 1);

        controller1.dispose();
      });
    });

    group('Edge Cases -', () {
      testWidgets('should handle same controller watched multiple times', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                // Watch same controller twice
                controller
                  ..watch(context)
                  ..watch(context); // Should be idempotent
                buildCount++;
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        controller.increment();
        await tester.pump();

        // Should only rebuild once despite double watch
        expect(buildCount, 2);

        controller.dispose();
      });

      testWidgets('should handle controller disposal while watched', (
        tester,
      ) async {
        final controller = TestController();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                controller.watch(context);
                return Text('Count: ${controller.count}');
              },
            ),
          ),
        );

        // Dispose controller while widget is still mounted
        controller.dispose();

        // Should not crash
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('should handle re-watching with different config', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;
        var useKey = false;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                if (useKey) {
                  controller.watch(context, key: 'test');
                } else {
                  controller.watch(context);
                }
                buildCount++;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      useKey = !useKey;
                    });
                  },
                  child: Text('Count: ${controller.count}'),
                );
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Global notify - should rebuild
        controller.increment();
        await tester.pump();

        expect(buildCount, 2);

        // Change to key-based watch
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(buildCount, 3);

        // Global notify - should NOT rebuild (now watching with key)
        controller.increment();
        await tester.pump();

        expect(buildCount, 3); // No rebuild

        // Key-based notify - should rebuild
        controller.incrementWithKey('test');
        await tester.pump();

        expect(buildCount, 4); // Rebuilt

        controller.dispose();
      });
    });

    group('Derive Functionality -', () {
      test('should create derived controller with initial value', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        expect(derived.value, 0);
        expect(derived, isA<ValueController<int>>());

        controller.dispose();
        derived.dispose();
      });

      test('should update derived value when source changes', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        expect(derived.value, 0);

        controller.increment();
        expect(derived.value, 1);

        controller.increment();
        expect(derived.value, 2);

        controller.dispose();
        derived.dispose();
      });

      test('should notify listeners when derived value changes', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        expect(notifyCount, 0);

        controller.increment();
        expect(notifyCount, 1);

        controller.increment();
        expect(notifyCount, 2);

        controller.dispose();
        derived.dispose();
      });

      test('should not notify when value does not change (distinct mode)', () {
        final controller = TestController();
        // Derive a value that stays the same
        final derived = controller.derive((c) => c.count > 0);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        expect(derived.value, false);
        expect(notifyCount, 0);

        // First increment: false -> true (should notify)
        controller.increment();
        expect(derived.value, true);
        expect(notifyCount, 1);

        // Second increment: true -> true (should NOT notify)
        controller.increment();
        expect(derived.value, true);
        expect(notifyCount, 1); // Still 1

        controller.dispose();
        derived.dispose();
      });

      test('should notify on every change when distinct is false', () {
        final controller = TestController();
        // Derive with distinct: false
        final derived = controller.derive(
          (c) => c.count > 0,
          distinct: false,
        );

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        expect(derived.value, false);
        expect(notifyCount, 0);

        // First increment: false -> true (should notify)
        controller.increment();
        expect(derived.value, true);
        expect(notifyCount, 1);

        // Second increment: true -> true (should STILL notify)
        controller.increment();
        expect(derived.value, true);
        expect(notifyCount, 2); // Notified again

        controller.dispose();
        derived.dispose();
      });

      test('should handle complex transformations', () {
        final controller = TestController();
        final derived = controller.derive((c) => 'Count: ${c.count}');

        expect(derived.value, 'Count: 0');

        controller.increment();
        expect(derived.value, 'Count: 1');

        controller.increment();
        expect(derived.value, 'Count: 2');

        controller.dispose();
        derived.dispose();
      });

      test('should handle multiple derived controllers from same source', () {
        final controller = TestController();
        final derived1 = controller.derive((c) => c.count);
        final derived2 = controller.derive((c) => c.count * 2);
        final derived3 = controller.derive((c) => c.count > 5);

        expect(derived1.value, 0);
        expect(derived2.value, 0);
        expect(derived3.value, false);

        controller
          ..count = 10
          ..notifyListeners();

        expect(derived1.value, 10);
        expect(derived2.value, 20);
        expect(derived3.value, true);

        controller.dispose();
        derived1.dispose();
        derived2.dispose();
        derived3.dispose();
      });

      test('should track previous value in derived controller', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        expect(derived.prevValue, isNull);
        expect(derived.hasPrevValue, false);

        controller.increment();
        expect(derived.value, 1);
        expect(derived.prevValue, 0);
        expect(derived.hasPrevValue, true);

        controller.increment();
        expect(derived.value, 2);
        expect(derived.prevValue, 1);

        controller.dispose();
        derived.dispose();
      });

      test('should handle nullable derived values', () {
        final controller = TestController();
        final derived = controller.derive<int?>(
          (c) => c.count == 0 ? null : c.count,
        );

        expect(derived.value, isNull);

        controller.increment();
        expect(derived.value, 1);

        controller
          ..count = 0
          ..notifyListeners();
        expect(derived.value, isNull);

        controller.dispose();
        derived.dispose();
      });

      test('should handle objects as derived values', () {
        final controller = TestController();
        final derived = controller.derive((c) => {'count': c.count});

        expect(derived.value, {'count': 0});

        controller.increment();
        expect(derived.value, {'count': 1});

        controller.dispose();
        derived.dispose();
      });

      test('should allow chaining derived controllers', () {
        final controller = TestController();
        final derived1 = controller.derive((c) => c.count);
        final derived2 = derived1.derive((c) => c.value * 2);

        expect(derived2.value, 0);

        controller.increment();
        expect(derived1.value, 1);
        expect(derived2.value, 2);

        controller.increment();
        expect(derived1.value, 2);
        expect(derived2.value, 4);

        controller.dispose();
        derived1.dispose();
        derived2.dispose();
      });

      test('should not break when source is disposed', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        controller.increment();
        expect(notifyCount, 1);

        controller.dispose();

        // Derived should still have the last value
        expect(derived.value, 1);

        // But no more notifications when trying to update disposed controller
        // (This is expected behavior - source is gone)

        derived.dispose();
      });

      test('should work with ValueController as source', () {
        final source = ValueController<int>(0);
        final derived = source.derive((c) => c.value * 10);

        expect(derived.value, 0);

        source.value = 5;
        expect(derived.value, 50);

        source.value = 10;
        expect(derived.value, 100);

        source.dispose();
        derived.dispose();
      });

      test('should maintain type safety', () {
        final controller = TestController();
        final intDerived = controller.derive<int>((c) => c.count);
        final stringDerived = controller.derive<String>(
          (c) => 'Count: ${c.count}',
        );
        final boolDerived = controller.derive<bool>((c) => c.count > 0);

        expect(intDerived.value, isA<int>());
        expect(stringDerived.value, isA<String>());
        expect(boolDerived.value, isA<bool>());

        controller.dispose();
        intDerived.dispose();
        stringDerived.dispose();
        boolDerived.dispose();
      });

      test('should handle rapid source updates correctly', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        // Rapid updates
        for (var i = 0; i < 100; i++) {
          controller.increment();
        }

        expect(derived.value, 100);
        expect(notifyCount, 100);

        controller.dispose();
        derived.dispose();
      });

      test('should handle selector throwing exception gracefully', () {
        final controller = TestController();
        var shouldThrow = false;

        final derived = controller.derive((c) {
          if (shouldThrow) throw Exception('Selector error');
          return c.count;
        });

        expect(derived.value, 0);

        controller.increment();
        expect(derived.value, 1);

        // This will cause selector to throw on next notification
        shouldThrow = true;

        // The exception should be caught by FlutterError.reportError
        expect(controller.increment, throwsException);

        controller.dispose();
        derived.dispose();
      });

      test('should work correctly with manual notifyListeners', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        // Manually notify without changing value
        controller.notifyListeners();
        expect(notifyCount, 0); // Distinct mode, no change

        // Change value and manually notify
        controller
          ..count = 5
          ..notifyListeners();
        expect(derived.value, 5);
        expect(notifyCount, 1);

        controller.dispose();
        derived.dispose();
      });

      test('should allow derived controller to be used as ValueController', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        // Should be a ValueController
        expect(derived, isA<ValueController<int>>());

        // Can be used with ValueListenableBuilder (tested implicitly)
        expect(derived.value, 0);

        controller.dispose();
        derived.dispose();
      });

      test('should handle concurrent listeners on derived controller', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var count1 = 0;
        var count2 = 0;
        var count3 = 0;

        derived
          ..addListener(() => count1++)
          ..addListener(() => count2++)
          ..addListener(() => count3++);

        controller.increment();

        expect(count1, 1);
        expect(count2, 1);
        expect(count3, 1);

        controller.dispose();
        derived.dispose();
      });

      test('should auto-dispose when last listener removed (autoDispose: true)',
          () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        void listener() {}
        derived.addListener(listener);

        expect(derived.isDisposed, isFalse);
        expect(controller.hasListeners, isTrue);

        // Remove the listener
        derived.removeListener(listener);

        // Wait for scheduleMicrotask
        await Future<void>.delayed(Duration.zero);

        // Should be auto-disposed
        expect(derived.isDisposed, isTrue);
        // Source listener should be removed
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      test('should not auto-dispose when autoDispose: false', () async {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );

        void listener() {}
        derived.addListener(listener);

        expect(derived.isDisposed, isFalse);

        // Remove the listener
        derived.removeListener(listener);

        // Wait for scheduleMicrotask
        await Future<void>.delayed(Duration.zero);

        // Should NOT be auto-disposed
        expect(derived.isDisposed, isFalse);
        // Source listener should still be attached
        expect(controller.hasListeners, isTrue);

        // Manual disposal required
        derived.dispose();
        expect(derived.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      test('should not auto-dispose until all listeners removed', () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        void listener1() {}
        void listener2() {}
        derived
          ..addListener(listener1)
          ..addListener(listener2)
          // Remove first listener
          ..removeListener(listener1);
        await Future<void>.delayed(Duration.zero);

        // Should NOT be disposed yet (still has listener2)
        expect(derived.isDisposed, isFalse);

        // Remove second listener
        derived.removeListener(listener2);
        await Future<void>.delayed(Duration.zero);

        // Now should be disposed
        expect(derived.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      test('should cleanup source listener on manual dispose', () {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );

        expect(controller.hasListeners, isTrue);

        // Manual dispose
        derived.dispose();

        // Source listener should be removed
        expect(controller.hasListeners, isFalse);
        expect(derived.isDisposed, isTrue);

        controller.dispose();
      });

      test('should not update derived after auto-dispose', () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        void listener() => notifyCount++;
        derived.addListener(listener);

        controller.increment();
        expect(derived.value, 1);
        expect(notifyCount, 1);

        // Remove listener to trigger auto-dispose
        derived.removeListener(listener);
        await Future<void>.delayed(Duration.zero);

        expect(derived.isDisposed, isTrue);

        // Source changes should not affect disposed derived
        controller.increment();

        // Value should remain at last known value (disposed state)
        expect(notifyCount, 1); // No additional notifications

        controller.dispose();
      });

      test('should handle re-adding listener before auto-dispose completes',
          () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        void listener1() {}
        void listener2() {}

        derived
          ..addListener(listener1)
          ..removeListener(listener1)
          // Immediately add another listener before microtask runs
          ..addListener(listener2);

        // Wait for scheduleMicrotask
        await Future<void>.delayed(Duration.zero);

        // Should NOT be disposed because new listener was added
        expect(derived.isDisposed, isFalse);

        controller.dispose();
        derived.dispose();
      });

      test('should handle double dispose safely', () {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        )
          ..dispose()
          ..toString();

        expect(derived.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        // Second dispose should not throw
        expect(derived.dispose, returnsNormally);

        controller.dispose();
      });

      test('should dispose derived safely after source is disposed', () {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );

        // Dispose source first
        controller.dispose();
        expect(controller.isDisposed, isTrue);

        // Disposing derived should not throw
        expect(derived.dispose, returnsNormally);
        expect(derived.isDisposed, isTrue);
      });

      test('should handle multiple add/remove cycles', () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        void listener1() {}
        void listener2() {}

        // Cycle 1: add and remove
        derived
          ..addListener(listener1)
          ..removeListener(listener1);
        await Future<void>.delayed(Duration.zero);
        expect(derived.isDisposed, isTrue);

        // Create new derived for cycle 2
        final derived2 = controller.derive((c) => c.count)
          ..addListener(listener1)
          ..removeListener(listener1)
          ..addListener(listener2);
        await Future<void>.delayed(Duration.zero);
        expect(derived2.isDisposed, isFalse);

        // Remove last listener
        derived2.removeListener(listener2);
        await Future<void>.delayed(Duration.zero);
        expect(derived2.isDisposed, isTrue);

        controller.dispose();
      });

      test('should handle dispose during source notification', () {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );

        var notifyCount = 0;
        derived.addListener(() {
          notifyCount++;
          if (notifyCount == 1) {
            // Dispose during first notification
            derived.dispose();
          }
        });

        controller.increment();
        expect(notifyCount, 1);
        expect(derived.isDisposed, isTrue);

        // Further increments should not affect disposed derived
        controller.increment();
        expect(notifyCount, 1); // Still 1

        controller.dispose();
      });

      test('should handle derived never having listeners', () async {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        // Never add a listener, just use the value
        expect(derived.value, 0);

        controller.increment();
        // Value should still update through source listener
        expect(derived.value, 1);

        // Dispose should work fine
        derived.dispose();
        expect(derived.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      test('should handle removing non-existent listener safely', () {
        final controller = TestController();
        final derived = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );

        void listener() {}

        // Remove listener that was never added - should not throw
        expect(() => derived.removeListener(listener), returnsNormally);

        controller.dispose();
        derived.dispose();
      });

      test('should handle selector throwing on initial call', () {
        final controller = TestController();

        // Selector throws immediately
        expect(
          () => controller.derive<int>((c) => throw Exception('Init error')),
          throwsException,
        );

        controller.dispose();
      });

      test('should not leak memory when autoDispose triggers', () async {
        final controller = TestController();

        // Create many derived controllers
        for (var i = 0; i < 100; i++) {
          final derived = controller.derive((c) => c.count);
          void listener() {}
          derived
            ..addListener(listener)
            ..removeListener(listener);
        }

        // Wait for all auto-disposes
        await Future<void>.delayed(Duration.zero);

        // Source should have no listeners (all derived disposed)
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      testWidgets('should work correctly with ValueListenableBuilder pattern',
          (tester) async {
        final controller = TestController();
        // Create derived outside build - this is the recommended pattern
        final derived = controller.derive((c) => c.count);

        await tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: derived,
              builder: (context, value, _) => Text('Count: $value'),
            ),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);
        expect(controller.hasListeners, isTrue);

        controller.increment();
        await tester.pump();

        expect(find.text('Count: 1'), findsOneWidget);

        // Widget unmount removes ValueListenableBuilder's listener
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pump();

        // Use runAsync for real async operations (microtask scheduling)
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();

        // Derived should be auto-disposed and source listener removed
        expect(derived.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });

      test('should handle source notifying with same value multiple times', () {
        final controller = TestController();
        final derived = controller.derive((c) => c.count);

        var notifyCount = 0;
        derived.addListener(() => notifyCount++);

        // Force notify without changing value
        controller.notifyListeners();
        expect(notifyCount, 0); // Distinct mode, no change

        controller.notifyListeners();
        expect(notifyCount, 0); // Still no change

        // Now actually change value
        controller.increment();
        expect(notifyCount, 1);

        controller.dispose();
        derived.dispose();
      });

      test('should handle derived from derived with autoDispose', () async {
        final controller = TestController();
        final derived1 = controller.derive((c) => c.count);
        final derived2 = derived1.derive((c) => c.value * 2);

        void listener1() {}
        void listener2() {}

        // Add listeners to both to keep them alive
        derived1.addListener(listener1);
        derived2.addListener(listener2);

        controller.increment();
        expect(derived1.value, 1);
        expect(derived2.value, 2);

        // Remove listener from derived2 only
        derived2.removeListener(listener2);
        await Future<void>.delayed(Duration.zero);

        // derived2 should be disposed (no listeners)
        expect(derived2.isDisposed, isTrue);

        // derived1 should still work (still has listener1)
        expect(derived1.isDisposed, isFalse);
        controller.increment();
        expect(derived1.value, 2);

        // Cleanup
        derived1.removeListener(listener1);
        await Future<void>.delayed(Duration.zero);
        expect(derived1.isDisposed, isTrue);

        controller.dispose();
      });

      test('should handle autoDispose: false with chained derived', () {
        final controller = TestController();
        final derived1 = controller.derive(
          (c) => c.count,
          autoDispose: false,
        );
        final derived2 = derived1.derive(
          (c) => c.value * 2,
          autoDispose: false,
        );

        controller.increment();
        expect(derived2.value, 2);

        // Manual disposal in reverse order
        derived2.dispose();
        expect(derived2.isDisposed, isTrue);
        expect(derived1.hasListeners, isFalse);

        derived1.dispose();
        expect(derived1.isDisposed, isTrue);
        expect(controller.hasListeners, isFalse);

        controller.dispose();
      });
    });
  });
}
