import 'package:flutter/material.dart';

import 'viewfinder.dart' show Viewfinder;

/// Optional page-indicator for a [Viewfinder].
///
/// Three variants:
/// - [ViewfinderPageIndicatorDots] — one dot per item.
/// - [ViewfinderPageIndicatorLabel] — a single text label (default: `"i / N"`).
/// - [ViewfinderPageIndicatorAdaptive] — dots up to a threshold, label beyond.
sealed class ViewfinderPageIndicator {
  const ViewfinderPageIndicator({
    this.alignment = .bottomCenter,
    this.padding = const .all(16),
  });

  /// Where the indicator sits within the viewfinder.
  final Alignment alignment;

  /// Padding applied around the indicator before alignment.
  final EdgeInsets padding;
}

/// Renders one dot per item, highlighting the current page.
final class ViewfinderPageIndicatorDots extends ViewfinderPageIndicator {
  const ViewfinderPageIndicatorDots({
    super.alignment,
    super.padding,
    this.dotSize = 8,
    this.activeDotSize = 10,
    this.spacing = 8,
    this.color = Colors.white54,
    this.activeColor = Colors.white,
  });

  /// Diameter of inactive dots.
  final double dotSize;

  /// Diameter of the active dot.
  final double activeDotSize;

  /// Spacing between dots.
  final double spacing;

  final Color color;
  final Color activeColor;
}

/// Signature for [ViewfinderPageIndicatorLabel.labelBuilder] and the label
/// portion of [ViewfinderPageIndicatorAdaptive].
typedef ViewfinderPageIndicatorLabelBuilder =
    Widget Function(BuildContext context, int currentIndex, int itemCount);

/// Renders a single text label (default `"i / N"` pill).
///
/// Provide [labelBuilder] to fully customize the rendered widget; pass `null`
/// to use the default styling.
final class ViewfinderPageIndicatorLabel extends ViewfinderPageIndicator {
  const ViewfinderPageIndicatorLabel({
    super.alignment,
    super.padding,
    this.labelBuilder,
  });

  final ViewfinderPageIndicatorLabelBuilder? labelBuilder;
}

/// Renders [dots] when `itemCount <= maxDots`; switches to [label] beyond it.
///
/// The [alignment] and [padding] on the inner [dots] / [label] are ignored —
/// the outer values on the [ViewfinderPageIndicatorAdaptive] are the source of
/// truth. A debug-mode assert catches accidental customization of the inner
/// values.
final class ViewfinderPageIndicatorAdaptive extends ViewfinderPageIndicator {
  ViewfinderPageIndicatorAdaptive({
    super.alignment,
    super.padding,
    this.dots = const ViewfinderPageIndicatorDots(),
    this.label = const ViewfinderPageIndicatorLabel(),
    this.maxDots = 12,
  }) : assert(maxDots >= 0, 'maxDots must be non-negative') {
    assert(
      dots.alignment == alignment && dots.padding == padding,
      'Inner dots alignment/padding are ignored — set them on '
      'ViewfinderPageIndicatorAdaptive instead.',
    );
    assert(
      label.alignment == alignment && label.padding == padding,
      'Inner label alignment/padding are ignored — set them on '
      'ViewfinderPageIndicatorAdaptive instead.',
    );
  }

  final ViewfinderPageIndicatorDots dots;
  final ViewfinderPageIndicatorLabel label;

  /// Maximum item count for which dots are rendered. Beyond this, the label
  /// variant takes over.
  final int maxDots;
}

/// Internal widget that renders the configured indicator.
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

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final cfg = config;
    final content = switch (cfg) {
      ViewfinderPageIndicatorDots() => _DotsView(
        dots: cfg,
        itemCount: itemCount,
        currentIndex: currentIndex,
      ),
      ViewfinderPageIndicatorLabel() => _LabelView(
        builder: cfg.labelBuilder,
        currentIndex: currentIndex,
        itemCount: itemCount,
      ),
      ViewfinderPageIndicatorAdaptive() => itemCount > cfg.maxDots
          ? _LabelView(
              builder: cfg.label.labelBuilder,
              currentIndex: currentIndex,
              itemCount: itemCount,
            )
          : _DotsView(
              dots: cfg.dots,
              itemCount: itemCount,
              currentIndex: currentIndex,
            ),
    };
    return Align(
      alignment: cfg.alignment,
      child: Padding(padding: cfg.padding, child: content),
    );
  }
}

class _DotsView extends StatelessWidget {
  const _DotsView({
    required this.dots,
    required this.itemCount,
    required this.currentIndex,
  });

  final ViewfinderPageIndicatorDots dots;
  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    children: [
      for (var i = 0; i < itemCount; i++)
        Padding(
          padding: .symmetric(horizontal: dots.spacing / 2),
          child: AnimatedContainer(
            duration: const .new(milliseconds: 180),
            width: i == currentIndex ? dots.activeDotSize : dots.dotSize,
            height: i == currentIndex ? dots.activeDotSize : dots.dotSize,
            decoration: BoxDecoration(
              shape: .circle,
              color: i == currentIndex ? dots.activeColor : dots.color,
            ),
          ),
        ),
    ],
  );
}

class _LabelView extends StatelessWidget {
  const _LabelView({
    required this.builder,
    required this.currentIndex,
    required this.itemCount,
  });

  final ViewfinderPageIndicatorLabelBuilder? builder;
  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final builder = this.builder;
    if (builder != null) return builder(context, currentIndex, itemCount);
    return Container(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: .circular(16),
      ),
      child: Text(
        '${currentIndex + 1} / $itemCount',
        style: const .new(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
