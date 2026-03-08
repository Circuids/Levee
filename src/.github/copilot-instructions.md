# Levee — Copilot Instructions

## Project Overview

Levee is a **lean, backend-agnostic pagination engine** for Flutter (v1.0.0).
It manages pagination state, page loading, optional caching, retry policies, filtering, and local list mutations.
It does **NOT** manage backend synchronization, distributed data consistency, mutation queues, CRDT merging, or offline conflict resolution.

## Tech Stack

- **Language:** Dart (SDK >=3.0.0 <4.0.0)
- **Framework:** Flutter (>=3.0.0)
- **Dependencies:** `collection: ^1.18.0` (only external dep)
- **Testing:** `flutter_test`
- **Linting:** `flutter_lints: ^5.0.0`

## Project Structure

The Flutter package source lives in `src/`. All paths below are relative to `src/`.
For a detailed architecture diagram and data flow, see `docs/architecture.md`.

```
lib/
  levee.dart                          # Barrel file — all public exports
  src/
    core/                             # Pagination engine
      paginator.dart                  #   Paginator<T, K> (ChangeNotifier)
      page_state.dart                 #   PageState<T>, PageStatus enum
      merge_mode.dart                 #   MergeMode enum (append, replaceByKey)
      retry_policy.dart               #   RetryPolicy class
    query/                            # Query types
      page_query.dart                 #   PageQuery<K>
      filter_query.dart               #   FilterQuery, FilterField, FilterOperation, SortField
    data/                             # Data contracts
      data_source.dart                #   DataSource<T, K> (abstract)
      page_data.dart                  #   PageData<T, K>
    cache/                            # Caching
      cache_store.dart                #   CacheStore<T, K> (abstract)
      memory_cache_store.dart         #   MemoryCacheStore<T, K> (default impl)
      cache_policy.dart               #   CachePolicy enum
    ui/                               # Flutter widgets
      levee_builder.dart              #   LeveeBuilder<T, K> (headless)
      levee_collection_view.dart      #   LeveeCollectionView<T, K> (full-featured)
    utils/                            # Internal utilities
      equals.dart                     #   Equals class with listEquals and listHash

test/
  levee_test.dart                     # Export verification
  paginator_test.dart                 # Paginator unit tests
  cache_store_test.dart               # MemoryCacheStore tests
  contracts_test.dart                 # Type contract tests
  merge_mode_test.dart                # MergeMode tests
  collection_view_test.dart           # Widget tests (LeveeBuilder + LeveeCollectionView)
```

## Architecture

```
LeveeCollectionView / LeveeBuilder  ← UI (listens via ChangeNotifier)
        │
        ▼
   Paginator<T, K>                  ← Core engine (state machine)
        ├── DataSource<T, K>        ← User implements (REST, GraphQL, Firestore, etc.)
        ├── CacheStore<T, K>?       ← Optional (MemoryCacheStore is default)
        ├── CachePolicy             ← cacheFirst | networkFirst | cacheOnly | networkOnly
        ├── RetryPolicy?            ← Optional exponential backoff
        └── MergeMode               ← append | replaceByKey
```

## Key Design Principles

1. **Backend-agnostic:** `DataSource<T, K>` is the only integration point. Paginator never knows about HTTP, Firestore, etc.
2. **Generic page keys:** `K` can be `int` (offset), `String` (cursor), `DocumentSnapshot`, or any type.
3. **Immutable state:** `PageState<T>` is immutable with `copyWith`. State transitions go through `notifyListeners()`.
4. **One file = one concept:** Each file contains a single primary type. No `models.dart` or `types.dart` dump files.
5. **Domain-grouped folders:** Files are grouped by domain (`core/`, `cache/`, `query/`, `data/`, `ui/`), NOT by type kind.
6. **Optional complexity:** Cache, retry, merge mode, and filters are all opt-in. Simple by default.
7. **No over-abstraction:** No service locators, DI frameworks, event buses, or generic repositories.

## Coding Conventions

### Dart Style
- Follow `flutter_lints` rules (analysis_options.yaml)
- Use `const` constructors wherever possible
- Prefer `final` fields on immutable types
- Use named parameters for constructors with more than 2 params
- All public APIs must have `///` doc comments

### Naming
- Method on DataSource: `fetch()` (NOT `load()`)
- Page data class: `PageData<T, K>` (NOT `Page<T, K>`)
- Page key field: `nextPageKey` (NOT `nextKey`)
- Last page flag: `isLastPage` (NOT `hasMore` — but `PageState` uses `hasMore` for the accumulated state)
- Insert position param: `index` (NOT `position`)

### File Organization
- One primary type per file
- Barrel file (`levee.dart`) exports everything with explicit `show` clauses
- Internal types (like `_CacheEntry`) stay private in their file
- Imports use relative paths within `lib/src/`

### Testing
- Tests import via `package:levee/levee.dart` (barrel), never internal paths
- Use `MockDataSource` pattern with a function callback for flexible test scenarios
- Widget tests use `pumpAndSettle()` for async state transitions
- Always call `paginator.dispose()` at end of test

## Things to AVOID

- Adding dependencies
- Creating mutation queues, CRDT merging, or backend sync logic
- Deep merging fields in `MergeMode.replaceByKey` — it's full item replacement only
- Reordering items during merge — order is always preserved
- Making `DataSource.fetch()` aware of cache — caching is Paginator's responsibility
- Putting multiple unrelated types in one file
- Using `dynamic` except in `FilterField.value` (which must accept any filter value)

## Common Tasks

### Adding a new feature to Paginator
1. Add parameter to `Paginator` constructor
2. Wire into the appropriate `_load*` method or `_updateStateFromPage`
3. Export from `levee.dart` if introducing a new type
4. Add tests in `paginator_test.dart`

### Running tests
```bash
cd src
flutter test
```

### Formatting
```bash
cd src
dart format .
```
