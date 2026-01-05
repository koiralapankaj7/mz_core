import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:mz_utils/src/throttler.dart';

void main() {
  group('EasyDebounce Tests |', () {
    tearDown(EasyDebounce.cancelAll);

    test('should debounce callback execution', () async {
      var executed = false;

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
      );

      // Should not execute immediately
      expect(executed, isFalse);

      // Wait for debounce duration
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have executed
      expect(executed, isTrue);
    });

    test('should cancel previous debounce when called again', () async {
      var firstExecuted = false;
      var secondExecuted = false;

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => firstExecuted = true,
      );

      // Call again with same tag before first completes
      await Future<void>.delayed(const Duration(milliseconds: 50));

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => secondExecuted = true,
      );

      // Wait for both periods
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // First should be cancelled, second should execute
      expect(firstExecuted, isFalse);
      expect(secondExecuted, isTrue);
    });

    test('should execute immediately when duration is zero', () {
      var executed = false;

      EasyDebounce.debounce(
        'test',
        Duration.zero,
        () => executed = true,
      );

      // Should execute synchronously
      expect(executed, isTrue);
    });

    test('should fire callback immediately', () {
      var executed = false;

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
      );

      // Fire immediately
      EasyDebounce.fire('test');

      expect(executed, isTrue);
    });

    test('should not error when firing non-existent tag', () {
      expect(() => EasyDebounce.fire('nonexistent'), returnsNormally);
    });

    test('should cancel debounce operation', () async {
      var executed = false;

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
      );

      // Cancel before execution
      EasyDebounce.cancel('test');

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
    });

    test('should not error when cancelling non-existent tag', () {
      expect(() => EasyDebounce.cancel('nonexistent'), returnsNormally);
    });

    test('should cancel all debounce operations', () async {
      var first = false;
      var second = false;

      EasyDebounce.debounce(
        'first',
        const Duration(milliseconds: 100),
        () => first = true,
      );

      EasyDebounce.debounce(
        'second',
        const Duration(milliseconds: 100),
        () => second = true,
      );

      // Cancel all
      EasyDebounce.cancelAll();

      // Wait to ensure neither executes
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('should count active operations', () {
      expect(EasyDebounce.count(), 0);

      EasyDebounce.debounce(
        'first',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(EasyDebounce.count(), 1);

      EasyDebounce.debounce(
        'second',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(EasyDebounce.count(), 2);

      EasyDebounce.cancel('first');

      expect(EasyDebounce.count(), 1);

      EasyDebounce.cancelAll();

      expect(EasyDebounce.count(), 0);
    });

    test('should check if operation is active', () {
      expect(EasyDebounce.isActive('test'), isFalse);

      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(EasyDebounce.isActive('test'), isTrue);

      EasyDebounce.cancel('test');

      expect(EasyDebounce.isActive('test'), isFalse);
    });

    test('should handle multiple operations with different tags', () async {
      var first = false;
      var second = false;
      var third = false;

      EasyDebounce.debounce(
        'first',
        const Duration(milliseconds: 50),
        () => first = true,
      );

      EasyDebounce.debounce(
        'second',
        const Duration(milliseconds: 100),
        () => second = true,
      );

      EasyDebounce.debounce(
        'third',
        const Duration(milliseconds: 150),
        () => third = true,
      );

      // Wait for all to complete
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(first, isTrue);
      expect(second, isTrue);
      expect(third, isTrue);
    });
  });

  group('Throttler Tests |', () {
    test('should throttle with immediate call', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var callCount = 0;

      // First call should execute immediately
      throttler.call(() => callCount++);
      expect(callCount, 1);
      expect(throttler.isBusy, isTrue);

      // Second call during throttle should be queued
      throttler.call(() => callCount++);
      expect(callCount, 1); // Still 1, second call queued

      // Wait for throttle to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Queued call should have executed
      expect(callCount, 2);
      expect(throttler.isBusy, isFalse);

      throttler.dispose();
    });

    test('should throttle without immediate call', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var callCount = 0;

      // First call should not execute immediately
      throttler.call(() => callCount++, immediateCall: false);
      expect(callCount, 0);
      expect(throttler.isBusy, isTrue);

      // Wait for throttle
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(callCount, 1);
      expect(throttler.isBusy, isFalse);

      throttler.dispose();
    });

    test('should override action with latest call', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var value = 0;

      throttler
        ..call(() => value = 1)
        ..call(() => value = 2)
        ..call(() => value = 3);

      // Wait for throttle
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have executed the last action
      expect(value, 3);

      throttler.dispose();
    });

    test('should cancel pending action', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var executed = false;

      throttler
        ..call(() => executed = true, immediateCall: false)
        ..cancel();

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
      expect(throttler.isBusy, isFalse);

      throttler.dispose();
    });

    test('should dispose throttler', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var executed = false;

      throttler
        ..call(() => executed = true, immediateCall: false)
        ..dispose();

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
      expect(throttler.isBusy, isFalse);
    });

    test('should allow reuse after cancel', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var callCount = 0;

      throttler
        ..call(() => callCount++)
        ..cancel()
        // Use again
        ..call(() => callCount++);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(callCount, 2);

      throttler.dispose();
    });

    test('should handle rapid successive calls', () async {
      final throttler = Throttler(const Duration(milliseconds: 100));
      var finalValue = 0;

      // Make many rapid calls
      for (var i = 1; i <= 10; i++) {
        throttler.call(() => finalValue = i);
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have executed first immediately and last after throttle
      expect(finalValue, 10);

      throttler.dispose();
    });
  });

  group('AdvanceDebouncer Tests |', () {
    tearDown(AdvanceDebouncer.cancelAll);

    test('should debounce async function', () async {
      var executionCount = 0;

      final debounced = AdvanceDebouncer.debounce<String, int>(
        'test',
        (value) async {
          executionCount++;
          return 'Result: $value';
        },
        duration: const Duration(milliseconds: 100),
      );

      // Call multiple times
      final future1 = debounced(1);
      final future2 = debounced(2);
      final future3 = debounced(3);

      // First two should be cancelled
      final result1 = await future1;
      final result2 = await future2;
      final result3 = await future3;

      expect(result1, isNull); // Cancelled
      expect(result2, isNull); // Cancelled
      expect(result3, 'Result: 3'); // Executed
      expect(executionCount, 1); // Only executed once
    });

    test('should execute immediately with Duration.zero', () async {
      var executionCount = 0;

      final debounced = AdvanceDebouncer.debounce<String, int>(
        'test',
        (value) async {
          executionCount++;
          return 'Result: $value';
        },
        duration: Duration.zero,
      );

      final result = await debounced(42);

      expect(result, 'Result: 42');
      expect(executionCount, 1);
    });

    test('should fire debounced function immediately', () async {
      final debounced = AdvanceDebouncer.debounce<String, int>(
        'test',
        (value) async => 'Result: $value',
        duration: const Duration(milliseconds: 100),
      );

      // Start a debounce
      unawaited(debounced(5));

      // Fire immediately
      final fireFunc = AdvanceDebouncer.fire<String, int>('test');
      final result = await fireFunc(10);

      expect(result, 'Result: 10');
    });

    test('should return null when firing non-existent tag', () async {
      final fireFunc = AdvanceDebouncer.fire<String, int>('nonexistent');
      final result = await fireFunc(42);

      expect(result, isNull);
    });

    test('should cancel debounce operation', () async {
      var executed = false;

      final debounced = AdvanceDebouncer.debounce<void, int>(
        'test',
        (value) async {
          executed = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced(42));

      // Cancel before execution
      AdvanceDebouncer.cancel('test');

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
    });

    test('should cancel all operations', () async {
      var first = false;
      var second = false;

      final debounced1 = AdvanceDebouncer.debounce<void, int>(
        'first',
        (value) async {
          first = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      final debounced2 = AdvanceDebouncer.debounce<void, int>(
        'second',
        (value) async {
          second = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced1(1));
      unawaited(debounced2(2));

      AdvanceDebouncer.cancelAll();

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('should count active operations', () async {
      expect(AdvanceDebouncer.count(), 0);

      final debounced1 = AdvanceDebouncer.debounce<void, int>(
        'first',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      final debounced2 = AdvanceDebouncer.debounce<void, int>(
        'second',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced1(1));
      expect(AdvanceDebouncer.count(), 1);

      unawaited(debounced2(2));
      expect(AdvanceDebouncer.count(), 2);

      AdvanceDebouncer.cancel('first');
      expect(AdvanceDebouncer.count(), 1);

      AdvanceDebouncer.cancelAll();
      expect(AdvanceDebouncer.count(), 0);
    });

    test('should check if operation is active', () async {
      expect(AdvanceDebouncer.isActive('test'), isFalse);

      final debounced = AdvanceDebouncer.debounce<void, int>(
        'test',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced(42));

      expect(AdvanceDebouncer.isActive('test'), isTrue);

      AdvanceDebouncer.cancel('test');

      expect(AdvanceDebouncer.isActive('test'), isFalse);
    });

    test('should handle null duration with default', () async {
      var executed = false;

      final debounced = AdvanceDebouncer.debounce<void, int>(
        'test',
        (value) async {
          executed = true;
        },
        // duration is null, should use default 500ms
      );

      unawaited(debounced(42));

      // Wait for default duration
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(executed, isTrue);
    });

    test('should handle type safety with generics', () async {
      final debounced = AdvanceDebouncer.debounce<List<String>, String>(
        'search',
        (query) async {
          return ['result1-$query', 'result2-$query'];
        },
        duration: const Duration(milliseconds: 50),
      );

      final result = await debounced('flutter');

      expect(result, isA<List<String>>());
      expect(result, ['result1-flutter', 'result2-flutter']);
    });

    test('should handle concurrent debounces with different tags', () async {
      var firstValue = 0;
      var secondValue = 0;

      final first = AdvanceDebouncer.debounce<void, int>(
        'first',
        (value) async {
          firstValue = value;
        },
        duration: const Duration(milliseconds: 50),
      );

      final second = AdvanceDebouncer.debounce<void, int>(
        'second',
        (value) async {
          secondValue = value;
        },
        duration: const Duration(milliseconds: 50),
      );

      unawaited(first(100));
      unawaited(second(200));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(firstValue, 100);
      expect(secondValue, 200);
    });

    test('should replace operation when same tag is reused', () async {
      var executionCount = 0;

      // Create first debounce
      final first = AdvanceDebouncer.debounce<String, int>(
        'shared-tag',
        (value) async {
          executionCount++;
          return 'First: $value';
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(first(1));

      // Create second debounce with same tag
      final second = AdvanceDebouncer.debounce<String, int>(
        'shared-tag',
        (value) async {
          executionCount++;
          return 'Second: $value';
        },
        duration: const Duration(milliseconds: 100),
      );

      final result = await second(2);

      expect(result, 'Second: 2');
      expect(executionCount, 1); // Only second should execute
    });
  });
}
