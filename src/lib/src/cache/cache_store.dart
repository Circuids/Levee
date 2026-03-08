import '../data/page_data.dart';
import '../query/page_query.dart';

/// Abstract cache interface with query-aware methods and optional TTL support.
///
/// Example:
/// ```dart
/// final cache = MemoryCacheStore<Product, int>();
///
/// final paginator = Paginator<Product, int>(
///   source: ProductDataSource(),
///   cache: cache,
/// );
/// ```
abstract class CacheStore<T, K> {
  /// Get cached page by key with query context.
  ///
  /// Returns null if cache miss or expired.
  Future<PageData<T, K>?> get(String key, PageQuery<K> query);

  /// Store page with optional TTL.
  Future<void> put(String key, PageQuery<K> query, PageData<T, K> value,
      {Duration? ttl});

  /// Remove cached value by key.
  Future<void> remove(String key);

  /// Clear all cached values.
  Future<void> clear();

  /// Check if key exists and is not expired.
  Future<bool> has(String key);
}
