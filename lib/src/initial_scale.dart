import 'package:flutter/painting.dart';

/// The starting scale applied to a `ViewfinderImage` before the user
/// interacts with it.
sealed class ViewfinderInitialScale {
  const ViewfinderInitialScale();

  /// Fit the content entirely inside the viewport (letter-boxing). Default.
  const factory ViewfinderInitialScale.contain() = _Contain;

  /// Fill the viewport, cropping overflow.
  const factory ViewfinderInitialScale.cover() = _Cover;

  /// Explicit scale. 1.0 = fit, 2.0 = 2× fit, …
  const factory ViewfinderInitialScale.value(double scale) = _ValueScale;

  /// BoxFit used for the initial layout of the underlying `Image`.
  BoxFit get boxFit;

  /// Multiplier applied on top of [boxFit] for the initial transformation.
  double get baseScale;
}

class _Contain extends ViewfinderInitialScale {
  const _Contain();
  @override
  BoxFit get boxFit => BoxFit.contain;
  @override
  double get baseScale => 1.0;
}

class _Cover extends ViewfinderInitialScale {
  const _Cover();
  @override
  BoxFit get boxFit => BoxFit.cover;
  @override
  double get baseScale => 1.0;
}

class _ValueScale extends ViewfinderInitialScale {
  const _ValueScale(this.scale) : assert(scale > 0);
  final double scale;
  @override
  BoxFit get boxFit => BoxFit.contain;
  @override
  double get baseScale => scale;
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
