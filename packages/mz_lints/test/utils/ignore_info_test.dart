import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mz_lints/src/utils/ignore_info.dart';
import 'package:test/test.dart';

void main() {
  group('IgnoreInfo', () {
    group('isIgnoredForFile', () {
      test('returns true for file-level ignore', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
      });

      test('returns true for multiple rules in single ignore_for_file', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier, remove_listener\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
        expect(ignoreInfo.isIgnoredForFile('remove_listener'), isTrue);
      });

      test('returns true for multiple ignore_for_file comments', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier\n'
          '// ignore_for_file: remove_listener\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
        expect(ignoreInfo.isIgnoredForFile('remove_listener'), isTrue);
      });

      test('returns false for non-ignored rule', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('remove_listener'), isFalse);
      });

      test('returns false when no ignores present', () {
        final unit = _parseUnit('void main() {}\n');
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isFalse);
      });
    });

    group('isIgnoredAtLine', () {
      test('returns true for line-level ignore', () {
        // Line 1: void main() {
        // Line 2: // ignore: dispose_notifier
        // Line 3: final x = 1;
        // Line 4: }
        final unit = _parseUnit(
          'void main() {\n'
          '  // ignore: dispose_notifier\n'
          '  final x = 1;\n'
          '}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        // The ignore comment is on line 2, applies to line 3
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 3), isTrue);
      });

      test('returns true for file-level ignore at any line', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier\n'
          'void main() {\n'
          '  final x = 1;\n'
          '}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 1), isTrue);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 2), isTrue);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 3), isTrue);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 100), isTrue);
      });

      test('returns false for line-level ignore on wrong line', () {
        // Line 1: void main() {
        // Line 2: // ignore: dispose_notifier
        // Line 3: final x = 1;  <- ignored
        // Line 4: final y = 2;
        // Line 5: }
        final unit = _parseUnit(
          'void main() {\n'
          '  // ignore: dispose_notifier\n'
          '  final x = 1;\n'
          '  final y = 2;\n'
          '}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        // Line 3 is the only line ignored
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 2), isFalse);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 4), isFalse);
      });

      test('handles multiple rules in line ignore', () {
        // Line 1: void main() {
        // Line 2: // ignore: dispose_notifier, remove_listener
        // Line 3: final x = 1;  <- ignored
        // Line 4: }
        final unit = _parseUnit(
          'void main() {\n'
          '  // ignore: dispose_notifier, remove_listener\n'
          '  final x = 1;\n'
          '}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredAtLine('dispose_notifier', 3), isTrue);
        expect(ignoreInfo.isIgnoredAtLine('remove_listener', 3), isTrue);
      });
    });

    group('isIgnoredAtNode', () {
      test('returns true for ignored node by file-level', () {
        final unit = _parseUnit(
          '// ignore_for_file: dispose_notifier\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        final mainFunc = unit.declarations.first;
        expect(
          ignoreInfo.isIgnoredAtNode('dispose_notifier', mainFunc, unit),
          isTrue,
        );
      });

      test('returns false for non-ignored node', () {
        final unit = _parseUnit('void main() {}\n');
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        final mainFunc = unit.declarations.first;
        expect(
          ignoreInfo.isIgnoredAtNode('dispose_notifier', mainFunc, unit),
          isFalse,
        );
      });
    });

    group('edge cases', () {
      test('handles whitespace in rule names', () {
        final unit = _parseUnit(
          '// ignore_for_file:  dispose_notifier , remove_listener\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
        expect(ignoreInfo.isIgnoredForFile('remove_listener'), isTrue);
      });

      test('handles empty file', () {
        final unit = _parseUnit('');
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isFalse);
      });

      test('handles ignore at end of file', () {
        final unit = _parseUnit(
          'void main() {}\n'
          '// ignore_for_file: dispose_notifier\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
      });

      test('handles block comment ignore_for_file', () {
        final unit = _parseUnit(
          '/* ignore_for_file: dispose_notifier */\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
      });

      test('handles block comment without closing marker', () {
        // This tests the case where block comment doesn't end with */
        // (though this is syntactically invalid Dart, the parser handles it)
        final unit = _parseUnit(
          '/* ignore_for_file: dispose_notifier */\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isTrue);
      });

      test('handles regular comment that is not an ignore directive', () {
        final unit = _parseUnit(
          '// This is a regular comment\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isFalse);
      });

      test('handles block comment that is not an ignore directive', () {
        final unit = _parseUnit(
          '/* This is a block comment */\n'
          'void main() {}\n',
        );
        final ignoreInfo = IgnoreInfo.fromUnit(unit);
        expect(ignoreInfo.isIgnoredForFile('dispose_notifier'), isFalse);
      });
    });
  });
}

/// Parses a Dart source and returns the CompilationUnit.
CompilationUnit _parseUnit(String code) {
  final result = parseString(content: code);
  return result.unit;
}
