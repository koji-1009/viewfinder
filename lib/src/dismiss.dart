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
    this.direction = ViewfinderDismissDirection.vertical,
    this.threshold = 0.25,
    this.fadeBackground = true,
    this.backgroundColor = Colors.black,
    this.slideType = ViewfinderDismissSlideType.wholePage,
    this.onProgress,
  });

  /// Invoked after the user releases past [threshold].
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
}

/// Wraps [child] with a drag-to-dismiss gesture. [enabled] should be false
/// while the child is zoomed so pans belong to the viewer, not the wrapper.
class ViewfinderDismissible extends StatefulWidget {
  const ViewfinderDismissible({
    super.key,
    required this.config,
    required this.enabled,
    required this.child,
  });

  final ViewfinderDismiss config;
  final bool enabled;
  final Widget child;

  @override
  State<ViewfinderDismissible> createState() => _ViewfinderDismissibleState();
}

class _ViewfinderDismissibleState extends State<ViewfinderDismissible>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  double _lastReportedProgress = 0.0;
  late final AnimationController _release;

  @override
  void initState() {
    super.initState();
    _release =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
        )..addListener(() {
          setState(() => _dragOffset *= 1 - _release.value);
          _reportProgress();
        });
  }

  @override
  void dispose() {
    _release.dispose();
    super.dispose();
  }

  bool _acceptsDelta(double dy) => switch (widget.config.direction) {
    .vertical => true,
    .down => dy > 0 || _dragOffset > 0,
    .up => dy < 0 || _dragOffset < 0,
  };

  void _reportProgress() {
    final cb = widget.config.onProgress;
    if (cb == null) return;
    final size = context.size?.height ?? 0;
    final progress = size <= 0
        ? 0.0
        : (_dragOffset.abs() / size).clamp(0.0, 1.0);
    if ((progress - _lastReportedProgress).abs() < 1e-4) return;
    _lastReportedProgress = progress;
    cb(progress);
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    if (!_acceptsDelta(d.delta.dy)) return;
    setState(() => _dragOffset += d.delta.dy);
    _reportProgress();
  }

  void _handleDragEnd(DragEndDetails _) {
    final size = context.size?.height ?? 1;
    final progress = (_dragOffset.abs() / size).clamp(0.0, 1.0);
    if (progress >= widget.config.threshold) {
      widget.config.onDismiss();
    } else {
      _release.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final progress = (_dragOffset.abs() / (size.height == 0 ? 1 : size.height))
        .clamp(0.0, 1.0);

    final bg = widget.config.fadeBackground
        ? widget.config.backgroundColor.withValues(
            alpha: 1.0 - progress.clamp(0.0, 0.7),
          )
        : widget.config.backgroundColor;

    return ColoredBox(
      color: bg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: widget.enabled ? _handleDragUpdate : null,
        onVerticalDragEnd: widget.enabled ? _handleDragEnd : null,
        child: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Opacity(
            opacity: (1.0 - progress * 0.3).clamp(0.3, 1.0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
