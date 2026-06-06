import 'package:flutter/widgets.dart';

/// How the viewer should treat a single-pointer pan once its dominant
/// direction is known.
enum ViewfinderPanVerdict {
  /// Hand the pointer to the gesture arena so an ancestor scrollable
  /// (e.g. a [PageView]) can claim the drag.
  release,

  /// Stay in the arena under normal acceptance rules; other
  /// recognizers may still win.
  compete,

  /// Claim the arena immediately, before ancestor recognizers accept.
  claim,
}

/// Decides the verdict for a pan whose finger moves toward [direction].
typedef ViewfinderPanGate =
    ViewfinderPanVerdict Function(AxisDirection direction);
