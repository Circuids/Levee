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
