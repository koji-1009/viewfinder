import 'package:flutter/widgets.dart';

import '../thumbnails.dart';

/// Lays out a [bar] (thumbnail strip) and the main [child] (pager) along
/// the axis dictated by [position]. Internal — `Viewfinder` uses this
/// to keep its build method declarative.
class ThumbnailFrame extends StatelessWidget {
  const ThumbnailFrame({
    super.key,
    required this.position,
    required this.bar,
    required this.child,
  });

  final ViewfinderThumbnailPosition position;
  final Widget bar;
  final Widget child;

  @override
  Widget build(BuildContext context) => switch (position) {
    .bottom => Column(
      children: [
        Expanded(child: child),
        bar,
      ],
    ),
    .top => Column(
      children: [
        bar,
        Expanded(child: child),
      ],
    ),
    .left => Row(
      children: [
        bar,
        Expanded(child: child),
      ],
    ),
    .right => Row(
      children: [
        Expanded(child: child),
        bar,
      ],
    ),
  };
}
