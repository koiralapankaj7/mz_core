import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/extensions.dart';

void main() {
  group('IterableMZX Tests |', () {
    group('toIndexedMap', () {
      test('should create map with indices as keys', () {
        final list = ['a', 'b', 'c'];
        final result = list.toIndexedMap((i) => 'item_$i');

        expect(result, {0: 'item_0', 1: 'item_1', 2: 'item_2'});
      });

      test('should handle empty iterable', () {
        final list = <String>[];
        final result = list.toIndexedMap((i) => 'item_$i');

        expect(result, isEmpty);
      });

      test('should handle single element', () {
        final list = ['only'];
        final result = list.toIndexedMap((i) => i * 10);

        expect(result, {0: 0});
      });
    });

    group('toMap', () {
      test('should convert iterable to map using function', () {
        final numbers = [1, 2, 3];
        final result = numbers.toMap((n) => MapEntry('key$n', n * 10));

        expect(result, {'key1': 10, 'key2': 20, 'key3': 30});
      });

      test('should handle duplicate keys by keeping last value', () {
        final numbers = [1, 2, 1];
        final result = numbers.toMap((n) => MapEntry('key', n));

        expect(result, {'key': 1}); // Last occurrence wins
      });

      test('should handle empty iterable', () {
        final list = <int>[];
        final result = list.toMap((n) => MapEntry('key$n', n));

        expect(result, isEmpty);
      });
    });

    group('firstWhereWithIndexOrNull', () {
      test('should return tuple with index and element when found', () {
        final numbers = [10, 20, 30, 40];
        final result = numbers.firstWhereWithIndexOrNull((n) => n > 25);

        expect(result, isNotNull);
        expect(result!.$1, 2); // index
        expect(result.$2, 30); // element
      });

      test('should return null when no element matches', () {
        final numbers = [10, 20, 30];
        final result = numbers.firstWhereWithIndexOrNull((n) => n > 100);

        expect(result, isNull);
      });

      test('should return first match when multiple elements match', () {
        final numbers = [10, 20, 30, 40];
        final result = numbers.firstWhereWithIndexOrNull((n) => n >= 20);

        expect(result!.$1, 1);
        expect(result.$2, 20);
      });

      test('should handle empty iterable', () {
        final list = <int>[];
        final result = list.firstWhereWithIndexOrNull((n) => true);

        expect(result, isNull);
      });
    });

    group('indexOf', () {
      test('should return index of first occurrence', () {
        final items = {'apple', 'banana', 'cherry'};
        expect(items.indexOf('banana'), greaterThanOrEqualTo(0));
      });

      test('should return -1 when value not found', () {
        final items = {'apple', 'banana'}.map((e) => e);
        expect(items.indexOf('grape'), -1);
      });

      test('should return first index for duplicate values', () {
        final numbers = [1, 2, 3, 2, 4].where((n) => true);
        expect(numbers.indexOf(2), 1);
      });

      test('should handle empty iterable', () {
        final iterable = <String>[].where((e) => true);
        expect(iterable.indexOf('test'), -1);
      });

      test('should find element in middle of iterable', () {
        final iterable = [1, 2, 3, 4, 5].where((n) => true);
        expect(iterable.indexOf(3), 2);
        expect(iterable.indexOf(5), 4);
      });
    });
  });

  group('ListMZX Tests |', () {
    group('removeFirstWhere', () {
      test('should remove and return first matching element', () {
        final items = [1, 2, 3, 4, 5];
        final removed = items.removeFirstWhere((n) => n > 3);

        expect(removed, 4);
        expect(items, [1, 2, 3, 5]);
      });

      test('should return null when no match found', () {
        final items = [1, 2, 3];
        final removed = items.removeFirstWhere((n) => n > 10);

        expect(removed, isNull);
        expect(items, [1, 2, 3]); // List unchanged
      });

      test('should remove only first occurrence', () {
        final items = [1, 2, 2, 3];
        final removed = items.removeFirstWhere((n) => n == 2);

        expect(removed, 2);
        expect(items, [1, 2, 3]);
      });

      test('should handle empty list', () {
        final items = <int>[];
        final removed = items.removeFirstWhere((n) => true);

        expect(removed, isNull);
      });
    });

    group('removeFirstWhere1', () {
      test('should return MapEntry with index and removed element', () {
        final items = ['a', 'b', 'c', 'd'];
        final removed = items.removeFirstWhere1((s) => s == 'c');

        expect(removed, isNotNull);
        expect(removed!.key, 2); // index
        expect(removed.value, 'c'); // element
        expect(items, ['a', 'b', 'd']);
      });

      test('should return null when no match found', () {
        final items = ['a', 'b'];
        final removed = items.removeFirstWhere1((s) => s == 'z');

        expect(removed, isNull);
        expect(items, ['a', 'b']); // List unchanged
      });

      test('should remove only first occurrence', () {
        final items = [1, 2, 2, 3];
        final removed = items.removeFirstWhere1((n) => n == 2);

        expect(removed!.key, 1);
        expect(removed.value, 2);
        expect(items, [1, 2, 3]);
      });
    });

    group('replaceFirst', () {
      test('should replace element when test returns non-null', () {
        final items = [1, 2, 3, 4];
        final index = items.replaceFirst((n) => n == 3 ? 10 : null);

        expect(index, 2);
        expect(items, [1, 2, 10, 4]);
      });

      test('should return -1 when no replacement occurs', () {
        final items = [1, 2, 3];
        final index = items.replaceFirst((n) => null);

        expect(index, -1);
        expect(items, [1, 2, 3]); // List unchanged
      });

      test('should replace only first matching element', () {
        final items = [1, 2, 2, 3];
        final index = items.replaceFirst((n) => n == 2 ? 20 : null);

        expect(index, 1);
        expect(items, [1, 20, 2, 3]);
      });

      test('should handle empty list', () {
        final items = <int>[];
        final index = items.replaceFirst((n) => 10);

        expect(index, -1);
      });
    });

    group('replaceAll', () {
      test('should replace existing items and add new ones', () {
        final list = [1, 2, 3]..replaceAll([2, 4]);

        expect(list, [1, 2, 3, 4]);
      });

      test('should only add items when none exist in list', () {
        final list = [1, 2]..replaceAll([3, 4]);

        expect(list, [1, 2, 3, 4]);
      });

      test('should replace all matching items', () {
        final list = [1, 2, 3]..replaceAll([1, 2, 3]);

        expect(list, [1, 2, 3]); // All replaced with same values
      });

      test('should handle empty items iterable', () {
        final list = [1, 2]..replaceAll([]);

        expect(list, [1, 2]); // Unchanged
      });

      test('should handle empty list', () {
        final list = <int>[]..replaceAll([1, 2]);

        expect(list, [1, 2]); // All added
      });
    });

    group('removeAll', () {
      test('should remove first occurrence by default', () {
        final list = [1, 2, 3, 2, 4, 2]..removeAll([2, 4]);

        expect(list, [1, 3, 2, 2]); // First 2 and first 4 removed
      });

      test('should remove all occurrences when firstOccurrences is false', () {
        final list = [1, 2, 3, 2, 4, 2]
          ..removeAll([2], firstOccurrences: false);

        expect(list, [1, 3, 4]); // All 2s removed
      });

      test('should handle items not in list', () {
        final list = [1, 2, 3]..removeAll([5, 6]);

        expect(list, [1, 2, 3]); // Unchanged
      });

      test('should handle empty items iterable', () {
        final list = [1, 2, 3]..removeAll([]);

        expect(list, [1, 2, 3]); // Unchanged
      });

      test('should remove multiple different items', () {
        final list = [1, 2, 3, 4, 5]..removeAll([1, 3, 5]);

        expect(list, [2, 4]);
      });

      test(
        'should remove all duplicates when firstOccurrences is false',
        () {
          final list = [1, 1, 2, 2, 3, 3]
            ..removeAll([1, 2], firstOccurrences: false);

          expect(list, [3, 3]);
        },
      );
    });
  });

  group('SetMZX Tests |', () {
    group('removeAndReturn', () {
      test('should remove and return element if present', () {
        final set = {1, 2, 3};
        final removed = set.removeAndReturn(2);

        expect(removed, 2);
        expect(set, {1, 3});
      });

      test('should return null when element not in set', () {
        final set = {1, 2, 3};
        final removed = set.removeAndReturn(5);

        expect(removed, isNull);
        expect(set, {1, 2, 3}); // Set unchanged
      });

      test('should handle empty set', () {
        final set = <int>{};
        final removed = set.removeAndReturn(1);

        expect(removed, isNull);
      });

      test('should use lookup to find actual element', () {
        final set = {'hello', 'world'};
        final removed = set.removeAndReturn('hello');

        expect(removed, 'hello');
        expect(set, {'world'});
      });
    });
  });

  group('IntMZX Tests |', () {
    group('fillTo', () {
      test('should create map from start to end index', () {
        final map = 0.fillTo(3, 'x');

        expect(map, {0: 'x', 1: 'x', 2: 'x', 3: 'x'});
      });

      test('should work with non-zero start', () {
        final map = 5.fillTo(7, true);

        expect(map, {5: true, 6: true, 7: true});
      });

      test('should handle single value range', () {
        final map = 3.fillTo(3, 'single');

        expect(map, {3: 'single'});
      });

      test('should handle different value types', () {
        final map = 1.fillTo(2, <String>[]);

        expect(map.length, 2);
        expect(map[1], isA<List<String>>());
        expect(map[2], isA<List<String>>());
      });
    });
  });

  group('NumMZX Tests |', () {
    group('toStringAsFixedFloor', () {
      test('should return 1 decimal place for integers', () {
        expect(5.0.toStringAsFixedFloor(2), '5.0');
        expect(10.0.toStringAsFixedFloor(3), '10.0');
      });

      test('should use specified decimal places for non-integers', () {
        expect(5.123.toStringAsFixedFloor(2), '5.12');
        expect(5.789.toStringAsFixedFloor(1), '5.8');
        expect(3.14159.toStringAsFixedFloor(3), '3.142');
      });

      test('should handle zero decimal places', () {
        expect(5.678.toStringAsFixedFloor(0), '6');
      });

      test('should work with negative numbers', () {
        expect((-5.0).toStringAsFixedFloor(2), '-5.0');
        expect((-5.123).toStringAsFixedFloor(2), '-5.12');
      });

      test('should handle very small decimal parts', () {
        expect(5.001.toStringAsFixedFloor(2), '5.00');
      });
    });
  });

  group('WidgetMZX Tests |', () {
    group('insertBetween', () {
      testWidgets('should insert widgets between elements', (tester) async {
        final widgets = <Widget>[
          const Text('A'),
          const Text('B'),
          const Text('C'),
        ];

        final result = widgets.insertBetween((i) => const SizedBox.shrink());

        expect(result.length, 5); // 3 texts + 2 separators
        expect(result[0], isA<Text>());
        expect(result[1], isA<SizedBox>());
        expect(result[2], isA<Text>());
        expect(result[3], isA<SizedBox>());
        expect(result[4], isA<Text>());
      });

      testWidgets('should handle single widget', (tester) async {
        final widgets = <Widget>[const Text('Only')];
        final result = widgets.insertBetween((i) => const SizedBox.shrink());

        expect(result.length, 1); // No separator for single widget
        expect(result[0], isA<Text>());
      });

      testWidgets('should handle empty iterable', (tester) async {
        final widgets = <Widget>[];
        final result = widgets.insertBetween((i) => const SizedBox.shrink());

        expect(result, isEmpty);
      });

      testWidgets('should pass correct index to builder', (tester) async {
        final widgets = <Widget>[
          const Text('A'),
          const Text('B'),
          const Text('C'),
        ];

        final result = widgets.insertBetween((i) => Text('sep$i'));

        expect((result[1] as Text).data, 'sep0');
        expect((result[3] as Text).data, 'sep1');
      });
    });
  });

  group('StringMZX Tests |', () {
    group('toCapitalizedWords', () {
      test('should convert camelCase to capitalized words', () {
        expect('helloWorld'.toCapitalizedWords(), 'Hello World');
        expect('myVariableName'.toCapitalizedWords(), 'My Variable Name');
      });

      test('should convert snake_case to capitalized words', () {
        expect('user_name'.toCapitalizedWords(), 'User Name');
        expect(
          'first_name_last_name'.toCapitalizedWords(),
          'First Name Last Name',
        );
      });

      test('should convert kebab-case to capitalized words', () {
        expect('api-key'.toCapitalizedWords(), 'Api Key');
        expect('http-request'.toCapitalizedWords(), 'Http Request');
      });

      test('should handle PascalCase', () {
        expect('HelloWorld'.toCapitalizedWords(), 'Hello World');
        expect('HTTPSConnection'.toCapitalizedWords(), 'H T T P S Connection');
      });

      test('should handle mixed formats', () {
        expect('API_Key-value'.toCapitalizedWords(), 'A P I Key Value');
      });

      test('should handle empty string', () {
        expect(''.toCapitalizedWords(), '');
      });

      test('should handle single word', () {
        expect('hello'.toCapitalizedWords(), 'Hello');
        expect('HELLO'.toCapitalizedWords(), 'H E L L O');
      });

      test('should handle multiple spaces', () {
        expect('hello  world'.toCapitalizedWords(), 'Hello World');
      });

      test('should handle strings with numbers', () {
        expect('value1Test2'.toCapitalizedWords(), 'Value1 Test2');
      });
    });
  });
}
