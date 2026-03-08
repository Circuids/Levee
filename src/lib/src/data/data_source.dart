import '../data/page_data.dart';
import '../query/page_query.dart';

/// Minimal backend integration contract.
///
/// Implement this interface to connect your backend (REST, GraphQL, Firestore,
/// SQLite, etc.) to the Levee pagination engine.
///
/// [T] is the type of items being paginated.
/// [K] is the type of the page key (int for offset, String for cursor, etc).
///
/// Example:
/// ```dart
/// class ProductDataSource implements DataSource<Product, int> {
///   final ApiClient _client;
///
///   ProductDataSource(this._client);
///
///   @override
///   Future<PageData<Product, int>> fetch(PageQuery<int> query) async {
///     final response = await _client.getProducts(
///       offset: query.pageKey ?? 0,
///       limit: query.pageSize,
///     );
///
///     return PageData(
///       items: response.products,
///       nextPageKey: response.hasMore ? (query.pageKey ?? 0) + query.pageSize : null,
///       isLastPage: !response.hasMore,
///     );
///   }
/// }
/// ```
abstract class DataSource<T, K> {
  /// Fetch a page of items based on the query.
  ///
  /// The [query] contains:
  /// - `pageSize`: Number of items to fetch
  /// - `pageKey`: Identifier for which page to fetch (null for first page)
  /// - `filter`: Optional filtering and sorting configuration
  Future<PageData<T, K>> fetch(PageQuery<K> query);
}
