/// Observable collection implementations that notify listeners on changes.
///
/// Provides [ListenableList], [ListenableSet], and [ListenableMap] which
/// notify listeners whenever the collection is modified.
library;

import 'dart:math';

import 'package:mz_utils/src/controller.dart';

/// {@template mz_utils.ListenableList}
/// A list implementation that notifies listeners whenever it is modified.
///
/// [ListenableList] is a fully functional `List<E>` that automatically notifies
/// registered listeners when any modification occurs. It combines the standard
/// list interface with Flutter's `Listenable` pattern for reactive programming.
///
/// ## When to Use ListenableList
///
/// Use [ListenableList] when you need:
/// * **Reactive UI updates** when list data changes
/// * **Multiple widgets** listening to the same list data
/// * **Automatic rebuilds** without manual setState calls
/// * **Observable collections** that integrate with Flutter's listener pattern
///
/// ## Key Features
///
/// * **Full List API**: All standard `List<E>` methods work normally
/// * **Automatic Notifications**: Every modification triggers listeners
/// * **Flutter Integration**: Works seamlessly with `ListenableBuilder`
/// * **Performance**: Minimal overhead, only notifies when actually modified
/// * **Type Safety**: Generic type parameter ensures compile-time checking
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create and use a listenable list:
///
/// ```dart
/// final todos = ListenableList<String>();
///
/// // Add listener
/// todos.addListener(() {
///   print('Todos changed: ${todos.length} items');
/// });
///
/// todos.add('Buy milk');      // Prints: Todos changed: 1 items
/// todos.add('Walk dog');      // Prints: Todos changed: 2 items
/// todos.removeAt(0);          // Prints: Todos changed: 1 items
/// ```
/// {@end-tool}
///
/// ## Widget Integration
///
/// {@tool snippet}
/// Use with Flutter widgets:
///
/// ```dart
/// class TodoListWidget extends StatefulWidget {
///   const TodoListWidget({super.key, required this.todos});
///
///   final ListenableList<String> todos;
///
///   @override
///   State<TodoListWidget> createState() => _TodoListWidgetState();
/// }
///
/// class _TodoListWidgetState extends State<TodoListWidget> {
///   @override
///   void initState() {
///     super.initState();
///     widget.todos.addListener(_onTodosChanged);
///   }
///
///   void _onTodosChanged() {
///     setState(() {}); // Rebuild when todos change
///   }
///
///   @override
///   void dispose() {
///     widget.todos.removeListener(_onTodosChanged);
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListView.builder(
///       itemCount: widget.todos.length,
///       itemBuilder: (context, index) {
///         return ListTile(title: Text(widget.todos[index]));
///       },
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Creating ListenableLists
///
/// {@tool snippet}
/// Multiple construction options:
///
/// ```dart
/// // Empty list
/// final empty = ListenableList<int>();
///
/// // From existing list
/// final fromList = ListenableList<String>.from(['a', 'b', 'c']);
///
/// // From any iterable
/// final fromIterable = ListenableList<int>.fromIterable([1, 2, 3]);
/// ```
/// {@end-tool}
///
/// ## Batch Operations
///
/// {@tool snippet}
/// Optimize multiple modifications:
///
/// ```dart
/// final numbers = ListenableList<int>();
///
/// // Less efficient - notifies 1000 times
/// for (var i = 0; i < 1000; i++) {
///   numbers.add(i);
/// }
///
/// // More efficient - build list then add all (notifies once)
/// final items = List.generate(1000, (i) => i);
/// numbers.addAll(items); // Single notification
/// ```
/// {@end-tool}
///
/// ## Performance Considerations
///
/// * Listeners are notified on **every** modification
/// * For bulk operations, use `addAll`, `removeRange`, etc.
/// * Consider batching updates to reduce listener notifications
/// * Check `isEmpty` before `clear()` to avoid unnecessary notifications
///
/// ## Common Patterns
///
/// {@tool snippet}
/// Shopping cart example:
///
/// ```dart
/// class ShoppingCart {
///   final items = ListenableList<Product>();
///
///   void addProduct(Product product) {
///     items.add(product);
///     // Listeners automatically notified
///   }
///
///   void removeProduct(int index) {
///     items.removeAt(index);
///     // Listeners automatically notified
///   }
///
///   void clear() {
///     items.clear();
///     // Listeners automatically notified
///   }
///
///   int get totalItems => items.length;
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ListenableSet], for set collections with change notifications
/// * [Controller], the base mixin providing listener functionality
/// {@endtemplate}
class ListenableList<E> with Controller implements List<E> {
  /// Creates an empty listenable list.
  ListenableList() : _list = [];

  /// Creates a listenable list from an existing list.
  ListenableList.from(List<E> list) : _list = [...list];

  /// Creates a listenable list from an iterable.
  ListenableList.fromIterable(Iterable<E> iterable)
      : _list = List<E>.from(iterable);

  late final List<E> _list;

  @override
  E get first => _list.first;

  @override
  E get last => _list.last;

  @override
  int get length => _list.length;

  @override
  set first(E value) {
    _list.first = value;
    notifyListeners();
  }

  @override
  set last(E value) {
    _list.last = value;
    notifyListeners();
  }

  @override
  set length(int newLength) {
    if (_list.length == newLength) return;
    _list.length = newLength;
    notifyListeners();
  }

  @override
  List<E> operator +(List<E> other) {
    return _list + other;
  }

  @override
  E operator [](int index) {
    return _list[index];
  }

  @override
  void operator []=(int index, E value) {
    _list[index] = value;
    notifyListeners();
  }

  @override
  void add(E value) {
    _list.add(value);
    notifyListeners();
  }

  @override
  void addAll(Iterable<E> iterable) {
    if (iterable.isEmpty) return;
    _list.addAll(iterable);
    notifyListeners();
  }

  @override
  bool any(bool Function(E element) test) {
    return _list.any(test);
  }

  @override
  Map<int, E> asMap() {
    return _list.asMap();
  }

  @override
  List<R> cast<R>() {
    return _list.cast<R>();
  }

  @override
  void clear() {
    if (_list.isEmpty) return;
    _list.clear();
    notifyListeners();
  }

  @override
  bool contains(Object? element) {
    return _list.contains(element);
  }

  @override
  E elementAt(int index) {
    return _list[index];
  }

  @override
  bool every(bool Function(E element) test) {
    return _list.every(test);
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) {
    return _list.expand(toElements);
  }

  @override
  void fillRange(int start, int end, [E? fillValue]) {
    if (start >= end) return;
    _list.fillRange(start, end, fillValue);
    notifyListeners();
  }

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _list.firstWhere(test, orElse: orElse);
  }

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) {
    return _list.fold(initialValue, combine);
  }

  @override
  Iterable<E> followedBy(Iterable<E> other) {
    return _list.followedBy(other);
  }

  @override
  void forEach(void Function(E element) action) {
    _list.forEach(action);
  }

  @override
  Iterable<E> getRange(int start, int end) {
    return _list.getRange(start, end);
  }

  @override
  int indexOf(E element, [int start = 0]) {
    return _list.indexOf(element, start);
  }

  @override
  int indexWhere(bool Function(E element) test, [int start = 0]) {
    return _list.indexWhere(test, start);
  }

  @override
  void insert(int index, E element) {
    _list.insert(index, element);
    notifyListeners();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    if (iterable.isEmpty) return;
    _list.insertAll(index, iterable);
    notifyListeners();
  }

  @override
  bool get isEmpty => _list.isEmpty;

  @override
  bool get isNotEmpty => _list.isNotEmpty;

  @override
  Iterator<E> get iterator => _list.iterator;

  @override
  String join([String separator = '']) {
    return _list.join(separator);
  }

  @override
  int lastIndexOf(E element, [int? start]) {
    return _list.lastIndexOf(element, start);
  }

  @override
  int lastIndexWhere(bool Function(E element) test, [int? start]) {
    return _list.lastIndexWhere(test, start);
  }

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _list.lastWhere(test, orElse: orElse);
  }

  @override
  Iterable<T> map<T>(T Function(E e) toElement) {
    return _list.map(toElement);
  }

  @override
  E reduce(E Function(E value, E element) combine) {
    return _list.reduce(combine);
  }

  @override
  bool remove(Object? value) {
    final removed = _list.remove(value);
    if (removed) notifyListeners();
    return removed;
  }

  @override
  E removeAt(int index) {
    final value = _list.removeAt(index);
    notifyListeners();
    return value;
  }

  @override
  E removeLast() {
    final value = _list.removeLast();
    notifyListeners();
    return value;
  }

  @override
  void removeRange(int start, int end) {
    if (start >= end) return;
    _list.removeRange(start, end);
    notifyListeners();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final initialLength = _list.length;
    _list.removeWhere(test);
    if (_list.length != initialLength) notifyListeners();
  }

  @override
  void replaceRange(int start, int end, Iterable<E> replacements) {
    _list.replaceRange(start, end, replacements);
    notifyListeners();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final initialLength = _list.length;
    _list.retainWhere(test);
    if (_list.length != initialLength) notifyListeners();
  }

  @override
  Iterable<E> get reversed => _list.reversed;

  @override
  void setAll(int index, Iterable<E> iterable) {
    if (iterable.isEmpty) return;
    _list.setAll(index, iterable);
    notifyListeners();
  }

  @override
  void setRange(int start, int end, Iterable<E> iterable, [int skipCount = 0]) {
    if (iterable.isEmpty) return;
    _list.setRange(start, end, iterable, skipCount);
    notifyListeners();
  }

  @override
  void shuffle([Random? random]) {
    if (_list.length <= 1) return;
    _list.shuffle(random);
    notifyListeners();
  }

  @override
  E get single => _list.single;

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _list.singleWhere(test, orElse: orElse);
  }

  @override
  Iterable<E> skip(int count) {
    return _list.skip(count);
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) {
    return _list.skipWhile(test);
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _list.sort(compare);
    notifyListeners();
  }

  @override
  List<E> sublist(int start, [int? end]) {
    return _list.sublist(start, end);
  }

  @override
  Iterable<E> take(int count) {
    return _list.take(count);
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) {
    return _list.takeWhile(test);
  }

  @override
  List<E> toList({bool growable = true}) {
    return _list.toList(growable: growable);
  }

  @override
  Set<E> toSet() {
    return _list.toSet();
  }

  @override
  Iterable<E> where(bool Function(E element) test) {
    return _list.where(test);
  }

  @override
  Iterable<V> whereType<V>() {
    return _list.whereType<V>();
  }

  /// Reset the list to the given [value] and notify listeners if
  /// the list is not empty or the value is not null.
  void reset({List<E>? value}) {
    final notify = _list.isNotEmpty || value != null;
    _list.clear();
    if (value != null) {
      _list.addAll(value);
    }
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _list.clear();
    super.dispose();
  }
}

/// {@template mz_utils.ListenableSet}
/// A set implementation that notifies listeners whenever it is modified.
///
/// [ListenableSet] is a fully functional `Set<E>` that automatically notifies
/// registered listeners when any modification occurs. It combines the standard
/// set interface with Flutter's `Listenable` pattern for reactive programming.
///
/// ## When to Use ListenableSet
///
/// Use [ListenableSet] when you need:
/// * **Reactive UI updates** when set data changes
/// * **Unique collections** with automatic notifications
/// * **Multiple widgets** listening to the same set data
/// * **Observable collections** that prevent duplicates
///
/// ## Key Features
///
/// * **Full Set API**: All standard `Set<E>` methods work normally
/// * **Automatic Notifications**: Every modification triggers listeners
/// * **Uniqueness Guarantee**: Maintains set uniqueness semantics
/// * **Performance**: Only notifies when set actually changes
/// * **Type Safety**: Generic type parameter ensures compile-time checking
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create and use a listenable set:
///
/// ```dart
/// final tags = ListenableSet<String>();
///
/// // Add listener
/// tags.addListener(() {
///   print('Tags changed: ${tags.length} items');
/// });
///
/// tags.add('flutter');   // Prints: Tags changed: 1 items
/// tags.add('dart');      // Prints: Tags changed: 2 items
/// tags.add('flutter');   // No notification - duplicate not added
/// tags.remove('dart');   // Prints: Tags changed: 1 items
/// ```
/// {@end-tool}
///
/// ## Widget Integration
///
/// {@tool snippet}
/// Use with Flutter widgets:
///
/// ```dart
/// class TagsWidget extends StatefulWidget {
///   const TagsWidget({super.key, required this.tags});
///
///   final ListenableSet<String> tags;
///
///   @override
///   State<TagsWidget> createState() => _TagsWidgetState();
/// }
///
/// class _TagsWidgetState extends State<TagsWidget> {
///   @override
///   void initState() {
///     super.initState();
///     widget.tags.addListener(_onTagsChanged);
///   }
///
///   void _onTagsChanged() {
///     setState(() {}); // Rebuild when tags change
///   }
///
///   @override
///   void dispose() {
///     widget.tags.removeListener(_onTagsChanged);
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Wrap(
///       spacing: 8,
///       children: [
///         for (final tag in widget.tags)
///           Chip(label: Text(tag)),
///       ],
///     );
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Creating ListenableSets
///
/// {@tool snippet}
/// Multiple construction options:
///
/// ```dart
/// // Empty set
/// final empty = ListenableSet<int>();
///
/// // From existing set
/// final fromSet = ListenableSet<String>.from({'a', 'b', 'c'});
///
/// // From any iterable (duplicates removed)
/// final fromIterable = ListenableSet<int>.fromIterable([1, 2, 2, 3]);
/// // Results in {1, 2, 3}
/// ```
/// {@end-tool}
///
/// ## Set Operations
///
/// {@tool snippet}
/// Use standard set operations:
///
/// ```dart
/// final set1 = ListenableSet<int>.from({1, 2, 3});
/// final set2 = {2, 3, 4};
///
/// set1.addListener(() => print('Set1 changed'));
///
/// // Union
/// final union = set1.union(set2); // {1, 2, 3, 4}
///
/// // Intersection
/// final intersection = set1.intersection(set2); // {2, 3}
///
/// // Difference
/// final difference = set1.difference(set2); // {1}
///
/// // Modify original set (triggers notification)
/// set1.addAll(set2); // Prints: Set1 changed
/// ```
/// {@end-tool}
///
/// ## Performance Considerations
///
/// * Listeners notified only when set **actually changes**
/// * Adding duplicates does NOT trigger notifications
/// * Use `addAll` for bulk additions instead of multiple `add` calls
/// * Check `isEmpty` before `clear()` to avoid unnecessary notifications
///
/// ## Common Patterns
///
/// {@tool snippet}
/// Selected items tracker:
///
/// ```dart
/// class SelectionManager {
///   final selectedIds = ListenableSet<String>();
///
///   void toggleSelection(String id) {
///     if (selectedIds.contains(id)) {
///       selectedIds.remove(id);
///     } else {
///       selectedIds.add(id);
///     }
///     // Listeners automatically notified
///   }
///
///   void clearSelection() {
///     selectedIds.clear();
///     // Listeners automatically notified
///   }
///
///   bool isSelected(String id) => selectedIds.contains(id);
///
///   int get selectionCount => selectedIds.length;
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [ListenableList], for list collections with change notifications
/// * [Controller], the base mixin providing listener functionality
/// {@endtemplate}
class ListenableSet<E> with Controller implements Set<E> {
  /// Creates an empty listenable set.
  ListenableSet() : _set = {};

  /// Creates a listenable set from an existing set.
  ListenableSet.from(Set<E> set) : _set = {...set};

  /// Creates a listenable set from an iterable.
  ListenableSet.fromIterable(Iterable<E> iterable)
      : _set = Set<E>.from(iterable);
  late final Set<E> _set;

  @override
  bool add(E value) {
    if (_set.add(value)) {
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  void addAll(Iterable<E> elements) {
    if (elements.isEmpty) return;
    _set.addAll(elements);
    notifyListeners();
  }

  @override
  bool any(bool Function(E element) test) {
    return _set.any(test);
  }

  @override
  Set<R> cast<R>() {
    return _set.cast<R>();
  }

  @override
  void clear() {
    if (_set.isEmpty) return;
    _set.clear();
    notifyListeners();
  }

  @override
  bool contains(Object? value) {
    return _set.contains(value);
  }

  @override
  bool containsAll(Iterable<Object?> other) {
    return _set.containsAll(other);
  }

  @override
  Set<E> difference(Set<Object?> other) {
    return _set.difference(other);
  }

  @override
  E elementAt(int index) {
    return _set.elementAt(index);
  }

  @override
  bool every(bool Function(E element) test) {
    return _set.every(test);
  }

  @override
  Iterable<T> expand<T>(Iterable<T> Function(E element) toElements) {
    return _set.expand(toElements);
  }

  @override
  E get first => _set.first;

  @override
  E firstWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _set.firstWhere(test, orElse: orElse);
  }

  @override
  T fold<T>(T initialValue, T Function(T previousValue, E element) combine) {
    return _set.fold(initialValue, combine);
  }

  @override
  Iterable<E> followedBy(Iterable<E> other) {
    return _set.followedBy(other);
  }

  @override
  void forEach(void Function(E element) action) {
    _set.forEach(action);
  }

  @override
  Set<E> intersection(Set<Object?> other) {
    return _set.intersection(other);
  }

  @override
  bool get isEmpty => _set.isEmpty;

  @override
  bool get isNotEmpty => _set.isNotEmpty;

  @override
  Iterator<E> get iterator => _set.iterator;

  @override
  String join([String separator = '']) {
    return _set.join(separator);
  }

  @override
  E get last => _set.last;

  @override
  E lastWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _set.lastWhere(test, orElse: orElse);
  }

  @override
  int get length => _set.length;

  @override
  E? lookup(Object? object) {
    return _set.lookup(object);
  }

  @override
  Iterable<T> map<T>(T Function(E e) toElement) {
    return _set.map(toElement);
  }

  @override
  E reduce(E Function(E value, E element) combine) {
    return _set.reduce(combine);
  }

  @override
  bool remove(Object? value) {
    if (_set.remove(value)) {
      notifyListeners();
      return true;
    }
    return false;
  }

  @override
  void removeAll(Iterable<Object?> elements) {
    if (elements.isEmpty) return;
    _set.removeAll(elements);
    notifyListeners();
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final initialLength = _set.length;
    _set.removeWhere(test);
    if (_set.length != initialLength) notifyListeners();
  }

  @override
  void retainAll(Iterable<Object?> elements) {
    if (elements.isEmpty) return;
    _set.retainAll(elements);
    notifyListeners();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final initialLength = _set.length;
    _set.retainWhere(test);
    if (_set.length != initialLength) notifyListeners();
  }

  @override
  E get single => _set.single;

  @override
  E singleWhere(bool Function(E element) test, {E Function()? orElse}) {
    return _set.singleWhere(test, orElse: orElse);
  }

  @override
  Iterable<E> skip(int count) {
    return _set.skip(count);
  }

  @override
  Iterable<E> skipWhile(bool Function(E value) test) {
    return _set.skipWhile(test);
  }

  @override
  Iterable<E> take(int count) {
    return _set.take(count);
  }

  @override
  Iterable<E> takeWhile(bool Function(E value) test) {
    return _set.takeWhile(test);
  }

  @override
  List<E> toList({bool growable = true}) {
    return _set.toList(growable: growable);
  }

  @override
  Set<E> toSet() {
    return _set.toSet();
  }

  @override
  Set<E> union(Set<E> other) {
    return _set.union(other);
  }

  @override
  Iterable<E> where(bool Function(E element) test) {
    return _set.where(test);
  }

  @override
  Iterable<T> whereType<T>() {
    return _set.whereType<T>();
  }

  /// Reset the set to the given [value] and notify listeners if the set is not
  /// empty or the value is not null.
  void reset({Set<E>? value}) {
    final notify = _set.isNotEmpty || value != null;
    _set.clear();
    if (value != null) {
      _set.addAll(value);
    }
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _set.clear();
    super.dispose();
  }
}

/// A map implementation that notifies listeners when modified.
class ListenableMap<K, V> with Controller implements Map<K, V> {
  /// Creates an empty listenable map.
  ListenableMap() : _map = {};

  /// Creates a listenable map from an existing map.
  ListenableMap.from(Map<K, V> map) : _map = {...map};

  /// Creates a listenable map from map entries.
  ListenableMap.fromEntries(Iterable<MapEntry<K, V>> entries)
      : _map = Map<K, V>.fromEntries(entries);
  late final Map<K, V> _map;

  @override
  V? operator [](Object? key) {
    return _map[key];
  }

  @override
  void operator []=(K key, V value) {
    _map[key] = value;
    notifyListeners();
  }

  @override
  void addAll(Map<K, V> other) {
    if (other.isEmpty) return;
    _map.addAll(other);
    notifyListeners();
  }

  @override
  void addEntries(Iterable<MapEntry<K, V>> newEntries) {
    if (newEntries.isEmpty) return;
    _map.addEntries(newEntries);
    notifyListeners();
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    return _map.cast<RK, RV>();
  }

  @override
  void clear() {
    if (_map.isEmpty) return;
    _map.clear();
    notifyListeners();
  }

  @override
  bool containsKey(Object? key) {
    return _map.containsKey(key);
  }

  @override
  bool containsValue(Object? value) {
    return _map.containsValue(value);
  }

  @override
  Iterable<MapEntry<K, V>> get entries => _map.entries;

  @override
  void forEach(void Function(K key, V value) action) {
    _map.forEach(action);
  }

  @override
  bool get isEmpty => _map.isEmpty;

  @override
  bool get isNotEmpty => _map.isNotEmpty;

  @override
  Iterable<K> get keys => _map.keys;

  @override
  int get length => _map.length;

  @override
  Map<K2, V2> map<K2, V2>(MapEntry<K2, V2> Function(K key, V value) convert) {
    return _map.map(convert);
  }

  @override
  V putIfAbsent(K key, V Function() ifAbsent) {
    var isAbsent = false;
    final value = _map.putIfAbsent(key, () {
      isAbsent = true;
      return ifAbsent();
    });
    if (isAbsent) notifyListeners();
    return value;
  }

  @override
  V? remove(Object? key) {
    if (_map.remove(key) case final V value) {
      notifyListeners();
      return value;
    }
    return null;
  }

  @override
  void removeWhere(bool Function(K key, V value) test) {
    var removed = false;
    _map.removeWhere((k, v) {
      final result = test(k, v);
      if (!removed) removed = result;
      return result;
    });
    if (removed) notifyListeners();
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final value = _map.update(key, update, ifAbsent: ifAbsent);
    notifyListeners();
    return value;
  }

  @override
  void updateAll(V Function(K key, V value) update) {
    _map.updateAll(update);
    notifyListeners();
  }

  @override
  Iterable<V> get values => _map.values;

  /// Reset the map to empty or to a new value.
  ///
  /// If [value] is provided, the map is cleared and replaced with [value].
  /// Otherwise, just clears the map.
  void reset({Map<K, V>? value}) {
    final notify = _map.isNotEmpty || value != null;
    _map.clear();
    if (value != null) {
      _map.addAll(value);
    }
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _map.clear();
    super.dispose();
  }
}
