import 'package:flutter/widgets.dart';

import 'internal/colors.dart' as colors;
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
    this.safeArea = true,
  });

  /// Where the indicator sits within the viewfinder.
  final Alignment alignment;

  /// Padding applied around the indicator before alignment.
  final EdgeInsets padding;

  /// When `true` (default), the indicator keeps clear of system
  /// intrusions — a bottom-aligned indicator sits above the home
  /// indicator / browser chrome instead of sinking under it. Set
  /// `false` to manage the inset yourself via [padding].
  final bool safeArea;
}

/// Builds the screen-reader label for a dots indicator. See
/// [ViewfinderPageIndicatorDots.semanticLabelBuilder].
typedef ViewfinderPageIndicatorSemanticLabelBuilder =
    String Function(int currentIndex, int itemCount);

/// Renders one dot per item, highlighting the current page.
final class ViewfinderPageIndicatorDots extends ViewfinderPageIndicator {
  /// Creates a dots indicator.
  const ViewfinderPageIndicatorDots({
    super.alignment,
    super.padding,
    super.safeArea,
    this.dotSize = 8,
    this.activeDotSize = 10,
    this.spacing = 8,
    this.color = colors.white54,
    this.activeColor = colors.white,
    this.semanticLabelBuilder,
  });

  /// Diameter of inactive dots.
  final double dotSize;

  /// Diameter of the active dot.
  final double activeDotSize;

  /// Spacing between dots.
  final double spacing;

  /// Color of inactive dots.
  final Color color;

  /// Color of the dot for the current page.
  final Color activeColor;

  /// Builds the screen-reader label for the dot row, which is
  /// otherwise purely visual. Defaults to
  /// `'Page ${currentIndex + 1} of $itemCount'` — supply your own for
  /// localization.
  final ViewfinderPageIndicatorSemanticLabelBuilder? semanticLabelBuilder;

  /// Identity tuple backing [==] and [hashCode] — one field list
  /// instead of two parallel ones (records compare and hash
  /// structurally).
  Object get _props => (
    alignment,
    padding,
    safeArea,
    dotSize,
    activeDotSize,
    spacing,
    color,
    activeColor,
    semanticLabelBuilder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorDots && other._props == _props;

  @override
  int get hashCode => _props.hashCode;
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
  /// Creates a text-label indicator. Pass [labelBuilder] to customize
  /// the rendered widget; default styling is a pill with `"i / N"`.
  const ViewfinderPageIndicatorLabel({
    super.alignment,
    super.padding,
    super.safeArea,
    this.labelBuilder,
  });

  /// Builds the rendered label. When `null`, a default pill is used.
  final ViewfinderPageIndicatorLabelBuilder? labelBuilder;

  Object get _props => (alignment, padding, safeArea, labelBuilder);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorLabel && other._props == _props;

  @override
  int get hashCode => _props.hashCode;
}

/// Renders [dots] when `itemCount <= maxDots`; switches to [label] beyond it.
///
/// The [alignment] and [padding] on the inner [dots] / [label] are ignored —
/// the outer values on the [ViewfinderPageIndicatorAdaptive] are the source of
/// truth. Customizing the inner values is rejected by a debug-only assert; in
/// release builds it is silently ignored.
final class ViewfinderPageIndicatorAdaptive extends ViewfinderPageIndicator {
  /// Creates an adaptive indicator. The default values match standard
  /// photo-viewer behaviour: dots up to 12 items, then `"i / N"` label.
  const ViewfinderPageIndicatorAdaptive({
    super.alignment,
    super.padding,
    super.safeArea,
    this.dots = const ViewfinderPageIndicatorDots(),
    this.label = const ViewfinderPageIndicatorLabel(),
    this.maxDots = 12,
  }) : assert(maxDots >= 0, 'maxDots must be non-negative');

  /// Configuration used while rendering dots (`itemCount <= maxDots`).
  final ViewfinderPageIndicatorDots dots;

  /// Configuration used once `itemCount` exceeds [maxDots].
  final ViewfinderPageIndicatorLabel label;

  /// Maximum item count for which dots are rendered. Beyond this, the label
  /// variant takes over.
  final int maxDots;

  Object get _props => (alignment, padding, safeArea, dots, label, maxDots);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderPageIndicatorAdaptive && other._props == _props;

  @override
  int get hashCode => _props.hashCode;
}
