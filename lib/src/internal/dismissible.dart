import 'package:flutter/material.dart';

import '../dismiss.dart';

/// Wraps [child] with a drag-to-dismiss gesture. [enabled] should be false
/// while the child is zoomed so pans belong to the viewer, not the wrapper.
///
/// Internal — driven by `Viewfinder` based on its public
/// [ViewfinderDismiss] config.
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
          duration: const .new(milliseconds: 180),
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

  /// The single denominator for drag progress: the viewport height.
  /// The trigger threshold, [ViewfinderDismiss.onProgress], and the
  /// visual fade/translate must all divide by the same extent —
  /// `slideType: onlyImage` shrinks this widget's own render box (the
  /// thumbnail strip takes part of the column), so `context.size`
  /// would make the threshold diverge from the documented "fraction
  /// of viewport height" and from the visuals.
  double _viewportExtent() {
    final h = MediaQuery.sizeOf(context).height;
    return h <= 0 ? 0 : h;
  }

  void _reportProgress() {
    final cb = widget.config.onProgress;
    if (cb == null) return;
    final size = _viewportExtent();
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
    final size = _viewportExtent();
    final progress = size <= 0
        ? 0.0
        : (_dragOffset.abs() / size).clamp(0.0, 1.0);
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
        behavior: .opaque,
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
