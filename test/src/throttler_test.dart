import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/debouncer.dart';
import 'package:mz_core/src/throttler.dart';

void main() {
  group('Debouncer Tests |', () {
    tearDown(Debouncer.cancelAll);

    test('should debounce callback execution', () async {
      var executed = false;

      Debouncer.debounce(
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

      Debouncer.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => firstExecuted = true,
      );

      // Call again with same tag before first completes
      await Future<void>.delayed(const Duration(milliseconds: 50));

      Debouncer.debounce(
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

      Debouncer.debounce(
        'test',
        Duration.zero,
        () => executed = true,
      );

      // Should execute synchronously
      expect(executed, isTrue);
    });

    test('should fire callback immediately', () {
      var executed = false;

      Debouncer.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
      );

      // Fire immediately
      Debouncer.fire('test');

      expect(executed, isTrue);
    });

    test('should not error when firing non-existent tag', () {
      expect(() => Debouncer.fire('nonexistent'), returnsNormally);
    });

    test('should cancel debounce operation', () async {
      var executed = false;

      Debouncer.debounce(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
      );

      // Cancel before execution
      Debouncer.cancel('test');

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
    });

    test('should not error when cancelling non-existent tag', () {
      expect(() => Debouncer.cancel('nonexistent'), returnsNormally);
    });

    test('should cancel all debounce operations', () async {
      var first = false;
      var second = false;

      Debouncer.debounce(
        'first',
        const Duration(milliseconds: 100),
        () => first = true,
      );

      Debouncer.debounce(
        'second',
        const Duration(milliseconds: 100),
        () => second = true,
      );

      // Cancel all
      Debouncer.cancelAll();

      // Wait to ensure neither executes
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('should count active operations', () {
      expect(Debouncer.count(), 0);

      Debouncer.debounce(
        'first',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(Debouncer.count(), 1);

      Debouncer.debounce(
        'second',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(Debouncer.count(), 2);

      Debouncer.cancel('first');

      expect(Debouncer.count(), 1);

      Debouncer.cancelAll();

      expect(Debouncer.count(), 0);
    });

    test('should check if operation is active', () {
      expect(Debouncer.isActive('test'), isFalse);

      Debouncer.debounce(
        'test',
        const Duration(milliseconds: 100),
        () {},
      );

      expect(Debouncer.isActive('test'), isTrue);

      Debouncer.cancel('test');

      expect(Debouncer.isActive('test'), isFalse);
    });

    test('should handle multiple operations with different tags', () async {
      var first = false;
      var second = false;
      var third = false;

      Debouncer.debounce(
        'first',
        const Duration(milliseconds: 50),
        () => first = true,
      );

      Debouncer.debounce(
        'second',
        const Duration(milliseconds: 100),
        () => second = true,
      );

      Debouncer.debounce(
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
    tearDown(Throttler.cancelAll);

    test('should throttle with immediate call', () async {
      var callCount = 0;

      // First call should execute immediately
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => callCount++,
      );
      expect(callCount, 1);
      expect(Throttler.isBusy('test'), isTrue);

      // Second call during throttle should be queued
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => callCount++,
      );
      expect(callCount, 1); // Still 1, second call queued

      // Wait for throttle to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Queued call should have executed
      expect(callCount, 2);
      expect(Throttler.isBusy('test'), isFalse);
    });

    test('should throttle without immediate call', () async {
      var callCount = 0;

      // First call should not execute immediately
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => callCount++,
        immediateCall: false,
      );
      expect(callCount, 0);
      expect(Throttler.isBusy('test'), isTrue);

      // Wait for throttle
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(callCount, 1);
      expect(Throttler.isBusy('test'), isFalse);
    });

    test('should override action with latest call', () async {
      var value = 0;

      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => value = 1,
      );
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => value = 2,
      );
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => value = 3,
      );

      // Wait for throttle
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have executed the last action
      expect(value, 3);
    });

    test('should cancel pending action', () async {
      var executed = false;

      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => executed = true,
        immediateCall: false,
      );
      Throttler.cancel('test');

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
      expect(Throttler.isBusy('test'), isFalse);
    });

    test('should cancel all throttlers', () async {
      var first = false;
      var second = false;

      Throttler.throttle(
        'first',
        const Duration(milliseconds: 100),
        () => first = true,
        immediateCall: false,
      );
      Throttler.throttle(
        'second',
        const Duration(milliseconds: 100),
        () => second = true,
        immediateCall: false,
      );
      Throttler.cancelAll();

      // Wait to ensure they don't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('should allow reuse after cancel', () async {
      var callCount = 0;

      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => callCount++,
      );
      Throttler.cancel('test');
      // Use again
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () => callCount++,
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(callCount, 2);
    });

    test('should handle rapid successive calls', () async {
      var finalValue = 0;

      // Make many rapid calls
      for (var i = 1; i <= 10; i++) {
        Throttler.throttle(
          'test',
          const Duration(milliseconds: 100),
          () => finalValue = i,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Should have executed first immediately and last after throttle
      expect(finalValue, 10);
    });

    test('should count active operations', () async {
      expect(Throttler.count(), 0);

      Throttler.throttle('first', const Duration(milliseconds: 100), () {});
      Throttler.throttle('second', const Duration(milliseconds: 100), () {});

      expect(Throttler.count(), 2);

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(Throttler.count(), 0);
    });

    test('should check if operation is active', () async {
      expect(Throttler.isActive('test'), isFalse);

      Throttler.throttle('test', const Duration(milliseconds: 100), () {});
      expect(Throttler.isActive('test'), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(Throttler.isActive('test'), isFalse);
    });

    test('should handle multiple operations with different tags', () async {
      var first = 0;
      var second = 0;

      Throttler.throttle(
        'first',
        const Duration(milliseconds: 50),
        () => first++,
      );
      Throttler.throttle(
        'second',
        const Duration(milliseconds: 100),
        () => second++,
      );

      // Both should execute immediately
      expect(first, 1);
      expect(second, 1);

      // Queue more
      Throttler.throttle(
        'first',
        const Duration(milliseconds: 50),
        () => first++,
      );
      Throttler.throttle(
        'second',
        const Duration(milliseconds: 100),
        () => second++,
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, 2);
      expect(second, 2);
    });
  });

  group('Debouncer Async Tests |', () {
    tearDown(Debouncer.cancelAll);

    test('should debounce async function', () async {
      var executionCount = 0;

      final debounced = Debouncer.debounceAsync<String, int>(
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

      final debounced = Debouncer.debounceAsync<String, int>(
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
      final debounced = Debouncer.debounceAsync<String, int>(
        'test',
        (value) async => 'Result: $value',
        duration: const Duration(milliseconds: 100),
      );

      // Start a debounce
      unawaited(debounced(5));

      // Fire immediately
      final fireFunc = Debouncer.fireAsync<String, int>('test');
      final result = await fireFunc(10);

      expect(result, 'Result: 10');
    });

    test('should return null when firing non-existent tag', () async {
      final fireFunc = Debouncer.fireAsync<String, int>('nonexistent');
      final result = await fireFunc(42);

      expect(result, isNull);
    });

    test('should cancel debounce operation', () async {
      var executed = false;

      final debounced = Debouncer.debounceAsync<void, int>(
        'test',
        (value) async {
          executed = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced(42));

      // Cancel before execution
      Debouncer.cancel('test');

      // Wait to ensure it doesn't execute
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(executed, isFalse);
    });

    test('should cancel all operations', () async {
      var first = false;
      var second = false;

      final debounced1 = Debouncer.debounceAsync<void, int>(
        'first',
        (value) async {
          first = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      final debounced2 = Debouncer.debounceAsync<void, int>(
        'second',
        (value) async {
          second = true;
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced1(1));
      unawaited(debounced2(2));

      Debouncer.cancelAll();

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('should count active operations', () async {
      expect(Debouncer.count(), 0);

      final debounced1 = Debouncer.debounceAsync<void, int>(
        'first',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      final debounced2 = Debouncer.debounceAsync<void, int>(
        'second',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced1(1));
      expect(Debouncer.count(), 1);

      unawaited(debounced2(2));
      expect(Debouncer.count(), 2);

      Debouncer.cancel('first');
      expect(Debouncer.count(), 1);

      Debouncer.cancelAll();
      expect(Debouncer.count(), 0);
    });

    test('should check if operation is active', () async {
      expect(Debouncer.isActive('test'), isFalse);

      final debounced = Debouncer.debounceAsync<void, int>(
        'test',
        (value) async {},
        duration: const Duration(milliseconds: 100),
      );

      unawaited(debounced(42));

      expect(Debouncer.isActive('test'), isTrue);

      Debouncer.cancel('test');

      expect(Debouncer.isActive('test'), isFalse);
    });

    test('should handle null duration with default', () async {
      var executed = false;

      final debounced = Debouncer.debounceAsync<void, int>(
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
      final debounced = Debouncer.debounceAsync<List<String>, String>(
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

      final first = Debouncer.debounceAsync<void, int>(
        'first',
        (value) async {
          firstValue = value;
        },
        duration: const Duration(milliseconds: 50),
      );

      final second = Debouncer.debounceAsync<void, int>(
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
      final first = Debouncer.debounceAsync<String, int>(
        'shared-tag',
        (value) async {
          executionCount++;
          return 'First: $value';
        },
        duration: const Duration(milliseconds: 100),
      );

      unawaited(first(1));

      // Create second debounce with same tag
      final second = Debouncer.debounceAsync<String, int>(
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
