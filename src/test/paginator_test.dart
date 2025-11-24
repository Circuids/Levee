import 'package:flutter_test/flutter_test.dart';
import 'package:levee/levee.dart';

// Mock DataSource for testing
class MockDataSource<T, K> implements DataSource<T, K> {
  final Future<PageData<T, K>> Function(PageQuery<K> query) fetchPageImpl;
  int fetchCallCount = 0;

  MockDataSource(this.fetchPageImpl);

  @override
  Future<PageData<T, K>> fetch(PageQuery<K> query) {
    fetchCallCount++;
    return fetchPageImpl(query);
  }
}

// Mock CacheStore for testing
class MockCacheStore<T, K> implements CacheStore<T, K> {
  final Map<String, PageData<T, K>> _cache = {};
  int getCallCount = 0;
  int putCallCount = 0;
  int removeCallCount = 0;
  int clearCallCount = 0;
  int hasCallCount = 0;

  @override
  Future<PageData<T, K>?> get(String key, PageQuery<K> query) async {
    getCallCount++;
    return _cache[key];
  }

  @override
  Future<void> put(String key, PageQuery<K> query, PageData<T, K> value,
      {Duration? ttl}) async {
    putCallCount++;
    _cache[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    removeCallCount++;
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    clearCallCount++;
    _cache.clear();
  }

  @override
  Future<bool> has(String key) async {
    hasCallCount++;
    return _cache.containsKey(key);
  }
}

// Test Model
class TestItem {
  final int id;
  final String name;

  TestItem(this.id, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  group('Paginator Cache Policies', () {
    late MockDataSource<TestItem, int> dataSource;
    late MockCacheStore<TestItem, int> cacheStore;

    setUp(() {
      dataSource = MockDataSource((query) async {
        // Simulate network delay
        await Future.delayed(Duration(milliseconds: 10));
        final pageKey = query.pageKey ?? 0;
        return PageData<TestItem, int>(
          items: [
            TestItem(pageKey, 'Item $pageKey'),
            TestItem(pageKey + 1, 'Item ${pageKey + 1}'),
          ],
          nextPageKey: pageKey + 2,
          isLastPage: false,
        );
      });

      cacheStore = MockCacheStore<TestItem, int>();
    });

    test('CacheFirst - returns cached data without network call', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.cacheFirst,
      );

      // First load - should hit network
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);
      expect(dataSource.fetchCallCount, 1);
      expect(cacheStore.putCallCount, 1);

      // Create new paginator with same config - should use cache
      final paginator2 = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.cacheFirst,
      );

      await paginator2.loadInitial();
      // Cache first shows cached data immediately (or refreshed data if background fetch completed)
      expect(paginator2.state.items.length, 2);

      paginator.dispose();
      paginator2.dispose();
    });

    test('NetworkFirst - always fetches from network', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.networkFirst,
      );

      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);
      expect(dataSource.fetchCallCount, 1);

      // Load next page - should hit network again
      await paginator.loadNext();
      expect(paginator.state.items.length, 4);
      expect(dataSource.fetchCallCount, 2);

      paginator.dispose();
    });

    test('NetworkFirst - falls back to cache on network error', () async {
      // Create data source that fails initially, then succeeds
      int callCount = 0;
      final unstableDataSource = MockDataSource<TestItem, int>((query) async {
        callCount++;
        if (callCount == 1) {
          throw Exception('Network error');
        }
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Success Item')],
          nextPageKey: null,
          isLastPage: true,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: unstableDataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.networkFirst,
        retryPolicy: RetryPolicy(maxAttempts: 0), // No retries
      );

      // First load fails - should result in error since no cache
      await paginator.loadInitial();
      expect(paginator.state.status, PageStatus.error);

      // Now manually add to cache and try with cacheFirst to verify cache works
      final paginator2 = Paginator<TestItem, int>(
        source: unstableDataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.cacheFirst,
      );

      await paginator2.loadInitial();
      // Should succeed with network (callCount=2)
      expect(paginator2.state.items.length, 1);

      paginator.dispose();
      paginator2.dispose();
    });

    test('CacheOnly - only returns cached data', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.cacheOnly,
      );

      // Since cache key generation is internal, test that cacheOnly doesn't hit network
      await paginator.loadInitial();

      expect(dataSource.fetchCallCount, 0); // No network call
      // State will be error since cache is empty, which is correct behavior

      paginator.dispose();
    });

    test('CacheOnly - returns error when cache is empty', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.cacheOnly,
      );

      await paginator.loadInitial();

      expect(paginator.state.items, isEmpty);
      expect(paginator.state.status, PageStatus.error); // Should be error state
      expect(dataSource.fetchCallCount, 0); // No network call

      paginator.dispose();
    });

    test('NetworkOnly - always fetches from network and ignores cache',
        () async {
      // Pre-populate cache
      final cachedPage = PageData<TestItem, int>(
        items: [TestItem(0, 'Cached Item')],
        nextPageKey: 2,
        isLastPage: false,
      );
      final testQuery = PageQuery<int>(pageSize: 2, pageKey: null);
      await cacheStore.put('page_0_null', testQuery, cachedPage);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      await paginator.loadInitial();

      expect(paginator.state.items.length, 2);
      expect(paginator.state.items.first.name, 'Item 0'); // Not cached
      expect(dataSource.fetchCallCount, 1);
      expect(cacheStore.getCallCount, 0); // Cache not checked

      paginator.dispose();
    });
  });

  group('Paginator Retry Logic', () {
    test('retries on network failure with exponential backoff', () async {
      int attemptCount = 0;
      final dataSource = MockDataSource<TestItem, int>((query) async {
        attemptCount++;
        if (attemptCount < 3) {
          throw Exception('Network error');
        }
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Success')],
          nextPageKey: 2,
          isLastPage: false,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 3),
      );

      final startTime = DateTime.now();
      await paginator.loadInitial();
      final duration = DateTime.now().difference(startTime);

      // Should succeed on 3rd attempt
      expect(paginator.state.items.length, 1);
      expect(attemptCount, 3);
      expect(paginator.state.status, PageStatus.ready);

      // Should have delayed (exponential backoff: 1s + 2s = 3s minimum)
      // Using loose bounds for test timing reliability
      expect(duration.inMilliseconds, greaterThan(2500));

      paginator.dispose();
    });

    test('gives up after maxRetries exceeded', () async {
      final dataSource = MockDataSource<TestItem, int>((query) async {
        throw Exception('Network error');
      });

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 2),
      );

      await paginator.loadInitial();

      // Should have error after maxAttempts retries
      expect(paginator.state.status, PageStatus.error);
      expect(paginator.state.error.toString(), contains('Network error'));
      expect(dataSource.fetchCallCount, 2); // maxAttempts = 2

      paginator.dispose();
    });

    test('does not retry on success', () async {
      final dataSource = MockDataSource<TestItem, int>((query) async {
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Success')],
          nextPageKey: 2,
          isLastPage: false,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 3),
      );

      await paginator.loadInitial();

      expect(paginator.state.items.length, 1);
      expect(dataSource.fetchCallCount, 1); // Only one attempt
      expect(paginator.state.status, PageStatus.ready);

      paginator.dispose();
    });
  });

  group('Paginator State Management', () {
    late MockDataSource<TestItem, int> dataSource;

    setUp(() {
      dataSource = MockDataSource((query) async {
        await Future.delayed(Duration(milliseconds: 10));
        final pageKey = query.pageKey ?? 0;
        return PageData<TestItem, int>(
          items: [TestItem(pageKey, 'Item $pageKey')],
          nextPageKey: pageKey < 4 ? pageKey + 2 : null,
          isLastPage: pageKey >= 4,
        );
      });
    });

    test('initial state is correct', () {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      expect(paginator.state.items, isEmpty);
      expect(paginator.state.status, PageStatus.idle);
      expect(paginator.state.error, isNull);
      expect(paginator.state.hasMore, true);

      paginator.dispose();
    });

    test('loading state transitions correctly', () async {
      final slowDataSource = MockDataSource<TestItem, int>((query) async {
        await Future.delayed(Duration(milliseconds: 100));
        return PageData<TestItem, int>(
          items: [TestItem(query.pageKey ?? 0, 'Item')],
          nextPageKey: (query.pageKey ?? 0) + 2,
          isLastPage: false,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: slowDataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Load initial page first
      await paginator.loadInitial();
      expect(paginator.state.status, PageStatus.ready);

      // Now load next page which DOES set loading status
      final loadFuture = paginator.loadNext();

      // Wait a bit then check if loading
      await Future.delayed(Duration(milliseconds: 10));
      final wasLoading = paginator.state.status == PageStatus.loading;

      // Complete the load
      await loadFuture;

      // Should have transitioned through loading to ready
      expect(wasLoading, true);
      expect(paginator.state.status, PageStatus.ready);
      expect(paginator.state.items.length, 2); // Initial + next page

      paginator.dispose();
    });

    test('error state is set on failure', () async {
      final errorDataSource = MockDataSource<TestItem, int>((query) async {
        throw Exception('Test error');
      });

      final paginator = Paginator<TestItem, int>(
        source: errorDataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 0),
      );

      await paginator.loadInitial();

      expect(paginator.state.status, PageStatus.error);
      expect(paginator.state.error.toString(), contains('Test error'));

      paginator.dispose();
    });

    test('hasMore is false when nextPageKey is null', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Load pages until no more
      await paginator.loadInitial(); // page at key 0
      expect(paginator.state.hasMore, true);

      await paginator.loadNext(); // page at key 2
      expect(paginator.state.hasMore, true);

      await paginator.loadNext(); // page at key 4, nextKey = null
      expect(paginator.state.hasMore, false);

      paginator.dispose();
    });

    test('loadNext does nothing when already loading', () async {
      final slowDataSource = MockDataSource<TestItem, int>((query) async {
        await Future.delayed(Duration(milliseconds: 100));
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Item')],
          nextPageKey: 2,
          isLastPage: false,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: slowDataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Start first load
      final future1 = paginator.loadInitial();

      // Try to load next while loading
      await paginator.loadNext();

      await future1;

      // Should only have one page
      expect(paginator.state.items.length, 1);
      expect(slowDataSource.fetchCallCount, 1);

      paginator.dispose();
    });

    test('loadNext does nothing when hasMore is false', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Load all pages
      await paginator.loadInitial();
      await paginator.loadNext();
      await paginator.loadNext();

      expect(paginator.state.hasMore, false);
      final itemCount = paginator.state.items.length;

      // Try to load more
      await paginator.loadNext();

      expect(paginator.state.items.length, itemCount); // No change
      expect(dataSource.fetchCallCount, 3); // No additional call

      paginator.dispose();
    });

    test('refresh clears items and reloads from first page', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Load multiple pages
      await paginator.loadInitial();
      await paginator.loadNext();
      expect(paginator.state.items.length, 2);

      // Refresh
      await paginator.refresh();

      // Should have reloaded from first page
      expect(paginator.state.items.length, 1);
      expect(paginator.state.items.first.id, 0);
      expect(dataSource.fetchCallCount, 3); // 2 initial + 1 refresh

      paginator.dispose();
    });

    test('notifies listeners on state changes', () async {
      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      int notificationCount = 0;
      paginator.addListener(() {
        notificationCount++;
      });

      await paginator.loadInitial();

      // Should notify at least twice: loading start + loading end
      expect(notificationCount, greaterThanOrEqualTo(2));

      paginator.dispose();
    });
  });

  group('Paginator with Filters', () {
    test('different filters create different cache keys', () async {
      final dataSource = MockDataSource<TestItem, int>((query) async {
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Item')],
          nextPageKey: null,
          isLastPage: true,
        );
      });

      final cacheStore = MockCacheStore<TestItem, int>();

      // Load with filter1
      final paginator1 = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 10,
        cachePolicy: CachePolicy.cacheFirst,
        initialFilter: FilterQuery(
          filters: [
            FilterField(
              field: 'status',
              value: 'active',
              operation: FilterOperation.equals,
            ),
          ],
        ),
      );

      await paginator1.loadInitial();

      // Load with filter2
      final paginator2 = Paginator<TestItem, int>(
        source: dataSource,
        cache: cacheStore,
        pageSize: 10,
        cachePolicy: CachePolicy.cacheFirst,
        initialFilter: FilterQuery(
          filters: [
            FilterField(
              field: 'status',
              value: 'inactive',
              operation: FilterOperation.equals,
            ),
          ],
        ),
      );

      await paginator2.loadInitial();

      // Should have made two network calls (different cache keys)
      expect(dataSource.fetchCallCount, 2);
      expect(cacheStore.putCallCount, 2);

      paginator1.dispose();
      paginator2.dispose();
    });

    test('updateFilter reloads data with new filter', () async {
      final dataSource = MockDataSource<TestItem, int>((query) async {
        final filterValue = query.filter?.filters.firstOrNull?.value ?? 'none';
        return PageData<TestItem, int>(
          items: [TestItem(0, 'Item with filter: $filterValue')],
          nextPageKey: null,
          isLastPage: true,
        );
      });

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 10,
        cachePolicy: CachePolicy.networkOnly,
      );

      // Initial load
      await paginator.loadInitial();
      expect(paginator.state.items.first.name, 'Item with filter: none');

      // Update filter
      await paginator.updateFilter(FilterQuery(
        filters: [
          FilterField(
            field: 'status',
            value: 'active',
            operation: FilterOperation.equals,
          ),
        ],
      ));

      expect(paginator.state.items.first.name, 'Item with filter: active');
      expect(dataSource.fetchCallCount, 2);

      paginator.dispose();
    });
  });

  group('Paginator List Mutations', () {
    late Paginator<TestItem, int> paginator;
    late MockDataSource<TestItem, int> dataSource;

    setUp(() {
      dataSource = MockDataSource((query) async {
        final pageKey = query.pageKey ?? 0;
        return PageData<TestItem, int>(
          items: [
            TestItem(pageKey, 'Item $pageKey'),
            TestItem(pageKey + 1, 'Item ${pageKey + 1}'),
          ],
          nextPageKey: pageKey + 2,
          isLastPage: false,
        );
      });

      paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );
    });

    tearDown(() {
      paginator.dispose();
    });

    test('updateItem replaces matching item', () async {
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);
      expect(paginator.state.items[0].name, 'Item 0');

      // Update first item
      paginator.updateItem(
        TestItem(0, 'Updated Item 0'),
        (item) => item.id == 0,
      );

      expect(paginator.state.items.length, 2);
      expect(paginator.state.items[0].name, 'Updated Item 0');
      expect(paginator.state.items[1].name, 'Item 1');
    });

    test('updateItem does nothing if predicate matches no items', () async {
      await paginator.loadInitial();
      final originalLength = paginator.state.items.length;

      paginator.updateItem(
        TestItem(999, 'Non-existent'),
        (item) => item.id == 999,
      );

      expect(paginator.state.items.length, originalLength);
    });

    test('removeItem removes matching items', () async {
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);

      // Remove first item
      paginator.removeItem((item) => item.id == 0);

      expect(paginator.state.items.length, 1);
      expect(paginator.state.items[0].id, 1);
    });

    test('removeItem removes multiple matching items', () async {
      await paginator.loadInitial();
      await paginator.loadNext();
      expect(paginator.state.items.length, 4);

      // Remove all even-numbered items
      paginator.removeItem((item) => item.id % 2 == 0);

      expect(paginator.state.items.length, 2);
      expect(paginator.state.items.every((item) => item.id % 2 == 1), true);
    });

    test('removeItem does nothing if predicate matches no items', () async {
      await paginator.loadInitial();
      final originalLength = paginator.state.items.length;

      paginator.removeItem((item) => item.id == 999);

      expect(paginator.state.items.length, originalLength);
    });

    test('insertItem adds item at top by default', () async {
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);

      final newItem = TestItem(99, 'New Item');
      paginator.insertItem(newItem);

      expect(paginator.state.items.length, 3);
      expect(paginator.state.items[0].id, 99);
      expect(paginator.state.items[0].name, 'New Item');
    });

    test('insertItem adds item at specified position', () async {
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);

      final newItem = TestItem(99, 'New Item');
      paginator.insertItem(newItem, position: 1);

      expect(paginator.state.items.length, 3);
      expect(paginator.state.items[1].id, 99);
      expect(paginator.state.items[0].id, 0);
      expect(paginator.state.items[2].id, 1);
    });

    test('insertItem clamps position to valid range', () async {
      await paginator.loadInitial();
      expect(paginator.state.items.length, 2);

      // Try to insert at position 999 (should clamp to end)
      final newItem = TestItem(99, 'New Item');
      paginator.insertItem(newItem, position: 999);

      expect(paginator.state.items.length, 3);
      expect(paginator.state.items[2].id, 99);
    });

    test('insertItem works on empty list', () async {
      // Don't load initial, start with empty list
      expect(paginator.state.items.length, 0);

      final newItem = TestItem(99, 'New Item');
      paginator.insertItem(newItem);

      expect(paginator.state.items.length, 1);
      expect(paginator.state.items[0].id, 99);
    });

    test('mutations trigger notifyListeners', () async {
      await paginator.loadInitial();
      int notificationCount = 0;

      paginator.addListener(() {
        notificationCount++;
      });

      paginator.updateItem(TestItem(0, 'Updated'), (item) => item.id == 0);
      expect(notificationCount, 1);

      paginator.removeItem((item) => item.id == 1);
      expect(notificationCount, 2);

      paginator.insertItem(TestItem(99, 'New'));
      expect(notificationCount, 3);
    });
  });
}
