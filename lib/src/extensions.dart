import 'package:flutter/widgets.dart' show Widget;

/// {@template mz_core.IterableMZX}
/// Extension methods for [Iterable] providing additional utility operations.
///
/// [IterableMZX] adds convenient methods to the standard [Iterable] interface
/// for common data transformation tasks like creating maps, finding elements
/// with indices, and searching.
///
/// ## Available Methods
///
/// * **toIndexedMap**: Convert iterable to map with indices as keys
/// * **toMap**: Convert iterable to map using custom key-value extraction
/// * **firstWhereWithIndexOrNull**: Find first matching element with its index
/// * **indexOf**: Get the index of a specific value
///
/// {@tool snippet}
/// Example usage:
///
/// ```dart
/// final items = ['apple', 'banana', 'cherry'];
///
/// // Convert to indexed map
/// final indexed = items.toIndexedMap((i) => 'item$i');
/// // {0: 'item0', 1: 'item1', 2: 'item2'}
///
/// // Convert to custom map
/// final map = items.toMap((e) => MapEntry(e[0], e));
/// // {'a': 'apple', 'b': 'banana', 'c': 'cherry'}
///
/// // Find with index
/// final result = items.firstWhereWithIndexOrNull((e) => e.startsWith('b'));
/// // (1, 'banana')
///
/// // Get index
/// final index = items.indexOf('cherry'); // 2
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ListMZX], additional methods for [List]
/// * [SetMZX], additional methods for [Set]
/// {@endtemplate}
extension IterableMZX<T> on Iterable<T> {
  /// Converts this iterable into a map where keys are indices.
  ///
  /// The [value] function is called for each index to generate the map value.
  /// This is useful when you need to create a map from an iterable with
  /// custom values based on the index position.
  ///
  /// Example:
  /// ```dart
  /// final list = ['a', 'b', 'c'];
  /// final map = list.toIndexedMap((i) => 'item_$i');
  /// // Result: {0: 'item_0', 1: 'item_1', 2: 'item_2'}
  /// ```
  Map<int, V> toIndexedMap<V>(V Function(int index) value) {
    final map = <int, V>{};
    for (var i = 0; i < length; i++) {
      map[i] = value(i);
    }
    return map;
  }

  /// Converts this iterable into a map using the provided [value] function.
  ///
  /// The [value] function is called for each element to generate a
  /// [MapEntry] with the key and value. If multiple elements produce the
  /// same key, the last one wins.
  ///
  /// Example:
  /// ```dart
  /// final users = [User(id: 1, name: 'Alice'), User(id: 2, name: 'Bob')];
  /// final userMap = users.toMap((u) => MapEntry(u.id, u.name));
  /// // Result: {1: 'Alice', 2: 'Bob'}
  /// ```
  Map<K, V> toMap<K, V>(MapEntry<K, V> Function(T e) value) {
    final map = <K, V>{};
    for (final element in this) {
      final entry = value(element);
      map[entry.key] = entry.value;
    }
    return map;
  }

  /// Finds the first element matching [test] and returns it with its index.
  ///
  /// Returns a record `(index, element)` for the first element where [test]
  /// returns true, or `null` if no matching element is found.
  ///
  /// Example:
  /// ```dart
  /// final numbers = [10, 20, 30, 40];
  /// final result = numbers.firstWhereWithIndexOrNull((n) => n > 25);
  /// // Result: (2, 30) - element 30 at index 2
  ///
  /// final notFound = numbers.firstWhereWithIndexOrNull((n) => n > 100);
  /// // Result: null
  /// ```
  (int, T)? firstWhereWithIndexOrNull(bool Function(T e) test) {
    var index = 0;
    for (final element in this) {
      if (test(element)) return (index, element);
      index++;
    }
    return null;
  }

  /// Returns the index of the first occurrence of [value].
  ///
  /// Returns the zero-based index of the first element equal to [value],
  /// or -1 if [value] is not found in this iterable.
  ///
  /// Example:
  /// ```dart
  /// final items = ['apple', 'banana', 'cherry'];
  /// print(items.indexOf('banana')); // 1
  /// print(items.indexOf('grape'));  // -1
  /// ```
  int indexOf(T value) {
    var index = 0;
    for (final element in this) {
      if (value == element) {
        return index;
      }
      index++;
    }
    return -1;
  }
}

/// {@template mz_core.ListMZX}
/// Extension methods for [List] providing additional modification operations.
///
/// [ListMZX] adds convenient removal methods to the standard [List] interface
/// for conditional element removal operations.
///
/// ## Available Methods
///
/// * **removeFirstWhere**: Remove first element matching a condition
/// * **removeLastWhere**: Remove last element matching a condition
///
/// {@tool snippet}
/// Example usage:
///
/// ```dart
/// final numbers = [1, 2, 3, 4, 5, 3];
///
/// // Remove first element > 2
/// final removed = numbers.removeFirstWhere((n) => n > 2);
/// // removed: 3, numbers: [1, 2, 4, 5, 3]
///
/// // Remove last element == 3
/// final last = numbers.removeLastWhere((n) => n == 3);
/// // last: 3, numbers: [1, 2, 4, 5]
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [IterableMZX], additional methods for [Iterable]
/// {@endtemplate}
extension ListMZX<T> on List<T> {
  /// Removes the first element matching [test] and returns it.
  ///
  /// Searches through the list for the first element where [test] returns
  /// true, removes it, and returns the removed element. Returns `null` if
  /// no matching element is found.
  ///
  /// Example:
  /// ```dart
  /// final items = [1, 2, 3, 4, 5];
  /// final removed = items.removeFirstWhere((n) => n > 3);
  /// print(removed); // 4
  /// print(items);   // [1, 2, 3, 5]
  /// ```
  T? removeFirstWhere(bool Function(T e) test) {
    for (var i = 0; i < length; i++) {
      if (test(this[i])) {
        return removeAt(i);
      }
    }
    return null;
  }

  /// Removes the first element matching [test] and returns it with its index.
  ///
  /// Similar to [removeFirstWhere], but returns a [MapEntry] containing
  /// both the index and the removed element. Returns `null` if no matching
  /// element is found.
  ///
  /// Example:
  /// ```dart
  /// final items = ['a', 'b', 'c', 'd'];
  /// final removed = items.removeFirstWhere1((s) => s == 'c');
  /// print(removed); // MapEntry(2, 'c')
  /// print(items);   // ['a', 'b', 'd']
  /// ```
  MapEntry<int, T>? removeFirstWhere1(bool Function(T e) test) {
    for (var i = 0; i < length; i++) {
      if (test(this[i])) {
        return MapEntry(i, removeAt(i));
      }
    }
    return null;
  }

  /// Replaces the first element where [test] returns a non-null value.
  ///
  /// Iterates through the list and calls [test] for each element. When [test]
  /// returns a non-null value, that element is replaced with the returned
  /// value. Returns the index of the replaced element, or -1 if no element
  /// was replaced.
  ///
  /// Example:
  /// ```dart
  /// final items = [1, 2, 3, 4];
  /// final index = items.replaceFirst((n) => n == 3 ? 10 : null);
  /// print(index); // 2
  /// print(items); // [1, 2, 10, 4]
  /// ```
  int replaceFirst(T? Function(T e) test) {
    for (var i = 0; i < length; i++) {
      final res = test(this[i]);
      if (res != null) {
        this[i] = res;
        return i;
      }
    }
    return -1;
  }

  /// Replaces or adds elements from [items] to this list.
  ///
  /// For each item in [items], if an equal element exists in this list,
  /// it is replaced with the new item. If no equal element exists, the
  /// item is added to the end of the list.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3];
  /// list.replaceAll([2, 4]); // Replace 2, add 4
  /// print(list); // [1, 2, 3, 4]
  /// ```
  void replaceAll(Iterable<T> items) {
    for (final value in items) {
      final index = indexOf(value);
      if (index != -1) {
        this[index] = value;
      } else {
        add(value);
      }
    }
  }

  /// Removes all occurrences of [items] from this list.
  ///
  /// By default ([firstOccurrences] = true), removes only the first
  /// occurrence of each item. Set [firstOccurrences] to false to remove
  /// all occurrences of each item.
  ///
  /// Example:
  /// ```dart
  /// final list = [1, 2, 3, 2, 4, 2];
  /// list.removeAll([2, 4]);
  /// print(list); // [1, 3, 2, 2] - only first 2 and 4 removed
  ///
  /// final list2 = [1, 2, 3, 2, 4, 2];
  /// list2.removeAll([2], firstOccurrences: false);
  /// print(list2); // [1, 3, 4] - all 2s removed
  /// ```
  void removeAll(Iterable<T> items, {bool firstOccurrences = true}) {
    for (final item in items) {
      if (firstOccurrences) {
        remove(item);
      } else {
        while (contains(item)) {
          remove(item);
        }
      }
    }
  }
}

/// {@template mz_core.SetMZX}
/// Extension methods for [Set] providing additional operations.
///
/// [SetMZX] adds convenient methods to the standard [Set] interface for
/// toggling and replacing elements.
///
/// ## Available Methods
///
/// * **toggle**: Add or remove an element from the set
/// * **replaceAll**: Replace or add multiple elements
///
/// {@tool snippet}
/// Example usage:
///
/// ```dart
/// final tags = <String>{'flutter', 'dart'};
///
/// // Toggle elements
/// tags.toggle('flutter'); // Removes 'flutter'
/// tags.toggle('web');     // Adds 'web'
/// // Result: {'dart', 'web'}
///
/// // Replace all
/// tags.replaceAll(['flutter', 'mobile']);
/// // Result: {'dart', 'web', 'flutter', 'mobile'}
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ListMZX], additional methods for [List]
/// {@endtemplate}
extension SetMZX<T> on Set<T> {
  /// Removes an element from the set and returns it if present.
  ///
  /// Uses [lookup] to find the actual element in the set (which may differ
  /// from the provided [element] if they're equal but not identical), then
  /// removes and returns it. Returns `null` if the element is not in the set.
  ///
  /// Example:
  /// ```dart
  /// final set = {1, 2, 3};
  /// final removed = set.removeAndReturn(2);
  /// print(removed); // 2
  /// print(set);     // {1, 3}
  ///
  /// final notFound = set.removeAndReturn(5);
  /// print(notFound); // null
  /// ```
  T? removeAndReturn(T element) {
    final found = lookup(element);
    if (found != null) {
      remove(element);
      return found;
    }
    return null;
  }
}

/// Extension methods for [int] providing range operations.
extension IntMZX<T> on int {
  /// Creates a map with keys from this int to [index], filled with [value].
  ///
  /// Generates a map where keys range from this integer (inclusive) to
  /// [index] (inclusive), with all values set to [value].
  ///
  /// Example:
  /// ```dart
  /// final map = 0.fillTo(3, 'x');
  /// print(map); // {0: 'x', 1: 'x', 2: 'x', 3: 'x'}
  ///
  /// final map2 = 5.fillTo(7, true);
  /// print(map2); // {5: true, 6: true, 7: true}
  /// ```
  Map<int, T> fillTo(int index, T value) {
    final map = <int, T>{};
    for (var i = this; i <= index; i++) {
      map[i] = value;
    }
    return map;
  }
}

/// Extension methods for [num] providing formatting utilities.
extension NumMZX on num {
  /// Converts this number to a string with adaptive decimal precision.
  ///
  /// If the number is an integer (no decimal part), returns it with 1
  /// decimal place. Otherwise, returns it with [fractionDigits] decimal
  /// places.
  ///
  /// Example:
  /// ```dart
  /// print(5.0.toStringAsFixedFloor(2));   // "5.0"
  /// print(5.123.toStringAsFixedFloor(2)); // "5.12"
  /// print(5.789.toStringAsFixedFloor(1)); // "5.8"
  /// ```
  String toStringAsFixedFloor(int fractionDigits) {
    // Check if the number is an integer (no decimal part)
    if (this % 1 == 0) {
      // No decimal part, use 1 decimal place
      return toStringAsFixed(1);
    }

    // Has decimal part, use [fractionDigits] decimal places
    return toStringAsFixed(fractionDigits);
  }
}

/// Extension methods for [Iterable]<[Widget]> providing layout utilities.
extension WidgetMZX on Iterable<Widget> {
  /// Inserts widgets between each element of this iterable.
  ///
  /// The [builder] function is called for each position where a widget
  /// should be inserted, with the index of the preceding widget. Returns
  /// a new list with the separators inserted.
  ///
  /// Example:
  /// ```dart
  /// final widgets = [Text('A'), Text('B'), Text('C')];
  /// final withDividers = widgets.insertBetween(
  ///   (i) => Divider(),
  /// );
  /// // Result: [Text('A'), Divider(), Text('B'), Divider(), Text('C')]
  /// ```
  List<Widget> insertBetween(Widget Function(int index) builder) {
    final c = <Widget>[...this];
    for (var i = c.length; i-- > 0;) {
      if (i < c.length - 1) {
        c.insert(i + 1, builder(i));
      }
    }
    return c;
  }
}

/// {@template mz_core.StringMZX}
/// Extension methods for [String] providing text transformation utilities.
///
/// [StringMZX] adds convenient case conversion methods to the standard [String]
/// interface for transforming between different naming conventions.
///
/// ## Available Methods
///
/// * **toCapitalizedWords**: Convert to "Capitalized Words" format
/// * **toCamelCase**: Convert to "camelCase" format
/// * **toSnakeCase**: Convert to "snake_case" format
///
/// {@tool snippet}
/// Example usage:
///
/// ```dart
/// final text = 'hello_world';
///
/// // Capitalized Words
/// print(text.toCapitalizedWords()); // "Hello World"
///
/// // camelCase
/// print(text.toCamelCase()); // "helloWorld"
///
/// // snake_case
/// print('HelloWorld'.toSnakeCase()); // "hello_world"
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [IterableMZX], additional methods for [Iterable]
/// {@endtemplate}
extension StringMZX on String {
  /// Converts this string to capitalized words format.
  ///
  /// Splits camelCase, PascalCase, snake_case, and kebab-case strings into
  /// separate words, then capitalizes the first letter of each word while
  /// making the rest lowercase.
  ///
  /// Example:
  /// ```dart
  /// print('helloWorld'.toCapitalizedWords());     // "Hello World"
  /// print('user_name'.toCapitalizedWords());      // "User Name"
  /// print('API-Key'.toCapitalizedWords());        // "Api Key"
  /// print('HTTPSConnection'.toCapitalizedWords());// "Https Connection"
  /// ```
  String toCapitalizedWords() {
    if (isEmpty) return this;

    String capitalize(String word) {
      return word.isEmpty
          ? ''
          : word[0].toUpperCase() + word.substring(1).toLowerCase();
    }

    final words = replaceAllMapped(
      RegExp('[A-Z]'),
      (m) => ' ${m[0]}',
    ).replaceAll(RegExp('[-_]'), ' ').trim().split(RegExp(r'\s+'));

    return words.map(capitalize).join(' ');
  }
}
