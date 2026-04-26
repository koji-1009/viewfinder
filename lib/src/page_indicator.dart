import 'package:flutter/material.dart';

import 'viewfinder.dart' show Viewfinder;

/// Optional page-indicator for a [Viewfinder].
@immutable
class ViewfinderPageIndicator {
  const ViewfinderPageIndicator({
    this.dotSize = 8,
    this.activeDotSize = 10,
    this.spacing = 8,
    this.color = Colors.white54,
    this.activeColor = Colors.white,
    this.alignment = Alignment.bottomCenter,
    this.padding = const EdgeInsets.all(16),
    this.maxDots = 12,
  });

  /// Diameter of inactive dots.
  final double dotSize;

  /// Diameter of the active dot.
  final double activeDotSize;

  /// Spacing between dots.
  final double spacing;

  final Color color;
  final Color activeColor;
  final Alignment alignment;
  final EdgeInsets padding;

  /// When the item count exceeds this value the indicator falls back to
  /// a "1 / N" numeric label.
  final int maxDots;
}

/// Internal widget that renders dots or a numeric page count.
class ViewfinderPageIndicatorOverlay extends StatelessWidget {
  const ViewfinderPageIndicatorOverlay({
    super.key,
    required this.config,
    required this.itemCount,
    required this.currentIndex,
  });

  final ViewfinderPageIndicator config;
  final int itemCount;
  final int currentIndex;

  Widget _dots() => Row(
    mainAxisSize: .min,
    children: [
      for (var i = 0; i < itemCount; i++)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: config.spacing / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == currentIndex ? config.activeDotSize : config.dotSize,
            height: i == currentIndex ? config.activeDotSize : config.dotSize,
            decoration: BoxDecoration(
              shape: .circle,
              color: i == currentIndex ? config.activeColor : config.color,
            ),
          ),
        ),
    ],
  );

  Widget _numeric() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      '${currentIndex + 1} / $itemCount',
      style: TextStyle(color: config.activeColor, fontSize: 13),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final content = itemCount > config.maxDots ? _numeric() : _dots();
    return Align(
      alignment: config.alignment,
      child: Padding(padding: config.padding, child: content),
    );
  }
}
