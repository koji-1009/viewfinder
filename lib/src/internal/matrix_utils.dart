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

/// Rotation angle of [m]'s 2D linear part, in radians.
double rotationOf(Matrix4 m) => math.atan2(m.storage[1], m.storage[0]);

/// Returns [base] rotated by [radians] around [focal] (in local
/// coordinates of the viewport).
Matrix4 rotateAroundFocal({
  required Matrix4 base,
  required Offset focal,
  required double radians,
}) {
  return Matrix4.identity()
    ..translateByDouble(focal.dx, focal.dy, 0, 1)
    ..rotateZ(radians)
    ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
    ..multiply(base);
}

/// Splits a scroll delta into the components along and across [axis].
({double along, double cross}) splitScrollDelta(Offset delta, Axis axis) =>
    axis == Axis.horizontal
    ? (along: delta.dx, cross: delta.dy)
    : (along: delta.dy, cross: delta.dx);

/// Applies the 2D portion of [m] to point [p].
Offset applyMatrix2D(Matrix4 m, Offset p) {
  final v = m.storage;
  return Offset(
    v[0] * p.dx + v[4] * p.dy + v[12],
    v[1] * p.dx + v[5] * p.dy + v[13],
  );
}

/// Axis-aligned bounding box on screen for a 0..[viewport].width by
/// 0..[viewport].height rect transformed by [m]. Correct under
/// rotation, since the bbox is computed from all four projected corners.
({double minX, double maxX, double minY, double maxY}) contentBbox(
  Matrix4 m,
  Size viewport,
) {
  // Unrolled into locals: this runs per frame during gestures and
  // animations (translation clamp + swipe-gate derivation), so no
  // per-call allocation.
  final v = m.storage;
  final w = viewport.width;
  final h = viewport.height;
  final x0 = v[12], y0 = v[13]; // (0, 0)
  final x1 = v[0] * w + v[12], y1 = v[1] * w + v[13]; // (w, 0)
  final x2 = v[4] * h + v[12], y2 = v[5] * h + v[13]; // (0, h)
  final x3 = v[0] * w + v[4] * h + v[12]; // (w, h)
  final y3 = v[1] * w + v[5] * h + v[13];
  return (
    minX: math.min(math.min(x0, x1), math.min(x2, x3)),
    maxX: math.max(math.max(x0, x1), math.max(x2, x3)),
    minY: math.min(math.min(y0, y1), math.min(y2, y3)),
    maxY: math.max(math.max(y0, y1), math.max(y2, y3)),
  );
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
