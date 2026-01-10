/// @docImport 'debouncer.dart';
/// @docImport 'throttler.dart';
library;

import 'dart:async';

/// A cached entry with completer and optional expiration.
class _MemoizerEntry<T> {
  _MemoizerEntry(this.completer, this.expiresAt);

  final Completer<T> completer;
  final DateTime? expiresAt;
  T? _cachedValue;
  bool _hasValue = false;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Store the value once computation completes.
  void complete(T value) {
    _cachedValue = value;
    _hasValue = true;
    completer.complete(value);
  }

  Future<T>? get future => isExpired ? null : completer.future;

  /// Get the cached value (only valid after setValue is called).
  T? get value => _hasValue ? _cachedValue : null;

  /// Whether we have a cached value.
  bool get hasValue => _hasValue;
}

/// {@template mz_core.Memoizer}
/// A static utility class for memoizing (caching) expensive async operations.
///
/// Memoization stores the results of function calls and returns the cached
/// result when the same inputs occur again, avoiding redundant computation
/// or network requests.
///
/// Similar to [Debouncer], `Memoizer` uses string tags to identify cached
/// values, making it easy to cache, retrieve, and invalidate specific entries.
///
/// ## Features
///
/// * **Tag-based caching**: Each tag stores one cached value
/// * **TTL support**: Optional time-to-live for automatic expiration
/// * **In-flight deduplication**: Concurrent calls share the same computation
/// * **Force refresh**: Bypass cache when needed
/// * **Error handling**: Option to cache or skip failed results
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Cache an API call:
///
/// ```dart
/// Future<User> getCurrentUser() {
///   return Memoizer.run(
///     'current-user',
///     () => api.fetchCurrentUser(),
///   );
/// }
///
/// void logout() {
///   Memoizer.clear('current-user');
/// }
/// ```
/// {@end-tool}
///
/// ## TTL (Time-To-Live)
///
/// {@tool snippet}
/// Cache with expiration:
///
/// ```dart
/// Future<AppConfig> getConfig() {
///   return Memoizer.run(
///     'app-config',
///     () => api.fetchConfig(),
///     ttl: const Duration(minutes: 5),
///   );
/// }
/// ```
/// {@end-tool}
///
/// ## Key-based Caching
///
/// {@tool snippet}
/// Cache multiple values with dynamic tags:
///
/// ```dart
/// Future<Product> getProduct(String id) {
///   return Memoizer.run(
///     'product-$id',
///     () => api.fetchProduct(id),
///     ttl: const Duration(minutes: 10),
///   );
/// }
///
/// void invalidateProduct(String id) {
///   Memoizer.clear('product-$id');
/// }
/// ```
/// {@end-tool}
///
/// ## Force Refresh
///
/// {@tool snippet}
/// Bypass cache for pull-to-refresh:
///
/// ```dart
/// Future<User> refreshUser() {
///   return Memoizer.run(
///     'current-user',
///     () => api.fetchCurrentUser(),
///     forceRefresh: true,
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Debouncer], which delays execution until calls stop
/// * [Throttler], which limits execution frequency
/// {@endtemplate}
abstract class Memoizer {
  static final Map<String, _MemoizerEntry<dynamic>> _entries = {};

  /// Runs [computation] and caches the result under [tag].
  ///
  /// If a cached value exists for [tag] and hasn't expired, returns it
  /// immediately without running [computation].
  ///
  /// If [forceRefresh] is true, ignores any cached value and runs
  /// [computation] again.
  ///
  /// If [ttl] is provided, the cached value expires after that duration.
  ///
  /// If [cacheErrors] is false (default), failed computations are not cached
  /// and will be retried on next call.
  ///
  /// Concurrent calls with the same [tag] share the same computation -
  /// only one request is made and all callers receive the same result.
  ///
  /// {@tool snippet}
  /// Basic usage:
  ///
  /// ```dart
  /// // First call - runs computation
  /// final user1 = await Memoizer.run('user', () => api.fetchUser());
  ///
  /// // Second call - returns cached value instantly
  /// final user2 = await Memoizer.run('user', () => api.fetchUser());
  ///
  /// // Force refresh - runs computation again
  /// final user3 = await Memoizer.run(
  ///   'user',
  ///   () => api.fetchUser(),
  ///   forceRefresh: true,
  /// );
  /// ```
  /// {@end-tool}
  static Future<T> run<T>(
    String tag,
    Future<T> Function() computation, {
    bool forceRefresh = false,
    Duration? ttl,
    bool cacheErrors = false,
  }) {
    late final future = _entries[tag]?.future;
    // Check for valid cached entry
    if (!forceRefresh && future is Future<T>) return future;

    // Create new entry with completer
    final completer = Completer<T>();
    final entry = _MemoizerEntry<T>(
      completer,
      ttl != null ? DateTime.now().add(ttl) : null,
    );
    _entries[tag] = entry;

    // Run computation
    unawaited(
      computation()
          .then(entry.complete)
          .catchError((Object error, StackTrace stackTrace) {
        // Remove failed entry so next call retries
        if (!cacheErrors) _entries.remove(tag);
        completer.completeError(error, stackTrace);
      }),
    );

    return completer.future;
  }

  /// Returns the cached value for [tag], or null if not cached/expired.
  ///
  /// This is a synchronous check - it doesn't run any computation.
  /// Returns null if the computation is still in progress.
  static T? getValue<T>(String tag) {
    final entry = _entries[tag];
    if (entry != null && !entry.isExpired && entry.hasValue) {
      return entry.value as T?;
    }
    return null;
  }

  /// Returns true if there is a valid (non-expired) cached value for [tag].
  static bool hasValue(String tag) {
    final entry = _entries[tag];
    return entry != null && !entry.isExpired && entry.hasValue;
  }

  /// Returns true if there is an in-flight computation for [tag].
  static bool isPending(String tag) {
    final entry = _entries[tag];
    return entry != null && !entry.completer.isCompleted;
  }

  /// Clears the cached value for [tag].
  ///
  /// The next call to [run] with this tag will execute the computation.
  static void clear(String tag) {
    _entries.remove(tag);
  }

  /// Clears all cached values.
  static void clearAll() {
    _entries.clear();
  }

  /// Returns the number of cached values (including pending).
  static int count() => _entries.length;

  /// Returns all cached tags.
  static Iterable<String> get tags => _entries.keys;

  /// Removes all expired entries from the cache.
  ///
  /// Call this periodically to free memory from expired entries.
  static void removeExpired() {
    _entries.removeWhere((_, entry) => entry.isExpired);
  }
}
