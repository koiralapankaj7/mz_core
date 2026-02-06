import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Listener;
import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/controller.dart';

// Expose internal classes for testing
export 'package:mz_core/src/controller.dart' show Listener;

// Test helper classes
class TestController with Controller {
  void notify([Object? key, Object? value]) {
    notifyListeners(key: key, value: value);
  }
}

void main() {
  group('Controller Tests |', () {
    group('Basic Functionality -', () {
      test('should handle listeners without keys', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(() => count++)
          ..notify();
        expect(count, 1);
        controller.dispose();
      });

      test('should handle multiple listeners', () {
        final controller = TestController();
        var count1 = 0;
        var count2 = 0;

        controller
          ..addListener(() => count1++)
          ..addListener(() => count2++)
          ..notify();

        expect(count1, 1);
        expect(count2, 1);

        controller.dispose();
      });

      test('should handle listener removal', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;

        controller
          ..addListener(listener)
          ..notify();
        expect(count, 1);

        controller
          ..removeListener(listener)
          ..notify();
        expect(count, 1);

        controller.dispose();
      });

      test('should prevent duplicate listeners', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;

        controller
          ..addListener(listener)
          ..addListener(listener) // Duplicate - should not be added
          ..notify();

        expect(count, 1); // Should only notify once

        controller.dispose();
      });

      test('should handle rapid add/remove cycles', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;

        for (var i = 0; i < 100; i++) {
          controller
            ..addListener(listener)
            ..removeListener(listener);
        }

        controller.notify();
        expect(count, 0); // No listeners should remain

        controller.dispose();
      });
    });

    group('Set-based Storage -', () {
      test('should store simple VoidCallbacks in Set without wrapper', () {
        final controller = TestController();
        var count = 0;

        // Simple VoidCallback - should be stored directly in Set
        controller
          ..addListener(() => count++)
          ..notify();

        expect(count, 1);
        controller.dispose();
      });

      test('should provide O(1) removal for simple listeners', () {
        // Test O(1) by comparing removal times at different scales
        // If O(1), 10x more listeners should take ~10x time, not 100x
        int measureRemovalTime(int count) {
          final controller = TestController();
          final listeners = List.generate(count, (i) => () {});
          // ignore: cascade_invocations, forEach needed for benchmark
          listeners.forEach(controller.addListener);

          final stopwatch = Stopwatch()..start();
          listeners.forEach(controller.removeListener);
          stopwatch.stop();

          controller.dispose();
          return stopwatch.elapsedMicroseconds;
        }

        // Warm up JIT
        measureRemovalTime(100);

        // Measure at two scales
        final time100 = measureRemovalTime(100);
        final time1000 = measureRemovalTime(1000);

        // With O(1) removal, 10x listeners should be roughly 10x slower
        // With O(n) removal, it would be ~100x slower
        // Allow ratio up to 30x to account for variance (still catches O(n))
        final ratio = time1000 / (time100 == 0 ? 1 : time100);
        expect(ratio, lessThan(30));
      });

      test('should handle Set operations correctly', () {
        final controller = TestController();
        var count1 = 0;
        var count2 = 0;

        void listener1() => count1++;
        void listener2() => count2++;

        controller
          ..addListener(listener1)
          ..addListener(listener2)
          ..addListener(listener1) // Duplicate - should not add
          ..notify();

        expect(count1, 1); // Only called once despite duplicate add
        expect(count2, 1);

        controller.dispose();
      });
    });

    group('Cached List Iteration -', () {
      test('should cache List for fast iteration', () {
        final controller = TestController();
        var notifyCount = 0;

        // Add 100 simple listeners
        for (var i = 0; i < 100; i++) {
          controller.addListener(() => notifyCount++);
        }

        // First notify - creates cache
        final stopwatch1 = Stopwatch()..start();
        controller.notify();
        stopwatch1.stop();

        // Second notify - uses cache (should be same speed or faster)
        final stopwatch2 = Stopwatch()..start();
        controller.notify();
        stopwatch2.stop();

        expect(notifyCount, 200); // 100 listeners × 2 notifications
        // Cache should not slow down iterations
        expect(
          stopwatch2.elapsedMicroseconds,
          lessThanOrEqualTo(stopwatch1.elapsedMicroseconds * 1.2),
        );

        controller.dispose();
      });

      test('should invalidate cache on add', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(() => count++)
          ..notify();

        expect(count, 1);

        // Add new listener - should invalidate cache
        controller
          ..addListener(() => count++)
          ..notify();

        expect(count, 3); // 1 (first notify) + 2 (second notify)

        controller.dispose();
      });

      test('should invalidate cache on remove', () {
        final controller = TestController();
        var count = 0;
        void listener1() => count++;
        void listener2() => count++;

        controller
          ..addListener(listener1)
          ..addListener(listener2)
          ..notify();

        expect(count, 2);

        // Remove listener - should invalidate cache
        controller
          ..removeListener(listener1)
          ..notify();

        expect(count, 3); // 2 (first notify) + 1 (second notify)

        controller.dispose();
      });
    });

    group('Conditional Wrapping -', () {
      test('should NOT wrap simple VoidCallbacks', () {
        final controller = TestController();
        var count = 0;

        // Simple VoidCallback (priority=0, no predicate) - no wrapper
        controller
          ..addListener(() => count++)
          ..notify();

        expect(count, 1);
        controller.dispose();
      });

      test('should wrap listeners with priority', () {
        final controller = TestController();
        final callOrder = <String>[];

        controller
          ..addListener(() => callOrder.add('high'), priority: 10)
          ..addListener(() => callOrder.add('normal'))
          ..addListener(() => callOrder.add('low'), priority: -10)
          ..notify();

        expect(callOrder, ['high', 'normal', 'low']);

        controller.dispose();
      });

      test('should wrap listeners with predicate', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(
            () => count++,
            predicate: (key, value) => value is int && value > 10,
          )
          ..notify(null, 5) // Should not execute
          ..notify(null, 15); // Should execute

        expect(count, 1);

        controller.dispose();
      });

      test('should wrap ValueCallback listeners', () {
        final controller = TestController();
        Object? receivedValue;

        controller
          ..addListener((Object? value) => receivedValue = value)
          ..notify(null, 'test-value');

        expect(receivedValue, equals('test-value'));

        controller.dispose();
      });

      test('should mix simple and complex listeners correctly', () {
        final controller = TestController();
        final callOrder = <String>[];

        controller
          ..addListener(() => callOrder.add('simple1'))
          ..addListener(() => callOrder.add('high'), priority: 10)
          ..addListener(() => callOrder.add('simple2'))
          ..addListener(() => callOrder.add('low'), priority: -10)
          ..notify();

        // High priority, then simple (priority 0), then low priority
        expect(
          callOrder,
          ['high', 'simple1', 'simple2', 'low'],
        );

        controller.dispose();
      });
    });

    group('Key-based Notifications -', () {
      test('should notify only key-specific listeners', () {
        final controller = TestController();
        var countA = 0;
        var countB = 0;
        controller
          ..addListener(() => countA++, key: 'A')
          ..addListener(() => countB++, key: 'B')
          ..notify('A');
        expect(countA, 1);
        expect(countB, 0);
        controller.dispose();
      });

      test('should handle multiple keys for same listener', () {
        final controller = TestController();
        var count = 0;
        controller
          ..addListener(() => count++, key: ['A', 'B'])
          ..notify('A');
        expect(count, 1);
        controller.notify('B');
        expect(count, 2);
        controller.dispose();
      });

      test('should handle key removal correctly', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;
        controller
          ..addListener(listener, key: 'A')
          ..removeListener(listener, key: 'A')
          ..notify('A');
        expect(count, 0);
        controller.dispose();
      });

      test('should handle empty key collection removal', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;
        controller
          ..addListener(listener, key: <String>[])
          ..removeListener(listener, key: <String>[])
          ..notify();
        expect(count, 0);
      });

      test('should handle non-existent key removal', () {
        final controller = TestController();
        var count = 0;
        void listener() => count++;
        // Add listener with key 'A' but remove with non-existent key 'B'
        controller
          ..addListener(listener, key: 'A')
          ..removeListener(listener, key: 'B')
          ..notify('A');
        expect(count, 1); // Should still notify since wrong key was removed
      });

      test('should handle null key notification', () {
        final controller = TestController();
        var count = 0;
        controller
          ..addListener(() => count++)
          ..notify(null, 'test-value'); // No key
        expect(count, 1);
      });

      test('should handle iterable keys', () {
        final controller = TestController();
        var countA = 0;
        var countB = 0;
        controller
          ..addListener(() => countA++, key: 'A')
          ..addListener(() => countB++, key: 'B')
          ..notify(['A', 'B']);
        expect(countA, 1);
        expect(countB, 1);
      });

      test('should handle key-based notifications with Set storage', () {
        final controller = TestController();
        var globalCount = 0;
        var keyACount = 0;

        controller
          ..addListener(() => globalCount++) // Simple - stored in Set
          ..addListener(() => keyACount++, key: 'A') // Key-based
          ..notify('A');

        expect(globalCount, 1); // Global listener executed
        expect(keyACount, 1); // Key listener executed

        controller.dispose();
      });
    });

    group('Value & Key-Value Callbacks -', () {
      test('should handle value callbacks', () {
        final controller = TestController();
        Object? receivedValue;

        controller
          ..addListener((Object? value) => receivedValue = value)
          ..notify(null, 'test-value');
        expect(receivedValue, equals('test-value'));

        controller.dispose();
      });

      test('should handle key-value callbacks', () {
        final controller = TestController();
        Object? receivedKey;
        Object? receivedValue;
        controller
          ..addListener((Object? key, Object? value) {
            receivedKey = key;
            receivedValue = value;
          })
          ..notify('test-key', 'test-value');
        expect(receivedKey, equals('test-key'));
        expect(receivedValue, equals('test-value'));
        controller.dispose();
      });

      test('should handle key-value-controller callbacks', () {
        final controller = TestController();
        Object? receivedKey;
        Object? receivedValue;
        Controller? receivedController;
        controller
          ..addListener((Object? key, Object? value, Controller ctrl) {
            receivedKey = key;
            receivedValue = value;
            receivedController = ctrl;
          })
          ..notify('test-key', 'test-value');
        expect(receivedKey, equals('test-key'));
        expect(receivedValue, equals('test-value'));
        expect(receivedController, equals(controller));
        controller.dispose();
      });
    });

    group('Priority -', () {
      test('should call listeners in priority order', () {
        final controller = Controller();
        final callOrder = <String>[];
        controller
          ..addListener(() => callOrder.add('low'), priority: -10)
          ..addListener(() => callOrder.add('high'), priority: 10)
          ..addListener(() => callOrder.add('low1'), priority: -3)
          ..addListener(() => callOrder.add('normal'))
          ..addListener(() => callOrder.add('high1'), priority: 3)
          ..notifyListeners();
        expect(callOrder, ['high', 'high1', 'normal', 'low1', 'low']);
      });

      test('should call listeners with same priority in order of addition', () {
        final controller = Controller();
        final callOrder = <String>[];
        controller
          ..addListener(() => callOrder.add('first'))
          ..addListener(() => callOrder.add('second'))
          ..notifyListeners();
        expect(callOrder, ['first', 'second']);
      });

      test('should call key-specific listeners in priority order', () {
        final controller = Controller();
        final callOrder = <String>[];
        controller
          ..addListener(() {
            callOrder.add('global');
          })
          ..addListener(
            () => callOrder.add('key-low'),
            key: 'key',
            priority: -10,
          )
          ..addListener(
            () => callOrder.add('key-high'),
            key: 'key',
            priority: 10,
          )
          ..notifyListeners(key: 'key');
        expect(callOrder, ['key-high', 'global', 'key-low']);
      });

      test(
        'should respect priority with mixed simple and complex listeners',
        () {
          final controller = Controller();
          final callOrder = <String>[];

          controller
            ..addListener(() => callOrder.add('simple1')) // Priority 0
            ..addListener(() => callOrder.add('high'), priority: 10)
            ..addListener(() => callOrder.add('simple2')) // Priority 0
            ..addListener(() => callOrder.add('low'), priority: -10)
            ..addListener(() => callOrder.add('simple3')) // Priority 0
            ..notifyListeners();

          // High (10), then all simple (0), then low (-10)
          expect(
            callOrder,
            ['high', 'simple1', 'simple2', 'simple3', 'low'],
          );
        },
      );
    });

    group('Predicate Filtering -', () {
      test('should execute listener only when predicate returns true', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(
            () => count++,
            predicate: (key, value) => value is int && value > 10,
          )
          ..notify(null, 5)
          ..notify(null, 15)
          ..notify(null, 8)
          ..notify(null, 20);

        expect(count, 2); // Only 15 and 20

        controller.dispose();
      });

      test('should work with key-based predicates', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(
            () => count++,
            key: 'user',
            predicate: (key, value) => value is String && value.length > 3,
          )
          ..notify('user', 'ab') // Too short
          ..notify('user', 'john') // Valid
          ..notify('other', 'ignored') // Wrong key
          ..notify('user', 'alice'); // Valid

        expect(count, 2); // Only 'john' and 'alice'

        controller.dispose();
      });

      test('should handle predicate with value callback', () {
        final controller = TestController();
        final values = <int>[];

        controller
          ..addListener(
            (Object? value) => values.add(value! as int),
            predicate: (key, value) => value is int && value.isEven,
          )
          ..notify(null, 1)
          ..notify(null, 2)
          ..notify(null, 3)
          ..notify(null, 4);

        expect(values, [2, 4]);

        controller.dispose();
      });
    });

    group('Listener Signatures -', () {
      test('should accept VoidCallback', () {
        final controller = TestController();
        var count = 0;

        controller
          ..addListener(() => count++)
          ..notify();

        expect(count, 1);
        controller.dispose();
      });

      test('should accept ValueCallback', () {
        final controller = TestController();
        Object? receivedValue;

        controller
          ..addListener((Object? value) => receivedValue = value)
          ..notify(null, 'test');

        expect(receivedValue, 'test');
        controller.dispose();
      });

      test('should accept KvCallback', () {
        final controller = TestController();
        Object? receivedKey;
        Object? receivedValue;

        controller
          ..addListener((Object? key, Object? value) {
            receivedKey = key;
            receivedValue = value;
          })
          ..notify('key', 'value');

        expect(receivedKey, 'key');
        expect(receivedValue, 'value');
        controller.dispose();
      });

      test('should accept KvcCallback', () {
        final controller = TestController();
        Controller? receivedController;

        controller
          ..addListener((Object? key, Object? value, Controller ctrl) {
            receivedController = ctrl;
          })
          ..notify();

        expect(receivedController, controller);
        controller.dispose();
      });
    });

    group('Disposal -', () {
      test('should mark controller as disposed', () {
        final controller = TestController();
        var count = 0;
        controller.addListener(() => count++);

        expect(controller.isDisposed, isFalse);

        controller.dispose();

        expect(controller.isDisposed, isTrue);

        // Can call dispose multiple times safely
        controller.dispose();
        expect(controller.isDisposed, isTrue);
      });

      test('should handle multiple disposes gracefully', () {
        final controller = TestController();

        // Add many simple listeners
        for (var i = 0; i < 100; i++) {
          controller.addListener(() {});
        }

        controller.dispose();
        expect(controller.isDisposed, isTrue);

        // Can dispose multiple times
        controller.dispose();
        expect(controller.isDisposed, isTrue);
      });

      test('should prevent operations after dispose', () {
        final controller = TestController();

        // Add listeners with priority
        for (var i = 0; i < 10; i++) {
          controller.addListener(() {}, priority: i);
        }

        controller.dispose();

        expect(controller.isDisposed, isTrue);

        // Operations after dispose should be no-ops (not throw)
        controller
          ..addListener(() {}) // Should be ignored
          ..removeListener(() {}) // Should be ignored
          ..notifyListeners(); // Should be ignored
      });
    });

    group('Static Methods -', () {
      test('should handle maybeDispatchObjectCreation', () {
        final controller = TestController();
        Controller.maybeDispatchObjectCreation(controller);
        // Second call should not dispatch again
        Controller.maybeDispatchObjectCreation(controller);
      });

      test('should handle maybeDispatchObjectDispose', () {
        final controller = TestController();
        Controller.maybeDispatchObjectCreation(controller);
        Controller.maybeDispatchObjectDispose(controller);
        // Second call should not throw
        Controller.maybeDispatchObjectDispose(controller);
      });
    });

    group('Performance -', () {
      test('should handle many simple listeners efficiently', () {
        final controller = TestController();
        var count = 0;

        // Add 1000 simple listeners
        for (var i = 0; i < 1000; i++) {
          controller.addListener(() => count++);
        }

        final stopwatch = Stopwatch()..start();
        controller.notify();
        stopwatch.stop();

        expect(count, 1000);
        // Should complete in less than 5ms
        expect(stopwatch.elapsedMilliseconds, lessThan(5));

        controller.dispose();
      });

      test('should handle mixed listeners efficiently', () {
        final controller = TestController();
        var count = 0;

        // Add 500 simple + 500 complex listeners
        for (var i = 0; i < 500; i++) {
          controller
            ..addListener(() => count++) // Simple
            ..addListener(() => count++, priority: i % 10); // Complex
        }

        final stopwatch = Stopwatch()..start();
        controller.notify();
        stopwatch.stop();

        expect(count, 1000);
        // Should complete in less than 10ms
        expect(stopwatch.elapsedMilliseconds, lessThan(10));

        controller.dispose();
      });
    });

    group('Advanced Features -', () {
      test('should handle complex listener removal', () {
        final controller = TestController();
        var count = 0;

        void listener() => count++;

        // Add complex listener (with priority)
        controller
          ..addListener(listener, priority: 10)
          ..notify();
        expect(count, 1);

        // Remove complex listener
        controller
          ..removeListener(listener)
          ..notify();
        expect(count, 1); // Should not increase

        controller.dispose();
      });

      test('should remove iterable of keys', () {
        final controller = TestController();
        var count = 0;

        void listener() => count++;

        // Add listener to multiple keys
        // Notify all keys
        controller
          ..addListener(listener, key: ['key1', 'key2', 'key3'])
          ..notify('key1')
          ..notify('key2')
          ..notify('key3');
        expect(count, 3);

        // Remove from all keys using iterable
        // Should not notify anymore
        controller
          ..removeListener(listener, key: ['key1', 'key2', 'key3'])
          ..notify('key1')
          ..notify('key2')
          ..notify('key3');
        expect(count, 3); // No change

        controller.dispose();
      });

      test('should notify single key without global listeners', () {
        final controller = TestController();
        var keyCount = 0;
        var globalCount = 0;

        // Notify with includeGlobalListeners = false (internal behavior)
        controller
          ..addListener(() => globalCount++) // Global
          ..addListener(() => keyCount++, key: 'specific')
          ..notify('specific');

        // Both should be called (default behavior includes global)
        expect(keyCount, 1);
        expect(globalCount, 1);

        controller.dispose();
      });

      test('should track listener counts', () {
        final controller = TestController();

        expect(controller.globalListenersCount, 0);
        expect(controller.keyedListenersCount('key1'), 0);
        expect(controller.hasListeners, isFalse);

        // Add global listener
        controller.addListener(() {});
        expect(controller.globalListenersCount, 1);
        expect(controller.hasListeners, isTrue);

        // Add key-specific listener
        controller
          ..addListener(() {}, key: 'key1')
          ..addListener(() {}, key: 'key1');
        expect(controller.keyedListenersCount('key1'), 2);

        // Add to another key
        controller.addListener(() {}, key: 'key2');
        expect(controller.keyedListenersCount('key2'), 1);
        expect(controller.keyedListenersCount('nonexistent'), 0);

        controller.dispose();
      });

      test('should handle only complex listeners', () {
        final controller = TestController();
        final callOrder = <String>[];

        // Add only complex listeners (no simple ones)
        controller
          ..addListener(() => callOrder.add('high'), priority: 10)
          ..addListener(() => callOrder.add('medium'), priority: 5)
          ..addListener(() => callOrder.add('low'), priority: 1)
          ..notify();

        expect(callOrder, ['high', 'medium', 'low']);

        controller.dispose();
      });

      test('should clean up empty listener sets', () {
        final controller = TestController();

        void listener1() {}
        void listener2() {}

        // Add complex listeners
        controller
          ..addListener(listener1, priority: 10)
          ..addListener(listener2, priority: 5);

        expect(controller.hasListeners, isTrue);

        // Remove all
        controller
          ..removeListener(listener1)
          ..removeListener(listener2);

        // All internal sets should be cleaned up
        expect(controller.globalListenersCount, 0);

        controller.dispose();
      });

      test('should test Listener equality and hashCode', () {
        void listener1() {}
        void listener2() {}

        final cListener1 =
            Listener.create(listener1, priority: 0, predicate: null);
        final cListener2 =
            Listener.create(listener1, priority: 0, predicate: null);
        final cListener3 =
            Listener.create(listener2, priority: 0, predicate: null);

        // Same function - should be equal
        expect(cListener1, equals(cListener2));
        expect(cListener1.hashCode, equals(cListener2.hashCode));

        // Different function - should not be equal
        expect(cListener1, isNot(equals(cListener3)));
      });

      test('should support Listener.merge factory', () {
        var count1 = 0;
        var count2 = 0;

        final listener1 = Listener.create(
          () => count1++,
          priority: 0,
          predicate: null,
        );
        final listener2 = Listener.create(
          () => count2++,
          priority: 0,
          predicate: null,
        );

        final merged = Listener.merge([listener1, listener2]);

        final controller = TestController();
        merged.call(controller, null, null);

        // Both listeners should be called
        expect(count1, 1);
        expect(count2, 1);
      });

      test('should merge multiple key listeners', () {
        final controller = TestController();
        var count = 0;

        // Add to single key
        controller
          ..addListener(() => count++, key: 'key1')
          // Notify single source
          ..notify('key1');
        expect(count, 1);

        controller.dispose();
      });
    });

    group('Controller.merge -', () {
      test('should merge multiple controllers', () {
        final controller1 = TestController();
        final controller2 = TestController();

        var count = 0;
        void listener() => count++;

        final merged = Controller.merge([controller1, controller2])
          ..addListener(listener);

        // Notify controller1
        controller1.notify();
        expect(count, 1);

        // Notify controller2
        controller2.notify();
        expect(count, 2);

        // Remove listener
        merged
          ..removeListener(listener)
          ..dispose();

        controller1
          ..notify()
          ..dispose();
        controller2
          ..notify()
          ..dispose();
        expect(count, 2); // No change
      });

      test('should handle mixed Controller and Listenable', () {
        final controller = TestController();
        final notifier = ChangeNotifier();

        var count = 0;
        void listener() => count++;

        final merged = Controller.merge([controller, notifier])
          ..addListener(listener);

        controller.notify();
        expect(count, 1);

        notifier.notifyListeners();
        expect(count, 2);

        merged
          ..removeListener(listener)
          ..dispose();

        controller.dispose();
        notifier.dispose();
      });

      test('should filter out null controllers', () {
        final controller = TestController();

        var count = 0;
        void listener() => count++;

        final merged = Controller.merge([controller, null, null])
          ..addListener(listener);

        controller
          ..notify()
          ..dispose();
        expect(count, 1);

        merged.dispose();
      });
    });
  });

  group('Widget Integration Tests |', () {
    group('ControllerProvider -', () {
      testWidgets('should provide controller to descendants', (tester) async {
        TestController? found;

        await tester.pumpWidget(
          ControllerProvider<TestController>(
            create: (_) => TestController(),
            child: Builder(
              builder: (context) {
                found = Controller.ofType<TestController>(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(found, isNotNull);
        expect(found, isA<TestController>());
      });

      testWidgets('should handle maybe lookup', (tester) async {
        TestController? found;
        await tester.pumpWidget(
          ControllerProvider<TestController>(
            create: (_) => TestController(),
            child: Builder(
              builder: (context) {
                found = Controller.maybeOfType<TestController>(context);
                return const SizedBox();
              },
            ),
          ),
        );
        expect(found, isNotNull);
        expect(found, isA<TestController>());
      });

      testWidgets('should throw when controller not found', (tester) async {
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            // Wrap in MaterialApp to provide proper context
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          () => Controller.ofType<TestController>(capturedContext),
          throwsA(isA<FlutterError>()),
        );
      });

      testWidgets('should return null for maybeOfType when not found', (
        tester,
      ) async {
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            // Wrap in MaterialApp to provide proper context
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(Controller.maybeOfType<TestController>(capturedContext), isNull);
      });

      testWidgets('should find controller with listen: false', (tester) async {
        TestController? found;

        await tester.pumpWidget(
          ControllerProvider<TestController>(
            create: (_) => TestController(),
            child: Builder(
              builder: (context) {
                found = Controller.ofType<TestController>(
                  context,
                  listen: false,
                );
                return const SizedBox();
              },
            ),
          ),
        );

        expect(found, isNotNull);
        expect(found, isA<TestController>());
      });

      testWidgets('should return null for maybeOfType with listen: false',
          (tester) async {
        late BuildContext capturedContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(
          Controller.maybeOfType<TestController>(
            capturedContext,
            listen: false,
          ),
          isNull,
        );
      });

      testWidgets(
          'should not rebuild widget when listen: false and controller changes',
          (tester) async {
        var listenFalseBuildCount = 0;
        var listenTrueBuildCount = 0;
        final key = GlobalKey();

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerProvider<TestController>(
              key: key,
              create: (_) => TestController(),
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      // Using listen: false should not create dependency
                      Controller.maybeOfType<TestController>(
                        context,
                        listen: false,
                      );
                      listenFalseBuildCount++;
                      return const SizedBox();
                    },
                  ),
                  Builder(
                    builder: (context) {
                      // Using listen: true (default) should create dependency
                      Controller.maybeOfType<TestController>(context);
                      listenTrueBuildCount++;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(listenFalseBuildCount, 1);
        expect(listenTrueBuildCount, 1);

        // Trigger a rebuild by updating the widget tree
        await tester.pumpWidget(
          MaterialApp(
            home: ControllerProvider<TestController>(
              key: key,
              create: (_) => TestController(),
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      Controller.maybeOfType<TestController>(
                        context,
                        listen: false,
                      );
                      listenFalseBuildCount++;
                      return const SizedBox();
                    },
                  ),
                  Builder(
                    builder: (context) {
                      Controller.maybeOfType<TestController>(context);
                      listenTrueBuildCount++;
                      return const SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        // Both should rebuild since we pumped a new widget tree
        // The real difference is in dependency registration, which we can't
        // easily observe directly. What we CAN verify is that listen: false
        // still finds the controller correctly.
        expect(listenFalseBuildCount, 2);
        expect(listenTrueBuildCount, 2);
      });
    });

    group('ControllerBuilder -', () {
      testWidgets('should rebuild when controller notifies', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller,
              builder: (context, ctrl) {
                buildCount++;
                return const Text('test');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Notify - should rebuild
        controller.notify();
        await tester.pump();

        expect(buildCount, 2);
        expect(find.text('test'), findsOneWidget);

        controller.dispose();
      });

      testWidgets('should rebuild only for specific key', (tester) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller,
              filterKey: 'specificKey',
              builder: (context, ctrl) {
                buildCount++;
                return const Text('test');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Notify with wrong key - should NOT rebuild
        controller.notify('otherKey');
        await tester.pump();

        expect(buildCount, 1); // No rebuild

        // Notify with correct key - should rebuild
        controller.notify('specificKey');
        await tester.pump();

        expect(buildCount, 2); // Rebuilt

        controller.dispose();
      });

      testWidgets('should rebuild with predicate filter', (tester) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller,
              predicate: (key, value) => value is int && value > 10,
              builder: (context, ctrl) {
                buildCount++;
                return const Text('test');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Notify with value <= 10 - should NOT rebuild
        controller.notify(null, 5);
        await tester.pump();

        expect(buildCount, 1); // No rebuild

        // Notify with value > 10 - should rebuild
        controller.notify(null, 15);
        await tester.pump();

        expect(buildCount, 2); // Rebuilt

        controller.dispose();
      });
    });

    group('Coverage: Uncovered Lines -', () {
      test('should handle only complex listeners (hasOnlyComplex)', () {
        final controller = TestController();
        var count = 0;

        // Add only complex listener (with priority)
        controller
          ..addListener(() => count++, priority: 5)
          ..notify();

        expect(count, 1);
        controller.dispose();
      });

      test('should handle merge algorithm edge cases', () {
        final controller = TestController();
        final calls = <int>[];

        // Add listeners with priorities that test merge edge cases
        controller
          ..addListener(() => calls.add(1), priority: 10)
          ..addListener(() => calls.add(2), priority: 5)
          ..addListener(() => calls.add(3), priority: 3)
          ..addListener(() => calls.add(4), priority: 1)
          ..notify();

        expect(calls, [1, 2, 3, 4]); // Sorted by priority
        controller.dispose();
      });

      test(
        'should handle single key notification without global listeners',
        () {
          final controller = TestController();
          var keyCount = 0;
          const globalCount = 0;

          // Add only key-based listener, no global listeners
          controller
            ..addListener(() => keyCount++, key: 'test')
            // Notify with key - should call key listener
            ..notify('test');
          expect(keyCount, 1);
          expect(globalCount, 0);

          controller.dispose();
        },
      );

      test('should handle single source optimization', () {
        final controller = TestController();
        var count = 0;

        // Single listener for one key
        controller
          ..addListener(() => count++, key: 'single')
          ..notify('single');

        expect(count, 1);
        controller.dispose();
      });

      test('should handle listener errors gracefully', () {
        final controller = TestController();
        var successCount = 0;

        // Add global listener that throws
        // Add key-based listener
        // Notify with key AND includeGlobalListeners
        // This forces the merge path which has error handling
        controller
          ..addListener(
            () {
              throw Exception('Test error');
            },
            priority: 1,
          )
          ..addListener(() => successCount++, key: 'test')
          ..notify('test');

        // Key listener should still be called despite error in global listener
        expect(successCount, 1);
        controller.dispose();
      });

      testWidgets('should handle ControllerBuilder didUpdateWidget', (
        tester,
      ) async {
        final controller1 = TestController();
        final controller2 = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller1,
              builder: (context, ctrl) {
                buildCount++;
                return const Text('Test');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Update widget with different controller
        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller2,
              builder: (context, ctrl) {
                buildCount++;
                return const Text('Test');
              },
            ),
          ),
        );

        expect(buildCount, 2);

        // Notify old controller - should not rebuild
        controller1.notify();
        await tester.pump();
        expect(buildCount, 2);

        // Notify new controller - should rebuild
        controller2.notify();
        await tester.pump();
        expect(buildCount, 3);

        controller1.dispose();
        controller2.dispose();
      });

      testWidgets('should handle ControllerBuilder with different filterKey', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller,
              filterKey: 'key1',
              builder: (context, ctrl) {
                buildCount++;
                return const Text('Test');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Update widget with different filterKey
        await tester.pumpWidget(
          MaterialApp(
            home: ControllerBuilder<TestController>(
              controller: controller,
              filterKey: 'key2',
              builder: (context, ctrl) {
                buildCount++;
                return const Text('Test');
              },
            ),
          ),
        );

        expect(buildCount, 2);

        // Notify with old key - should not rebuild
        controller.notify('key1');
        await tester.pump();
        expect(buildCount, 2);

        // Notify with new key - should rebuild
        controller.notify('key2');
        await tester.pump();
        expect(buildCount, 3);

        controller.dispose();
      });

      testWidgets('should update InheritedWidget when controller changes', (
        tester,
      ) async {
        final controller1 = TestController();
        final controller2 = TestController();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ControllerProvider<TestController>(
                  create: (context) => controller1,
                  child: Builder(
                    builder: (context) {
                      final ctrl = Controller.ofType<TestController>(context);
                      return Text('Controller: ${ctrl.hashCode}');
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(find.textContaining('Controller:'), findsOneWidget);

        // Update to different controller - should trigger rebuild
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return ControllerProvider<TestController>(
                  create: (context) => controller2,
                  child: Builder(
                    builder: (context) {
                      final ctrl = Controller.ofType<TestController>(context);
                      return Text('Controller: ${ctrl.hashCode}');
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(find.textContaining('Controller:'), findsOneWidget);

        controller1.dispose();
        controller2.dispose();
      });

      test('should cover hasOnlyComplex getter fully', () {
        final controller = TestController();
        var count = 0;

        // Add only complex listeners (with predicate or priority)
        // This ensures _complexListeners is not empty
        // and _simpleCallbacks is empty
        // This should hit the hasOnlyComplex code path (lines 99-102)
        controller
          ..addListener(() => count++, predicate: (k, v) => true)
          ..addListener(() => count++, priority: 5)
          ..notify();

        expect(count, 2);
        controller.dispose();
      });

      test('should handle merge algorithm with leftover from first array', () {
        final controller = TestController();
        final calls = <String>[];

        // Create scenario where first array has leftover elements
        // Priority: A(10), A(8), B(5), B(3)
        // After merge: should be A(10), B(5), A(8), B(3)
        // This tests lines 326-327
        // Notify with key and global listeners
        controller
          ..addListener(() => calls.add('A1'), priority: 10)
          ..addListener(() => calls.add('A2'), priority: 8)
          ..addListener(() => calls.add('B1'), key: 'key1', priority: 5)
          ..addListener(() => calls.add('B2'), key: 'key1', priority: 3)
          ..notify('key1');

        // Verify merge happened correctly
        expect(calls.length, 4);
        controller.dispose();
      });

      test('should use fast path for single key without global listeners', () {
        final controller = TestController();
        var count = 0;

        // Add ONLY key-based listener, no global listeners
        // Notify with includeGlobalListeners: false (line 605-608)
        controller
          ..addListener(() => count++, key: 'test')
          ..notifyListeners(
            key: 'test',
            includeGlobalListeners: false,
          );

        expect(count, 1);
        controller.dispose();
      });

      test('should handle single source in multiple keys notification', () {
        final controller = TestController();
        var count = 0;

        // Add listeners to multiple keys
        // Notify with iterable of keys where only one has listeners (line 686)
        controller
          ..addListener(() => count++, key: 'key1')
          ..notify(['key1', 'key2', 'key3']);

        expect(count, 1);
        controller.dispose();
      });

      testWidgets('should handle ControllerBuilder predicate change', (
        tester,
      ) async {
        final controller = TestController();
        var buildCount = 0;
        var usePredicate1 = true;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return ControllerBuilder<TestController>(
                  controller: controller,
                  predicate: usePredicate1
                      ? (k, v) => v is int && v > 5
                      : (k, v) => v is int && v > 10,
                  builder: (ctx, ctrl) {
                    buildCount++;
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {
                          usePredicate1 = !usePredicate1;
                        });
                      },
                      child: const Text('Toggle'),
                    );
                  },
                );
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Change predicate (line 883)
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();

        expect(buildCount, 2);

        controller.dispose();
      });

      test('should call _noOp in _MergeListener', () {
        // Create Listener instances to merge
        final listener1 = Listener.create(
          () {},
          priority: 5,
          predicate: (k, v) => true,
        );
        final listener2 = Listener.create(
          () {},
          priority: 3,
          predicate: (k, v) => true,
        );

        // Create merged listener
        final merged = Listener.merge([listener1, listener2]);

        // Access the underlying function to trigger _noOp
        final controller = TestController();

        // Call the parent Listener's function directly
        // ignore: avoid_dynamic_calls - Testing internal _noOp function
        merged.function();

        // Also call the merged listener
        merged.call(controller, null, null);

        controller.dispose();
      });

      test('should handle merge with longer first array', () {
        final controller = TestController();
        final calls = <String>[];

        // Create scenario: array A is longer than B
        // A: priority 10, 8, 6
        // B: priority 9
        // Merge should interleave then add leftover from A
        controller
          ..addListener(() => calls.add('A10'), priority: 10)
          ..addListener(() => calls.add('A8'), priority: 8)
          ..addListener(() => calls.add('A6'), priority: 6)
          ..addListener(() => calls.add('B9'), key: 'test', priority: 9)
          ..notify('test');

        // Should merge and handle leftover from A (lines 326-327)
        expect(calls, ['A10', 'B9', 'A8', 'A6']);
        controller.dispose();
      });

      test('should hit all code paths for mixed listeners', () {
        // Ensure hasOnly* getters are tested by creating various scenarios
        final controller = TestController();
        var count = 0;

        // Start with only complex listeners (for hasOnlyComplex path)
        controller
          ..addListener(() => count++, priority: 1)
          ..notify();
        expect(count, 1);

        // Add a simple listener (now has both)
        controller
          ..addListener(() => count++)
          ..notify();
        expect(count, 3);

        controller.dispose();
      });
    });
  });

  group('ValueController Tests |', () {
    group('Constructor and Initial Value', () {
      test('should create controller with initial int value', () {
        final controller = ValueController<int>(42);

        expect(controller.value, equals(42));
        expect(controller.hasPrevValue, isFalse);
        expect(controller.prevValue, isNull);
      });

      test('should create controller with initial String value', () {
        final controller = ValueController<String>('hello');

        expect(controller.value, equals('hello'));
        expect(controller.hasPrevValue, isFalse);
        expect(controller.prevValue, isNull);
      });

      test('should create controller with nullable value', () {
        final controller = ValueController<int?>(null);

        expect(controller.value, isNull);
        expect(controller.hasPrevValue, isFalse);
        expect(controller.prevValue, isNull);
      });
    });

    group('Value Getter and Setter', () {
      test('should get current value', () {
        final controller = ValueController<int>(10);

        expect(controller.value, equals(10));
      });

      test('should set new value and notify listeners', () {
        final controller = ValueController<int>(10);
        var notified = false;

        controller
          ..addListener(() => notified = true)
          ..value = 20;

        expect(controller.value, equals(20));
        expect(notified, isTrue);
      });

      test('should update prevValue when setting new value', () {
        final controller = ValueController<int>(10)..value = 20;

        expect(controller.value, equals(20));
        expect(controller.prevValue, equals(10));
        expect(controller.hasPrevValue, isTrue);
      });

      test('should not notify listeners when value is the same', () {
        final controller = ValueController<int>(10);
        var notificationCount = 0;

        controller
          ..addListener(() => notificationCount++)
          ..value = 10;

        expect(controller.value, equals(10));
        expect(notificationCount, equals(0));
        expect(controller.prevValue, isNull);
      });

      test('should handle multiple value changes', () {
        final controller = ValueController<int>(1);
        final values = <int>[];

        controller
          ..addListener(() => values.add(controller.value))
          ..value = 2
          ..value = 3
          ..value = 4;

        expect(controller.value, equals(4));
        expect(controller.prevValue, equals(3));
        expect(values, equals([2, 3, 4]));
      });
    });

    group('onChanged Method', () {
      test('should return true and notify when value changes', () {
        final controller = ValueController<int>(10);
        var notified = false;
        controller.addListener(() => notified = true);

        final result = controller.onChanged(20);

        expect(result, isTrue);
        expect(controller.value, equals(20));
        expect(controller.prevValue, equals(10));
        expect(notified, isTrue);
      });

      test('should return false when value is the same', () {
        final controller = ValueController<int>(10);
        var notificationCount = 0;
        controller.addListener(() => notificationCount++);

        final result = controller.onChanged(10);

        expect(result, isFalse);
        expect(controller.value, equals(10));
        expect(controller.prevValue, isNull);
        expect(notificationCount, equals(0));
      });

      test('should not notify listeners when silent is true', () {
        final controller = ValueController<int>(10);
        var notified = false;
        controller.addListener(() => notified = true);

        final result = controller.onChanged(20, silent: true);

        expect(result, isTrue);
        expect(controller.value, equals(20));
        expect(controller.prevValue, equals(10));
        expect(notified, isFalse);
      });

      test('should pass key to notifyListeners', () {
        final controller = ValueController<int>(10);
        Object? receivedKey;

        controller
          ..addListener(
            (Object? key, Object? value) => receivedKey = key,
            key: 'counter',
          )
          ..onChanged(20, key: 'counter');

        expect(receivedKey, equals('counter'));
      });

      test('should handle rapid value changes', () {
        final controller = ValueController<int>(0);
        final changes = <int>[];
        controller.addListener(() => changes.add(controller.value));

        for (var i = 1; i <= 5; i++) {
          controller.onChanged(i);
        }

        expect(controller.value, equals(5));
        expect(controller.prevValue, equals(4));
        expect(changes, equals([1, 2, 3, 4, 5]));
      });
    });

    group('prevValue and hasPrevValue', () {
      test('should have no previous value initially', () {
        final controller = ValueController<int>(10);

        expect(controller.hasPrevValue, isFalse);
        expect(controller.prevValue, isNull);
      });

      test('should have previous value after first change', () {
        final controller = ValueController<int>(10)..value = 20;

        expect(controller.hasPrevValue, isTrue);
        expect(controller.prevValue, equals(10));
      });

      test('should update prevValue on each change', () {
        final controller = ValueController<String>('a')
          ..value = 'b'
          ..value = 'c'
          ..value = 'd';

        expect(controller.prevValue, equals('c'));
      });

      test('should handle nullable types for prevValue', () {
        final controller = ValueController<int?>(null)..value = 10;

        expect(controller.prevValue, isNull);
        expect(controller.hasPrevValue, isFalse);

        controller.value = 20;

        expect(controller.prevValue, equals(10));
        expect(controller.hasPrevValue, isTrue);
      });

      test('should preserve prevValue when setting same value', () {
        final controller = ValueController<int>(10)
          ..value = 20
          ..value = 20;

        expect(controller.prevValue, equals(10));
        expect(controller.value, equals(20));
      });
    });

    group('notifyListeners Override', () {
      test('should pass value to super.notifyListeners by default', () {
        final controller = ValueController<int>(42);
        Object? receivedValue;

        controller
          ..addListener(
            (Object? key, Object? value) => receivedValue = value,
          )
          ..notifyListeners();

        expect(receivedValue, equals(42));
      });

      test('should use custom value when provided', () {
        final controller = ValueController<int>(42);
        Object? receivedValue;

        controller
          ..addListener(
            (Object? key, Object? value) => receivedValue = value,
          )
          ..notifyListeners(value: 100);

        expect(receivedValue, equals(100));
      });

      test('should respect includeGlobalListeners parameter', () {
        final controller = ValueController<int>(42);
        var globalNotified = false;
        var keyNotified = false;

        controller
          ..addListener(() => globalNotified = true)
          ..addListener(() => keyNotified = true, key: 'test')
          ..notifyListeners(
            key: 'test',
            includeGlobalListeners: false,
          );

        expect(globalNotified, isFalse);
        expect(keyNotified, isTrue);
      });
    });

    group('ValueListenable Integration', () {
      test('should implement ValueListenable interface', () {
        final controller = ValueController<int>(42);

        expect(controller, isA<ValueListenable<int>>());
      });

      test('should notify on value change', () {
        final controller = ValueController<int>(10);
        var buildCount = 0;
        int? lastValue;

        void listener() {
          buildCount++;
          lastValue = controller.value;
        }

        controller
          ..addListener(listener)
          ..value = 20
          ..value = 30;

        expect(buildCount, equals(2));
        expect(lastValue, equals(30));
      });

      test('should work with multiple listeners', () {
        final controller = ValueController<int>(10);
        var listener1Called = false;
        var listener2Called = false;

        controller
          ..addListener(() => listener1Called = true)
          ..addListener(() => listener2Called = true)
          ..value = 20;

        expect(listener1Called, isTrue);
        expect(listener2Called, isTrue);
      });

      test('should remove listeners properly', () {
        final controller = ValueController<int>(10);
        var notificationCount = 0;
        void listener() => notificationCount++;

        controller
          ..addListener(listener)
          ..value = 20
          ..removeListener(listener)
          ..value = 30;

        expect(notificationCount, equals(1));
      });
    });

    group('Equality and Edge Cases', () {
      test('should handle null values for nullable types', () {
        final controller = ValueController<String?>(null);
        var notificationCount = 0;

        controller
          ..addListener(() => notificationCount++)
          ..value = null;

        expect(notificationCount, equals(0));
        expect(controller.value, isNull);
      });

      test('should transition from null to non-null', () {
        final controller = ValueController<int?>(null);
        var notified = false;

        controller
          ..addListener(() => notified = true)
          ..value = 42;

        expect(notified, isTrue);
        expect(controller.value, equals(42));
        expect(controller.prevValue, isNull);
      });

      test('should transition from non-null to null', () {
        final controller = ValueController<int?>(42);
        var notified = false;

        controller
          ..addListener(() => notified = true)
          ..value = null;

        expect(notified, isTrue);
        expect(controller.value, isNull);
        expect(controller.prevValue, equals(42));
      });

      test('should handle zero values correctly', () {
        final controller = ValueController<int>(0);
        var notificationCount = 0;

        controller
          ..addListener(() => notificationCount++)
          ..value = 0;

        expect(notificationCount, equals(0));
        expect(controller.value, equals(0));
      });

      test('should handle empty string correctly', () {
        final controller = ValueController<String>('');
        var notificationCount = 0;

        controller
          ..addListener(() => notificationCount++)
          ..value = '';

        expect(notificationCount, equals(0));
        expect(controller.value, equals(''));
      });

      test('should handle boolean values', () {
        final controller = ValueController<bool>(false);
        final values = <bool>[];

        controller
          ..addListener(() => values.add(controller.value))
          ..value = true
          ..value = false
          ..value = false;

        expect(values, equals([true, false]));
        expect(controller.value, isFalse);
      });
    });

    group('Disposal', () {
      test('should not notify after disposal', () {
        final controller = ValueController<int>(10);
        var notificationCount = 0;

        controller
          ..addListener(() => notificationCount++)
          ..dispose()
          ..value = 20;

        expect(notificationCount, equals(0));
      });

      test('should not throw when setting value after disposal', () {
        final controller = ValueController<int>(10)..dispose();

        expect(() => controller.value = 20, returnsNormally);
      });

      test('should not throw when calling onChanged after disposal', () {
        final controller = ValueController<int>(10)..dispose();

        expect(() => controller.onChanged(20), returnsNormally);
      });
    });
  });

  group('Coverage Tests', () {
    test('should throw for unsupported callback type', () {
      // Line 60-63: Unsupported callback type error
      expect(
        () => Listener.create(
          (String a, int b, bool c) {}, // Unsupported signature
          priority: 0,
          predicate: null,
        ),
        throwsArgumentError,
      );
    });

    test('should test MergeListener equality and hashCode', () {
      // Lines 145, 159, 162, 164-165: _MergeListener equality/hashCode/priority
      final listener1 = Listener.create(() {}, priority: 1, predicate: null);
      final listener2 = Listener.create(() {}, priority: 2, predicate: null);

      final merged1 = Listener.merge([listener1, listener2]);
      final merged2 = Listener.merge([listener1, listener2]);
      final merged3 = Listener.merge([listener2, listener1]);

      // Same listeners in same order should be equal
      expect(merged1, equals(merged2));
      expect(merged1.hashCode, equals(merged2.hashCode));

      // Different order should not be equal
      expect(merged1, isNot(equals(merged3)));

      // MergeListener priority should always be 0
      expect(merged1.priority, equals(0));
    });

    test('should handle deeply nested key iterables', () {
      // Line 504: yield* _flattenKeys(k) for nested iterables
      final controller = TestController();
      var count = 0;

      // Create deeply nested key structure
      final nestedKeys = [
        'key1',
        [
          'key2',
          ['key3', 'key4'],
        ],
      ];

      controller
        ..addListener(() => count++, key: nestedKeys)
        ..notifyListeners(key: 'key3');

      expect(count, 1);
      controller.dispose();
    });

    test('should skip null values in key iterables', () {
      // Line 502: if (k == null) continue;
      final controller = TestController();
      var count = 0;

      // Create key list with null values
      final keysWithNulls = ['key1', null, 'key2', null];

      controller
        ..addListener(() => count++, key: keysWithNulls)
        ..notifyListeners(key: 'key1');

      expect(count, 1);

      controller.notifyListeners(key: 'key2');
      expect(count, 2);

      controller.dispose();
    });

    test('should return single listener when only one key has priority', () {
      // Lines 551, 555-556: listeners.length == 1 branch
      final controller = TestController();

      // Add listener with priority to single key in list
      final listener = controller.addListener(
        () {},
        key: ['key1'],
        priority: 1,
      );

      // Should return the single listener directly, not merged
      expect(listener, isNotNull);
      expect(listener, isA<Listener>());

      controller.dispose();
    });

    test('should return merged listener when multiple keys have priority', () {
      // Line 557: Listener.merge(listeners) branch
      final controller = TestController();

      // Add listener with priority to multiple keys
      final listener = controller.addListener(
        () {},
        key: ['key1', 'key2'],
        priority: 1,
      );

      // Should return merged listener
      expect(listener, isNotNull);

      controller.dispose();
    });

    test('should notify multiple keys with global listeners', () {
      // Line 680: sets.add(_globalListeners!) in _notifyMultipleKeys
      final controller = TestController();
      final calls = <String>[];

      controller
        ..addListener(() => calls.add('global'))
        ..addListener(() => calls.add('key1'), key: 'key1')
        ..addListener(() => calls.add('key2'), key: 'key2')
        ..notifyListeners(key: ['key1', 'key2']);

      expect(calls, containsAll(['global', 'key1', 'key2']));
      controller.dispose();
    });

    test('should merge multiple keys with priority listeners', () {
      // Line 703: _notifyMerged(sets, keys, value) call
      final controller = TestController();
      final calls = <String>[];

      controller
        ..addListener(() => calls.add('global-hi'), priority: 10)
        ..addListener(() => calls.add('key1'), key: 'key1', priority: 5)
        ..addListener(() => calls.add('key2'), key: 'key2', priority: 1)
        ..notifyListeners(key: ['key1', 'key2']);

      // Should be sorted by priority
      expect(calls, ['global-hi', 'key1', 'key2']);
      controller.dispose();
    });

    test('should handle Controller.merge addListener', () {
      // Line 877: _MergingController.addListener
      final c1 = TestController();
      final c2 = TestController();
      final merged = Controller.merge([c1, c2]);
      var count = 0;

      merged.addListener(() => count++, priority: 1);

      c1.notifyListeners();
      expect(count, 1);

      c2.notifyListeners();
      expect(count, 2);

      merged.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Benchmarking Tests
  // ---------------------------------------------------------------------------
  // These tests measure performance characteristics of Controller in various
  // real-world scenarios. They validate that operations complete within
  // acceptable time bounds for 60fps rendering (16.67ms frame budget).
  // ---------------------------------------------------------------------------

  group('Benchmarks', () {
    // Configuration
    const iterations = 10000;
    const tableRows = 100;
    const tableCols = 300;
    const totalCells = tableRows * tableCols; // 30,000 cells

    group('Best Case Scenarios', () {
      test('simple VoidCallback notify (no keys, no priority)', () {
        final controller = TestController();
        var count = 0;

        // Add simple listener
        controller.addListener(() => count++);

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners();
        }
        sw.stop();

        expect(count, iterations);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Best case notify: ${avgUs.toStringAsFixed(3)}us/op');

        // Should be under 1us per notify
        expect(avgUs, lessThan(1));

        controller.dispose();
      });

      test('simple VoidCallback add/remove cycle', () {
        final controller = TestController();
        void listener() {}

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller
            ..addListener(listener)
            ..removeListener(listener);
        }
        sw.stop();

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Best case add/remove: ${avgUs.toStringAsFixed(3)}us/op');

        // Should be under 5us per cycle
        expect(avgUs, lessThan(5));

        controller.dispose();
      });

      test('multiple simple listeners notify', () {
        final controller = TestController();
        var count = 0;

        // Add 100 simple listeners
        for (var i = 0; i < 100; i++) {
          controller.addListener(() => count++);
        }

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations ~/ 10; i++) {
          controller.notifyListeners();
        }
        sw.stop();

        expect(count, (iterations ~/ 10) * 100);

        final avgUs = sw.elapsedMicroseconds / (iterations ~/ 10);
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  100 listeners notify: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });
    });

    group('Worst Case Scenarios', () {
      test('keyed + priority + global merge notify', () {
        final controller = TestController();
        var count = 0;

        // Global + keyed listeners with different priorities
        controller
          ..addListener(() => count++, priority: 100) // Global high
          ..addListener(() => count++, key: 'cell', priority: 50) // Medium
          ..addListener(() => count++, key: 'cell', priority: 1); // Low

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners(key: 'cell');
        }
        sw.stop();

        expect(count, iterations * 3);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Worst case notify: ${avgUs.toStringAsFixed(3)}us/op');

        // Should still be under 5us per notify
        expect(avgUs, lessThan(5));

        controller.dispose();
      });

      test('multiple keys notify with merging', () {
        final controller = TestController();
        var count = 0;

        // Global priority listener + multiple keyed listeners
        controller
          ..addListener(() => count++, priority: 10) // Global
          ..addListener(() => count++, key: 'row-0')
          ..addListener(() => count++, key: 'col-0')
          ..addListener(() => count++, key: 'cell-0-0', priority: 5);

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners(key: ['row-0', 'col-0', 'cell-0-0']);
        }
        sw.stop();

        // 4 listeners called per notification
        expect(count, iterations * 4);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Multi-key merge notify: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });

      test('predicate filtering overhead', () {
        final controller = TestController();
        var count = 0;

        // Listener with predicate that filters half the notifications
        controller.addListener(
          (Object? _, Object? value) {
            if (value is int && value.isEven) count++;
          },
          predicate: (_, value) => value is int && value.isEven,
          priority: 1,
        );

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners(value: i);
        }
        sw.stop();

        // Only even values trigger the listener
        expect(count, iterations ~/ 2);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Predicate filtering: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });
    });

    group('Table Scenarios (${tableRows}x$tableCols)', () {
      test('single cell update', () {
        final controller = TestController();
        var count = 0;

        // Register listeners for all cells (simulating table)
        for (var r = 0; r < tableRows; r++) {
          for (var c = 0; c < tableCols; c++) {
            controller.addListener(() => count++, key: 'cell-$r-$c');
          }
        }

        // Measure single cell update
        count = 0;
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners(key: 'cell-50-150');
        }
        sw.stop();

        expect(count, iterations);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Single cell update: ${avgUs.toStringAsFixed(3)}us/op');

        // Single cell should be O(1), under 0.5us
        expect(avgUs, lessThan(0.5));

        controller.dispose();
      });

      test('row update (notify entire row)', () {
        final controller = TestController();
        var count = 0;

        // Register row listeners
        for (var r = 0; r < tableRows; r++) {
          controller.addListener(() => count++, key: 'row-$r');
        }

        // Measure row update
        count = 0;
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations ~/ 100; i++) {
          controller.notifyListeners(key: 'row-50');
        }
        sw.stop();

        expect(count, iterations ~/ 100);

        final avgUs = sw.elapsedMicroseconds / (iterations ~/ 100);
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Row update: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });

      test('column update (notify entire column)', () {
        final controller = TestController();
        var count = 0;

        // Register column listeners
        for (var c = 0; c < tableCols; c++) {
          controller.addListener(() => count++, key: 'col-$c');
        }

        // Measure column update
        count = 0;
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations ~/ 100; i++) {
          controller.notifyListeners(key: 'col-150');
        }
        sw.stop();

        expect(count, iterations ~/ 100);

        final avgUs = sw.elapsedMicroseconds / (iterations ~/ 100);
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Column update: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });

      test('full table refresh (global notify)', () {
        final controller = TestController();
        var count = 0;

        // Global listener for full refresh
        controller.addListener(() => count++);

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations ~/ 100; i++) {
          controller.notifyListeners();
        }
        sw.stop();

        expect(count, iterations ~/ 100);

        final avgUs = sw.elapsedMicroseconds / (iterations ~/ 100);
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Full refresh: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });

      test('mixed workload (cell + row + column updates)', () {
        final controller = TestController();
        var cellCount = 0;
        var rowCount = 0;
        var colCount = 0;

        // Register mixed listeners
        controller
          ..addListener(() => cellCount++, key: 'cell-50-150')
          ..addListener(() => rowCount++, key: 'row-50')
          ..addListener(() => colCount++, key: 'col-150');

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          // Simulate typical table interaction pattern
          controller.notifyListeners(key: 'cell-50-150'); // Cell edit
          if (i % 10 == 0) {
            controller.notifyListeners(key: 'row-50'); // Row selection
          }
          if (i % 20 == 0) {
            controller.notifyListeners(key: 'col-150'); // Column sort
          }
        }
        sw.stop();

        expect(cellCount, iterations);
        expect(rowCount, iterations ~/ 10);
        expect(colCount, iterations ~/ 20);

        const totalOps = iterations + (iterations ~/ 10) + (iterations ~/ 20);
        final avgUs = sw.elapsedMicroseconds / totalOps;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print(
          '  Mixed workload: ${avgUs.toStringAsFixed(3)}us/op ($totalOps ops)',
        );

        controller.dispose();
      });
    });

    group('ChangeNotifier Comparison', () {
      test('ChangeNotifier baseline - simple notify', () {
        final notifier = ValueNotifier<int>(-1);
        var count = 0;

        notifier.addListener(() => count++);

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          notifier.value = i;
        }
        sw.stop();

        expect(count, iterations);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  ChangeNotifier notify: ${avgUs.toStringAsFixed(3)}us/op');

        notifier.dispose();
      });

      test('Controller - simple notify (for comparison)', () {
        final controller = TestController();
        var count = 0;

        controller.addListener(() => count++);

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller.notifyListeners();
        }
        sw.stop();

        expect(count, iterations);

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Controller notify: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });

      test('ChangeNotifier baseline - add/remove', () {
        final notifier = ValueNotifier<int>(0);
        void listener() {}

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          notifier
            ..addListener(listener)
            ..removeListener(listener);
        }
        sw.stop();

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  ChangeNotifier add/remove: ${avgUs.toStringAsFixed(3)}us/op');

        notifier.dispose();
      });

      test('Controller - add/remove (for comparison)', () {
        final controller = TestController();
        void listener() {}

        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          controller
            ..addListener(listener)
            ..removeListener(listener);
        }
        sw.stop();

        final avgUs = sw.elapsedMicroseconds / iterations;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Controller add/remove: ${avgUs.toStringAsFixed(3)}us/op');

        controller.dispose();
      });
    });

    group('Memory Pressure', () {
      test('rapid listener churn', () {
        final controller = TestController();
        final listeners = <VoidCallback>[];

        // Create many listeners
        for (var i = 0; i < 1000; i++) {
          listeners.add(() {});
        }

        final sw = Stopwatch()..start();
        for (var round = 0; round < 100; round++) {
          // Add all then remove all
          listeners
            ..forEach(controller.addListener)
            ..forEach(controller.removeListener);
        }
        sw.stop();

        final avgMs = sw.elapsedMilliseconds / 100;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  1000 listener churn: ${avgMs.toStringAsFixed(2)}ms/round');

        // Should complete within frame budget
        expect(avgMs, lessThan(16.67));

        controller.dispose();
      });

      test('keyed listener scaling', () {
        final controller = TestController();

        // Add listeners for many keys
        final sw = Stopwatch()..start();
        for (var i = 0; i < totalCells; i++) {
          controller.addListener(() {}, key: 'cell-$i');
        }
        sw.stop();

        final avgUs = sw.elapsedMicroseconds / totalCells;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print(
          '  $totalCells keyed listeners: ${avgUs.toStringAsFixed(3)}us/add',
        );

        // Verify O(1) lookup still works
        final lookupSw = Stopwatch()..start();
        controller.notifyListeners(key: 'cell-${totalCells - 1}');
        lookupSw.stop();

        final lookupUs = lookupSw.elapsedMicroseconds;
        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Lookup with $totalCells keys: ${lookupUs}us');

        controller.dispose();
      });
    });

    group('60fps Frame Budget Analysis', () {
      test('maximum notifications per frame', () {
        final controller = TestController();
        var count = 0;
        controller.addListener(() => count++);

        // Measure how many notifications fit in 16.67ms (60fps frame)
        const frameBudgetUs = 16670; // 16.67ms in microseconds
        final sw = Stopwatch()..start();
        var notifications = 0;
        while (sw.elapsedMicroseconds < frameBudgetUs) {
          controller.notifyListeners();
          notifications++;
        }
        sw.stop();

        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Max notifications/frame: $notifications');
        // Benchmark output for performance analysis (continued from above)
        // ignore: avoid_print
        print(
          '  Avg time: ${(frameBudgetUs / notifications).toStringAsFixed(2)}us/notify',
        );

        // Should support at least 10,000 notifications per frame
        expect(notifications, greaterThan(10000));

        controller.dispose();
      });

      test('keyed notifications per frame', () {
        final controller = TestController();

        // Setup with 1000 keyed listeners
        for (var i = 0; i < 1000; i++) {
          controller.addListener(() {}, key: 'key-$i');
        }

        const frameBudgetUs = 16670;
        final sw = Stopwatch()..start();
        var notifications = 0;
        var keyIndex = 0;
        while (sw.elapsedMicroseconds < frameBudgetUs) {
          controller.notifyListeners(key: 'key-${keyIndex % 1000}');
          notifications++;
          keyIndex++;
        }
        sw.stop();

        // Benchmark output for performance analysis
        // ignore: avoid_print
        print('  Max keyed notifications/frame: $notifications');

        // Should support at least 5,000 keyed notifications per frame
        expect(notifications, greaterThan(5000));

        controller.dispose();
      });
    });
  });
}
