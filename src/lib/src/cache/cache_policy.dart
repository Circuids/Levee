/// Defines cache behavior strategies.
enum CachePolicy {
  /// Show cache immediately, fetch network in background to update.
  cacheFirst,

  /// Try network first, fallback to cache on error.
  networkFirst,

  /// Only use cache, never fetch network (offline mode).
  cacheOnly,

  /// Always fetch network, bypass cache.
  networkOnly,
}
