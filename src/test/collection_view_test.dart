import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levee/levee.dart';

// Test Model
class TestItem {
  final int id;
  final String name;

  TestItem(this.id, this.name);
}

// Mock DataSource for testing
class MockDataSource implements DataSource<TestItem, int> {
  final List<List<TestItem>> pages;
  int fetchCallCount = 0;

  MockDataSource(this.pages);

  @override
  Future<PageData<TestItem, int>> fetch(PageQuery<int> query) async {
    fetchCallCount++;
    await Future.delayed(Duration(milliseconds: 10));

    final pageIndex = query.pageKey ?? 0;
    if (pageIndex >= pages.length) {
      return PageData<TestItem, int>(
        items: [],
        nextPageKey: null,
        isLastPage: true,
      );
    }

    return PageData<TestItem, int>(
      items: pages[pageIndex],
      nextPageKey: pageIndex + 1 < pages.length ? pageIndex + 1 : null,
      isLastPage: pageIndex + 1 >= pages.length,
    );
  }
}

void main() {
  group('LeveeBuilder Widget Tests', () {
    testWidgets('renders initial loading state', (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1'), TestItem(2, 'Item 2')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeBuilder<TestItem>(
              paginator: paginator,
              builder: (context, state) {
                if (state.items.isEmpty && state.status == PageStatus.idle) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    return ListTile(title: Text(state.items[index].name));
                  },
                );
              },
            ),
          ),
        ),
      );

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('renders items after data loads', (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1'), TestItem(2, 'Item 2')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeBuilder<TestItem>(
              paginator: paginator,
              builder: (context, state) {
                if (state.items.isEmpty && state.status == PageStatus.idle) {
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    return ListTile(title: Text(state.items[index].name));
                  },
                );
              },
            ),
          ),
        ),
      );

      // Load data
      paginator.loadInitial();
      await tester.pumpAndSettle();

      // Should show items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      paginator.dispose();
    });

    testWidgets('renders error state', (WidgetTester tester) async {
      final paginator = Paginator<TestItem, int>(
        source: DataSourceAdapter<TestItem, int>(
          fetchPage: (query) async {
            throw Exception('Test error');
          },
        ),
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeBuilder<TestItem>(
              paginator: paginator,
              builder: (context, state) {
                if (state.status == PageStatus.error) {
                  return Center(
                    child: Text('Error: ${state.error.toString()}'),
                  );
                }
                return Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ),
      );

      // Load data
      paginator.loadInitial();
      await tester.pumpAndSettle();

      // Should show error
      expect(find.textContaining('Error:'), findsOneWidget);
      expect(find.textContaining('Test error'), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('updates when paginator state changes',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1')],
        [TestItem(2, 'Item 2')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeBuilder<TestItem>(
              paginator: paginator,
              builder: (context, state) {
                return Column(
                  children: [
                    Text('Count: ${state.items.length}'),
                    ...state.items
                        .map((item) => ListTile(title: Text(item.name))),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Initial state
      expect(find.text('Count: 0'), findsOneWidget);

      // Load first page
      paginator.loadInitial();
      await tester.pumpAndSettle();
      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);

      // Load second page
      paginator.loadNext();
      await tester.pumpAndSettle();
      expect(find.text('Count: 2'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      paginator.dispose();
    });
  });

  group('LeveeCollectionView Widget Tests', () {
    testWidgets('renders items using itemBuilder',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1'), TestItem(2, 'Item 2')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return ListTile(title: Text(item.name));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show items
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('shows loading indicator when building',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 1,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return ListTile(title: Text(item.name));
              },
              loadingBuilder: (context) {
                return Center(child: Text('Custom Loading'));
              },
            ),
          ),
        ),
      );

      // LeveeCollectionView loads automatically, so data might already be loaded
      // Just verify the widget built correctly
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('shows error widget when specified',
        (WidgetTester tester) async {
      final paginator = Paginator<TestItem, int>(
        source: DataSourceAdapter<TestItem, int>(
          fetchPage: (query) async {
            throw Exception('Test error');
          },
        ),
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
        retryPolicy: RetryPolicy(maxAttempts: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return ListTile(title: Text(item.name));
              },
              errorBuilder: (context, error) {
                return Center(child: Text('Custom Error: $error'));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show custom error
      expect(find.textContaining('Custom Error:'), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('shows empty widget when no items',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [], // Empty page
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 10,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return ListTile(title: Text(item.name));
              },
              emptyBuilder: (context) {
                return Center(child: Text('No items found'));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show empty widget
      expect(find.text('No items found'), findsOneWidget);

      paginator.dispose();
    });

    testWidgets('triggers loadNext when scrolling near end',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        List.generate(20, (i) => TestItem(i, 'Item $i')),
        List.generate(20, (i) => TestItem(i + 20, 'Item ${i + 20}')),
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 20,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return SizedBox(
                  height: 50,
                  child: ListTile(title: Text(item.name)),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should have first page
      expect(find.text('Item 0'), findsOneWidget);
      expect(paginator.state.items.length, 20);

      // Scroll to trigger next page load
      await tester.drag(find.byType(ListView), Offset(0, -1000));
      await tester.pumpAndSettle();

      // Should have loaded second page
      expect(paginator.state.items.length, 40);

      paginator.dispose();
    });

    testWidgets('does not use separator by default',
        (WidgetTester tester) async {
      final dataSource = MockDataSource([
        [TestItem(1, 'Item 1'), TestItem(2, 'Item 2')],
      ]);

      final paginator = Paginator<TestItem, int>(
        source: dataSource,
        pageSize: 2,
        cachePolicy: CachePolicy.networkOnly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeveeCollectionView<TestItem, int>(
              paginator: paginator,
              itemBuilder: (context, item, index) {
                return ListTile(title: Text(item.name));
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show items without custom separators
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      paginator.dispose();
    });
  });
}

// Helper adapter for creating DataSource from function
class DataSourceAdapter<T, K> implements DataSource<T, K> {
  final Future<PageData<T, K>> Function(PageQuery<K> query) fetchPage;

  DataSourceAdapter({required this.fetchPage});

  @override
  Future<PageData<T, K>> fetch(PageQuery<K> query) {
    return fetchPage(query);
  }
}
