import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/memoizer.dart';

void main() {
  group('Memoizer Tests |', () {
    tearDown(Memoizer.clearAll);

    group('run() |', () {
      test('should execute computation on first call', () async {
        var computationCount = 0;

        final result = await Memoizer.run('test', () async {
          computationCount++;
          return 'result';
        });

        expect(result, equals('result'));
        expect(computationCount, equals(1));
      });

      test('should return cached value on subsequent calls', () async {
        var computationCount = 0;

        await Memoizer.run('test', () async {
          computationCount++;
          return 'cached';
        });

        final result = await Memoizer.run<String>('test', () async {
          computationCount++;
          return 'new value';
        });

        expect(result, equals('cached'));
        expect(computationCount, equals(1));
      });

      test('should execute computation when forceRefresh is true', () async {
        var computationCount = 0;

        await Memoizer.run('test', () async {
          computationCount++;
          return 'first';
        });

        final result = await Memoizer.run<String>(
          'test',
          () async {
            computationCount++;
            return 'refreshed';
          },
          forceRefresh: true,
        );

        expect(result, equals('refreshed'));
        expect(computationCount, equals(2));
      });

      test('should expire cached value after TTL', () async {
        var computationCount = 0;

        await Memoizer.run(
          'test',
          () async {
            computationCount++;
            return 'first';
          },
          ttl: const Duration(milliseconds: 50),
        );

        // Wait for TTL to expire
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final result = await Memoizer.run<String>('test', () async {
          computationCount++;
          return 'second';
        });

        expect(result, equals('second'));
        expect(computationCount, equals(2));
      });

      test('should deduplicate in-flight requests', () async {
        var computationCount = 0;

        // Start two calls simultaneously
        final future1 = Memoizer.run('test', () async {
          computationCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'result';
        });

        final future2 = Memoizer.run<String>('test', () async {
          computationCount++;
          return 'different';
        });

        final results = await Future.wait([future1, future2]);

        expect(results[0], equals('result'));
        expect(results[1], equals('result'));
        expect(computationCount, equals(1));
      });

      test('should not cache errors by default', () async {
        var computationCount = 0;

        // First call fails
        try {
          await Memoizer.run<String>('test', () async {
            computationCount++;
            throw Exception('error');
          });
        } on Exception catch (_) {}

        // Second call should retry
        final result = await Memoizer.run<String>('test', () async {
          computationCount++;
          return 'success';
        });

        expect(result, equals('success'));
        expect(computationCount, equals(2));
      });

      test('should propagate errors from computation', () async {
        expect(
          () => Memoizer.run<String>(
            'test',
            () async => throw Exception('test error'),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should cache different values for different tags', () async {
        var computationCount = 0;

        final result1 = await Memoizer.run('tag1', () async {
          computationCount++;
          return 'value1';
        });

        final result2 = await Memoizer.run('tag2', () async {
          computationCount++;
          return 'value2';
        });

        expect(result1, equals('value1'));
        expect(result2, equals('value2'));
        expect(computationCount, equals(2));
      });

      test('should support dynamic tags for key-based caching', () async {
        Future<String> getProduct(String id) {
          return Memoizer.run('product-$id', () async => 'Product $id');
        }

        final p1 = await getProduct('123');
        final p2 = await getProduct('456');
        final p1Again = await getProduct('123');

        expect(p1, equals('Product 123'));
        expect(p2, equals('Product 456'));
        expect(p1Again, equals('Product 123'));
        expect(Memoizer.count(), equals(2));
      });
    });

    group('getValue() |', () {
      test('should return cached value', () async {
        await Memoizer.run('test', () async => 'value');

        expect(Memoizer.getValue<String>('test'), equals('value'));
      });

      test('should return null for unknown tag', () {
        expect(Memoizer.getValue<String>('unknown'), isNull);
      });

      test('should return null for expired value', () async {
        await Memoizer.run(
          'test',
          () async => 'expired',
          ttl: const Duration(milliseconds: 10),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(Memoizer.getValue<String>('test'), isNull);
      });
    });

    group('hasValue() |', () {
      test('should return true when cached', () async {
        await Memoizer.run('test', () async => 'value');

        expect(Memoizer.hasValue('test'), isTrue);
      });

      test('should return false for unknown tag', () {
        expect(Memoizer.hasValue('unknown'), isFalse);
      });

      test('should return false for expired value', () async {
        await Memoizer.run(
          'test',
          () async => 'value',
          ttl: const Duration(milliseconds: 10),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(Memoizer.hasValue('test'), isFalse);
      });
    });

    group('isPending() |', () {
      test('should return true during computation', () async {
        final future = Memoizer.run('test', () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'value';
        });

        expect(Memoizer.isPending('test'), isTrue);

        await future;

        expect(Memoizer.isPending('test'), isFalse);
      });

      test('should return false for unknown tag', () {
        expect(Memoizer.isPending('unknown'), isFalse);
      });
    });

    group('clear() |', () {
      test('should remove cached value', () async {
        await Memoizer.run('test', () async => 'value');

        Memoizer.clear('test');

        expect(Memoizer.getValue<String>('test'), isNull);
      });

      test('should allow new computation after clear', () async {
        var computationCount = 0;

        await Memoizer.run('test', () async {
          computationCount++;
          return 'first';
        });

        Memoizer.clear('test');

        final result = await Memoizer.run<String>('test', () async {
          computationCount++;
          return 'second';
        });

        expect(result, equals('second'));
        expect(computationCount, equals(2));
      });
    });

    group('clearAll() |', () {
      test('should remove all cached values', () async {
        await Memoizer.run('tag1', () async => 'value1');
        await Memoizer.run('tag2', () async => 'value2');

        Memoizer.clearAll();

        expect(Memoizer.getValue<String>('tag1'), isNull);
        expect(Memoizer.getValue<String>('tag2'), isNull);
        expect(Memoizer.count(), equals(0));
      });
    });

    group('count() |', () {
      test('should return number of cached entries', () async {
        await Memoizer.run('tag1', () async => 'value1');
        await Memoizer.run('tag2', () async => 'value2');

        expect(Memoizer.count(), equals(2));
      });

      test('should return 0 when empty', () {
        expect(Memoizer.count(), equals(0));
      });
    });

    group('tags |', () {
      test('should return all cached tags', () async {
        await Memoizer.run('tag1', () async => 'value1');
        await Memoizer.run('tag2', () async => 'value2');

        expect(Memoizer.tags, containsAll(['tag1', 'tag2']));
      });
    });

    group('removeExpired() |', () {
      test('should remove only expired entries', () async {
        await Memoizer.run(
          'expired',
          () async => 'value',
          ttl: const Duration(milliseconds: 10),
        );
        await Memoizer.run('valid', () async => 'value');

        await Future<void>.delayed(const Duration(milliseconds: 50));

        Memoizer.removeExpired();

        expect(Memoizer.getValue<String>('expired'), isNull);
        expect(Memoizer.getValue<String>('valid'), equals('value'));
        expect(Memoizer.count(), equals(1));
      });
    });
  });
}
