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
  final corners = <Offset>[
    applyMatrix2D(m, Offset.zero),
    applyMatrix2D(m, Offset(viewport.width, 0)),
    applyMatrix2D(m, Offset(0, viewport.height)),
    applyMatrix2D(m, Offset(viewport.width, viewport.height)),
  ];
  var minX = corners.first.dx;
  var maxX = corners.first.dx;
  var minY = corners.first.dy;
  var maxY = corners.first.dy;
  for (final p in corners.skip(1)) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return (minX: minX, maxX: maxX, minY: minY, maxY: maxY);
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
