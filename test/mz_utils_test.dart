import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/mz_core.dart';

void main() {
  group('mz_core library exports', () {
    test('should create instances of exported classes', () {
      // Verify that key exports work by creating instances
      final logger = SimpleLogger();
      expect(logger, isA<SimpleLogger>());

      final list = ListenableList<int>();
      expect(list, isA<ListenableList<int>>());

      final set = ListenableSet<String>();
      expect(set, isA<ListenableSet<String>>());

      expect(LogLevel.values, isNotEmpty);
    });

    test('should access static methods', () {
      // Verify static classes are accessible
      Debouncer.debounce(
        'test',
        const Duration(milliseconds: 100),
        () {},
      );
      expect(Debouncer.count(), greaterThan(0));

      Debouncer.cancelAll();
      expect(Debouncer.count(), equals(0));

      // Verify Throttler static API
      Throttler.throttle(
        'test',
        const Duration(milliseconds: 100),
        () {},
      );
      expect(Throttler.count(), greaterThan(0));

      Throttler.cancelAll();
      expect(Throttler.count(), equals(0));
    });
  });
}
