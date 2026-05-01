import 'package:flutter/material.dart';

import 'viewfinder.dart' show Viewfinder;

/// Which axis a drag-to-dismiss gesture is accepted on.
enum ViewfinderDismissDirection { vertical, down, up }

/// What moves during a drag-to-dismiss gesture.
///
/// - [wholePage]: the entire gallery (thumbnails included) translates
///   together with the drag, and the background fades uniformly.
/// - [onlyImage]: only the paging photo area translates; thumbnails,
///   page indicator, and any chromeOverlays remain in place.
enum ViewfinderDismissSlideType { wholePage, onlyImage }

/// Configures drag-to-dismiss for a [Viewfinder].
@immutable
class ViewfinderDismiss {
  const ViewfinderDismiss({
    required this.onDismiss,
    this.direction = .vertical,
    this.threshold = 0.25,
    this.fadeBackground = true,
    this.backgroundColor = Colors.black,
    this.slideType = ViewfinderDismissSlideType.wholePage,
    this.onProgress,
  });

  /// Invoked after the user releases past [threshold]. The widget itself
  /// does not pop the route or otherwise unmount — the callback owns that
  /// step. Failing to remove the widget here will leave the gallery in
  /// its dragged-out, partially translucent state.
  final VoidCallback onDismiss;

  final ViewfinderDismissDirection direction;

  /// Fraction of the viewport height that triggers dismissal when released.
  final double threshold;

  /// If true, the [backgroundColor] fades as the user drags.
  final bool fadeBackground;

  final Color backgroundColor;

  /// Controls what moves during the drag.
  final ViewfinderDismissSlideType slideType;

  /// Called whenever the drag progress changes, with a normalized
  /// magnitude in `[0.0, 1.0]` (`0.0` = at rest, `1.0` = the user has
  /// dragged a full viewport in the dismiss direction). Fires on every
  /// drag update and on the post-release spring-back. Useful for
  /// fading custom chrome overlays in step with the gesture.
  final ValueChanged<double>? onProgress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderDismiss &&
          onDismiss == other.onDismiss &&
          direction == other.direction &&
          threshold == other.threshold &&
          fadeBackground == other.fadeBackground &&
          backgroundColor == other.backgroundColor &&
          slideType == other.slideType &&
          onProgress == other.onProgress;

  @override
  int get hashCode => Object.hash(
    onDismiss,
    direction,
    threshold,
    fadeBackground,
    backgroundColor,
    slideType,
    onProgress,
  );
}

