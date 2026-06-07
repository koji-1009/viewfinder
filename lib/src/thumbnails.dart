import 'package:flutter/widgets.dart';

import 'internal/colors.dart' as colors;
import 'viewfinder.dart' show Viewfinder;

/// Where the thumbnail strip sits relative to the main viewer.
enum ViewfinderThumbnailPosition {
  /// Above the main viewer, horizontal strip.
  top,

  /// Below the main viewer, horizontal strip.
  bottom,

  /// Left of the main viewer, vertical strip.
  left,

  /// Right of the main viewer, vertical strip.
  right,
}

/// Signature for fully custom thumbnail builders.
typedef ViewfinderThumbnailItemBuilder =
    Widget Function(BuildContext context, int index, bool selected);

/// Builds the screen-reader label for a thumbnail tile. See
/// [ViewfinderThumbnails.semanticLabelBuilder].
typedef ViewfinderThumbnailSemanticLabelBuilder =
    String Function(int index, bool selected);

/// Configures the optional thumbnail strip shown alongside a [Viewfinder].
@immutable
class ViewfinderThumbnails {
  /// Creates a thumbnail strip config with library defaults
  /// (bottom, 56-pt tiles, white selected border).
  const ViewfinderThumbnails({
    this.position = .bottom,
    this.size = 56,
    this.spacing = 4,
    this.padding = const .all(8),
    this.safeArea = true,
    this.selectedBorder = const Border.fromBorderSide(
      BorderSide(color: colors.white, width: 2),
    ),
    this.unselectedOpacity = 0.55,
    this.backgroundColor = colors.black54,
    this.errorBuilder,
    this.itemBuilder,
    this.semanticLabelBuilder,
  });

  /// Convenience constructor for callers that always provide a custom
  /// [itemBuilder]. Identical to the default constructor but makes
  /// [itemBuilder] required at the call site.
  const ViewfinderThumbnails.custom({
    this.position = .bottom,
    this.size = 56,
    this.spacing = 4,
    this.padding = const .all(8),
    this.safeArea = true,
    this.backgroundColor = colors.black54,
    required ViewfinderThumbnailItemBuilder this.itemBuilder,
    this.semanticLabelBuilder,
  }) : selectedBorder = const Border.fromBorderSide(
         BorderSide(color: colors.white, width: 2),
       ),
       unselectedOpacity = 0.55,
       errorBuilder = null;

  /// Where the strip is anchored relative to the main viewer.
  final ViewfinderThumbnailPosition position;

  /// Tile edge length in logical pixels (square tiles).
  final double size;

  /// Gap between adjacent tiles in logical pixels.
  final double spacing;

  /// Internal content padding for the thumbnail strip. Combined with
  /// [safeArea] to produce the final inset.
  final EdgeInsets padding;

  /// When `true` (default), the outer edge of the strip respects the
  /// platform's safe-area inset — for example, a `.bottom` strip clears
  /// the iOS home indicator and a landscape notch on the sides. The
  /// [backgroundColor] still paints edge-to-edge through the inset.
  /// Set `false` to opt out and manage the inset yourself via [padding].
  final bool safeArea;

  /// Applied to the default tile only. Ignored when [itemBuilder] is
  /// provided — the builder owns the entire visual treatment.
  final Border selectedBorder;

  /// Applied to the default tile only. See [selectedBorder].
  final double unselectedOpacity;

  /// Background painted edge-to-edge behind the strip (including the
  /// safe-area inset when [safeArea] is true).
  final Color backgroundColor;

  /// Applied to the default tile only — fires when a thumbnail's
  /// [ImageProvider] fails to decode. Defaults to a neutral grey
  /// placeholder (a 12%-white `ColoredBox`) when null, which avoids
  /// the broken-image icon Flutter would otherwise render.
  /// Ignored when [itemBuilder] is provided — the builder owns the
  /// entire visual treatment, including error handling.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Optional fully custom tile builder. When provided, [selectedBorder]
  /// and [unselectedOpacity] are skipped — the builder receives the
  /// `selected` flag and renders the tile exactly as returned.
  final ViewfinderThumbnailItemBuilder? itemBuilder;

  /// Builds the screen-reader label for each tile. Defaults to
  /// `'Thumbnail ${index + 1}'` — supply your own for localization.
  /// Tiles are exposed as buttons with the selected state either way.
  final ViewfinderThumbnailSemanticLabelBuilder? semanticLabelBuilder;

  /// True when the strip lays out horizontally (top or bottom).
  bool get isHorizontal => switch (position) {
    .top || .bottom => true,
    .left || .right => false,
  };

  /// Strip thickness on its cross axis — tile [size] plus the padding
  /// stacked across the strip. Excludes any safe-area inset.
  double get crossExtent =>
      size + (isHorizontal ? padding.vertical : padding.horizontal);

  /// Identity tuple backing [==] and [hashCode] — one field list
  /// instead of two parallel ones (records compare and hash
  /// structurally).
  Object get _props => (
    position,
    size,
    spacing,
    padding,
    safeArea,
    selectedBorder,
    unselectedOpacity,
    backgroundColor,
    errorBuilder,
    itemBuilder,
    semanticLabelBuilder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderThumbnails && other._props == _props;

  @override
  int get hashCode => _props.hashCode;
}
