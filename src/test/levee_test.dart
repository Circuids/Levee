import 'package:flutter_test/flutter_test.dart';
import 'package:levee/levee.dart';

void main() {
  test('levee exports all public APIs', () {
    // Verify all core types are exported
    expect(PageData, isNotNull);
    expect(PageQuery, isNotNull);
    expect(PageStatus, isNotNull);
    expect(FilterQuery, isNotNull);
    expect(FilterField, isNotNull);
    expect(FilterOperation, isNotNull);
    expect(SortField, isNotNull);
    expect(CacheStore, isNotNull);
    expect(MemoryCacheStore, isNotNull);
    expect(DataSource, isNotNull);
    expect(Paginator, isNotNull);
    expect(PageState, isNotNull);
    expect(RetryPolicy, isNotNull);
    expect(CachePolicy, isNotNull);
    expect(LeveeBuilder, isNotNull);
    expect(LeveeCollectionView, isNotNull);
  });
}
