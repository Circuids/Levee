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
///   Future<PageData<Product, int>> fetch(PageQuery<int> query) async {
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

// Core
export 'src/core/paginator.dart' show Paginator;
export 'src/core/page_state.dart' show PageState, PageStatus;
export 'src/core/merge_mode.dart' show MergeMode;
export 'src/core/retry_policy.dart' show RetryPolicy;

// Query
export 'src/query/page_query.dart' show PageQuery;
export 'src/query/filter_query.dart'
    show FilterQuery, FilterField, FilterOperation, SortField;

// Data
export 'src/data/page_data.dart' show PageData;
export 'src/data/data_source.dart' show DataSource;

// Cache
export 'src/cache/cache_store.dart' show CacheStore;
export 'src/cache/memory_cache_store.dart' show MemoryCacheStore;
export 'src/cache/cache_policy.dart' show CachePolicy;

// UI
export 'src/ui/levee_builder.dart' show LeveeBuilder;
export 'src/ui/levee_collection_view.dart' show LeveeCollectionView;
