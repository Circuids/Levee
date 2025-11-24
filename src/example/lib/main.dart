import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:levee/levee.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Levee Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PostsListScreen(),
    );
  }
}

// Model
class Post {
  final int id;
  final int userId;
  final String title;
  final String body;

  Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  Post copyWith({int? id, int? userId, String? title, String? body}) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }
}

// DataSource implementation for JSONPlaceholder API
class PostsDataSource implements DataSource<Post, int> {
  final http.Client client;

  PostsDataSource(this.client);

  @override
  Future<PageData<Post, int>> fetch(PageQuery<int> query) async {
    final page = query.pageKey ?? 1;
    final url = Uri.parse(
      'https://jsonplaceholder.typicode.com/posts?_page=$page&_limit=${query.pageSize}',
    );

    final response = await client.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to load posts');
    }

    final List<dynamic> jsonList = json.decode(response.body);
    final posts = jsonList.map((json) => Post.fromJson(json)).toList();

    // JSONPlaceholder has 100 posts total
    final hasMore = page * query.pageSize < 100;

    return PageData<Post, int>(
      items: posts,
      nextPageKey: hasMore ? page + 1 : null,
      isLastPage: !hasMore,
    );
  }
}

// Main screen demonstrating Levee pagination
class PostsListScreen extends StatefulWidget {
  const PostsListScreen({super.key});

  @override
  State<PostsListScreen> createState() => _PostsListScreenState();
}

class _PostsListScreenState extends State<PostsListScreen> {
  late final Paginator<Post, int> _paginator;

  @override
  void initState() {
    super.initState();
    _paginator = Paginator<Post, int>(
      source: PostsDataSource(http.Client()),
      cache: MemoryCacheStore<Post, int>(),
      pageSize: 10,
      cachePolicy: CachePolicy.cacheFirst,
      retryPolicy: RetryPolicy(maxAttempts: 3),
    );
    _paginator.loadInitial();
  }

  @override
  void dispose() {
    _paginator.dispose();
    super.dispose();
  }

  void _addNewPost() {
    // Simulate creating a new post
    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 1,
      title: 'New Post',
      body: 'This is a new post created at ${DateTime.now()}',
    );

    // Add to top of list using mutation
    _paginator.insertItem(newPost, position: 0);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post added!')));
  }

  void _updatePost(Post post) {
    // Simulate updating a post
    final updatedPost = post.copyWith(title: '${post.title} (Updated)');

    // Update in list using mutation
    _paginator.updateItem(updatedPost, (p) => p.id == post.id);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Post updated!')));
  }

  void _deletePost(Post post) {
    // Remove from list using mutation
    _paginator.removeItem((p) => p.id == post.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Post deleted!'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Re-insert the post
            _paginator.insertItem(post, position: 0);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Levee Example - Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _paginator.refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: LeveeBuilder<Post, int>(
        paginator: _paginator,
        builder: (context, state) {
          // Loading first page
          if (state.status == PageStatus.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error with no cached data
          if (state.status == PageStatus.error && state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${state.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _paginator.loadInitial(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (state.items.isEmpty) {
            return const Center(child: Text('No posts found'));
          }

          // List with items
          return RefreshIndicator(
            onRefresh: () => _paginator.refresh(),
            child: ListView.builder(
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Loading indicator at bottom
                if (index == state.items.length) {
                  // Trigger next page load
                  if (state.status != PageStatus.loading) {
                    _paginator.loadNext();
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final post = state.items[index];
                return PostCard(
                  post: post,
                  onUpdate: () => _updatePost(post),
                  onDelete: () => _deletePost(post),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewPost,
        tooltip: 'Add Post',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const PostCard({
    super.key,
    required this.post,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${post.userId}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'update',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Update'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'update') {
                      onUpdate();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(
              'Post ID: ${post.id}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
