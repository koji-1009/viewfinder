import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../dismiss.dart';

/// Vertical drag that yields to a pinch: a second pointer arriving
/// before acceptance rejects the gesture, handing both pointers to
/// the scale recognizer. The stock recognizer tracks every pointer
/// and would win the arena off the first finger's drift (its
/// touch-slop is half the scale recognizer's pan-slop), making
/// pinches land as dismiss drags.
class _SingleTouchVerticalDragRecognizer extends VerticalDragGestureRecognizer {
  _SingleTouchVerticalDragRecognizer({super.debugOwner});

  int _pointers = 0;
  bool _accepted = false;

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers++;
    if (_pointers > 1 && !_accepted) {
      resolve(GestureDisposition.rejected);
      return;
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointers = 0;
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

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
  bool _pastThreshold = false;
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
  void didUpdateWidget(covariant ViewfinderDismissible oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Disabling mid-drag tears down the recognizer without firing
    // onEnd; spring back so the gallery doesn't stay translated.
    if (!widget.enabled &&
        oldWidget.enabled &&
        _dragOffset != 0 &&
        !_release.isAnimating) {
      _release.forward(from: 0);
    }
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

  /// Normalized drag progress in `[0, 1]`. The denominator is the
  /// viewport height: the trigger threshold,
  /// [ViewfinderDismiss.onProgress], and the visual fade/translate
  /// must all divide by the same extent — `slideType: onlyImage`
  /// shrinks this widget's own render box (the thumbnail strip takes
  /// part of the column), so `context.size` would make the threshold
  /// diverge from the documented "fraction of viewport height" and
  /// from the visuals.
  double _dragProgress() {
    final size = MediaQuery.sizeOf(context).height;
    return size <= 0 ? 0.0 : (_dragOffset.abs() / size).clamp(0.0, 1.0);
  }

  void _reportProgress() {
    final progress = _dragProgress();
    // Edge-triggered threshold signal (haptics hook) — fires once per
    // crossing in each direction, including during spring-back.
    final past = progress >= widget.config.threshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      widget.config.onThresholdCrossed?.call(past);
    }
    final cb = widget.config.onProgress;
    if (cb == null) return;
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
    if (_dragProgress() >= widget.config.threshold) {
      // Re-arm the threshold signal: when onDismiss keeps the widget
      // mounted, the next drag must be able to fire it again.
      _pastThreshold = false;
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
      child: RawGestureDetector(
        behavior: .opaque,
        gestures: <Type, GestureRecognizerFactory>{
          if (widget.enabled)
            _SingleTouchVerticalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _SingleTouchVerticalDragRecognizer
                >(() => _SingleTouchVerticalDragRecognizer(debugOwner: this), (
                  r,
                ) {
                  r
                    ..onUpdate = _handleDragUpdate
                    ..onEnd = _handleDragEnd;
                }),
        },
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
