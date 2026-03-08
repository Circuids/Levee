import 'package:flutter/material.dart';

import '../core/page_state.dart';
import '../core/paginator.dart';

/// Headless state listener for custom UI.
///
/// Use this widget when you want full control over the UI while still
/// listening to paginator state changes.
///
/// Example:
/// ```dart
/// LeveeBuilder<Product, int>(
///   paginator: paginator,
///   builder: (context, state) {
///     if (state.status == PageStatus.loading && state.items.isEmpty) {
///       return CircularProgressIndicator();
///     }
///
///     return ListView.builder(
///       itemCount: state.items.length,
///       itemBuilder: (context, index) => ProductCard(state.items[index]),
///     );
///   },
/// )
/// ```
class LeveeBuilder<T, K> extends StatefulWidget {
  /// Creates a [LeveeBuilder] that listens to paginator state changes.
  const LeveeBuilder({
    super.key,
    required this.paginator,
    required this.builder,
  });

  /// The paginator to listen to.
  final Paginator<T, K> paginator;

  /// Builder function that receives the current page state.
  final Widget Function(BuildContext context, PageState<T> state) builder;

  @override
  State<LeveeBuilder<T, K>> createState() => _LeveeBuilderState<T, K>();
}

class _LeveeBuilderState<T, K> extends State<LeveeBuilder<T, K>> {
  @override
  void initState() {
    super.initState();
    widget.paginator.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(LeveeBuilder<T, K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paginator != widget.paginator) {
      oldWidget.paginator.removeListener(_onStateChanged);
      widget.paginator.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.paginator.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.paginator.state);
  }
}
