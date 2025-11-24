# Levee Example

A complete example demonstrating Levee pagination features using the [JSONPlaceholder](https://jsonplaceholder.typicode.com/) REST API.

## Features Demonstrated

- ✅ **Pagination** - Infinite scroll with 10 posts per page
- ✅ **Cache-First** - Instant loading from cache with background refresh
- ✅ **Retry Logic** - Exponential backoff on network failures
- ✅ **Pull-to-Refresh** - Manual refresh support
- ✅ **List Mutations** - Add, update, and delete posts instantly
- ✅ **Error Handling** - Graceful error states with retry
- ✅ **Loading States** - Initial load and pagination indicators

## List Mutations Demo

The example showcases all three mutation methods:

### Add Post (insertItem)
Tap the **➕ FAB** to create a new post at the top of the list instantly.

### Update Post (updateItem)
Tap **⋮ → Update** on any post to append "(Updated)" to its title.

### Delete Post (removeItem)
Tap **⋮ → Delete** to remove a post with an undo option.

All mutations update the UI immediately without network calls, demonstrating how to use Levee with Firestore or other backends where you already have the updated data.

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Code Structure

- `Post` - Simple model with `fromJson` and `copyWith`
- `PostsDataSource` - Implements `DataSource<Post, int>` for REST API
- `PostsListScreen` - Main screen with `LeveeBuilder` for pagination
- `PostCard` - Individual post widget with mutation actions

## API Used

JSONPlaceholder provides 100 test posts:
- GET https://jsonplaceholder.typicode.com/posts?_page=1&_limit=10

Perfect for testing pagination without setting up a backend!
