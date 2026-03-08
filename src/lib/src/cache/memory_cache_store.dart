import '../data/page_data.dart';
import '../query/page_query.dart';
import 'cache_store.dart';

/// Default in-memory implementation with TTL support (ignores query parameter).
///
/// This is a simple key-value cache that stores pages in memory with optional
/// time-to-live (TTL) expiration.
///
/// Example:
/// ```dart
/// final cache = MemoryCacheStore<Product, int>();
///
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
  Future<PageData<T, K>?> get(String key, PageQuery<K> query) async {
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
  Future<void> put(String key, PageQuery<K> query, PageData<T, K> value,
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
    final value =
        await get(key, PageQuery<K>(pageSize: 0)); // Dummy query for has check
    return value != null;
  }
}

/// Internal cache entry with optional expiration.
class _CacheEntry<T, K> {
  const _CacheEntry(this.page, this.expiresAt);

  final PageData<T, K> page;
  final DateTime? expiresAt;
}
