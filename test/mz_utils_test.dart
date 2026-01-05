import 'package:flutter_test/flutter_test.dart';
import 'package:mz_utils/mz_utils.dart';

void main() {
  group('mz_utils library exports', () {
    test('should create instances of exported classes', () {
      // Verify that key exports work by creating instances
      final logger = SimpleLogger();
      expect(logger, isA<SimpleLogger>());

      final list = ListenableList<int>();
      expect(list, isA<ListenableList<int>>());

      final set = ListenableSet<String>();
      expect(set, isA<ListenableSet<String>>());

      final throttler = Throttler(const Duration(milliseconds: 100));
      expect(throttler, isA<Throttler>());

      expect(LogLevel.values, isNotEmpty);
    });

    test('should access static methods', () {
      // Verify static classes are accessible
      EasyDebounce.debounce(
        'test',
        const Duration(milliseconds: 100),
        () {},
      );
      expect(EasyDebounce.count(), greaterThan(0));

      EasyDebounce.cancelAll();
      expect(EasyDebounce.count(), equals(0));
    });
  });
}
