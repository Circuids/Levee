import 'filter.dart';

/// A single page of paginated data with metadata.
///
/// Contains items, pagination state ([nextPageKey], [isLastPage]),
/// and optional [totalCount].
///
/// Supports any pagination strategy via generic key type [K]:
/// - `int` for offset pagination (REST)
/// - `String` for cursor pagination (GraphQL)
/// - `DocumentSnapshot` for Firestore
///
/// Example:
/// ```dart
/// final page = PageData<Product, int>(
///   items: [product1, product2],
///   nextPageKey: 20,
///   isLastPage: false,
///   totalCount: 100,
/// );
/// ```
class PageData<T, K> {
  /// Creates a [PageData] with the given items and metadata.
  const PageData({
    required this.items,
    this.nextPageKey,
    required this.isLastPage,
    this.totalCount,
  });

  /// The items in this page.
  final List<T> items;

  /// The key to fetch the next page. Null if this is the last page.
  final K? nextPageKey;

  /// Whether this is the last page of data.
  final bool isLastPage;

  /// Optional total count of items across all pages.
  final int? totalCount;
}

/// Parameters for fetching a page of data.
///
/// Specifies [pageSize], optional [pageKey] for which page to fetch,
/// and optional [filter] for filtering/sorting.
///
/// Use `pageKey: null` for the first page, then use [PageData.nextPageKey]
/// for subsequent pages.
///
/// Example:
/// ```dart
/// final query = PageQuery<int>(
///   pageSize: 20,
///   pageKey: previousPage.nextPageKey,
///   filter: FilterQuery(
///     filters: [FilterField(field: 'status', value: 'active')],
///     sorting: [SortField('createdAt', descending: true)],
///   ),
/// );
/// ```
///
/// Note: Different filters create separate cache entries in [Paginator].
class PageQuery<K> {
  /// Creates a [PageQuery] with the given parameters.
  const PageQuery({
    required this.pageSize,
    this.pageKey,
    this.filter,
  });

  /// The number of items to fetch per page.
  final int pageSize;

  /// The key identifying which page to fetch.
  /// - For offset pagination: int (e.g., 0, 20, 40)
  /// - For cursor pagination: String or DocumentSnapshot
  /// - Null for the first page
  final K? pageKey;

  /// Optional filter and sorting configuration.
  final FilterQuery? filter;

  /// Creates a copy of this query with the given fields replaced.
  PageQuery<K> copyWith({
    int? pageSize,
    K? pageKey,
    FilterQuery? filter,
  }) {
    return PageQuery<K>(
      pageSize: pageSize ?? this.pageSize,
      pageKey: pageKey ?? this.pageKey,
      filter: filter ?? this.filter,
    );
  }
}

/// Pagination lifecycle state.
///
/// State transitions:
/// - `idle` → `ready` (after loadInitial)
/// - `ready` → `loading` → `ready` (after loadNext)
/// - Any → `error` (on failure)
///
/// Use with [PageState] to determine UI rendering
/// ready
///
/// Any state
///   ↓ error occurs
/// error
///   ↓ retry or refresh()
/// loading → ready
/// ```
///
/// ## Usage in UI
///
/// ```dart
/// LeveeBuilder<Product>(
///   paginator: paginator,
///   builder: (context, state) {
///     // Initial loading state
///     if (state.status == PageStatus.idle && state.items.isEmpty) {
///       return CircularProgressIndicator();
///     }
///
///     // Error state
///     if (state.status == PageStatus.error) {
///       return ErrorWidget(
///         message: state.error.toString(),
///         onRetry: () => paginator.refresh(),
///       );
///     }
///
///     // Loading next page (show items + bottom loader)
///     if (state.status == PageStatus.loading) {
///       return Column(
///         children: [
///           ItemList(items: state.items),
///           CircularProgressIndicator(),
///         ],
///       );
///     }
///
///     // Ready state - show items
///     return ItemList(items: state.items);
///   },
/// )
/// ```
///
/// ## Important Notes
///
/// - [idle]: Used for initial state. `loadInitial()` resets to idle,
///   not loading (for clean state reset)
/// - [loading]: Only set by `loadNext()`, not `loadInitial()`
/// - [ready]: Indicates successful data load
/// - [error]: Set when fetch fails after all retry attempts
///
/// See also:
/// - [PageState] for complete pagination state including status
/// - [Paginator.state] for accessing current status
enum PageStatus {
  /// Initial state before any data is loaded.
  ///
  /// This is also the state after calling `refresh()` or `loadInitial()`
  /// while the internal loading flag is set.
  idle,

  /// Currently loading the next page of data.
  ///
  /// Set by `loadNext()` but not `loadInitial()`. UI can show a
  /// loading indicator at the bottom of the list while keeping
  /// existing items visible.
  loading,

  /// Data has been loaded successfully.
  ///
  /// Items are available in [PageState.items]. More pages may be
  /// available if [PageState.hasMore] is true.
  ready,

  /// An error occurred during the last fetch operation.
  ///
  /// The error details are in [PageState.error]. Existing items
  /// (if any) remain available for display.
  error,
}
