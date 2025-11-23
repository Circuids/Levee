import 'package:collection/collection.dart';

/// Holds filtering and sorting configuration.
///
/// Example:
/// ```dart
/// final filter = FilterQuery(
///   filters: [
///     FilterField(field: 'status', value: 'active'),
///     FilterField(field: 'price', value: 100, operation: FilterOperation.greaterThan),
///   ],
///   sorting: [
///     SortField('date', descending: true),
///   ],
/// );
/// ```
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

/// Represents a single filter condition.
///
/// Example:
/// ```dart
/// // Equality filter (default)
/// FilterField(field: 'status', value: 'active')
///
/// // Greater than filter
/// FilterField(field: 'price', value: 100, operation: FilterOperation.greaterThan)
///
/// // Custom backend-specific filter
/// FilterField(field: 'tags', value: 'flutter', operation: FilterOperation.custom('array-contains'))
/// ```
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

/// Extensible filter operations with common defaults.
///
/// Provides 13 common filter operations covering 95% of use cases,
/// with support for custom backend-specific operations via [FilterOperation.custom].
///
/// Example:
/// ```dart
/// // Using predefined operations
/// FilterOperation.equals
/// FilterOperation.greaterThan
/// FilterOperation.contains
///
/// // Custom backend-specific operation
/// FilterOperation.custom('array-contains')  // Firestore
/// FilterOperation.custom('LIKE')            // SQL
/// ```
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

/// Defines sorting by field name and direction.
///
/// Example:
/// ```dart
/// // Ascending sort (default)
/// SortField('name')
///
/// // Descending sort
/// SortField('date', descending: true)
/// ```
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
