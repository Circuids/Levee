import 'page.dart';

/// Abstract cache interface with query-aware methods and optional TTL support.
///
/// The cache store provides a flexible caching layer that can be implemented
/// in multiple ways:
/// - Simple stores (Memory, Hive, SQLite): Ignore the query parameter
/// - Backend-integrated stores (Firestore): Use query to fetch from backend cache
///
/// Example:
/// ```dart
/// // Simple memory cache
/// final cache = MemoryCacheStore<Product, int>();
///
/// // Usage in Paginator
/// final paginator = Paginator<Product, int>(
///   source: ProductDataSource(),
///   cache: cache,
/// );
/// ```
abstract class CacheStore<T, K> {
  /// Get cached page by key with query context.
  ///
  /// The [query] parameter enables:
  /// - Simple stores: ignore query, just use key for lookup
  /// - Advanced stores: use query to fetch from backend cache (e.g., Firestore)
  ///
  /// Returns null if cache miss or expired.
  Future<Page<T, K>?> get(String key, PageQuery<K> query);

  /// Store page with optional TTL.
  ///
  /// The [query] parameter enables:
  /// - Simple stores: ignore query, just store by key
  /// - Advanced stores: extract metadata for backend cache tracking
  ///
  /// [ttl] specifies how long the cached page should be considered valid.
  Future<void> put(String key, PageQuery<K> query, Page<T, K> value,
      {Duration? ttl});

  /// Remove cached value by key.
  Future<void> remove(String key);

  /// Clear all cached values.
  Future<void> clear();

  /// Check if key exists and is not expired.
  Future<bool> has(String key);
}

/// Default in-memory implementation with TTL support (ignores query parameter).
///
/// This is a simple key-value cache that stores pages in memory with optional
/// time-to-live (TTL) expiration.
///
/// Example:
/// ```dart
/// final cache = MemoryCacheStore<Product, int>();
///
/// // Store with 5-minute TTL
/// await cache.put(
///   'products_page_0',
///   query,
///   page,
///   ttl: Duration(minutes: 5),
/// );
/// ```
class MemoryCacheStore<T, K> implements CacheStore<T, K> {
  final Map<String, _CacheEntry<T, K>> _cache = {};

  @override
  Future<Page<T, K>?> get(String key, PageQuery<K> query) async {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check expiry
    if (entry.expiresAt != null && DateTime.now().isAfter(entry.expiresAt!)) {
      _cache.remove(key);
      return null;
    }

    return entry.page;
  }

  @override
  Future<void> put(String key, PageQuery<K> query, Page<T, K> value,
      {Duration? ttl}) async {
    final expiresAt = ttl != null ? DateTime.now().add(ttl) : null;
    _cache[key] = _CacheEntry(value, expiresAt);
  }

  @override
  Future<void> remove(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }

  @override
  Future<bool> has(String key) async {
    final value = await get(
        key, PageQuery<K>(pageSize: 0)); // Dummy query for has check
    return value != null;
  }
}

/// Internal cache entry with optional expiration.
class _CacheEntry<T, K> {
  const _CacheEntry(this.page, this.expiresAt);

  final Page<T, K> page;
  final DateTime? expiresAt;
}
