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

// Test Model with key
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

  @override
  String toString() => 'TestItem($id, $name)';
}

void main() {
  group('MergeMode', () {
    group('append (default)', () {
      test('appends new page items to existing items', () async {
        final dataSource = MockDataSource<TestItem, int>((query) async {
          final key = query.pageKey ?? 0;
          return PageData<TestItem, int>(
            items: [
              TestItem(key, 'Item $key'),
              TestItem(key + 1, 'Item ${key + 1}'),
            ],
            nextPageKey: key + 2,
            isLastPage: false,
          );
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 2,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.append,
        );

        await paginator.loadInitial();
        expect(paginator.state.items.length, 2);
        expect(paginator.state.items[0].id, 0);
        expect(paginator.state.items[1].id, 1);

        await paginator.loadNext();
        expect(paginator.state.items.length, 4);
        expect(paginator.state.items[2].id, 2);
        expect(paginator.state.items[3].id, 3);

        paginator.dispose();
      });

      test('duplicates are kept in append mode', () async {
        final dataSource = MockDataSource<TestItem, int>((query) async {
          // Always returns the same items
          return PageData<TestItem, int>(
            items: [TestItem(0, 'Item 0'), TestItem(1, 'Item 1')],
            nextPageKey: (query.pageKey ?? 0) + 2,
            isLastPage: false,
          );
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 2,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.append,
        );

        await paginator.loadInitial();
        await paginator.loadNext();

        // In append mode, duplicates are kept
        expect(paginator.state.items.length, 4);
        expect(paginator.state.items[0].id, 0);
        expect(paginator.state.items[2].id, 0);

        paginator.dispose();
      });
    });

    group('replaceByKey', () {
      test('requires keySelector when using replaceByKey', () {
        expect(
          () => Paginator<TestItem, int>(
            source: MockDataSource<TestItem, int>(
                (q) async => PageData(items: [], isLastPage: true)),
            mergeMode: MergeMode.replaceByKey,
            // keySelector omitted
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('replaces existing items by key', () async {
        int callCount = 0;
        final dataSource = MockDataSource<TestItem, int>((query) async {
          callCount++;
          if (callCount == 1) {
            return PageData<TestItem, int>(
              items: [
                TestItem(1, 'Item 1 v1'),
                TestItem(2, 'Item 2 v1'),
                TestItem(3, 'Item 3 v1'),
              ],
              nextPageKey: 1,
              isLastPage: false,
            );
          } else {
            // Second page returns updated items 1,2 plus new item 4
            return PageData<TestItem, int>(
              items: [
                TestItem(1, 'Item 1 v2'),
                TestItem(2, 'Item 2 v2'),
                TestItem(4, 'Item 4 v1'),
              ],
              nextPageKey: null,
              isLastPage: true,
            );
          }
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 3,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.replaceByKey,
          keySelector: (item) => item.id,
        );

        await paginator.loadInitial();
        expect(paginator.state.items.length, 3);
        expect(paginator.state.items[0].name, 'Item 1 v1');
        expect(paginator.state.items[1].name, 'Item 2 v1');
        expect(paginator.state.items[2].name, 'Item 3 v1');

        await paginator.loadNext();
        // Items 1 and 2 should be replaced, item 3 unchanged, item 4 appended
        expect(paginator.state.items.length, 4);
        expect(paginator.state.items[0].name, 'Item 1 v2'); // Replaced
        expect(paginator.state.items[1].name, 'Item 2 v2'); // Replaced
        expect(paginator.state.items[2].name, 'Item 3 v1'); // Unchanged
        expect(paginator.state.items[3].name, 'Item 4 v1'); // Appended

        paginator.dispose();
      });

      test('preserves item order during replacement', () async {
        int callCount = 0;
        final dataSource = MockDataSource<TestItem, int>((query) async {
          callCount++;
          if (callCount == 1) {
            return PageData<TestItem, int>(
              items: [
                TestItem(1, 'First'),
                TestItem(2, 'Second'),
                TestItem(3, 'Third'),
              ],
              nextPageKey: 1,
              isLastPage: false,
            );
          } else {
            // Replace item 2 only
            return PageData<TestItem, int>(
              items: [TestItem(2, 'Updated Second')],
              nextPageKey: null,
              isLastPage: true,
            );
          }
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 3,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.replaceByKey,
          keySelector: (item) => item.id,
        );

        await paginator.loadInitial();
        await paginator.loadNext();

        // Order must be preserved
        expect(paginator.state.items[0].id, 1);
        expect(paginator.state.items[1].id, 2);
        expect(paginator.state.items[1].name, 'Updated Second');
        expect(paginator.state.items[2].id, 3);

        paginator.dispose();
      });

      test('appends all items when no keys match', () async {
        int callCount = 0;
        final dataSource = MockDataSource<TestItem, int>((query) async {
          callCount++;
          if (callCount == 1) {
            return PageData<TestItem, int>(
              items: [TestItem(1, 'First'), TestItem(2, 'Second')],
              nextPageKey: 1,
              isLastPage: false,
            );
          } else {
            return PageData<TestItem, int>(
              items: [TestItem(3, 'Third'), TestItem(4, 'Fourth')],
              nextPageKey: null,
              isLastPage: true,
            );
          }
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 2,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.replaceByKey,
          keySelector: (item) => item.id,
        );

        await paginator.loadInitial();
        await paginator.loadNext();

        // All items appended since no overlapping keys
        expect(paginator.state.items.length, 4);

        paginator.dispose();
      });

      test('initial load replaces state regardless of merge mode', () async {
        final dataSource = MockDataSource<TestItem, int>((query) async {
          return PageData<TestItem, int>(
            items: [TestItem(1, 'Item 1')],
            nextPageKey: null,
            isLastPage: true,
          );
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 2,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.replaceByKey,
          keySelector: (item) => item.id,
        );

        await paginator.loadInitial();
        expect(paginator.state.items.length, 1);

        // Load initial again should replace, not merge
        await paginator.refresh();
        expect(paginator.state.items.length, 1);

        paginator.dispose();
      });

      test('supports string keys via keySelector', () async {
        int callCount = 0;
        final dataSource = MockDataSource<TestItem, int>((query) async {
          callCount++;
          if (callCount == 1) {
            return PageData<TestItem, int>(
              items: [TestItem(1, 'alpha'), TestItem(2, 'beta')],
              nextPageKey: 1,
              isLastPage: false,
            );
          } else {
            return PageData<TestItem, int>(
              items: [TestItem(1, 'alpha-updated')],
              nextPageKey: null,
              isLastPage: true,
            );
          }
        });

        final paginator = Paginator<TestItem, int>(
          source: dataSource,
          pageSize: 2,
          cachePolicy: CachePolicy.networkOnly,
          mergeMode: MergeMode.replaceByKey,
          keySelector: (item) =>
              item.name.split('-').first, // key = "alpha" or "beta"
        );

        await paginator.loadInitial();
        await paginator.loadNext();

        // "alpha" key should match and replace
        expect(paginator.state.items.length, 2);
        expect(paginator.state.items[0].name, 'alpha-updated');
        expect(paginator.state.items[1].name, 'beta');

        paginator.dispose();
      });
    });
  });

  group('MergeMode enum', () {
    test('has expected values', () {
      expect(MergeMode.values, contains(MergeMode.append));
      expect(MergeMode.values, contains(MergeMode.replaceByKey));
      expect(MergeMode.values.length, 2);
    });
  });

  group('Local mutations with index parameter', () {
    late Paginator<TestItem, int> paginator;

    setUp(() async {
      final dataSource = MockDataSource<TestItem, int>((query) async {
        return PageData<TestItem, int>(
          items: [
            TestItem(1, 'Item 1'),
            TestItem(2, 'Item 2'),
            TestItem(3, 'Item 3'),
          ],
          nextPageKey: null,
          isLastPage: true,
        );
      });

      paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 3,
        cachePolicy: CachePolicy.networkOnly,
      );
      await paginator.loadInitial();
    });

    tearDown(() => paginator.dispose());

    test('insertItem with index=0 inserts at beginning', () {
      paginator.insertItem(TestItem(99, 'New'));
      expect(paginator.state.items[0].id, 99);
      expect(paginator.state.items.length, 4);
    });

    test('insertItem with specific index', () {
      paginator.insertItem(TestItem(99, 'New'), index: 2);
      expect(paginator.state.items[2].id, 99);
      expect(paginator.state.items.length, 4);
    });

    test('updateItem replaces first match', () {
      paginator.updateItem(
        TestItem(2, 'Updated Item 2'),
        (item) => item.id == 2,
      );
      expect(paginator.state.items[1].name, 'Updated Item 2');
      expect(paginator.state.items.length, 3);
    });

    test('removeItem removes matching items', () {
      paginator.removeItem((item) => item.id == 2);
      expect(paginator.state.items.length, 2);
      expect(paginator.state.items.any((i) => i.id == 2), false);
    });

    test('mutations notify listeners', () {
      int count = 0;
      paginator.addListener(() => count++);

      paginator.insertItem(TestItem(10, 'A'));
      expect(count, 1);

      paginator.updateItem(TestItem(10, 'B'), (i) => i.id == 10);
      expect(count, 2);

      paginator.removeItem((i) => i.id == 10);
      expect(count, 3);
    });

    test('mutations do not trigger network requests', () async {
      int fetchCount = 0;
      final ds = MockDataSource<TestItem, int>((query) async {
        fetchCount++;
        return PageData(
          items: [TestItem(1, 'A')],
          isLastPage: true,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );
      await p.loadInitial();
      expect(fetchCount, 1);

      p.insertItem(TestItem(2, 'B'));
      p.updateItem(TestItem(1, 'C'), (i) => i.id == 1);
      p.removeItem((i) => i.id == 2);
      expect(fetchCount, 1); // No additional fetches

      p.dispose();
    });
  });

  group('Retry policy', () {
    test('retries with exponential backoff and succeeds', () async {
      int attempts = 0;
      final ds = MockDataSource<TestItem, int>((query) async {
        attempts++;
        if (attempts < 3) throw Exception('fail');
        return PageData(
          items: [TestItem(1, 'OK')],
          isLastPage: true,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy:
            RetryPolicy(maxAttempts: 3, delay: Duration(milliseconds: 50)),
      );

      await p.loadInitial();
      expect(p.state.status, PageStatus.ready);
      expect(p.state.items.length, 1);
      expect(attempts, 3);

      p.dispose();
    });

    test('exhausts retries and returns error', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        throw Exception('permanent failure');
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy:
            RetryPolicy(maxAttempts: 2, delay: Duration(milliseconds: 10)),
      );

      await p.loadInitial();
      expect(p.state.status, PageStatus.error);
      expect(p.state.error.toString(), contains('permanent failure'));

      p.dispose();
    });

    test('respects retryIf condition', () async {
      int attempts = 0;
      final ds = MockDataSource<TestItem, int>((query) async {
        attempts++;
        throw Exception('not retryable');
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(
          maxAttempts: 5,
          delay: Duration(milliseconds: 10),
          retryIf: (e) => false, // Never retry
        ),
      );

      await p.loadInitial();
      expect(p.state.status, PageStatus.error);
      expect(attempts, 1); // Only one attempt since retryIf returns false

      p.dispose();
    });
  });

  group('Cache policies', () {
    test('cacheFirst returns cached data then background updates', () async {
      final cache = MemoryCacheStore<TestItem, int>();
      int fetchCount = 0;
      final ds = MockDataSource<TestItem, int>((query) async {
        fetchCount++;
        return PageData(
          items: [TestItem(fetchCount, 'v$fetchCount')],
          isLastPage: true,
        );
      });

      // First paginator populates cache
      final p1 = Paginator<TestItem, int>(
        source: ds,
        cache: cache,
        pageSize: 1,
        cachePolicy: CachePolicy.cacheFirst,
      );
      await p1.loadInitial();
      expect(fetchCount, 1);

      // Second paginator should get cache hit + background refresh
      final p2 = Paginator<TestItem, int>(
        source: ds,
        cache: cache,
        pageSize: 1,
        cachePolicy: CachePolicy.cacheFirst,
      );
      await p2.loadInitial();
      expect(fetchCount, 2); // Background refresh happened

      p1.dispose();
      p2.dispose();
    });

    test('networkOnly ignores cache', () async {
      final cache = MemoryCacheStore<TestItem, int>();
      final ds = MockDataSource<TestItem, int>((query) async {
        return PageData(
          items: [TestItem(1, 'Fresh')],
          isLastPage: true,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        cache: cache,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );
      await p.loadInitial();
      expect(p.state.items[0].name, 'Fresh');
      expect(p.state.isFromCache, false);

      p.dispose();
    });

    test('cacheOnly errors when no cache configured', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        return PageData(items: [TestItem(1, 'X')], isLastPage: true);
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.cacheOnly,
      );
      await p.loadInitial();
      expect(p.state.status, PageStatus.error);

      p.dispose();
    });
  });

  group('Pagination', () {
    test('loadInitial loads first page', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        return PageData(
          items: [TestItem(1, 'A'), TestItem(2, 'B')],
          nextPageKey: 2,
          isLastPage: false,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );
      await p.loadInitial();

      expect(p.state.items.length, 2);
      expect(p.state.hasMore, true);
      expect(p.state.status, PageStatus.ready);

      p.dispose();
    });

    test('loadNext loads subsequent pages', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        final key = query.pageKey ?? 0;
        return PageData(
          items: [TestItem(key, 'Item $key')],
          nextPageKey: key < 2 ? key + 1 : null,
          isLastPage: key >= 2,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      await p.loadInitial();
      expect(p.state.items.length, 1);

      await p.loadNext();
      expect(p.state.items.length, 2);

      await p.loadNext();
      expect(p.state.items.length, 3);
      expect(p.state.hasMore, false);

      p.dispose();
    });

    test('refresh clears and reloads', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        return PageData(
          items: [TestItem(1, 'A')],
          isLastPage: true,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      await p.loadInitial();
      expect(p.state.items.length, 1);

      await p.refresh();
      expect(p.state.items.length, 1);
      expect(ds.fetchCallCount, 2);

      p.dispose();
    });

    test('prevents concurrent loads', () async {
      final ds = MockDataSource<TestItem, int>((query) async {
        await Future.delayed(Duration(milliseconds: 50));
        return PageData(
          items: [TestItem(1, 'A')],
          nextPageKey: 1,
          isLastPage: false,
        );
      });

      final p = Paginator<TestItem, int>(
        source: ds,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      final f = p.loadInitial();
      await p.loadNext(); // Should be no-op while loadInitial is running
      await f;

      expect(ds.fetchCallCount, 1);
      p.dispose();
    });
  });
}
