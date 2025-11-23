import 'package:collection/collection.dart';

/// Filtering and sorting configuration for queries.
///
/// Specify filtering conditions and sort orders for your [DataSource].
/// Backend-specific interpretation gives flexibility with consistent API.
///
/// Example:
/// ```dart
/// final filter = FilterQuery(
///   filters: [
///     FilterField(field: 'status', value: 'active'),
///     FilterField(
///       field: 'price',
///       value: 100,
///       operation: FilterOperation.greaterThan,
///     ),
///   ],
///   sorting: [
///     SortField('createdAt', descending: true),
///   ],
/// );
/// ```
///
/// Your [DataSource] interprets the filters:
///
/// ```dart
/// @override
/// Future<PageData<Product, int>> fetch(PageQuery<int> query) async {
///   var url = Uri.parse('$baseUrl/products');
///
///   // Convert filters to query parameters
///   final params = <String, String>{};
///   if (query.filter != null) {
///     for (final filter in query.filter!.filters) {
///       params[filter.field] = filter.value.toString();
///       params['${filter.field}_op'] = filter.operation.value;
///     }
///   }
///
///   url = url.replace(queryParameters: params);
///   // ... fetch and return PageData
/// }
/// ```
///
/// ## Cache Key Impact
///
/// Filters are part of the cache key calculation. Different filters
/// create separate cache entries:
///
/// ```dart
/// // These queries have different cache keys:
/// PageQuery(
///   pageSize: 20,
///   filter: FilterQuery(filters: [FilterField(field: 'status', value: 'active')]),
/// );
///
/// PageQuery(
///   pageSize: 20,
///   filter: FilterQuery(filters: [FilterField(field: 'status', value: 'inactive')]),
/// );
/// ```
///
/// See also:
/// - [FilterField] for individual filter conditions
/// - [FilterOperation] for available filter operations
/// - [SortField] for sorting configuration
class FilterQuery {
  /// Creates a [FilterQuery] with optional filters and sorting.
  const FilterQuery({
    this.filters = const [],
    this.sorting = const [],
  });

  /// List of filter conditions to apply.
  final List<FilterField> filters;

  /// List of sort fields to apply.
  final List<SortField> sorting;

  /// Converts this filter query to a Map for serialization.
  Map<String, dynamic> toMap() => {
        'filters': filters.map((f) => f.toMap()).toList(),
        'sorting': sorting.map((s) => s.toMap()).toList(),
      };

  @override
  String toString() => toMap().toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterQuery &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(filters, other.filters) &&
          const ListEquality().equals(sorting, other.sorting);

  @override
  int get hashCode => Object.hash(
        const ListEquality().hash(filters),
        const ListEquality().hash(sorting),
      );
}

/// Represents a single filter condition to apply to a query.
///
/// [FilterField] defines what field to filter on, what value to compare
/// against, and what operation to use for comparison.
///
/// ## Basic Examples
///
/// ```dart
/// // Equality filter (default operation)
/// FilterField(field: 'status', value: 'active')
///
/// // Comparison filter
/// FilterField(
///   field: 'price',
///   value: 100,
///   operation: FilterOperation.greaterThan,
/// )
///
/// // Text search
/// FilterField(
///   field: 'description',
///   value: 'flutter',
///   operation: FilterOperation.contains,
/// )
/// ```
///
/// ## Custom Backend Operations
///
/// Use [FilterOperation.custom] for backend-specific operations:
///
/// ```dart
/// // Firestore array-contains
/// FilterField(
///   field: 'tags',
///   value: 'flutter',
///   operation: FilterOperation.custom('array-contains'),
/// )
///
/// // SQL LIKE with wildcards
/// FilterField(
///   field: 'name',
///   value: '%john%',
///   operation: FilterOperation.custom('LIKE'),
/// )
///
/// // PostgreSQL full-text search
/// FilterField(
///   field: 'content',
///   value: 'searchTerm',
///   operation: FilterOperation.custom('@@'),
/// )
/// ```
///
/// ## Complex Values
///
/// The [value] field can be any type:
///
/// ```dart
/// // List for 'in' operations
/// FilterField(
///   field: 'category',
///   value: ['electronics', 'computers'],
///   operation: FilterOperation.inList,
/// )
///
/// // DateTime for date comparisons
/// FilterField(
///   field: 'publishedAt',
///   value: DateTime(2024, 1, 1),
///   operation: FilterOperation.greaterThanOrEquals,
/// )
///
/// // Boolean flags
/// FilterField(
///   field: 'isPublished',
///   value: true,
/// )
/// ```
///
/// See also:
/// - [FilterOperation] for available operations
/// - [FilterQuery] for combining multiple filters
class FilterField {
  /// Creates a [FilterField] with the given field, value, and operation.
  const FilterField({
    required this.field,
    required this.value,
    this.operation = FilterOperation.equals,
  });

  /// The field name to filter on.
  final String field;

  /// The value to filter by.
  final dynamic value;

  /// The filter operation to apply (defaults to equals).
  final FilterOperation operation;

  /// Converts this filter field to a Map for serialization.
  Map<String, dynamic> toMap() => {
        'field': field,
        'value': value,
        'operation': operation.value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterField &&
          field == other.field &&
          value == other.value &&
          operation == other.operation;

  @override
  int get hashCode => Object.hash(field, value, operation);
}

/// Defines the comparison operation for a filter condition.
///
/// [FilterOperation] provides 13 common operations that cover most
/// filtering needs, plus the ability to define custom backend-specific
/// operations.
///
/// ## Standard Operations
///
/// ### Equality and Inequality
/// - [equals]: Field value equals the filter value (default)
/// - [notEquals]: Field value does not equal the filter value
///
/// ### Numeric Comparisons
/// - [greaterThan]: Field value > filter value
/// - [greaterThanOrEquals]: Field value >= filter value
/// - [lessThan]: Field value < filter value
/// - [lessThanOrEquals]: Field value <= filter value
///
/// ### Text Operations
/// - [contains]: Field contains the filter value (substring match)
/// - [startsWith]: Field starts with the filter value
/// - [endsWith]: Field ends with the filter value
///
/// ### List Operations
/// - [inList]: Field value is in the provided list
/// - [notInList]: Field value is not in the provided list
///
/// ### Null Checks
/// - [isNull]: Field value is null
/// - [isNotNull]: Field value is not null
///
/// ## Usage Examples
///
/// ```dart
/// // Comparison operations
/// FilterField(
///   field: 'age',
///   value: 18,
///   operation: FilterOperation.greaterThanOrEquals,
/// )
///
/// // Text search
/// FilterField(
///   field: 'description',
///   value: 'flutter',
///   operation: FilterOperation.contains,
/// )
///
/// // List membership
/// FilterField(
///   field: 'status',
///   value: ['active', 'pending'],
///   operation: FilterOperation.inList,
/// )
///
/// // Null checks
/// FilterField(
///   field: 'deletedAt',
///   value: null,
///   operation: FilterOperation.isNull,
/// )
/// ```
///
/// ## Custom Operations
///
/// Use [FilterOperation.custom] for backend-specific operations:
///
/// ```dart
/// // Firestore array operations
/// FilterOperation.custom('array-contains')
/// FilterOperation.custom('array-contains-any')
///
/// // SQL operations
/// FilterOperation.custom('LIKE')
/// FilterOperation.custom('ILIKE')  // Case-insensitive
/// FilterOperation.custom('REGEXP')
///
/// // MongoDB operations
/// FilterOperation.custom('\$regex')
/// FilterOperation.custom('\$elemMatch')
///
/// // GraphQL-specific
/// FilterOperation.custom('eq')
/// FilterOperation.custom('ne')
/// FilterOperation.custom('in')
/// ```
///
/// ## Backend Interpretation
///
/// Your [DataSource] implementation interprets operations:
///
/// ```dart
/// @override
/// Future<PageData<Product, int>> fetch(PageQuery<int> query) async {
///   final filters = query.filter?.filters ?? [];
///
///   for (final filter in filters) {
///     switch (filter.operation) {
///       case FilterOperation.equals:
///         // Apply equality filter
///         break;
///       case FilterOperation.greaterThan:
///         // Apply > comparison
///         break;
///       // Handle other operations...
///       default:
///         // Handle custom operations
///         if (filter.operation.value == 'array-contains') {
///           // Firestore-specific logic
///         }
///     }
///   }
/// }
/// ```
///
/// See also:
/// - [FilterField] for creating filter conditions
/// - [FilterQuery] for combining multiple filters
class FilterOperation {
  /// Creates a filter operation with the given value.
  const FilterOperation._(this.value);

  /// The string value representing this operation.
  final String value;

  // Common operations (covers 95% of cases)

  /// Equality comparison (==).
  static const equals = FilterOperation._('equals');

  /// Inequality comparison (!=).
  static const notEquals = FilterOperation._('notEquals');

  /// Greater than comparison (>).
  static const greaterThan = FilterOperation._('greaterThan');

  /// Greater than or equal comparison (>=).
  static const greaterThanOrEquals = FilterOperation._('greaterThanOrEquals');

  /// Less than comparison (<).
  static const lessThan = FilterOperation._('lessThan');

  /// Less than or equal comparison (<=).
  static const lessThanOrEquals = FilterOperation._('lessThanOrEquals');

  /// String contains check.
  static const contains = FilterOperation._('contains');

  /// String starts with check.
  static const startsWith = FilterOperation._('startsWith');

  /// String ends with check.
  static const endsWith = FilterOperation._('endsWith');

  /// Value is in list check.
  static const inList = FilterOperation._('inList');

  /// Value is not in list check.
  static const notInList = FilterOperation._('notInList');

  /// Null check.
  static const isNull = FilterOperation._('isNull');

  /// Not null check.
  static const isNotNull = FilterOperation._('isNotNull');

  /// Creates a custom filter operation for backend-specific needs.
  ///
  /// Example:
  /// ```dart
  /// // Firestore array-contains
  /// FilterOperation.custom('array-contains')
  ///
  /// // SQL LIKE operator
  /// FilterOperation.custom('LIKE')
  /// ```
  const FilterOperation.custom(this.value);

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FilterOperation && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Defines how to sort results by a specific field.
///
/// [SortField] specifies a field name and sort direction (ascending or
/// descending). Multiple sort fields create a sort hierarchy for tie-breaking.
///
/// ## Basic Usage
///
/// ```dart
/// // Ascending sort (default)
/// SortField('name')
///
/// // Descending sort
/// SortField('createdAt', descending: true)
/// ```
///
/// ## Multiple Sort Fields
///
/// When multiple [SortField]s are provided, they create a sort priority:
///
/// ```dart
/// FilterQuery(
///   sorting: [
///     SortField('priority', descending: true),  // Primary sort
///     SortField('createdAt', descending: true), // Secondary sort
///     SortField('title'),                       // Tertiary sort
///   ],
/// )
/// ```
///
/// This sorts by priority first, then by creation date for items with
/// the same priority, and finally by title for items with the same
/// priority and date.
///
/// ## Real-World Examples
///
/// ### E-commerce: Sort by relevance, then price
/// ```dart
/// FilterQuery(
///   sorting: [
///     SortField('relevanceScore', descending: true),
///     SortField('price'),  // Ascending for cheapest first
///   ],
/// )
/// ```
///
/// ### Social feed: Latest first
/// ```dart
/// FilterQuery(
///   sorting: [
///     SortField('publishedAt', descending: true),
///   ],
/// )
/// ```
///
/// ### Leaderboard: High score with tie-breaker
/// ```dart
/// FilterQuery(
///   sorting: [
///     SortField('score', descending: true),
///     SortField('completedAt'),  // Earlier completion wins ties
///   ],
/// )
/// ```
///
/// ### Alphabetical with case handling
/// ```dart
/// FilterQuery(
///   sorting: [
///     SortField('lastName'),
///     SortField('firstName'),
///   ],
/// )
/// ```
///
/// ## Backend Interpretation
///
/// Your [DataSource] implementation applies the sorting:
///
/// ```dart
/// @override
/// Future<PageData<Product, int>> fetch(PageQuery<int> query) async {
///   var queryBuilder = database.collection('products');
///
///   // Apply sorts in order
///   final sorts = query.filter?.sorting ?? [];
///   for (final sort in sorts) {
///     queryBuilder = queryBuilder.orderBy(
///       sort.field,
///       descending: sort.descending,
///     );
///   }
///
///   // ... execute query
/// }
/// ```
///
/// See also:
/// - [FilterQuery] for combining sorts with filters
class SortField {
  /// Creates a [SortField] with the given field name and optional descending flag.
  const SortField(this.field, {this.descending = false});

  /// The field name to sort by.
  final String field;

  /// Whether to sort in descending order (true) or ascending (false).
  final bool descending;

  /// Converts this sort field to a Map for serialization.
  Map<String, dynamic> toMap() => {
        'field': field,
        'order': descending ? 'desc' : 'asc',
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SortField &&
          field == other.field &&
          descending == other.descending;

  @override
  int get hashCode => Object.hash(field, descending);
}
