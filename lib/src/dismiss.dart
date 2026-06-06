import 'package:flutter/material.dart';

import 'viewfinder.dart' show Viewfinder;

/// Which axis a drag-to-dismiss gesture is accepted on.
enum ViewfinderDismissDirection {
  /// Accept either upward or downward drags.
  vertical,

  /// Accept only downward drags.
  down,

  /// Accept only upward drags.
  up,
}

/// What moves during a drag-to-dismiss gesture.
///
/// - [wholePage]: the entire gallery (thumbnails included) translates
///   together with the drag, and the background fades uniformly.
/// - [onlyImage]: only the paging photo area translates; thumbnails,
///   page indicator, and any chromeOverlays remain in place.
enum ViewfinderDismissSlideType {
  /// Translate the whole gallery (thumbnails + indicator + overlays)
  /// in step with the drag.
  wholePage,

  /// Translate only the paging photo area; chrome stays anchored.
  onlyImage,
}

/// Configures drag-to-dismiss for a [Viewfinder].
@immutable
class ViewfinderDismiss {
  /// Creates a drag-to-dismiss config. [onDismiss] is required and is
  /// invoked once the user releases a drag past [threshold].
  const ViewfinderDismiss({
    required this.onDismiss,
    this.direction = .vertical,
    this.threshold = 0.25,
    this.fadeBackground = true,
    this.backgroundColor = Colors.black,
    this.slideType = .wholePage,
    this.onProgress,
    this.onThresholdCrossed,
  });

  /// Invoked after the user releases past [threshold]. The widget itself
  /// does not pop the route or otherwise unmount — the callback owns that
  /// step. Failing to remove the widget here will leave the gallery in
  /// its dragged-out, partially translucent state.
  final VoidCallback onDismiss;

  /// Axis on which the drag-to-dismiss gesture is accepted.
  final ViewfinderDismissDirection direction;

  /// Fraction of the viewport height that triggers dismissal when released.
  final double threshold;

  /// If true, the [backgroundColor] fades as the user drags.
  final bool fadeBackground;

  /// The color shown behind the photo while it is being dragged. When
  /// [fadeBackground] is true, this color's alpha decreases as the user
  /// drags further from rest.
  final Color backgroundColor;

  /// Controls what moves during the drag.
  final ViewfinderDismissSlideType slideType;

  /// Called whenever the drag progress changes, with a normalized
  /// magnitude in `[0.0, 1.0]` (`0.0` = at rest, `1.0` = the user has
  /// dragged a full viewport in the dismiss direction). Fires on every
  /// drag update and on the post-release spring-back. Useful for
  /// fading custom chrome overlays in step with the gesture.
  final ValueChanged<double>? onProgress;

  /// Edge-triggered counterpart of [onProgress]: fires with `true`
  /// when the drag crosses [threshold] (releasing here would dismiss)
  /// and with `false` when it recedes back below — once per crossing,
  /// not per frame. The natural hook for a haptic tick
  /// (`HapticFeedback.selectionClick`) signalling "far enough".
  final ValueChanged<bool>? onThresholdCrossed;

  /// Identity tuple backing [==] and [hashCode] — one field list
  /// instead of two parallel ones (records compare and hash
  /// structurally).
  Object get _props => (
    onDismiss,
    direction,
    threshold,
    fadeBackground,
    backgroundColor,
    slideType,
    onProgress,
    onThresholdCrossed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewfinderDismiss && other._props == _props;

  @override
  int get hashCode => _props.hashCode;
}
