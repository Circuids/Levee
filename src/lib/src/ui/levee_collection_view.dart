import 'package:flutter/material.dart';

import '../core/page_state.dart';
import '../core/paginator.dart';
import 'levee_builder.dart';

/// Full-featured list/grid widget with infinite scroll and pull-to-refresh.
///
/// This widget provides a complete pagination UI out of the box with:
/// - Infinite scroll (triggers loadNext at configurable threshold)
/// - Pull-to-refresh
/// - Loading, empty, and error state handling
/// - List or grid rendering
/// - Custom builders for all states
///
/// Example:
/// ```dart
/// LeveeCollectionView<Product, int>(
///   paginator: paginator,
///   itemBuilder: (context, item, index) => ProductCard(item),
///   emptyBuilder: (context) => Text('No products found'),
///   errorBuilder: (context, error) => Text('Error: $error'),
/// )
/// ```
class LeveeCollectionView<T, K> extends StatefulWidget {
  /// Creates a [LeveeCollectionView] with the given configuration.
  const LeveeCollectionView({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.gridDelegate,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.separatorBuilder,
    this.enablePullToRefresh = true,
    this.enableInfiniteScroll = true,
    this.scrollThreshold = 0.8,
  });

  /// The paginator to use for data loading.
  final Paginator<T, K> paginator;

  /// Builder for each item in the list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Optional grid delegate. If provided, renders a grid instead of a list.
  final SliverGridDelegate? gridDelegate;

  /// Optional custom loading indicator.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Optional custom empty state widget.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Optional custom error widget.
  final Widget Function(BuildContext context, Exception error)? errorBuilder;

  /// Optional separator builder for list view.
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// Whether to enable pull-to-refresh.
  final bool enablePullToRefresh;

  /// Whether to enable infinite scroll.
  final bool enableInfiniteScroll;

  /// Scroll threshold (0.0 to 1.0) to trigger loadNext.
  /// Default is 0.8 (80% scrolled).
  final double scrollThreshold;

  @override
  State<LeveeCollectionView<T, K>> createState() =>
      _LeveeCollectionViewState<T, K>();
}

class _LeveeCollectionViewState<T, K> extends State<LeveeCollectionView<T, K>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Load first page
    widget.paginator.loadInitial();

    // Set up infinite scroll
    if (widget.enableInfiniteScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(LeveeCollectionView<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paginator != widget.paginator) {
      widget.paginator.loadInitial();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.enableInfiniteScroll) return;

    final position = _scrollController.position;
    final threshold = position.maxScrollExtent * widget.scrollThreshold;

    if (position.pixels >= threshold) {
      widget.paginator.loadNext();
    }
  }

  Future<void> _onRefresh() async {
    await widget.paginator.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return LeveeBuilder<T, K>(
      paginator: widget.paginator,
      builder: (context, state) {
        Widget content;

        // Initial loading state (idle = loadInitial in progress, loading = next page)
        if (state.items.isEmpty &&
            (state.status == PageStatus.idle ||
                state.status == PageStatus.loading)) {
          content = _buildLoading(context);
        }
        // Error state with no cached data
        else if (state.status == PageStatus.error && state.items.isEmpty) {
          content = _buildError(context, state.error!);
        }
        // Empty state
        else if (state.status == PageStatus.ready && state.items.isEmpty) {
          content = _buildEmpty(context);
        }
        // Success state with items
        else {
          content = _buildList(context, state);
        }

        // Wrap with RefreshIndicator if enabled
        if (widget.enablePullToRefresh) {
          // RefreshIndicator requires a scrollable child.
          // _buildList returns ScrollView subclasses (ListView/GridView),
          // but loading/error/empty states are non-scrollable — wrap them.
          final scrollableContent = content is ScrollView
              ? content
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: content,
                  ),
                );

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: scrollableContent,
          );
        }

        return content;
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(context);
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildError(BuildContext context, Exception error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: ${error.toString()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => widget.paginator.refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    if (widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }

    return const Center(
      child: Text('No items found'),
    );
  }

  Widget _buildList(BuildContext context, PageState<T> state) {
    final itemCount = state.items.length + (state.hasMore ? 1 : 0);

    // Grid view
    if (widget.gridDelegate != null) {
      return GridView.builder(
        controller: _scrollController,
        gridDelegate: widget.gridDelegate!,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return _buildLoadingIndicator(state);
          }
          return widget.itemBuilder(context, state.items[index], index);
        },
      );
    }

    // List view with separator
    if (widget.separatorBuilder != null) {
      return ListView.separated(
        controller: _scrollController,
        itemCount: itemCount,
        separatorBuilder: widget.separatorBuilder!,
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return _buildLoadingIndicator(state);
          }
          return widget.itemBuilder(context, state.items[index], index);
        },
      );
    }

    // Simple list view
    return ListView.builder(
      controller: _scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return _buildLoadingIndicator(state);
        }
        return widget.itemBuilder(context, state.items[index], index);
      },
    );
  }

  Widget _buildLoadingIndicator(PageState<T> state) {
    // Show loading indicator for next page
    if (state.status == PageStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Show retry attempt if retrying
    if (state.retryAttempt != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text('Retry attempt ${state.retryAttempt}...'),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
