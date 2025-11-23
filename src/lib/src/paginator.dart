
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'cache_store.dart';
import 'data_source.dart';
import 'filter.dart';
import 'page.dart';

/// Retry configuration for handling transient failures.
///
/// Example:
/// ```dart
/// RetryPolicy(maxAttempts: 3)  // Basic retry
/// RetryPolicy.exponential(maxAttempts: 5)  // Exponential backoff
/// ```
class RetryPolicy {
  /// Creates a retry policy with the given configuration.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.delay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.retryIf,
  });

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay between retries.
  final Duration delay;

  /// Maximum delay cap for exponential backoff.
  final Duration maxDelay;

  /// Optional conditional retry. If provided, only retry if this returns true.
  final bool Function(Exception)? retryIf;

  /// Helper constructor for exponential backoff retry policy.
  const RetryPolicy.exponential({
    this.maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  })  : delay = initialDelay,
        maxDelay = const Duration(seconds: 30),
        retryIf = null;
}

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

/// Immutable pagination state.
///
/// Exposes current items, status, errors, and loading flags.
class PageState<T> {
  /// Creates a page state with the given values.
  const PageState({
    required this.items,
    required this.status,
    this.error,
    required this.hasMore,
    this.isFromCache = false,
    this.isRefreshing = false,
    this.retryAttempt,
  });

  /// The list of items loaded so far.
  final List<T> items;

  /// Current pagination status.
  final PageStatus status;

  /// Error that occurred during loading (if any).
  final Exception? error;

  /// Whether there are more pages to load.
  final bool hasMore;

  /// True if the current data came from cache.
  final bool isFromCache;

  /// True if a background fetch is in progress (for cacheFirst policy).
  final bool isRefreshing;

  /// Current retry attempt number (null if no retry in progress).
  final int? retryAttempt;

  /// Creates an initial empty state.
  factory PageState.initial() => PageState<T>(
        items: const [],
        status: PageStatus.idle,
        hasMore: true,
      );

  /// Creates a copy of this state with the given fields replaced.
  PageState<T> copyWith({
    List<T>? items,
    PageStatus? status,
    Exception? error,
    bool? hasMore,
    bool? isFromCache,
    bool? isRefreshing,
    int? retryAttempt,
    bool clearError = false,
  }) {
    return PageState<T>(
      items: items ?? this.items,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      isFromCache: isFromCache ?? this.isFromCache,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      retryAttempt: retryAttempt,
    );
  }
}

/// Core pagination engine with state management.
///
/// Example:
/// ```dart
/// final paginator = Paginator<Product, int>(
///   source: ProductDataSource(),
///   cache: MemoryCacheStore(),
///   pageSize: 20,
///   cachePolicy: CachePolicy.cacheFirst,
/// );
///
/// await paginator.loadInitial();  // Load first page
/// await paginator.loadNext();     // Load next page
/// await paginator.refresh();      // Refresh data
/// ```
class Paginator<T, K> extends ChangeNotifier {
  /// Creates a paginator with the given configuration.
  Paginator({
    required this.source,
    this.cache,
    this.pageSize = 20,
    this.cachePolicy = CachePolicy.cacheFirst,
    this.retryPolicy,
    this.initialFilter,
  }) {
    _currentFilter = initialFilter;
  }

  /// The data source to fetch pages from.
  final DataSource<T, K> source;

  /// Optional cache store for caching pages.
  final CacheStore<T, K>? cache;

  /// Number of items per page.
  final int pageSize;

  /// Cache behavior strategy.
  final CachePolicy cachePolicy;

  /// Optional retry configuration.
  final RetryPolicy? retryPolicy;

  /// Initial filter to apply on first load.
  final FilterQuery? initialFilter;

  /// Current pagination state.
  PageState<T> get state => _state;
  PageState<T> _state = PageState.initial();

  /// Current filter being applied.
  FilterQuery? _currentFilter;

  /// Next page key to fetch.
  K? _nextPageKey;

  /// Whether a load operation is currently in progress.
  bool _isLoading = false;

  /// Load the first page.
  ///
  /// Respects the [cachePolicy] and [initialFilter] configuration.
  Future<void> loadInitial() async {
    if (_isLoading) return;

    _isLoading = true;
    _state = PageState.initial();
    _nextPageKey = null;
    notifyListeners();

    try {
      await _loadPage(isInitial: true);
    } finally {
      _isLoading = false;
    }
  }

  /// Load the next page.
  ///
  /// Does nothing if there are no more pages or if a load is already in progress.
  Future<void> loadNext() async {
    if (_isLoading || !_state.hasMore || _state.status == PageStatus.loading) {
      return;
    }

    _isLoading = true;
    _state = _state.copyWith(status: PageStatus.loading);
    notifyListeners();

    try {
      await _loadPage(isInitial: false);
    } finally {
      _isLoading = false;
    }
  }

  /// Refresh data, optionally clearing the cache.
  ///
  /// Resets pagination state and reloads the first page.
  Future<void> refresh({bool clearCache = true}) async {
    if (clearCache && cache != null) {
      await cache!.clear();
    }

    _isLoading = false; // Allow refresh even if loading
    await loadInitial();
  }

  /// Update the filter and reload data.
  ///
  /// Clears current items and loads the first page with the new filter.
  Future<void> updateFilter(FilterQuery? filter) async {
    _currentFilter = filter;
    _isLoading = false; // Cancel any in-progress load
    await loadInitial();
  }

  /// Load a page with the configured cache policy.
  Future<void> _loadPage({required bool isInitial}) async {
    final query = PageQuery<K>(
      pageSize: pageSize,
      pageKey: isInitial ? null : _nextPageKey,
      filter: _currentFilter,
    );

    switch (cachePolicy) {
      case CachePolicy.cacheFirst:
        await _loadCacheFirst(query, isInitial);
        break;
      case CachePolicy.networkFirst:
        await _loadNetworkFirst(query, isInitial);
        break;
      case CachePolicy.cacheOnly:
        await _loadCacheOnly(query, isInitial);
        break;
      case CachePolicy.networkOnly:
        await _loadNetworkOnly(query, isInitial);
        break;
    }
  }

  /// Cache-first policy: Show cache immediately, fetch network in background.
  Future<void> _loadCacheFirst(PageQuery<K> query, bool isInitial) async {
    final cacheKey = _generateCacheKey(query);
    PageData<T, K>? cachedPage;

    // Try to get from cache first
    if (cache != null) {
      cachedPage = await cache!.get(cacheKey, query);
    }

    if (cachedPage != null) {
      // Show cached data immediately
      _updateStateFromPage(cachedPage, isFromCache: true, isInitial: isInitial);
      _state = _state.copyWith(isRefreshing: true);
      notifyListeners();

      // Fetch from network in background to update cache
      try {
        final freshPage = await _fetchWithRetry(query);
        await cache?.put(cacheKey, query, freshPage);
        _updateStateFromPage(freshPage,
            isFromCache: false, isInitial: isInitial, clearRefreshing: true);
      } catch (e) {
        // Background fetch failed, but we have cached data so just clear refreshing flag
        _state = _state.copyWith(isRefreshing: false);
        notifyListeners();
      }
    } else {
      // Cache miss, fetch from network
      try {
        final page = await _fetchWithRetry(query);
        await cache?.put(cacheKey, query, page);
        _updateStateFromPage(page, isFromCache: false, isInitial: isInitial);
      } catch (e) {
        _handleError(e as Exception);
      }
    }
  }

  /// Network-first policy: Try network, fallback to cache on error.
  Future<void> _loadNetworkFirst(PageQuery<K> query, bool isInitial) async {
    final cacheKey = _generateCacheKey(query);

    try {
      final page = await _fetchWithRetry(query);
      await cache?.put(cacheKey, query, page);
      _updateStateFromPage(page, isFromCache: false, isInitial: isInitial);
    } catch (e) {
      // Network failed, try cache as fallback
      if (cache != null) {
        final cachedPage = await cache!.get(cacheKey, query);
        if (cachedPage != null) {
          _updateStateFromPage(cachedPage,
              isFromCache: true, isInitial: isInitial);
          return;
        }
      }
      _handleError(e as Exception);
    }
  }

  /// Cache-only policy: Only use cache, never fetch from network.
  Future<void> _loadCacheOnly(PageQuery<K> query, bool isInitial) async {
    if (cache == null) {
      _handleError(
          Exception('Cache-only policy requires a cache store to be configured'));
      return;
    }

    final cacheKey = _generateCacheKey(query);
    final cachedPage = await cache!.get(cacheKey, query);

    if (cachedPage != null) {
      _updateStateFromPage(cachedPage, isFromCache: true, isInitial: isInitial);
    } else {
      _handleError(Exception('No cached data available for this query'));
    }
  }

  /// Network-only policy: Always fetch from network, bypass cache.
  Future<void> _loadNetworkOnly(PageQuery<K> query, bool isInitial) async {
    try {
      final page = await _fetchWithRetry(query);
      _updateStateFromPage(page, isFromCache: false, isInitial: isInitial);
    } catch (e) {
      _handleError(e as Exception);
    }
  }

  /// Fetch a page from the data source with optional retry logic.
  Future<PageData<T, K>> _fetchWithRetry(PageQuery<K> query) async {
    if (retryPolicy == null) {
      return await source.fetch(query);
    }

    int attempt = 0;
    Duration currentDelay = retryPolicy!.delay;

    while (true) {
      try {
        if (attempt > 0) {
          _state = _state.copyWith(retryAttempt: attempt);
          notifyListeners();
        }

        return await source.fetch(query);
      } catch (e) {
        attempt++;

        // Check if we should retry
        final shouldRetry = attempt < retryPolicy!.maxAttempts &&
            (retryPolicy!.retryIf == null ||
                (e is Exception && retryPolicy!.retryIf!(e)));

        if (!shouldRetry) {
          rethrow;
        }

        // Exponential backoff
        await Future.delayed(currentDelay);
        currentDelay = Duration(
          milliseconds: math.min(
            currentDelay.inMilliseconds * 2,
            retryPolicy!.maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }

  /// Update state from a fetched page.
  void _updateStateFromPage(
    PageData<T, K> page, {
    required bool isFromCache,
    required bool isInitial,
    bool clearRefreshing = false,
  }) {
    final newItems = isInitial ? page.items : [..._state.items, ...page.items];
    _nextPageKey = page.nextPageKey;

    _state = PageState(
      items: newItems,
      status: PageStatus.ready,
      hasMore: !page.isLastPage,
      isFromCache: isFromCache,
      isRefreshing: clearRefreshing ? false : _state.isRefreshing,
      retryAttempt: null,
    );
    notifyListeners();
  }

  /// Handle error during page load.
  void _handleError(Exception error) {
    _state = _state.copyWith(
      status: PageStatus.error,
      error: error,
      isRefreshing: false,
      retryAttempt: null,
    );
    notifyListeners();
  }

  /// Generate a deterministic cache key from the query.
  String _generateCacheKey(PageQuery<K> query) {
    final keyParts = {
      'pageKey': query.pageKey?.toString() ?? 'null',
      'filter': query.filter?.toMap() ?? {},
    };
    final jsonString = jsonEncode(keyParts);
    return base64Encode(utf8.encode(jsonString));
  }

}
