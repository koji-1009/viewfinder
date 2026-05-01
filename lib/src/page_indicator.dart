import 'package:flutter/material.dart';

import 'viewfinder.dart' show Viewfinder;

/// Optional page-indicator for a [Viewfinder].
///
/// Three variants:
/// - [ViewfinderPageIndicatorDots] — one dot per item.
/// - [ViewfinderPageIndicatorLabel] — a single text label (default: `"i / N"`).
/// - [ViewfinderPageIndicatorAdaptive] — dots up to a threshold, label beyond.
@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorDots &&
          alignment == other.alignment &&
          padding == other.padding &&
          dotSize == other.dotSize &&
          activeDotSize == other.activeDotSize &&
          spacing == other.spacing &&
          color == other.color &&
          activeColor == other.activeColor;

  @override
  int get hashCode => Object.hash(
    alignment,
    padding,
    dotSize,
    activeDotSize,
    spacing,
    color,
    activeColor,
  );
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorLabel &&
          alignment == other.alignment &&
          padding == other.padding &&
          labelBuilder == other.labelBuilder;

  @override
  int get hashCode => Object.hash(alignment, padding, labelBuilder);
}

/// Renders [dots] when `itemCount <= maxDots`; switches to [label] beyond it.
///
/// The [alignment] and [padding] on the inner [dots] / [label] are ignored —
/// the outer values on the [ViewfinderPageIndicatorAdaptive] are the source of
/// truth. A debug-mode assert in the overlay catches accidental customization
/// of the inner values.
final class ViewfinderPageIndicatorAdaptive extends ViewfinderPageIndicator {
  const ViewfinderPageIndicatorAdaptive({
    super.alignment,
    super.padding,
    this.dots = const ViewfinderPageIndicatorDots(),
    this.label = const ViewfinderPageIndicatorLabel(),
    this.maxDots = 12,
  }) : assert(maxDots >= 0, 'maxDots must be non-negative');

  final ViewfinderPageIndicatorDots dots;
  final ViewfinderPageIndicatorLabel label;

  /// Maximum item count for which dots are rendered. Beyond this, the label
  /// variant takes over.
  final int maxDots;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorAdaptive &&
          alignment == other.alignment &&
          padding == other.padding &&
          dots == other.dots &&
          label == other.label &&
          maxDots == other.maxDots;

  @override
  int get hashCode => Object.hash(alignment, padding, dots, label, maxDots);
}

