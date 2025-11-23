import 'package:flutter_test/flutter_test.dart';
import 'package:levee/levee.dart';

void main() {
  group('MemoryCacheStore', () {
    late MemoryCacheStore<String, int> cache;

    setUp(() {
      cache = MemoryCacheStore<String, int>();
    });

    test('get returns null for non-existent key', () async {
      final query = PageQuery<int>(pageSize: 20);
      final result = await cache.get('nonexistent', query);

      expect(result, isNull);
    });

    test('put and get stores and retrieves page', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1', 'item2'],
        nextPageKey: 20,
        isLastPage: false,
      );

      await cache.put('key1', query, page);
      final result = await cache.get('key1', query);

      expect(result, isNotNull);
      expect(result!.items, ['item1', 'item2']);
      expect(result.nextPageKey, 20);
    });

    test('put with TTL expires after duration', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      // Store with 50ms TTL
      await cache.put('key1', query, page, ttl: Duration(milliseconds: 50));

      // Should be available immediately
      final result1 = await cache.get('key1', query);
      expect(result1, isNotNull);

      // Wait for expiry
      await Future.delayed(Duration(milliseconds: 100));

      // Should be expired now
      final result2 = await cache.get('key1', query);
      expect(result2, isNull);
    });

    test('put without TTL never expires', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      await cache.put('key1', query, page);
      await Future.delayed(Duration(milliseconds: 100));

      final result = await cache.get('key1', query);
      expect(result, isNotNull);
    });

    test('remove deletes cached entry', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      await cache.put('key1', query, page);
      expect(await cache.get('key1', query), isNotNull);

      await cache.remove('key1');
      expect(await cache.get('key1', query), isNull);
    });

    test('clear removes all entries', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      await cache.put('key1', query, page);
      await cache.put('key2', query, page);
      await cache.put('key3', query, page);

      expect(await cache.get('key1', query), isNotNull);
      expect(await cache.get('key2', query), isNotNull);
      expect(await cache.get('key3', query), isNotNull);

      await cache.clear();

      expect(await cache.get('key1', query), isNull);
      expect(await cache.get('key2', query), isNull);
      expect(await cache.get('key3', query), isNull);
    });

    test('has returns true for existing key', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      expect(await cache.has('key1'), false);

      await cache.put('key1', query, page);
      expect(await cache.has('key1'), true);
    });

    test('has returns false for expired key', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      await cache.put('key1', query, page, ttl: Duration(milliseconds: 50));
      expect(await cache.has('key1'), true);

      await Future.delayed(Duration(milliseconds: 100));
      expect(await cache.has('key1'), false);
    });

    test('handles multiple cache entries independently', () async {
      final query = PageQuery<int>(pageSize: 20);
      final page1 = PageData<String, int>(
        items: ['item1'],
        nextPageKey: 20,
        isLastPage: false,
      );
      final page2 = PageData<String, int>(
        items: ['item2'],
        nextPageKey: 40,
        isLastPage: false,
      );

      await cache.put('key1', query, page1);
      await cache.put('key2', query, page2);

      final result1 = await cache.get('key1', query);
      final result2 = await cache.get('key2', query);

      expect(result1!.items, ['item1']);
      expect(result1.nextPageKey, 20);
      expect(result2!.items, ['item2']);
      expect(result2.nextPageKey, 40);
    });

    test('query parameter is ignored (simple key-value store)', () async {
      final query1 = PageQuery<int>(
        pageSize: 20,
        filter: FilterQuery(
          filters: [FilterField(field: 'status', value: 'active')],
        ),
      );
      final query2 = PageQuery<int>(
        pageSize: 20,
        filter: FilterQuery(
          filters: [FilterField(field: 'status', value: 'inactive')],
        ),
      );

      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      // Store with query1
      await cache.put('key1', query1, page);

      // Retrieve with query2 - should still work (query ignored)
      final result = await cache.get('key1', query2);
      expect(result, isNotNull);
      expect(result!.items, ['item1']);
    });

    test('supports generic types correctly', () async {
      final intCache = MemoryCacheStore<int, String>();
      final query = PageQuery<String>(pageSize: 20, pageKey: 'cursor123');
      final page = PageData<int, String>(
        items: [1, 2, 3],
        nextPageKey: 'cursor456',
        isLastPage: false,
      );

      await intCache.put('key1', query, page);
      final result = await intCache.get('key1', query);

      expect(result, isNotNull);
      expect(result!.items, [1, 2, 3]);
      expect(result.nextPageKey, 'cursor456');
    });
  });
}
