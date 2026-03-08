import '../query/filter_query.dart';

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
