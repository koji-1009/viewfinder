import 'package:flutter/widgets.dart';

/// Returns a [Matrix4] that scales by [scale] centered on [focal]
/// (in local coordinates of the viewport).
Matrix4 scaleAroundFocal({required Offset focal, required double scale}) {
  return Matrix4.identity()
    ..translateByDouble(focal.dx, focal.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
}
