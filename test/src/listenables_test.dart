import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/listenables.dart';

void main() {
  group('ListenableList Tests |', () {
    group('Constructors -', () {
      test('should create empty list', () {
        final list = ListenableList<int>();
        expect(list.isEmpty, isTrue);
        expect(list.length, 0);
      });

      test('should create from existing list', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.length, 3);
        expect(list[0], 1);
        expect(list[2], 3);
      });

      test('should create from iterable', () {
        final list = ListenableList<int>.fromIterable({1, 2, 3});
        expect(list.length, 3);
        expect(list.contains(1), isTrue);
      });
    });

    group('Getters and Setters -', () {
      test('should get and set first element', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        expect(list.first, 1);

        list.first = 10;
        expect(list.first, 10);
        expect(notified, isTrue);
      });

      test('should get and set last element', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        expect(list.last, 3);

        list.last = 30;
        expect(list.last, 30);
        expect(notified, isTrue);
      });

      test('should set length and notify', () {
        final list = ListenableList<int?>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..length = 5;
        expect(list.length, 5);
        expect(notified, isTrue);
      });

      test('should not notify when setting same length', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..length = 3;
        expect(notified, isFalse);
      });

      test('should get isEmpty and isNotEmpty', () {
        final list = ListenableList<int>();
        expect(list.isEmpty, isTrue);
        expect(list.isNotEmpty, isFalse);

        list.add(1);
        expect(list.isEmpty, isFalse);
        expect(list.isNotEmpty, isTrue);
      });

      test('should get single element', () {
        final list = ListenableList<int>.from([42]);
        expect(list.single, 42);
      });

      test('should get reversed', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.reversed.toList(), [3, 2, 1]);
      });
    });

    group('Operators -', () {
      test('should access elements by index', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list[0], 1);
        expect(list[2], 3);
      });

      test('should set element by index and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        list[1] = 20;
        expect(list[1], 20);
        expect(notified, isTrue);
      });

      test('should concatenate lists with + operator', () {
        final list = ListenableList<int>.from([1, 2]);
        final result = list + [3, 4];
        expect(result, [1, 2, 3, 4]);
      });
    });

    group('Add Operations -', () {
      test('should add element and notify', () {
        final list = ListenableList<int>();
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..add(1);
        expect(list.length, 1);
        expect(list[0], 1);
        expect(notified, isTrue);
      });

      test('should add all elements and notify', () {
        final list = ListenableList<int>.from([1]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..addAll([2, 3]);
        expect(list.length, 3);
        expect(notified, isTrue);
      });

      test('should not notify when adding empty iterable', () {
        final list = ListenableList<int>.from([1]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..addAll([]);
        expect(notified, isFalse);
      });

      test('should insert element and notify', () {
        final list = ListenableList<int>.from([1, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..insert(1, 2);
        expect(list, [1, 2, 3]);
        expect(notified, isTrue);
      });

      test('should insert all elements and notify', () {
        final list = ListenableList<int>.from([1, 4]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..insertAll(1, [2, 3]);
        expect(list, [1, 2, 3, 4]);
        expect(notified, isTrue);
      });

      test('should not notify when inserting empty iterable', () {
        final list = ListenableList<int>.from([1]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..insertAll(0, []);
        expect(notified, isFalse);
      });
    });

    group('Remove Operations -', () {
      test('should remove element and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        final removed = list.remove(2);
        expect(removed, isTrue);
        expect(list, [1, 3]);
        expect(notified, isTrue);
      });

      test('should not notify when element not found', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        final removed = list.remove(5);
        expect(removed, isFalse);
        expect(notified, isFalse);
      });

      test('should remove at index and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        final value = list.removeAt(1);
        expect(value, 2);
        expect(list, [1, 3]);
        expect(notified, isTrue);
      });

      test('should remove last and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list.addListener(() => notified = true);

        final value = list.removeLast();
        expect(value, 3);
        expect(list, [1, 2]);
        expect(notified, isTrue);
      });

      test('should remove range and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..removeRange(1, 4);
        expect(list, [1, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when removing empty range', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..removeRange(1, 1);
        expect(notified, isFalse);
      });

      test('should remove where condition matches and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..removeWhere((e) => e.isEven);
        expect(list, [1, 3, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when removeWhere finds nothing', () {
        final list = ListenableList<int>.from([1, 3, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..removeWhere((e) => e.isEven);
        expect(notified, isFalse);
      });

      test('should retain where condition matches and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..retainWhere((e) => e.isOdd);
        expect(list, [1, 3, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when retainWhere keeps everything', () {
        final list = ListenableList<int>.from([1, 3, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..retainWhere((e) => e.isOdd);
        expect(notified, isFalse);
      });

      test('should clear and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..clear();
        expect(list.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when clearing empty list', () {
        final list = ListenableList<int>();
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..clear();
        expect(notified, isFalse);
      });
    });

    group('Modify Operations -', () {
      test('should fill range and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..fillRange(1, 4, 0);
        expect(list, [1, 0, 0, 0, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when filling empty range', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..fillRange(1, 1, 0);
        expect(notified, isFalse);
      });

      test('should replace range and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..replaceRange(1, 4, [10, 20]);
        expect(list, [1, 10, 20, 5]);
        expect(notified, isTrue);
      });

      test('should set all and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..setAll(1, [10, 20]);
        expect(list, [1, 10, 20, 4, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when setAll with empty iterable', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..setAll(1, []);
        expect(notified, isFalse);
      });

      test('should set range and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..setRange(1, 3, [10, 20, 30, 40]);
        expect(list, [1, 10, 20, 4, 5]);
        expect(notified, isTrue);
      });

      test('should not notify when setRange with empty iterable', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..setRange(1, 1, []);
        expect(notified, isFalse);
      });

      test('should shuffle and notify', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..shuffle(Random(42));
        expect(notified, isTrue);
      });

      test('should not notify when shuffling single element list', () {
        final list = ListenableList<int>.from([1]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..shuffle();
        expect(notified, isFalse);
      });

      test('should not notify when shuffling empty list', () {
        final list = ListenableList<int>();
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..shuffle();
        expect(notified, isFalse);
      });

      test('should sort and notify', () {
        final list = ListenableList<int>.from([3, 1, 2]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..sort();
        expect(list, [1, 2, 3]);
        expect(notified, isTrue);
      });
    });

    group('Query Operations -', () {
      test('should check contains', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.contains(2), isTrue);
        expect(list.contains(5), isFalse);
      });

      test('should find element at index', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.elementAt(1), 2);
      });

      test('should find index of element', () {
        final list = ListenableList<int>.from([1, 2, 3, 2]);
        expect(list.indexOf(2), 1);
        expect(list.indexOf(5), -1);
        expect(list.indexOf(2, 2), 3);
      });

      test('should find last index of element', () {
        final list = ListenableList<int>.from([1, 2, 3, 2]);
        expect(list.lastIndexOf(2), 3);
        expect(list.lastIndexOf(2, 2), 1);
      });

      test('should find index where condition matches', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.indexWhere((e) => e.isEven), 1);
        expect(list.indexWhere((e) => e > 10), -1);
      });

      test('should find last index where condition matches', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.lastIndexWhere((e) => e.isEven), 3);
      });

      test('should check any', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.any((e) => e.isEven), isTrue);
        expect(list.any((e) => e > 10), isFalse);
      });

      test('should check every', () {
        final list = ListenableList<int>.from([2, 4, 6]);
        expect(list.every((e) => e.isEven), isTrue);
        expect(list.every((e) => e > 3), isFalse);
      });

      test('should find first where', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.firstWhere((e) => e.isEven), 2);
        expect(list.firstWhere((e) => e > 10, orElse: () => -1), -1);
      });

      test('should find last where', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.lastWhere((e) => e.isEven), 4);
        expect(list.lastWhere((e) => e > 10, orElse: () => -1), -1);
      });

      test('should find single where', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.singleWhere((e) => e == 2), 2);
      });
    });

    group('Transform Operations -', () {
      test('should create as map', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final map = list.asMap();
        expect(map[0], 1);
        expect(map[2], 3);
      });

      test('should cast', () {
        final list = ListenableList<num>.from([1, 2, 3]);
        final intList = list.cast<int>();
        expect(intList, [1, 2, 3]);
      });

      test('should expand', () {
        final list = ListenableList<int>.from([1, 2]);
        final expanded = list.expand((e) => [e, e * 10]);
        expect(expanded.toList(), [1, 10, 2, 20]);
      });

      test('should fold', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final sum = list.fold<int>(0, (prev, e) => prev + e);
        expect(sum, 6);
      });

      test('should reduce', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final sum = list.reduce((a, b) => a + b);
        expect(sum, 6);
      });

      test('should follow by', () {
        final list = ListenableList<int>.from([1, 2]);
        final result = list.followedBy([3, 4]);
        expect(result.toList(), [1, 2, 3, 4]);
      });

      test('should for each', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final results = <int>[];
        list.forEach(results.add);
        expect(results, [1, 2, 3]);
      });

      test('should get range', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        expect(list.getRange(1, 4).toList(), [2, 3, 4]);
      });

      test('should get iterator', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final iter = list.iterator;
        expect(iter.moveNext(), isTrue);
        expect(iter.current, 1);
      });

      test('should join', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        expect(list.join(','), '1,2,3');
        expect(list.join(), '123');
      });

      test('should map', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final mapped = list.map((e) => e * 2);
        expect(mapped.toList(), [2, 4, 6]);
      });

      test('should skip', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.skip(2).toList(), [3, 4]);
      });

      test('should skip while', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.skipWhile((e) => e < 3).toList(), [3, 4]);
      });

      test('should sublist', () {
        final list = ListenableList<int>.from([1, 2, 3, 4, 5]);
        expect(list.sublist(1, 4), [2, 3, 4]);
        expect(list.sublist(2), [3, 4, 5]);
      });

      test('should take', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.take(2).toList(), [1, 2]);
      });

      test('should take while', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.takeWhile((e) => e < 3).toList(), [1, 2]);
      });

      test('should to list', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        final copy = list.toList();
        expect(copy, [1, 2, 3]);
        expect(copy.runtimeType, List<int>);
      });

      test('should to set', () {
        final list = ListenableList<int>.from([1, 2, 2, 3]);
        final set = list.toSet();
        expect(set, {1, 2, 3});
      });

      test('should where', () {
        final list = ListenableList<int>.from([1, 2, 3, 4]);
        expect(list.where((e) => e.isEven).toList(), [2, 4]);
      });

      test('should where type', () {
        final list = ListenableList<Object>.from([1, 'a', 2, 'b']);
        expect(list.whereType<int>().toList(), [1, 2]);
      });
    });

    group('Reset and Dispose -', () {
      test('should reset with new value and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..reset(value: [10, 20]);
        expect(list, [10, 20]);
        expect(notified, isTrue);
      });

      test('should reset to empty and notify', () {
        final list = ListenableList<int>.from([1, 2, 3]);
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..reset();
        expect(list.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when resetting empty list to null', () {
        final list = ListenableList<int>();
        var notified = false;
        list
          ..addListener(() => notified = true)
          ..reset();
        expect(notified, isFalse);
      });

      test('should dispose and clear', () {
        final list = ListenableList<int>.from([1, 2, 3])..dispose();
        expect(list.isEmpty, isTrue);
        expect(list.isDisposed, isTrue);
      });
    });
  });

  group('ListenableSet Tests |', () {
    group('Constructors -', () {
      test('should create empty set', () {
        final set = ListenableSet<int>();
        expect(set.isEmpty, isTrue);
        expect(set.length, 0);
      });

      test('should create from existing set', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.length, 3);
        expect(set.contains(2), isTrue);
      });

      test('should create from iterable', () {
        final set = ListenableSet<int>.fromIterable([1, 2, 2, 3]);
        expect(set.length, 3);
      });
    });

    group('Add Operations -', () {
      test('should add element and notify', () {
        final set = ListenableSet<int>();
        var notified = false;
        set.addListener(() => notified = true);

        final added = set.add(1);
        expect(added, isTrue);
        expect(set.contains(1), isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when adding duplicate', () {
        final set = ListenableSet<int>.from({1});
        var notified = false;
        set.addListener(() => notified = true);

        final added = set.add(1);
        expect(added, isFalse);
        expect(notified, isFalse);
      });

      test('should add all and notify', () {
        final set = ListenableSet<int>.from({1});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..addAll([2, 3]);
        expect(set.length, 3);
        expect(notified, isTrue);
      });

      test('should not notify when adding empty iterable', () {
        final set = ListenableSet<int>.from({1});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..addAll([]);
        expect(notified, isFalse);
      });
    });

    group('Remove Operations -', () {
      test('should remove element and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        var notified = false;
        set.addListener(() => notified = true);

        final removed = set.remove(2);
        expect(removed, isTrue);
        expect(set.contains(2), isFalse);
        expect(notified, isTrue);
      });

      test('should not notify when element not found', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        var notified = false;
        set.addListener(() => notified = true);

        final removed = set.remove(5);
        expect(removed, isFalse);
        expect(notified, isFalse);
      });

      test('should remove all and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..removeAll([2, 3]);
        expect(set, {1, 4});
        expect(notified, isTrue);
      });

      test('should not notify when removing empty iterable', () {
        final set = ListenableSet<int>.from({1, 2});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..removeAll([]);
        expect(notified, isFalse);
      });

      test('should remove where and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..removeWhere((e) => e.isEven);
        expect(set, {1, 3});
        expect(notified, isTrue);
      });

      test('should not notify when removeWhere finds nothing', () {
        final set = ListenableSet<int>.from({1, 3});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..removeWhere((e) => e.isEven);
        expect(notified, isFalse);
      });

      test('should retain all and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..retainAll([2, 3, 5]);
        expect(set, {2, 3});
        expect(notified, isTrue);
      });

      test('should not notify when retaining empty iterable', () {
        final set = ListenableSet<int>.from({1, 2});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..retainAll([]);
        expect(notified, isFalse);
      });

      test('should retain where and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..retainWhere((e) => e.isOdd);
        expect(set, {1, 3});
        expect(notified, isTrue);
      });

      test('should not notify when retainWhere keeps everything', () {
        final set = ListenableSet<int>.from({1, 3});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..retainWhere((e) => e.isOdd);
        expect(notified, isFalse);
      });

      test('should clear and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..clear();
        expect(set.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when clearing empty set', () {
        final set = ListenableSet<int>();
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..clear();
        expect(notified, isFalse);
      });
    });

    group('Query Operations -', () {
      test('should check contains', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.contains(2), isTrue);
        expect(set.contains(5), isFalse);
      });

      test('should check contains all', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.containsAll([2, 3]), isTrue);
        expect(set.containsAll([2, 5]), isFalse);
      });

      test('should get difference', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final diff = set.difference({2, 4});
        expect(diff, {1, 3});
      });

      test('should get intersection', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final inter = set.intersection({2, 3, 4});
        expect(inter, {2, 3});
      });

      test('should get union', () {
        final set = ListenableSet<int>.from({1, 2});
        final u = set.union({2, 3, 4});
        expect(u, {1, 2, 3, 4});
      });

      test('should lookup element', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.lookup(2), 2);
        expect(set.lookup(5), isNull);
      });

      test('should get element at index', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.elementAt(0), 1);
      });

      test('should check any', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.any((e) => e.isEven), isTrue);
        expect(set.any((e) => e > 10), isFalse);
      });

      test('should check every', () {
        final set = ListenableSet<int>.from({2, 4, 6});
        expect(set.every((e) => e.isEven), isTrue);
        expect(set.every((e) => e > 3), isFalse);
      });

      test('should get first', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.first, 1);
      });

      test('should get last', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.last, 3);
      });

      test('should get single', () {
        final set = ListenableSet<int>.from({42});
        expect(set.single, 42);
      });

      test('should find first where', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.firstWhere((e) => e.isEven), 2);
      });

      test('should find last where', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.lastWhere((e) => e.isEven), 4);
      });

      test('should find single where', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.singleWhere((e) => e == 2), 2);
      });

      test('should check isEmpty and isNotEmpty', () {
        final set = ListenableSet<int>();
        expect(set.isEmpty, isTrue);
        expect(set.isNotEmpty, isFalse);

        set.add(1);
        expect(set.isEmpty, isFalse);
        expect(set.isNotEmpty, isTrue);
      });

      test('should get length', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        expect(set.length, 3);
      });
    });

    group('Transform Operations -', () {
      test('should cast', () {
        final set = ListenableSet<num>.from({1, 2, 3});
        final intSet = set.cast<int>();
        expect(intSet, {1, 2, 3});
      });

      test('should expand', () {
        final set = ListenableSet<int>.from({1, 2});
        final expanded = set.expand((e) => [e, e * 10]);
        expect(expanded.toSet(), {1, 10, 2, 20});
      });

      test('should fold', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final sum = set.fold<int>(0, (prev, e) => prev + e);
        expect(sum, 6);
      });

      test('should reduce', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final sum = set.reduce((a, b) => a + b);
        expect(sum, 6);
      });

      test('should follow by', () {
        final set = ListenableSet<int>.from({1, 2});
        final result = set.followedBy([3, 4]);
        expect(result.toSet(), {1, 2, 3, 4});
      });

      test('should for each', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final results = <int>[];
        set.forEach(results.add);
        expect(results.length, 3);
      });

      test('should get iterator', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final iter = set.iterator;
        expect(iter.moveNext(), isTrue);
      });

      test('should join', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final joined = set.join(',');
        expect(joined.split(',').length, 3);
      });

      test('should map', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final mapped = set.map((e) => e * 2);
        expect(mapped.toSet(), {2, 4, 6});
      });

      test('should skip', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.skip(2).length, 2);
      });

      test('should skip while', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        final skipped = set.skipWhile((e) => e < 3);
        expect(skipped.toSet(), {3, 4});
      });

      test('should take', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.take(2).length, 2);
      });

      test('should take while', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        final taken = set.takeWhile((e) => e < 3);
        expect(taken.toSet(), {1, 2});
      });

      test('should to list', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final list = set.toList();
        expect(list.length, 3);
      });

      test('should to set', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        final copy = set.toSet();
        expect(copy, {1, 2, 3});
      });

      test('should where', () {
        final set = ListenableSet<int>.from({1, 2, 3, 4});
        expect(set.where((e) => e.isEven).toSet(), {2, 4});
      });

      test('should where type', () {
        final set = ListenableSet<Object>.from({1, 'a', 2, 'b'});
        expect(set.whereType<int>().toSet(), {1, 2});
      });
    });

    group('Reset and Dispose -', () {
      test('should reset with new value and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..reset(value: {10, 20});
        expect(set, {10, 20});
        expect(notified, isTrue);
      });

      test('should reset to empty and notify', () {
        final set = ListenableSet<int>.from({1, 2, 3});
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..reset();
        expect(set.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when resetting empty set to null', () {
        final set = ListenableSet<int>();
        var notified = false;
        set
          ..addListener(() => notified = true)
          ..reset();
        expect(notified, isFalse);
      });

      test('should dispose and clear', () {
        final set = ListenableSet<int>.from({1, 2, 3})..dispose();
        expect(set.isEmpty, isTrue);
        expect(set.isDisposed, isTrue);
      });
    });
  });

  group('ListenableMap Tests |', () {
    group('Constructors -', () {
      test('should create empty map', () {
        final map = ListenableMap<String, int>();
        expect(map.isEmpty, isTrue);
        expect(map.length, 0);
      });

      test('should create from existing map', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map.length, 2);
        expect(map['a'], 1);
      });

      test('should create from entries', () {
        final map = ListenableMap<String, int>.fromEntries([
          const MapEntry('a', 1),
          const MapEntry('b', 2),
        ]);
        expect(map.length, 2);
        expect(map['a'], 1);
      });
    });

    group('Operators -', () {
      test('should get value by key', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map['a'], 1);
        expect(map['c'], isNull);
      });

      test('should set value and notify', () {
        final map = ListenableMap<String, int>();
        var notified = false;
        map.addListener(() => notified = true);

        map['a'] = 1;
        expect(map['a'], 1);
        expect(notified, isTrue);
      });
    });

    group('Add Operations -', () {
      test('should add all and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..addAll({'b': 2, 'c': 3});
        expect(map.length, 3);
        expect(notified, isTrue);
      });

      test('should not notify when adding empty map', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..addAll({});
        expect(notified, isFalse);
      });

      test('should add entries and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..addEntries([const MapEntry('b', 2), const MapEntry('c', 3)]);
        expect(map.length, 3);
        expect(notified, isTrue);
      });

      test('should not notify when adding empty entries', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..addEntries([]);
        expect(notified, isFalse);
      });

      test('should put if absent and notify when key absent', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.putIfAbsent('b', () => 2);
        expect(value, 2);
        expect(map['b'], 2);
        expect(notified, isTrue);
      });

      test('should not notify when key already present', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.putIfAbsent('a', () => 10);
        expect(value, 1);
        expect(notified, isFalse);
      });
    });

    group('Remove Operations -', () {
      test('should remove key and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.remove('a');
        expect(value, 1);
        expect(map.containsKey('a'), isFalse);
        expect(notified, isTrue);
      });

      test('should not notify when key not found', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.remove('z');
        expect(value, isNull);
        expect(notified, isFalse);
      });

      test('should remove where and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..removeWhere((k, v) => v.isEven);
        expect(map, {'a': 1, 'c': 3});
        expect(notified, isTrue);
      });

      test('should not notify when removeWhere finds nothing', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'c': 3});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..removeWhere((k, v) => v.isEven);
        expect(notified, isFalse);
      });

      test('should clear and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..clear();
        expect(map.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when clearing empty map', () {
        final map = ListenableMap<String, int>();
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..clear();
        expect(notified, isFalse);
      });
    });

    group('Update Operations -', () {
      test('should update and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.update('a', (v) => v * 10);
        expect(value, 10);
        expect(map['a'], 10);
        expect(notified, isTrue);
      });

      test('should update with ifAbsent and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1});
        var notified = false;
        map.addListener(() => notified = true);

        final value = map.update('b', (v) => v * 10, ifAbsent: () => 2);
        expect(value, 2);
        expect(map['b'], 2);
        expect(notified, isTrue);
      });

      test('should update all and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..updateAll((k, v) => v * 10);
        expect(map, {'a': 10, 'b': 20});
        expect(notified, isTrue);
      });
    });

    group('Query Operations -', () {
      test('should check contains key', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map.containsKey('a'), isTrue);
        expect(map.containsKey('z'), isFalse);
      });

      test('should check contains value', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map.containsValue(1), isTrue);
        expect(map.containsValue(99), isFalse);
      });

      test('should check isEmpty and isNotEmpty', () {
        final map = ListenableMap<String, int>();
        expect(map.isEmpty, isTrue);
        expect(map.isNotEmpty, isFalse);

        map['a'] = 1;
        expect(map.isEmpty, isFalse);
        expect(map.isNotEmpty, isTrue);
      });

      test('should get length', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2, 'c': 3});
        expect(map.length, 3);
      });

      test('should get entries', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        final entries = map.entries.toList();
        expect(entries.length, 2);
        expect(entries.any((e) => e.key == 'a' && e.value == 1), isTrue);
      });

      test('should get keys', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map.keys.toSet(), {'a', 'b'});
      });

      test('should get values', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        expect(map.values.toSet(), {1, 2});
      });
    });

    group('Transform Operations -', () {
      test('should cast', () {
        final map = ListenableMap<String, num>.from({'a': 1, 'b': 2});
        final intMap = map.cast<String, int>();
        expect(intMap['a'], 1);
      });

      test('should for each', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        final results = <String>[];
        map.forEach((k, v) => results.add('$k:$v'));
        expect(results.length, 2);
      });

      test('should map', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        final mapped = map.map((k, v) => MapEntry(k, v * 10));
        expect(mapped, {'a': 10, 'b': 20});
      });
    });

    group('Reset and Dispose -', () {
      test('should reset with new value and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..reset(value: {'x': 10, 'y': 20});
        expect(map, {'x': 10, 'y': 20});
        expect(notified, isTrue);
      });

      test('should reset to empty and notify', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2});
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..reset();
        expect(map.isEmpty, isTrue);
        expect(notified, isTrue);
      });

      test('should not notify when resetting empty map to null', () {
        final map = ListenableMap<String, int>();
        var notified = false;
        map
          ..addListener(() => notified = true)
          ..reset();
        expect(notified, isFalse);
      });

      test('should dispose and clear', () {
        final map = ListenableMap<String, int>.from({'a': 1, 'b': 2})
          ..dispose();
        expect(map.isEmpty, isTrue);
        expect(map.isDisposed, isTrue);
      });
    });
  });

  group('ListenableNum Tests |', () {
    group('Constructors -', () {
      test('should create with int value', () {
        final counter = ListenableNum<int>(10);
        expect(counter.value, 10);
        expect(counter.prevValue, isNull);
      });

      test('should create with double value', () {
        final amount = ListenableNum<double>(10.5);
        expect(amount.value, 10.5);
        expect(amount.prevValue, isNull);
      });
    });

    group('Value Getter and Setter -', () {
      test('should get value', () {
        final counter = ListenableNum<int>(10);
        expect(counter.value, 10);
      });

      test('should set value and notify', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..value = 20;
        expect(counter.value, 20);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should not notify when setting same value', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..value = 10;
        expect(notified, isFalse);
      });
    });

    group('Previous Value Tracking -', () {
      test('should have no previous value initially', () {
        final counter = ListenableNum<int>(10);
        expect(counter.prevValue, isNull);
        expect(counter.hasPrevValue, isFalse);
      });

      test('should track previous value after change', () {
        final counter = ListenableNum<int>(10)
          ..value = 20
          ..value = 30;
        expect(counter.prevValue, 20);
        expect(counter.hasPrevValue, isTrue);
      });
    });

    group('Arithmetic Methods -', () {
      test('should add and notify', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..add(5);
        expect(counter.value, 15);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should add silently', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..add(5, silent: true);
        expect(counter.value, 15);
        expect(notified, isFalse);
      });

      test('should subtract and notify', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..subtract(3);
        expect(counter.value, 7);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should subtract silently', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..subtract(3, silent: true);
        expect(counter.value, 7);
        expect(notified, isFalse);
      });

      test('should multiply and notify', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..multiply(3);
        expect(counter.value, 30);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should multiply silently', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..multiply(3, silent: true);
        expect(counter.value, 30);
        expect(notified, isFalse);
      });

      test('should divide and notify', () {
        final amount = ListenableNum<double>(100);
        var notified = false;
        amount
          ..addListener(() => notified = true)
          ..divide(4);
        expect(amount.value, 25);
        expect(amount.prevValue, 100);
        expect(notified, isTrue);
      });

      test('should divide silently', () {
        final amount = ListenableNum<double>(100);
        var notified = false;
        amount
          ..addListener(() => notified = true)
          ..divide(4, silent: true);
        expect(amount.value, 25);
        expect(notified, isFalse);
      });

      test('should modulo and notify', () {
        final counter = ListenableNum<int>(17);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..modulo(5);
        expect(counter.value, 2);
        expect(counter.prevValue, 17);
        expect(notified, isTrue);
      });

      test('should modulo silently', () {
        final counter = ListenableNum<int>(17);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..modulo(5, silent: true);
        expect(counter.value, 2);
        expect(notified, isFalse);
      });
    });

    group('Increment and Decrement -', () {
      test('should increment and notify', () {
        final counter = ListenableNum<int>(5);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..increment();
        expect(counter.value, 6);
        expect(counter.prevValue, 5);
        expect(notified, isTrue);
      });

      test('should increment silently', () {
        final counter = ListenableNum<int>(5);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..increment(silent: true);
        expect(counter.value, 6);
        expect(notified, isFalse);
      });

      test('should decrement and notify', () {
        final counter = ListenableNum<int>(5);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..decrement();
        expect(counter.value, 4);
        expect(counter.prevValue, 5);
        expect(notified, isTrue);
      });

      test('should decrement silently', () {
        final counter = ListenableNum<int>(5);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..decrement(silent: true);
        expect(counter.value, 4);
        expect(notified, isFalse);
      });
    });

    group('Reset, Abs, Negate, and Clamp -', () {
      test('should reset to zero and notify', () {
        final counter = ListenableNum<int>(42);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..reset();
        expect(counter.value, 0);
        expect(counter.prevValue, 42);
        expect(notified, isTrue);
      });

      test('should not notify when resetting zero value', () {
        final counter = ListenableNum<int>(0);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..reset();
        expect(notified, isFalse);
      });

      test('should reset silently', () {
        final counter = ListenableNum<int>(42);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..reset(silent: true);
        expect(counter.value, 0);
        expect(notified, isFalse);
      });

      test('should get absolute value and notify', () {
        final counter = ListenableNum<int>(-10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..abs();
        expect(counter.value, 10);
        expect(counter.prevValue, -10);
        expect(notified, isTrue);
      });

      test('should not notify when value already positive', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..abs();
        expect(notified, isFalse);
      });

      test('should abs silently', () {
        final counter = ListenableNum<int>(-10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..abs(silent: true);
        expect(counter.value, 10);
        expect(notified, isFalse);
      });

      test('should negate and notify', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..negate();
        expect(counter.value, -10);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should negate silently', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..negate(silent: true);
        expect(counter.value, -10);
        expect(notified, isFalse);
      });

      test('should clamp and notify', () {
        final counter = ListenableNum<int>(15);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..clamp(0, 10);
        expect(counter.value, 10);
        expect(counter.prevValue, 15);
        expect(notified, isTrue);
      });

      test('should not notify when value already in range', () {
        final counter = ListenableNum<int>(5);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..clamp(0, 10);
        expect(notified, isFalse);
      });

      test('should clamp silently', () {
        final counter = ListenableNum<int>(15);
        var notified = false;
        counter
          ..addListener(() => notified = true)
          ..clamp(0, 10, silent: true);
        expect(counter.value, 10);
        expect(notified, isFalse);
      });
    });

    group('Arithmetic Operators -', () {
      test('should add with + operator and return value', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = counter + 5;
        expect(result, 15);
        expect(counter.value, 15);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should subtract with - operator and return value', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = counter - 3;
        expect(result, 7);
        expect(counter.value, 7);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should multiply with * operator and return value', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = counter * 3;
        expect(result, 30);
        expect(counter.value, 30);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });

      test('should divide with / operator and return value', () {
        final amount = ListenableNum<double>(100);
        var notified = false;
        amount.addListener(() => notified = true);

        final result = amount / 4;
        expect(result, 25);
        expect(amount.value, 25);
        expect(amount.prevValue, 100);
        expect(notified, isTrue);
      });

      test('should integer divide with ~/ operator and return value', () {
        final counter = ListenableNum<int>(17);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = counter ~/ 5;
        expect(result, 3);
        expect(counter.value, 3);
        expect(counter.prevValue, 17);
        expect(notified, isTrue);
      });

      test('should modulo with % operator and return value', () {
        final counter = ListenableNum<int>(17);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = counter % 5;
        expect(result, 2);
        expect(counter.value, 2);
        expect(counter.prevValue, 17);
        expect(notified, isTrue);
      });

      test('should negate with unary - operator and return value', () {
        final counter = ListenableNum<int>(10);
        var notified = false;
        counter.addListener(() => notified = true);

        final result = -counter;
        expect(result, -10);
        expect(counter.value, -10);
        expect(counter.prevValue, 10);
        expect(notified, isTrue);
      });
    });

    group('Comparison Operators -', () {
      test('should compare with < operator', () {
        final counter = ListenableNum<int>(5);
        expect(counter < 10, isTrue);
        expect(counter < 3, isFalse);
        expect(counter < 5, isFalse);
      });

      test('should compare with <= operator', () {
        final counter = ListenableNum<int>(5);
        expect(counter <= 10, isTrue);
        expect(counter <= 5, isTrue);
        expect(counter <= 3, isFalse);
      });

      test('should compare with > operator', () {
        final counter = ListenableNum<int>(5);
        expect(counter > 3, isTrue);
        expect(counter > 10, isFalse);
        expect(counter > 5, isFalse);
      });

      test('should compare with >= operator', () {
        final counter = ListenableNum<int>(5);
        expect(counter >= 3, isTrue);
        expect(counter >= 5, isTrue);
        expect(counter >= 10, isFalse);
      });
    });

    group('toString -', () {
      test('should convert to string', () {
        final counter = ListenableNum<int>(42);
        expect(counter.toString(), '42');

        final amount = ListenableNum<double>(10.5);
        expect(amount.toString(), '10.5');
      });
    });

    group('Chained Operations -', () {
      test('should chain arithmetic operations', () {
        final counter = ListenableNum<int>(10);
        var notifyCount = 0;
        counter
          ..addListener(() => notifyCount++)
          ..add(5)
          ..multiply(2)
          ..subtract(10);

        expect(counter.value, 20);
        expect(notifyCount, 3);
      });

      test('should use operator return values in expressions', () {
        final counter = ListenableNum<int>(10);
        final result = (counter + 5) * 2;
        expect(result, 30);
        expect(counter.value, 15);
      });
    });
  });
}
