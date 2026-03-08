# Levee Architecture & Internals

> v1.0.0 — Lean, backend-agnostic pagination engine for Flutter.

## Design Philosophy

- **Simplicity**: Minimal contracts, explicit APIs, no hidden magic.
- **Explicitness**: Developers see exactly what's happening — cache hit, network fetch, retry attempts — via `PageState` flags.
- **Lean core**: Only universally useful features: pagination, filtering, sorting, cache.
- **Simple by default**: No retry, `equals` operation, `cacheFirst` policy, `append` merge mode. Complexity is opt-in.
- **Backend agnostic**: Developers implement one method (`DataSource.fetch()`). Levee never knows about HTTP, Firestore, GraphQL, etc.
- **UI ready**: `LeveeCollectionView` covers list/grid, infinite scroll, refresh, and state handling out of the box. `LeveeBuilder` for full custom UI control.

---

## High-Level Overview

```
┌──────────────────────────────────────────────────────┐
│                     Flutter UI                        │
│  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │  LeveeBuilder    │  │  LeveeCollectionView     │  │
│  │  (headless)      │  │  (list/grid + scroll +   │  │
│  │                  │  │   refresh + states)       │  │
│  └────────┬─────────┘  └────────────┬─────────────┘  │
│           │ listens via              │ delegates to   │
│           │ ChangeNotifier           │ LeveeBuilder   │
└───────────┼──────────────────────────┼────────────────┘
            │                          │
            ▼                          ▼
┌──────────────────────────────────────────────────────┐
│               Paginator<T, K>                         │
│               (extends ChangeNotifier)                │
│                                                       │
│  State: PageState<T>                                  │
│  ├── items: List<T>                                   │
│  ├── status: idle | loading | ready | error           │
│  ├── hasMore, isFromCache, isRefreshing               │
│  └── retryAttempt, error                              │
│                                                       │
│  Public API:                                          │
│  ├── loadInitial()  → first page                      │
│  ├── loadNext()     → next page (infinite scroll)     │
│  ├── refresh()      → clear + reload                  │
│  ├── updateFilter() → new filter + reload             │
│  ├── insertItem()   → local insert                    │
│  ├── updateItem()   → local update                    │
│  └── removeItem()   → local remove                    │
│                                                       │
│  Config:                                              │
│  ├── mergeMode: append | replaceByKey                 │
│  ├── cachePolicy: cacheFirst | networkFirst | ...     │
│  └── retryPolicy?: maxAttempts, delay, retryIf        │
└───────┬─────────────────┬────────────────────────────┘
        │                 │
        ▼                 ▼
┌───────────────┐  ┌─────────────────────┐
│ DataSource    │  │ CacheStore<T, K>?   │
│ <T, K>        │  │                     │
│               │  │ MemoryCacheStore    │
│ fetch(query)  │  │ (default, with TTL) │
│ → PageData    │  │                     │
│               │  │ or custom impl      │
│ User impl:    │  │ (Hive, SQLite, etc) │
│ REST, GQL,    │  │                     │
│ Firestore...  │  └─────────────────────┘
└───────────────┘
```

## Data Flow

### 1. Load Initial / Load Next

```
User taps "load" or reaches scroll threshold
        │
        ▼
Paginator.loadInitial() / loadNext()
        │
        ├── Guard: skip if already loading or no more pages
        │
        ▼
_loadPage(query) → switch on CachePolicy:
        │
        ├── cacheFirst:   cache → UI → network (background) → UI
        ├── networkFirst: network → UI (fallback: cache → UI)
        ├── cacheOnly:    cache → UI (error if miss)
        └── networkOnly:  network → UI (no cache)
        │
        ▼
_fetchWithRetry(query) → DataSource.fetch(query)
        │                 ├── success → PageData<T, K>
        │                 └── error → retry (if RetryPolicy set)
        ▼
_updateStateFromPage(page)
        │
        ├── MergeMode.append:       [...existing, ...new]
        └── MergeMode.replaceByKey: Map-based O(n) merge
        │
        ▼
PageState updated → notifyListeners() → UI rebuilds
```

### 2. Filter / Refresh

```
updateFilter(filter) → reset state → loadInitial() with new filter
refresh()            → clear cache (optional) → loadInitial()
```

### 3. Local Mutations

```
insertItem(item, index) ──┐
updateItem(item, pred)  ──┤── Modify _state.items in-memory
removeItem(pred)        ──┘   → notifyListeners() → UI rebuilds
                              (No network call)
```

## Domain Folders

| Folder   | Responsibility                        | Key Types                                   |
| -------- | ------------------------------------- | ------------------------------------------- |
| `core/`  | Pagination engine + config            | `Paginator`, `PageState`, `MergeMode`, `RetryPolicy` |
| `query/` | Request types                         | `PageQuery`, `FilterQuery`, `FilterField`, `SortField`, `FilterOperation` |
| `data/`  | Backend integration contract          | `DataSource`, `PageData`                    |
| `cache/` | Cache abstraction + default impl      | `CacheStore`, `MemoryCacheStore`, `CachePolicy` |
| `ui/`    | Flutter widgets                       | `LeveeBuilder`, `LeveeCollectionView`       |
| `utils/` | Internal utilities (not public API)   | `Equals` class with `listEquals` and `listHash` |

## Cache Policy Behavior

| Policy        | Cache Hit                                   | Cache Miss             | Network Error             |
| ------------- | ------------------------------------------- | ---------------------- | ------------------------- |
| `cacheFirst`  | Show cache → background fetch → update UI   | Fetch network → cache  | Show cached (no error)    |
| `networkFirst`| —                                           | Fetch network → cache  | Fallback to cache         |
| `cacheOnly`   | Show cache                                  | Error state            | N/A (no network call)     |
| `networkOnly` | N/A (cache bypassed)                        | Fetch network          | Error state               |

## MergeMode Behavior

| Mode           | Next Page Behavior                                                 |
| -------------- | ------------------------------------------------------------------ |
| `append`       | Concatenate: `[...existing, ...new]`                               |
| `replaceByKey` | Match by `keySelector`, replace in-place; append truly new items   |

`replaceByKey` requires a `keySelector: (T) → Object` and uses a `Map<Object, int>` for O(n) lookups.

## Generics

- **`T`** — Item type (e.g., `Product`, `Post`, `User`)
- **`K`** — Page key type (e.g., `int` for offset, `String` for cursor, `DocumentSnapshot` for Firestore)

Both propagate through the entire stack: `Paginator<T, K>` → `DataSource<T, K>` → `PageData<T, K>` → `CacheStore<T, K>`.

## Widget Architecture

### LeveeBuilder<T, K>
Headless — subscribes to `Paginator` via `addListener` / `removeListener`, calls `builder(context, state)` on each change. Handles `didUpdateWidget` for paginator swaps.

### LeveeCollectionView<T, K>
Opinionated — delegates to `LeveeBuilder` internally. Provides:
- `ScrollController` with threshold-based infinite scroll
- `RefreshIndicator` wrapping (non-scrollable states wrapped in `SingleChildScrollView`)
- State-aware rendering: loading → error → empty → list/grid
- Grid support via optional `SliverGridDelegate`
- Calls `loadInitial()` automatically on `initState` and `didUpdateWidget` (paginator swap)

## Key Invariants

1. **Paginator is the single source of truth** — widgets only read `state`, never mutate it directly.
2. **DataSource never knows about cache** — caching decisions live entirely in Paginator.
3. **State is immutable** — all transitions go through `copyWith` + `notifyListeners()`.
4. **No external dependencies** beyond Flutter SDK + `collection` (for `ListEquality`).
5. **`keySelector` is required** when `mergeMode == MergeMode.replaceByKey` (assert at construction).
6. **Background fetch errors are silent** in `cacheFirst` — cached data is shown, no error state.

---

## API Contracts

### DataSource<T, K>

The only integration point with your backend. One method, one contract:

```dart
abstract class DataSource<T, K> {
  Future<PageData<T, K>> fetch(PageQuery<K> query);
}
```

- **Input:** `PageQuery<K>` — contains `pageSize`, `pageKey` (nullable for first page), and optional `FilterQuery`.
- **Output:** `PageData<T, K>` — contains `items`, `nextPageKey`, `isLastPage`, and optional `totalCount`.
- **Error handling:** Throw exceptions. Paginator catches them and applies retry (if configured) or sets error state.
- **FilterQuery interpretation:** The DataSource decides how to translate `FilterField` operations to its backend. Levee never interprets filters.

### PageQuery<K>

```dart
class PageQuery<K> {
  final int pageSize;
  final K? pageKey;        // null on first page
  final FilterQuery? filter;

  PageQuery<K> copyWith({...});
}
```

### PageData<T, K>

> Named `PageData` (not `Page`) to avoid shadowing `dart:ui`'s `Page` type.

```dart
class PageData<T, K> {
  final List<T> items;
  final K? nextPageKey;    // null if last page
  final bool isLastPage;
  final int? totalCount;   // optional
}
```

### FilterQuery, FilterField, FilterOperation, SortField

```dart
// Compose filters and sorting
FilterQuery(
  filters: [
    FilterField(field: 'status', value: 'active'),                          // defaults to equals
    FilterField(field: 'price', value: 100, operation: FilterOperation.greaterThan),
    FilterField(field: 'tags', value: 'flutter', operation: FilterOperation.custom('array-contains')),
  ],
  sorting: [
    SortField('date', descending: true),
    SortField('name'),
  ],
)
```

**Built-in operations:** `equals`, `notEquals`, `greaterThan`, `greaterThanOrEquals`, `lessThan`, `lessThanOrEquals`, `contains`, `startsWith`, `endsWith`, `inList`, `notInList`, `isNull`, `isNotNull`.

**Custom operations:** `FilterOperation.custom('LIKE')`, `FilterOperation.custom('array-contains')` — for backend-specific needs.

`FilterQuery` implements `==` / `hashCode` via `ListEquality` so it can be used in cache key generation.

### PageState<T>

Immutable state exposed by Paginator:

```dart
class PageState<T> {
  final List<T> items;
  final PageStatus status;    // idle | loading | ready | error
  final Exception? error;
  final bool hasMore;
  final bool isFromCache;     // true if current data came from cache
  final bool isRefreshing;    // true during cacheFirst background fetch
  final int? retryAttempt;    // current retry attempt number

  bool get isLoading => status == PageStatus.loading;
}
```

**State transitions:**
- `idle` → `loading` → `ready` (normal load)
- `ready` → `loading` → `ready` (next page)
- Any → `error` (on failure)
- `ready` with `isRefreshing: true` → `ready` with `isRefreshing: false` (cacheFirst background update)

### Paginator<T, K>

The core engine. Extends `ChangeNotifier`.

```dart
Paginator<T, K>({
  required DataSource<T, K> source,
  CacheStore<T, K>? cache,
  int pageSize = 20,
  CachePolicy cachePolicy = CachePolicy.cacheFirst,
  RetryPolicy? retryPolicy,
  FilterQuery? initialFilter,
  MergeMode mergeMode = MergeMode.append,
  Object Function(T item)? keySelector,  // required when mergeMode == replaceByKey
})
```

**Public methods:**

| Method | Behavior |
| --- | --- |
| `loadInitial()` | Resets state, loads first page. Respects cache policy. |
| `loadNext()` | Loads next page. No-op if already loading or `!hasMore`. |
| `refresh({clearCache})` | Clears cache (optional), resets, reloads first page. |
| `updateFilter(filter)` | Sets new filter, resets, reloads first page. |
| `insertItem(item, {index})` | Inserts item at index (default 0). Local only. |
| `updateItem(item, predicate)` | Replaces first match. Local only. |
| `removeItem(predicate)` | Removes all matches. Local only. |

### RetryPolicy

Optional. When provided, Paginator retries failed fetches with exponential backoff:

```dart
RetryPolicy(
  maxAttempts: 3,           // default
  delay: Duration(seconds: 1),  // initial delay, doubles each attempt
  maxDelay: Duration(seconds: 30),
  retryIf: (e) => e is SocketException,  // optional condition
)
```

During retries, `PageState.retryAttempt` is updated so UI can show retry progress.

---

## Cache Layer

### How It Works

Caching is **optional** — pass a `CacheStore<T, K>` to `Paginator` to enable it.

**Cache key generation:** Deterministic base64-encoded JSON of `{pageKey, filter.toMap()}`. Same query always produces the same key.

**Query-aware interface:** Both `get()` and `put()` receive the `PageQuery<K>` alongside the cache key. This enables two patterns:

| Store Type | How it uses the query param |
| --- | --- |
| Simple (Memory, Hive, SQLite) | Ignores query, uses key-value lookup |
| Backend-integrated (Firestore) | Uses query to fetch from backend's local cache |

### CacheStore<T, K> Interface

```dart
abstract class CacheStore<T, K> {
  Future<PageData<T, K>?> get(String key, PageQuery<K> query);
  Future<void> put(String key, PageQuery<K> query, PageData<T, K> value, {Duration? ttl});
  Future<void> remove(String key);
  Future<void> clear();
  Future<bool> has(String key);
}
```

### MemoryCacheStore<T, K>

Default in-memory implementation. Ignores the query parameter. Supports TTL via optional `Duration` on `put()`.

### Custom CacheStore Example: Firestore

```dart
class FirestoreCacheStore implements CacheStore<Product, DocumentSnapshot> {
  final Map<String, CacheMetadata> _metadata = {};

  @override
  Future<PageData<Product, DocumentSnapshot>?> get(
    String key,
    PageQuery<DocumentSnapshot> query,
  ) async {
    final meta = _metadata[key];
    if (meta == null || meta.isExpired) return null;

    // Fetch from Firestore's LOCAL cache (not server)
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where(/* interpret query.filter */)
        .startAfterDocument(query.pageKey)
        .limit(query.pageSize)
        .get(const GetOptions(source: Source.cache));

    if (snapshot.docs.isEmpty) {
      _metadata.remove(key);
      return null;
    }

    return PageData(
      items: snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
      nextPageKey: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      isLastPage: snapshot.docs.length < query.pageSize,
    );
  }

  @override
  Future<void> put(
    String key,
    PageQuery<DocumentSnapshot> query,
    PageData<Product, DocumentSnapshot> value,
    {Duration? ttl},
  ) async {
    _metadata[key] = CacheMetadata(timestamp: DateTime.now(), ttl: ttl);
    // Firestore already cached the documents locally; we just track metadata
  }

  // remove(), clear(), has() — straightforward Map operations on _metadata
}
```

---

## UI Widgets

### LeveeBuilder<T, K> — Headless

Subscribes to Paginator via `addListener` / `removeListener`. Calls your builder on every state change:

```dart
LeveeBuilder<Product, int>(
  paginator: paginator,
  builder: (context, state) {
    if (state.isLoading && state.items.isEmpty) {
      return CircularProgressIndicator();
    }
    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (_, i) => ProductCard(state.items[i]),
    );
  },
)
```

Handles `didUpdateWidget` — if you swap the paginator instance, it re-subscribes automatically.

### LeveeCollectionView<T, K> — Full-Featured

Delegates to `LeveeBuilder` internally. Provides everything out of the box:

```dart
LeveeCollectionView<Product, int>(
  paginator: paginator,
  itemBuilder: (context, item, index) => ProductCard(item),
  emptyBuilder: (context) => Text('No products found'),
  errorBuilder: (context, error) => Text('Error: $error'),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2), // optional grid
  enablePullToRefresh: true,   // default
  enableInfiniteScroll: true,  // default
  scrollThreshold: 0.8,       // trigger loadNext at 80% scroll
)
```

**How it renders:**

| Condition | What shows |
| --- | --- |
| Empty items + idle/loading | Loading indicator (or `loadingBuilder`) |
| Error + empty items | Error widget (or `errorBuilder`) |
| Ready + empty items | Empty widget (or `emptyBuilder`) |
| Has items | ListView or GridView (based on `gridDelegate`) |

**RefreshIndicator:** Non-scrollable states (loading, error, empty) are wrapped in `SingleChildScrollView` so pull-to-refresh works in all states. Scrollable content (ListView/GridView) is not double-wrapped.

---

## Usage Examples

### Basic Paginator

```dart
final paginator = Paginator<Product, int>(
  source: ProductDataSource(),
  cache: MemoryCacheStore(),
  pageSize: 20,
);

// In widget tree
LeveeCollectionView<Product, int>(
  paginator: paginator,
  itemBuilder: (context, item, index) => ProductCard(item),
);
```

### Cache Policies

```dart
// cacheFirst (default): Show cache instantly, update in background
Paginator<Product, int>(source: src, cachePolicy: CachePolicy.cacheFirst);

// networkFirst: Fresh data preferred, fallback to cache on error
Paginator<Product, int>(source: src, cachePolicy: CachePolicy.networkFirst);

// cacheOnly: Offline mode — never hits network
Paginator<Product, int>(source: src, cachePolicy: CachePolicy.cacheOnly);

// networkOnly: Always fresh — bypass cache
Paginator<Product, int>(source: src, cachePolicy: CachePolicy.networkOnly);
```

### Filters and Sorting

```dart
paginator.updateFilter(
  FilterQuery(
    filters: [
      FilterField(field: 'status', value: 'active'),
      FilterField(field: 'price', value: 100, operation: FilterOperation.greaterThan),
      FilterField(field: 'category', value: ['tech', 'gadgets'], operation: FilterOperation.inList),
    ],
    sorting: [
      SortField('date', descending: true),
      SortField('name'),
    ],
  ),
);
```

### Retry Policy

```dart
Paginator<Product, int>(
  source: ProductDataSource(),
  retryPolicy: RetryPolicy(
    maxAttempts: 3,
    delay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 30),
    retryIf: (e) => e is SocketException || e is TimeoutException,
  ),
);
```

### MergeMode: Replace by Key

```dart
Paginator<Product, int>(
  source: ProductDataSource(),
  mergeMode: MergeMode.replaceByKey,
  keySelector: (product) => product.id,  // required
);
// On loadNext(), items with matching keys are replaced in-place instead of duplicated.
```

### Cursor-Based Pagination

```dart
// Firestore with DocumentSnapshot cursor
final paginator = Paginator<Post, DocumentSnapshot>(
  source: FirestoreDataSource(),
  pageSize: 20,
);

// GraphQL with String cursor
final paginator = Paginator<Post, String>(
  source: GraphQLDataSource(),
  pageSize: 20,
);
```

### Local Mutations

```dart
// Insert at beginning
paginator.insertItem(newProduct);

// Insert at specific index
paginator.insertItem(newProduct, index: 3);

// Update first match
paginator.updateItem(updatedProduct, (existing) => existing.id == updatedProduct.id);

// Remove all matches
paginator.removeItem((item) => item.id == deletedId);
```

---

## Naming Conventions

These names are intentional and should not be changed:

| Actual Name | NOT | Reason |
| --- | --- | --- |
| `PageData<T, K>` | `Page<T, K>` | Avoids shadowing `dart:ui.Page` |
| `DataSource.fetch()` | `load()`, `get()` | `fetch` = network operation; `load` is reserved for Paginator |
| `nextPageKey` | `nextKey` | Explicit about what the key is for |
| `isLastPage` | `hasMore` on PageData | `hasMore` lives on `PageState` (accumulated state). `isLastPage` is per-page truth. |
| `insertItem(index:)` | `position:` | Dart convention (`List.insert` uses index) |

---

## What Levee Does NOT Do

Levee is a pagination engine with optional caching. It does **not** handle:

- Backend synchronization or write-back
- Distributed data consistency
- Mutation queues or optimistic updates on the server
- CRDT merging or offline conflict resolution
- Deep merging of item fields (replaceByKey is full item replacement only)

Local mutations (`insertItem`, `updateItem`, `removeItem`) operate on the in-memory list only and never trigger network calls.

---

## Roadmap

- **v1.0** ✅: All core features, 107 tests.
- **v1.1**: Example adapters (REST, Firestore, Supabase) in docs/examples.
- **v1.2**: Advanced cache stores (Hive, SQLite) as separate packages.
- **v2.0**: Community-driven extensions (debounce, offline sync, conflict resolution).
