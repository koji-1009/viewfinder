import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The starting scale applied to a `ViewfinderImage` before the user
/// interacts with it.
///
/// Sealed: pattern-match on the variant ([ViewfinderInitialScaleContain],
/// [ViewfinderInitialScaleCover], [ViewfinderInitialScaleValue]) when you
/// need to discriminate between presets and explicit scales.
@immutable
sealed class ViewfinderInitialScale {
  const ViewfinderInitialScale();

  /// Fit the content entirely inside the viewport (letter-boxing). Default.
  const factory ViewfinderInitialScale.contain() = ViewfinderInitialScaleContain;

  /// Fill the viewport, cropping overflow.
  const factory ViewfinderInitialScale.cover() = ViewfinderInitialScaleCover;

  /// Explicit scale. 1.0 = fit, 2.0 = 2× fit, …
  const factory ViewfinderInitialScale.value(double scale) =
      ViewfinderInitialScaleValue;

  /// BoxFit used for the initial layout of the underlying `Image`.
  BoxFit get boxFit;

  /// Multiplier applied on top of [boxFit] for the initial transformation.
  double get baseScale;
}

/// Letter-box variant. Canonical const singleton.
final class ViewfinderInitialScaleContain extends ViewfinderInitialScale {
  const ViewfinderInitialScaleContain();
  @override
  BoxFit get boxFit => BoxFit.contain;
  @override
  double get baseScale => 1.0;
}

/// Crop-to-fill variant. Canonical const singleton.
final class ViewfinderInitialScaleCover extends ViewfinderInitialScale {
  const ViewfinderInitialScaleCover();
  @override
  BoxFit get boxFit => BoxFit.cover;
  @override
  double get baseScale => 1.0;
}

/// Explicit-scale variant.
final class ViewfinderInitialScaleValue extends ViewfinderInitialScale {
  const ViewfinderInitialScaleValue(this.scale) : assert(scale > 0);
  final double scale;
  @override
  BoxFit get boxFit => BoxFit.contain;
  @override
  double get baseScale => scale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderInitialScaleValue && scale == other.scale;
  @override
  int get hashCode => Object.hash(ViewfinderInitialScaleValue, scale);
}

/// Whether the view is at its initial scale or the user has zoomed in.
enum ViewfinderScaleState { initial, zoomed }

/// Pick the next scale for a double-tap given a ladder of [scales].
///
/// The list is walked forward until a step is found that is meaningfully
/// larger than [currentScale]; if none is found, the first step is
/// returned (cycle wrap). An empty list disables the behavior by
/// returning [currentScale] unchanged.
///
/// - `[]` — disabled
/// - `[1, 2.5]` — toggle between 1× and 2.5×
/// - `[1, 2.5, 5]` — cycle through three stops
double nextDoubleTapScale({
  required List<double> scales,
  required double currentScale,
}) {
  if (scales.isEmpty) return currentScale;
  const epsilon = 0.01;
  for (final s in scales) {
    if (currentScale < s - epsilon) return s;
  }
  return scales.first;
}
