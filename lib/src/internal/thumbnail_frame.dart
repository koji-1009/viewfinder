import 'package:flutter/widgets.dart';

import '../thumbnails.dart';

/// Overlays the [bar] (thumbnail strip) on the edge of the full-bleed
/// [child] (pager) dictated by [position]. Internal — `Viewfinder` uses
/// this to keep its build method declarative.
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
  Widget build(BuildContext context) {
    final alignment = switch (position) {
      .bottom => Alignment.bottomCenter,
      .top => Alignment.topCenter,
      .left => Alignment.centerLeft,
      .right => Alignment.centerRight,
    };
    return Stack(
      fit: .expand,
      children: [
        child,
        Align(alignment: alignment, child: bar),
      ],
    );
  }
}
