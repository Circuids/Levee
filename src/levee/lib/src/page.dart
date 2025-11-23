import 'filter.dart';

/// Represents a slice of paginated data with metadata.
///
/// [T] is the type of items in the page.
/// [K] is the type of the page key (int, String, DocumentSnapshot, etc).
class Page<T, K> {
  /// Creates a [Page] with the given items and metadata.
  const Page({
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

/// Holds pagination parameters with generic page key support.
///
/// [K] is the type of the page key (int for offset, String for cursor, etc).
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

/// Explicit state machine for pagination status.
enum PageStatus {
  /// Initial state, no data loaded yet.
  idle,

  /// Loading data (initial or next page).
  loading,

  /// Data loaded successfully.
  ready,

  /// An error occurred during loading.
  error,
}
