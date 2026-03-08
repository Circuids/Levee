/// Defines how incoming page items are merged with existing items.
enum MergeMode {
  /// Simply append new items to the end of the list.
  append,

  /// Replace existing items that share the same key (via [keySelector]).
  ///
  /// Items not found in the existing list are appended at the end.
  /// Item order is preserved — no reordering occurs.
  ///
  /// Requires a `keySelector` to be provided to the [Paginator].
  replaceByKey,
}
