import 'package:flutter_test/flutter_test.dart';
import 'package:levee/levee.dart';

void main() {
  group('Page', () {
    test('creates page with items and metadata', () {
      final page = PageData<String, int>(
        items: ['item1', 'item2'],
        nextPageKey: 20,
        isLastPage: false,
        totalCount: 100,
      );

      expect(page.items, ['item1', 'item2']);
      expect(page.nextPageKey, 20);
      expect(page.isLastPage, false);
      expect(page.totalCount, 100);
    });

    test('creates last page with null nextPageKey', () {
      final page = PageData<String, int>(
        items: ['item1'],
        nextPageKey: null,
        isLastPage: true,
      );

      expect(page.items, ['item1']);
      expect(page.nextPageKey, null);
      expect(page.isLastPage, true);
      expect(page.totalCount, null);
    });
  });

  group('PageQuery', () {
    test('creates query with required fields', () {
      final query = PageQuery<int>(pageSize: 20);

      expect(query.pageSize, 20);
      expect(query.pageKey, null);
      expect(query.filter, null);
    });

    test('creates query with all fields', () {
      final filter = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
      );
      final query = PageQuery<int>(
        pageSize: 20,
        pageKey: 40,
        filter: filter,
      );

      expect(query.pageSize, 20);
      expect(query.pageKey, 40);
      expect(query.filter, filter);
    });

    test('copyWith creates new instance with updated fields', () {
      final original = PageQuery<int>(pageSize: 20, pageKey: 0);
      final copied = original.copyWith(pageKey: 20);

      expect(copied.pageSize, 20);
      expect(copied.pageKey, 20);
      expect(original.pageKey, 0); // Original unchanged
    });

    test('copyWith without arguments returns identical values', () {
      final filter = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
      );
      final original = PageQuery<int>(
        pageSize: 20,
        pageKey: 40,
        filter: filter,
      );
      final copied = original.copyWith();

      expect(copied.pageSize, original.pageSize);
      expect(copied.pageKey, original.pageKey);
      expect(copied.filter, original.filter);
    });

    test('supports generic page key types', () {
      final intQuery = PageQuery<int>(pageSize: 20, pageKey: 100);
      final stringQuery = PageQuery<String>(pageSize: 20, pageKey: 'cursor123');

      expect(intQuery.pageKey, isA<int>());
      expect(stringQuery.pageKey, isA<String>());
    });
  });

  group('PageStatus', () {
    test('has all expected states', () {
      expect(PageStatus.idle, isNotNull);
      expect(PageStatus.loading, isNotNull);
      expect(PageStatus.ready, isNotNull);
      expect(PageStatus.error, isNotNull);
    });
  });

  group('FilterQuery', () {
    test('creates empty filter query', () {
      const filter = FilterQuery();

      expect(filter.filters, isEmpty);
      expect(filter.sorting, isEmpty);
    });

    test('creates filter with multiple filters', () {
      final filter = FilterQuery(
        filters: [
          FilterField(field: 'status', value: 'active'),
          FilterField(
            field: 'price',
            value: 100,
            operation: FilterOperation.greaterThan,
          ),
        ],
      );

      expect(filter.filters.length, 2);
      expect(filter.filters[0].field, 'status');
      expect(filter.filters[1].field, 'price');
    });

    test('creates filter with sorting', () {
      final filter = FilterQuery(
        sorting: [
          SortField('date', descending: true),
          SortField('name'),
        ],
      );

      expect(filter.sorting.length, 2);
      expect(filter.sorting[0].field, 'date');
      expect(filter.sorting[0].descending, true);
      expect(filter.sorting[1].descending, false);
    });

    test('toMap serializes correctly', () {
      final filter = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
        sorting: [SortField('date', descending: true)],
      );

      final map = filter.toMap();

      expect(map['filters'], isA<List>());
      expect(map['sorting'], isA<List>());
      expect(map['filters'][0]['field'], 'status');
      expect(map['sorting'][0]['field'], 'date');
    });

    test('equality works correctly', () {
      final filter1 = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
        sorting: [SortField('date', descending: true)],
      );
      final filter2 = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
        sorting: [SortField('date', descending: true)],
      );
      final filter3 = FilterQuery(
        filters: [FilterField(field: 'status', value: 'inactive')],
        sorting: [SortField('date', descending: true)],
      );

      expect(filter1, equals(filter2));
      expect(filter1, isNot(equals(filter3)));
    });

    test('hashCode is consistent', () {
      final filter1 = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
      );
      final filter2 = FilterQuery(
        filters: [FilterField(field: 'status', value: 'active')],
      );

      expect(filter1.hashCode, equals(filter2.hashCode));
    });
  });

  group('FilterField', () {
    test('creates field with default equals operation', () {
      const field = FilterField(field: 'status', value: 'active');

      expect(field.field, 'status');
      expect(field.value, 'active');
      expect(field.operation, FilterOperation.equals);
    });

    test('creates field with custom operation', () {
      final field = FilterField(
        field: 'price',
        value: 100,
        operation: FilterOperation.greaterThan,
      );

      expect(field.field, 'price');
      expect(field.value, 100);
      expect(field.operation, FilterOperation.greaterThan);
    });

    test('toMap serializes correctly', () {
      final field = FilterField(
        field: 'price',
        value: 100,
        operation: FilterOperation.greaterThan,
      );

      final map = field.toMap();

      expect(map['field'], 'price');
      expect(map['value'], 100);
      expect(map['operation'], 'greaterThan');
    });

    test('equality works correctly', () {
      const field1 = FilterField(field: 'status', value: 'active');
      const field2 = FilterField(field: 'status', value: 'active');
      const field3 = FilterField(field: 'status', value: 'inactive');

      expect(field1, equals(field2));
      expect(field1, isNot(equals(field3)));
    });
  });

  group('FilterOperation', () {
    test('has all predefined operations', () {
      expect(FilterOperation.equals.value, 'equals');
      expect(FilterOperation.notEquals.value, 'notEquals');
      expect(FilterOperation.greaterThan.value, 'greaterThan');
      expect(FilterOperation.greaterThanOrEquals.value, 'greaterThanOrEquals');
      expect(FilterOperation.lessThan.value, 'lessThan');
      expect(FilterOperation.lessThanOrEquals.value, 'lessThanOrEquals');
      expect(FilterOperation.contains.value, 'contains');
      expect(FilterOperation.startsWith.value, 'startsWith');
      expect(FilterOperation.endsWith.value, 'endsWith');
      expect(FilterOperation.inList.value, 'inList');
      expect(FilterOperation.notInList.value, 'notInList');
      expect(FilterOperation.isNull.value, 'isNull');
      expect(FilterOperation.isNotNull.value, 'isNotNull');
    });

    test('supports custom operations', () {
      const customOp = FilterOperation.custom('array-contains');

      expect(customOp.value, 'array-contains');
    });

    test('equality works correctly', () {
      const op1 = FilterOperation.equals;
      const op2 = FilterOperation.equals;
      const op3 = FilterOperation.notEquals;
      const custom1 = FilterOperation.custom('LIKE');
      const custom2 = FilterOperation.custom('LIKE');

      expect(op1, equals(op2));
      expect(op1, isNot(equals(op3)));
      expect(custom1, equals(custom2));
    });

    test('toString returns value', () {
      expect(FilterOperation.equals.toString(), 'equals');
      expect(FilterOperation.custom('LIKE').toString(), 'LIKE');
    });
  });

  group('SortField', () {
    test('creates ascending sort by default', () {
      const sort = SortField('name');

      expect(sort.field, 'name');
      expect(sort.descending, false);
    });

    test('creates descending sort', () {
      const sort = SortField('date', descending: true);

      expect(sort.field, 'date');
      expect(sort.descending, true);
    });

    test('toMap serializes correctly', () {
      const asc = SortField('name');
      const desc = SortField('date', descending: true);

      expect(asc.toMap()['field'], 'name');
      expect(asc.toMap()['order'], 'asc');
      expect(desc.toMap()['field'], 'date');
      expect(desc.toMap()['order'], 'desc');
    });

    test('equality works correctly', () {
      const sort1 = SortField('name');
      const sort2 = SortField('name');
      const sort3 = SortField('name', descending: true);

      expect(sort1, equals(sort2));
      expect(sort1, isNot(equals(sort3)));
    });
  });
}
