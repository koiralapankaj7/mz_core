import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/controller.dart';
import 'package:mz_core/src/watcher.dart';

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
  });
}
