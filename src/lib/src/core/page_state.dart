/// Pagination lifecycle state.
///
/// State transitions:
/// - `idle` → `ready` (after loadInitial)
/// - `ready` → `loading` → `ready` (after loadNext)
/// - Any → `error` (on failure)
enum PageStatus {
  /// Initial state before any data is loaded.
  idle,

  /// Currently loading the next page of data.
  loading,

  /// Data has been loaded successfully.
  ready,

  /// An error occurred during the last fetch operation.
  error,
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

  /// Whether a load operation is currently in progress.
  bool get isLoading => status == PageStatus.loading;

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
