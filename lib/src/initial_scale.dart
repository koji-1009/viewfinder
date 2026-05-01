import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The starting scale applied to a `ViewfinderImage` before the user
/// interacts with it.
///
/// Construct via the [ViewfinderInitialScale.contain],
/// [ViewfinderInitialScale.cover], or [ViewfinderInitialScale.value]
/// factories. Each fit-based factory accepts an optional `factor`
/// multiplier — `contain(0.8)` shows the photo at 80% of the
/// fit-in-viewport size (leaving margin), `cover(1.2)` zooms to 120%
/// of the fill-viewport size. Consumers read [boxFit] and [baseScale];
/// the variant type itself is not part of the public surface.
@immutable
sealed class ViewfinderInitialScale {
  const ViewfinderInitialScale();

  /// Fit the content entirely inside the viewport (letter-boxing). Default.
  /// Optional [factor] multiplies the resulting scale: `contain(0.8)`
  /// shows the photo at 80% of fit, leaving margin around it.
  const factory ViewfinderInitialScale.contain([double factor]) = _Contain;

  /// Fill the viewport, cropping overflow. Optional [factor] multiplies
  /// the resulting scale: `cover(1.5)` zooms to 1.5× fill.
  const factory ViewfinderInitialScale.cover([double factor]) = _Cover;

  /// Explicit absolute scale relative to `BoxFit.contain`. Equivalent to
  /// [ViewfinderInitialScale.contain] with the same `factor`; kept as a
  /// shortcut for callers who want an absolute-multiplier reading
  /// (`value(2.0)` reads as "always 2×").
  const factory ViewfinderInitialScale.value(double scale) = _Contain;

  /// BoxFit used for the initial layout of the underlying `Image`.
  BoxFit get boxFit;

  /// Multiplier applied on top of [boxFit] for the initial transformation.
  double get baseScale;
}

class _Contain extends ViewfinderInitialScale {
  const _Contain([this.factor = 1.0]) : assert(factor > 0);
  final double factor;
  @override
  BoxFit get boxFit => BoxFit.contain;
  @override
  double get baseScale => factor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Contain && factor == other.factor;
  @override
  int get hashCode => Object.hash(_Contain, factor);
}

class _Cover extends ViewfinderInitialScale {
  const _Cover([this.factor = 1.0]) : assert(factor > 0);
  final double factor;
  @override
  BoxFit get boxFit => BoxFit.cover;
  @override
  double get baseScale => factor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Cover && factor == other.factor;
  @override
  int get hashCode => Object.hash(_Cover, factor);
}

/// Whether the view is at its initial scale or the user has zoomed in.
enum ViewfinderScaleState {
  /// At the initial scale supplied via [ViewfinderInitialScale].
  initial,

  /// Past the initial scale — the user has pinched / double-tapped /
  /// double-tap-dragged / mouse-wheel-zoomed in.
  zoomed,
}

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
