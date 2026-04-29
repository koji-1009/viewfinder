import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Returns a [Matrix4] that scales by [scale] centered on [focal]
/// (in local coordinates of the viewport).
Matrix4 scaleAroundFocal({required Offset focal, required double scale}) {
  return Matrix4.identity()
    ..translateByDouble(focal.dx, focal.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
}

/// 2D scale factor of [m], derived from the X column length.
///
/// Use this instead of [Matrix4.getMaxScaleOnAxis] for the photo
/// viewer's clamps and external scale reporting. The view's matrices
/// are built with `scaleByDouble(s, s, 1, 1)` (Z = 1 always), so when
/// the user pinches the X/Y scale below 1, [Matrix4.getMaxScaleOnAxis]
/// returns 1 (Z dominates), masking the shrink and breaking the
/// `minScale` clamp.
///
/// Rotation is folded into X/Y but preserves the column length, so
/// taking the X column's magnitude gives the uniform 2D scale
/// regardless of rotation.
double xyScale(Matrix4 m) {
  final s = m.storage;
  return math.sqrt(s[0] * s[0] + s[1] * s[1] + s[2] * s[2]);
}
