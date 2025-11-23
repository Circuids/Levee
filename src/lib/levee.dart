/// Levee: A lean, backend-agnostic pagination engine for Flutter.
///
/// Levee provides cache-first pagination with filtering, sorting, retry policies,
/// and UI widgets - all while staying dependency-free and explicit.
///
/// ## Quick Start
///
/// ```dart
/// // 1. Implement DataSource
/// class ProductDataSource implements DataSource<Product, int> {
///   @override
///   Future<Page<Product, int>> fetch(PageQuery<int> query) async {
///     // Fetch from your backend
///   }
/// }
///
/// // 2. Create Paginator
/// final paginator = Paginator<Product, int>(
///   source: ProductDataSource(),
///   cache: MemoryCacheStore(),
/// );
///
/// // 3. Use in UI
/// LeveeCollectionView<Product, int>(
///   paginator: paginator,
///   itemBuilder: (context, item, index) => ProductCard(item),
/// );
/// ```
library;

// Core contracts
export 'src/page.dart' show PageData, PageQuery, PageStatus;
export 'src/filter.dart'
    show FilterQuery, FilterField, FilterOperation, SortField;

// Cache layer
export 'src/cache_store.dart' show CacheStore, MemoryCacheStore;

// Backend integration
export 'src/data_source.dart' show DataSource;

// Paginator
export 'src/paginator.dart' show Paginator, PageState, RetryPolicy, CachePolicy;

// UI widgets
export 'src/collection_view.dart' show LeveeBuilder, LeveeCollectionView;
