<div align="center">
  <img src="src/logo.png" alt="Levee Logo" width="300"/>


  [![pub package](https://img.shields.io/pub/v/levee.svg)](https://pub.dev/packages/levee)
  [![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)
  [![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?logo=Flutter&logoColor=white)](https://flutter.dev)

</div>

**Levee** is a lightweight, high-performance, dependency-free pagination engine for Flutter that brings **cache-first architecture** and **generic page key support** to your applications. Whether you're paginating REST APIs with offset/limit, Firestore with cursors, or custom pagination schemes, Levee provides a unified, flexible foundation.

---

## Table of Contents

- [Features](#features-)
- [Quick Start](#quick-start-)
- [Cache Policies](#cache-policies-)
- [Retry Logic](#retry-logic-)
- [Filtering & Sorting](#filtering--sorting-)
- [DataSource Examples](#datasource-examples-)
- [Architecture](#architecture-️)
- [API Reference](#api-reference-)
- [Design Philosophy](#design-philosophy-)
- [Contributing](#contributing-)
- [License](#license-)
- [Support](#support-)

---

## Features 

- **Generic Page Keys (`K`)**: Use `int`, `String`, `DocumentSnapshot`, or custom types as page keys
- **Dependency-Free Core**: Zero external dependencies beyond Flutter SDK
- **Cache-First Architecture**: Four cache policies (CacheFirst, NetworkFirst, CacheOnly, NetworkOnly)
- **Automatic Retry Logic**: Exponential backoff with configurable max attempts
- **Advanced Filtering & Sorting**: Comprehensive `FilterQuery` system with 13+ operations
- **Deterministic Cache Keys**: Query parameters + filters create stable cache identities
- **Headless & UI Modes**: `LeveeBuilder` for custom UI, `LeveeCollectionView` for plug-and-play infinite scroll
- **State Management**: Built on `ChangeNotifier` for seamless Flutter integration
- **TTL Support**: Time-based cache expiration in `MemoryCacheStore`
- **Type-Safe**: Full generic support with `PageData<T,K>` and `DataSource<T,K>`

---

## Quick Start 🚀

### 1. Add to pubspec.yaml

```yaml
dependencies:
  levee: ^0.6.0
```

### 2. Define Your Data Source

```dart
import 'package:levee/levee.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserDataSource implements DataSource<User, int> {
  final String baseUrl;

  UserDataSource(this.baseUrl);

  @override
  Future<PageData<User, int>> fetchPage(PageQuery<int> query) async {
    // Build URL with query parameters
    final url = Uri.parse('$baseUrl/users').replace(queryParameters: {
      'page': query.key.toString(),
      'limit': query.pageSize.toString(),
      if (query.filters != null) ...buildFilterParams(query.filters!),
    });

    final response = await http.get(url);
    final data = json.decode(response.body);

    return PageData<User, int>(
      items: (data['users'] as List).map((json) => User.fromJson(json)).toList(),
      query: query,
      nextKey: data['hasMore'] ? query.key + 1 : null,
      status: PageStatus.success,
    );
  }

  Map<String, String> buildFilterParams(FilterQuery filters) {
    // Convert filters to API params
    return {
      for (var field in filters.fields)
        field.fieldName: field.value.toString(),
    };
  }
}
```

### 3. Initialize Paginator

```dart
final paginator = Paginator<User, int>(
  source: UserDataSource('https://api.example.com'),
  cache: MemoryCacheStore<User, int>(),
  pageSize: 20,
  cachePolicy: CachePolicy.cacheFirst,
  retryPolicy: RetryPolicy(maxAttempts: 3),
);
```

### 4. Build Your UI

**Option A: Headless with `LeveeBuilder`**

```dart
class UserListScreen extends StatelessWidget {
  final Paginator<User, int> paginator;

  UserListScreen(this.paginator);

  @override
  Widget build(BuildContext context) {
    return LeveeBuilder<User, int>(
      paginator: paginator,
      builder: (context, state) {
        if (state.pages.isEmpty && state.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        final allUsers = state.pages.expand((p) => p.items).toList();
        
        return ListView.builder(
          itemCount: allUsers.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == allUsers.length) {
              paginator.loadNextPage();
              return Center(child: CircularProgressIndicator());
            }
            return UserTile(user: allUsers[index]);
          },
        );
      },
    );
  }
}
```

**Option B: Full-Featured with `LeveeCollectionView`**

```dart
LeveeCollectionView<User, int>(
  paginator: paginator,
  itemBuilder: (context, user) => ListTile(
    leading: CircleAvatar(child: Text(user.name[0])),
    title: Text(user.name),
    subtitle: Text(user.email),
    trailing: Icon(Icons.chevron_right),
  ),
  loadingBuilder: (context) => Center(
    child: CircularProgressIndicator(),
  ),
  errorBuilder: (context, error) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        SizedBox(height: 16),
        Text('Error: $error'),
        ElevatedButton(
          onPressed: () => paginator.refresh(),
          child: Text('Retry'),
        ),
      ],
    ),
  ),
  emptyBuilder: (context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
        SizedBox(height: 16),
        Text('No users found'),
      ],
    ),
  ),
)
```

---

## Cache Policies 

Levee supports four cache policies to match your data freshness requirements:

| Policy | Description | Use Case |
|--------|-------------|----------|
| **`CacheFirst`** | Check cache first, fetch on miss | Default, balances speed and freshness |
| **`NetworkFirst`** | Always fetch fresh, fall back to cache on error | Real-time data with offline fallback |
| **`CacheOnly`** | Only return cached data | Offline-first, testing |
| **`NetworkOnly`** | Always fetch fresh, ignore cache | Critical data requiring latest state |

```dart
// Example: Switch to NetworkFirst for real-time updates
paginator.updateCachePolicy(CachePolicy.networkFirst);
```

---

## Retry Logic 🔄

Levee includes exponential backoff retry for transient failures:

```dart
final paginator = Paginator<User, int>(
  source: userDataSource,
  retryPolicy: RetryPolicy(
    maxAttempts: 3,
    delay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  ),
);
```

**Retry Behavior:**
- Attempts: `maxAttempts` (default: 3)
- Delays: Exponential backoff (1s, 2s, 4s, ...)
- Max delay: Capped at `maxDelay` (default: 30s)
- Conditional: Use `retryIf` to retry only on specific errors

---

## List Mutations ✏️

Update the paginated list instantly without refetching from the backend. Perfect for Firestore or when you already have the updated data in hand.

### updateItem

Update an existing item in the list:

```dart
// After updating Firestore
await postDoc.update({'likes': likes + 1});
paginator.updateItem(
  post.copyWith(likes: likes + 1),
  (p) => p.id == post.id,
);
// UI updates instantly, no network call needed
```

### removeItem

Remove an item from the list:

```dart
// After deleting from Firestore
await postDoc.delete();
paginator.removeItem((post) => post.id == deletedPostId);
// Item disappears from UI immediately
```

### insertItem

Insert a new item into the list:

```dart
// After creating in Firestore
final newPost = await postsCollection.add(postData);
paginator.insertItem(
  Post.fromFirestore(newPost),
  position: 0, // Add to top (default)
);
// New item appears instantly
```

**Why use mutations?**
- ⚡ **Instant UI updates** - No waiting for network calls
- 💰 **Save money** - Avoid expensive Firestore reads after mutations
- 🎯 **Better UX** - Immediate feedback for user actions
- 🧠 **Smart** - You already have the data after create/update/delete

**Note:** These methods only update the local list. They don't sync with the backend—you should call them **after** your backend operation succeeds.

---

## Filtering & Sorting 

### Filter Operations

Levee provides 13 predefined operations plus custom support:

```dart
final filters = FilterQuery(
  fields: [
    FilterField(
      fieldName: 'status',
      value: 'active',
      operation: FilterOperation.equals,
    ),
    FilterField(
      fieldName: 'age',
      value: 18,
      operation: FilterOperation.greaterThan,
    ),
    FilterField(
      fieldName: 'tags',
      value: 'flutter',
      operation: FilterOperation.arrayContains,
    ),
  ],
  sorts: [
    SortField(fieldName: 'createdAt', descending: true),
  ],
);

final query = PageQuery<int>(
  key: 1,
  pageSize: 20,
  filters: filters,
);
```

**Available Operations:**
- `equals`, `notEquals`
- `greaterThan`, `greaterThanOrEqual`, `lessThan`, `lessThanOrEqual`
- `isIn`, `isNotIn`
- `arrayContains`, `arrayContainsAny`
- `isNull`, `isNotNull`
- `like`
- `custom(String code)` - For provider-specific operations

### Deterministic Cache Keys

Filters and sorts are part of the cache key calculation, ensuring:
```dart
PageQuery(key: 1, filters: FilterQuery(...)) 
// Generates different cache key than:
PageQuery(key: 1, filters: null)
```

---

## DataSource Examples 

Levee's `DataSource` interface is simple yet powerful—implement one method to connect any backend. Here are production-ready examples:

### REST API with Offset Pagination

```dart
class RestDataSource implements DataSource<Product, int> {
  final String baseUrl;
  final http.Client client;

  RestDataSource(this.baseUrl, this.client);

  @override
  Future<PageData<Product, int>> fetchPage(PageQuery<int> query) async {
    final offset = (query.key - 1) * query.pageSize;
    final url = Uri.parse('$baseUrl/products').replace(queryParameters: {
      'offset': offset.toString(),
      'limit': query.pageSize.toString(),
    });

    final response = await client.get(url);
    if (response.statusCode != 200) throw Exception('Failed to load products');

    final data = json.decode(response.body);
    return PageData<Product, int>(
      items: (data['products'] as List).map((j) => Product.fromJson(j)).toList(),
      query: query,
      nextKey: data['hasMore'] ? query.key + 1 : null,
      status: PageStatus.success,
    );
  }
}
```

### Firestore with Cursor Pagination

```dart
class FirestoreDataSource implements DataSource<Post, DocumentSnapshot?> {
  final FirebaseFirestore firestore;
  final String collection;

  FirestoreDataSource(this.firestore, this.collection);

  @override
  Future<PageData<Post, DocumentSnapshot?>> fetchPage(
    PageQuery<DocumentSnapshot?> query,
  ) async {
    var firestoreQuery = firestore
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .limit(query.pageSize);

    if (query.key != null) {
      firestoreQuery = firestoreQuery.startAfterDocument(query.key!);
    }

    final snapshot = await firestoreQuery.get();
    return PageData<Post, DocumentSnapshot?>(
      items: snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList(),
      query: query,
      nextKey: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      status: PageStatus.success,
    );
  }
}
```

### GraphQL with Cursor Pagination

```dart
class GraphQLDataSource implements DataSource<User, String?> {
  final GraphQLClient client;

  GraphQLDataSource(this.client);

  @override
  Future<PageData<User, String?>> fetchPage(PageQuery<String?> query) async {
    final result = await client.query(QueryOptions(
      document: gql('''
        query GetUsers(\$first: Int!, \$after: String) {
          users(first: \$first, after: \$after) {
            edges { node { id name email } cursor }
            pageInfo { hasNextPage endCursor }
          }
        }
      '''),
      variables: {'first': query.pageSize, 'after': query.key},
    ));

    if (result.hasException) throw result.exception!;

    final edges = result.data!['users']['edges'] as List;
    final pageInfo = result.data!['users']['pageInfo'];

    return PageData<User, String?>(
      items: edges.map((e) => User.fromJson(e['node'])).toList(),
      query: query,
      nextKey: pageInfo['hasNextPage'] ? pageInfo['endCursor'] : null,
      status: PageStatus.success,
    );
  }
}
```

### Supabase with Range Pagination

```dart
class SupabaseDataSource implements DataSource<Todo, int> {
  final SupabaseClient supabase;
  final String table;

  SupabaseDataSource(this.supabase, this.table);

  @override
  Future<PageData<Todo, int>> fetchPage(PageQuery<int> query) async {
    final from = query.key;
    final to = from + query.pageSize - 1;

    final response = await supabase
        .from(table)
        .select()
        .range(from, to)
        .order('created_at', ascending: false);

    final todos = (response as List).map((json) => Todo.fromJson(json)).toList();

    return PageData<Todo, int>(
      items: todos,
      query: query,
      nextKey: todos.length == query.pageSize ? to + 1 : null,
      status: PageStatus.success,
    );
  }
}
```

### Local SQLite with Offset Pagination

```dart
class SQLiteDataSource implements DataSource<Note, int> {
  final Database database;

  SQLiteDataSource(this.database);

  @override
  Future<PageData<Note, int>> fetchPage(PageQuery<int> query) async {
    final offset = query.key;
    final results = await database.query(
      'notes',
      orderBy: 'created_at DESC',
      limit: query.pageSize,
      offset: offset,
    );

    final notes = results.map((row) => Note.fromMap(row)).toList();

    return PageData<Note, int>(
      items: notes,
      query: query,
      nextKey: notes.length == query.pageSize ? offset + query.pageSize : null,
      status: PageStatus.success,
    );
  }
}
```

---

## Architecture 

```
┌─────────────────────┐
│   UI Layer          │
│  LeveeBuilder /     │◄──── ChangeNotifier updates
│  CollectionView     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Paginator<T,K>    │
│  - Cache Policy     │
│  - Retry Logic      │
│  - State Management │
└──────┬──────────┬───┘
       │          │
       ▼          ▼
┌─────────────┐ ┌──────────────┐
│ CacheStore  │ │ DataSource   │
│  <T,K>      │ │   <T,K>      │
└─────────────┘ └──────────────┘
```

**Key Components:**

- **`Paginator<T,K>`**: Core engine managing cache, network, and state
- **`DataSource<T,K>`**: Contract for fetching pages (implement for your backend)
- **`CacheStore<T,K>`**: Contract for caching (use `MemoryCacheStore` or implement custom)
- **`PageData<T,K>`**: Immutable page representation with items and metadata
- **`PageQuery<K>`**: Query specification (key, size, filters, sorts)
- **`FilterQuery`**: Declarative filtering/sorting system

---

## API Reference 

### Core Classes

#### `Paginator<T, K>`

```dart
class Paginator<T, K> extends ChangeNotifier {
  Paginator({
    required DataSource<T, K> source,
    PageQuery<K> initialQuery,
    CacheStore<T, K>? cache,
    int pageSize = 20,
    CachePolicy cachePolicy = CachePolicy.cacheFirst,
    RetryPolicy? retryPolicy,
    FilterQuery? initialFilter,
  });

  // State
  PageState<T> get state;

  // Actions
  Future<void> loadInitial();
  Future<void> loadNext();
  Future<void> refresh({bool clearCache = true});
  Future<void> updateFilter(FilterQuery? filter);
  
  // List Mutations
  void updateItem(T item, bool Function(T) predicate);
  void removeItem(bool Function(T) predicate);
  void insertItem(T item, {int position = 0});
  
  void dispose();
}
```

#### `DataSource<T, K>`

```dart
abstract class DataSource<T, K> {
  Future<PageData<T, K>> fetchPage(PageQuery<K> query);
}
```

#### `CacheStore<T, K>`

```dart
abstract class CacheStore<T, K> {
  Future<PageData<T, K>?> get(PageQuery<K> query);
  Future<void> put(PageData<T, K> page);
  Future<void> remove(PageQuery<K> query);
  Future<void> clear();
}
```

### Data Structures

#### `PageData<T, K>`

```dart
class PageData<T, K> {
  final List<T> items;
  final PageQuery<K> query;
  final K? nextKey;
  final PageStatus status;
  final Object? error;
  final DateTime? cachedAt;
}
```

#### `PageQuery<K>`

```dart
class PageQuery<K> {
  final K key;
  final int pageSize;
  final FilterQuery? filters;

  PageQuery({
    required this.key,
    required this.pageSize,
    this.filters,
  });
}
```

#### `FilterQuery`

```dart
class FilterQuery {
  final List<FilterField> fields;
  final List<SortField> sorts;

  FilterQuery({
    required this.fields,
    this.sorts = const [],
  });
}
```

---

## Design Philosophy 

1. **Generic by Nature**: Single generic `K` for page keys supports any pagination scheme
2. **Cache-First**: Default to fast, offline-capable experiences
3. **Dependency-Free**: Core logic has zero external dependencies
4. **Framework-Agnostic Core**: Contracts can be implemented in non-Flutter contexts
5. **Deterministic Caching**: Query parameters + filters = stable cache keys
6. **Fail-Safe**: Retry logic and cache fallbacks prevent silent failures
7. **Developer Ergonomics**: Simple APIs with escape hatches for complexity

---

## Contributing 

Contributions welcome! Fork the repo, create a feature branch, add tests, ensure `flutter test` passes, and submit a PR.

---

## License 

BSD-3-Clause License. Copyright (c) 2025 Circuids. See [LICENSE](LICENSE) for details.

---

## Support 

- **Issues**: [GitHub Issues](https://github.com/Circuids/Levee/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Circuids/Levee/discussions)

---

**Levee** - Build pagination that scales from prototypes to production.
