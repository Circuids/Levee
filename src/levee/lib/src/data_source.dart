import 'page.dart';

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
///   Future<Page<Product, int>> fetch(PageQuery<int> query) async {
///     // Interpret filters for your backend
///     final filters = query.filter?.filters ?? [];
///     final sorting = query.filter?.sorting ?? [];
///
///     // Make API call
///     final response = await _client.getProducts(
///       offset: query.pageKey ?? 0,
///       limit: query.pageSize,
///       filters: filters,
///       sorting: sorting,
///     );
///
///     // Return paginated result
///     return Page(
///       items: response.products,
///       nextPageKey: response.hasMore ? (query.pageKey ?? 0) + query.pageSize : null,
///       isLastPage: !response.hasMore,
///       totalCount: response.totalCount,
///     );
///   }
/// }
/// ```
abstract class DataSource<T, K> {
  /// Fetch a page of items based on the query.
  ///
  /// Implementations should:
  /// - Interpret [FilterQuery] for their backend
  /// - Handle pagination using [pageKey] (offset, cursor, etc)
  /// - Return [Page] with items and next page key
  /// - Throw exceptions for errors (Paginator will handle retry if configured)
  ///
  /// The [query] contains:
  /// - `pageSize`: Number of items to fetch
  /// - `pageKey`: Identifier for which page to fetch (null for first page)
  /// - `filter`: Optional filtering and sorting configuration
  ///
  /// Example for Firestore:
  /// ```dart
  /// @override
  /// Future<Page<Product, DocumentSnapshot>> fetch(
  ///   PageQuery<DocumentSnapshot> query,
  /// ) async {
  ///   var ref = FirebaseFirestore.instance.collection('products');
  ///
  ///   // Apply filters
  ///   if (query.filter != null) {
  ///     for (final filter in query.filter!.filters) {
  ///       ref = ref.where(filter.field, isEqualTo: filter.value);
  ///     }
  ///   }
  ///
  ///   // Apply pagination
  ///   if (query.pageKey != null) {
  ///     ref = ref.startAfterDocument(query.pageKey);
  ///   }
  ///
  ///   final snapshot = await ref.limit(query.pageSize).get();
  ///
  ///   return Page(
  ///     items: snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
  ///     nextPageKey: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
  ///     isLastPage: snapshot.docs.length < query.pageSize,
  ///   );
  /// }
  /// ```
  Future<Page<T, K>> fetch(PageQuery<K> query);
}
