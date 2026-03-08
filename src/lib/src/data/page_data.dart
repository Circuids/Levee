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
