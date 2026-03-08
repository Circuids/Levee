## 1.0.0+1

- **New**: Documentation updates for 1.0.0 release, including README and API docs

## 1.0.0

**Stable Release**

- **New**: `MergeMode` enum with `append` (default) and `replaceByKey` strategies
  - `replaceByKey` uses a `keySelector` to replace existing items by key instead of duplicating
  - O(n) merge performance using Map lookups
- **New**: `mergeMode` and `keySelector` parameters on `Paginator`
- **Changed**: `insertItem` parameter renamed from `position` to `index`
- **Fixed**: `LeveeCollectionView` now properly handles paginator swap via `didUpdateWidget`
- **Fixed**: `LeveeCollectionView` wraps non-scrollable states (`loading`, `error`, `empty`) in `SingleChildScrollView` so `RefreshIndicator` works correctly
- **Fixed**: `LeveeCollectionView` shows loading indicator on initial `idle` state instead of an empty list
- **Improved**: Added `isLoading` getter to `PageState` for convenience
- **Improved**: Expanded test coverage (107 tests)
- **Updated**: README with MergeMode documentation, mutation API examples, and clarification of scope

## 0.6.0

**Breaking Change**

- **BREAKING**: `LeveeBuilder` now requires both generic type parameters `<T, K>` (previously only `<T>`)
  - Before: `LeveeBuilder<Post>(...)`
  - After: `LeveeBuilder<Post, int>(...)`
  - This ensures full type safety and consistency with `Paginator<T, K>`

**Features**

- Added list mutation methods: `updateItem`, `removeItem`, `insertItem`
- Improved API: Fixed `RetryPolicy` configuration in documentation
- Enhanced test coverage (77 tests)

## 0.5.5

**Feature Update**

- Added list mutation methods: `updateItem`, `removeItem`, `insertItem`
- Improved API: Fixed `RetryPolicy` configuration in documentation
- Enhanced test coverage (77 tests, +10 mutation tests)

## 0.5.0

**Initial Release**

Core Features:
- Generic page key support (`int`, `String`, `DocumentSnapshot`, custom types)
- Four cache policies: CacheFirst, NetworkFirst, CacheOnly, NetworkOnly
- Exponential backoff retry logic with configurable attempts
- Advanced filtering system with 13+ operations
- Deterministic cache keys based on query parameters
- Headless `LeveeBuilder` widget for custom UI
- Full-featured `LeveeCollectionView` with infinite scroll and pull-to-refresh
- In-memory cache store with TTL support
- Zero external dependencies (dependency-free core)
- Comprehensive test coverage (67 tests)
