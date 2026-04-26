import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Callback fired when panning hits a boundary.
///
/// [axis] is the axis along which the pan was clamped. [sign] is +1 when
/// the pan would have moved content in the positive direction (i.e., the
/// user is pulling content past the right / bottom edge) and -1 for the
/// opposite. Used by the gallery to let [PageView] take over the drag.
typedef ZoomableEdgeCallback = void Function(Axis axis, int sign);

/// Gate called by the arena-aware gesture recognizer to decide whether a
/// pan in the given direction should be consumed. Returning `false`
/// yields the pointer to the arena so an ancestor scroll view can claim
/// the drag.
typedef ZoomableCanPan = bool Function(Axis axis, int sign);

/// Default friction coefficient for post-release fling.
///
/// `0.0000135` is tuned for a smooth, gradual deceleration on a zoomed
/// photo — expressed as the fraction of the initial velocity retained
/// per second, so smaller means more aggressive deceleration.
///
/// Exposed through [ZoomableViewport.interactionEndFrictionCoefficient].
/// Callers that prefer a snappier feel can override with a higher
/// value (e.g. `0.135` for iOS-scroll-style, `0.015` for
/// Android-scroll-style deceleration).
const double kViewfinderDefaultFlingDrag = 0.0000135;

/// Continuous double-tap-drag zoom sensitivity: pixels of vertical drag
/// that correspond to 1× scale change.
const double _kDoubleTapDragPixelsPerUnit = 150.0;

/// The zoom-and-pan surface that backs the photo viewer.
///
/// - Focal-preserving pinch/pan/rotate via a custom
///   [_ArenaAwareScaleRecognizer] that yields horizontal drags back to
///   the gesture arena (so a parent [PageView] can take over) when the
///   image is already against the relevant edge.
/// - Double-tap-drag continuous zoom (iOS Photos style) via
///   [_DoubleTapDragRecognizer].
/// - Rotated-bbox-aware translation clamping.
/// - Post-release fling driven by Flutter's [FrictionSimulation].
class ZoomableViewport extends StatefulWidget {
  const ZoomableViewport({
    super.key,
    required this.child,
    required this.transformationController,
    this.minScale = 1.0,
    this.maxScale = 8.0,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.rotateEnabled = false,
    this.clipBehavior = Clip.none,
    this.onEdgeHit,
    this.canPan,
    this.fling = true,
    this.doubleTapDragZoom = true,
    this.interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    this.enableMouseWheelZoom = true,
  }) : assert(interactionEndFrictionCoefficient > 0);

  final Widget child;
  final TransformationController transformationController;
  final double minScale;
  final double maxScale;
  final bool panEnabled;
  final bool scaleEnabled;
  final bool rotateEnabled;
  final Clip clipBehavior;

  /// Fired on each frame where a pan hits a boundary.
  final ZoomableEdgeCallback? onEdgeHit;

  /// When supplied, a single-pointer pan in a direction that would
  /// exceed the image's edge on the detected axis is rejected before
  /// this widget claims the gesture arena, letting an ancestor scroll
  /// view (e.g. [PageView]) pick it up.
  ///
  /// The callback is consulted per axis: returning `false` for
  /// `(Axis.horizontal, 1)` means a finger moving right into a blocked
  /// state should yield.
  final ZoomableCanPan? canPan;

  /// When true, scale-end with residual velocity produces a
  /// boundary-clamped fling animation.
  final bool fling;

  /// When true, a double-tap followed by a vertical drag (without
  /// releasing) continuously scales around the first tap location —
  /// the standard iOS Photos "magic tap" gesture.
  final bool doubleTapDragZoom;

  /// Drag coefficient passed to [FrictionSimulation] for the
  /// post-release fling animation. Higher values decelerate more
  /// quickly. See [kViewfinderDefaultFlingDrag] for the default.
  final double interactionEndFrictionCoefficient;

  /// Whether mouse scroll wheel events should zoom around the pointer
  /// location. Defaults to `true` because the enclosing gallery is
  /// typically a full-screen photo viewer; callers embedding
  /// [ZoomableViewport] in a scrollable page can disable it to let
  /// wheel events bubble.
  final bool enableMouseWheelZoom;

  @override
  State<ZoomableViewport> createState() => _ZoomableViewportState();
}

class _ZoomableViewportState extends State<ZoomableViewport>
    with TickerProviderStateMixin {
  // Gesture-start snapshot for scale/pan/rotate.
  Matrix4 _startMatrix = Matrix4.identity();
  Offset _startFocalViewport = Offset.zero;
  bool _inGesture = false;

  // Double-tap-drag snapshot.
  Matrix4? _dtdStartMatrix;
  Offset _dtdFocal = Offset.zero;
  Offset _dtdStartDragPoint = Offset.zero;

  // Viewport size captured by LayoutBuilder.
  Size _viewport = Size.zero;

  // Fling.
  late final AnimationController _flingController;
  _FlingRunner? _runner;

  // Rubber-band snap-back.
  late final AnimationController _snapBackController;
  Matrix4Tween? _snapBackTween;

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSnapBackTick);
  }

  @override
  void dispose() {
    _flingController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  void _onFlingTick() {
    final runner = _runner;
    if (runner == null) return;
    final t = _flingController.value;
    // Allow elastic over-pan during fling: when the fling simulation
    // carries the matrix past an edge, the displayed translation
    // approaches the viewport-dim asymptote with the rubber-band
    // function rather than snapping flat against the edge. The
    // simulation's raw position keeps decelerating; once it's done,
    // [_snapBackIfOverPan] springs whatever over-pan remains back to
    // the strict-clamp position.
    final m = _clampMatrix(runner.matrixAt(t), elastic: true);
    widget.transformationController.value = m;
    if (runner.isDoneAt(t)) {
      _flingController.stop();
      _runner = null;
      _snapBackIfOverPan();
    }
  }

  void _stopFling() {
    if (_flingController.isAnimating) {
      _flingController.stop();
    }
    _runner = null;
  }

  void _onSnapBackTick() {
    final tween = _snapBackTween;
    if (tween == null) return;
    final t = Curves.easeOutCubic.transform(_snapBackController.value);
    widget.transformationController.value = tween.transform(t);
    if (_snapBackController.isCompleted) {
      _snapBackTween = null;
    }
  }

  void _stopSnapBack() {
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }
    _snapBackTween = null;
  }

  /// If the current matrix sits in rubber-band over-pan territory,
  /// animate it back to the strict-clamp position.
  void _snapBackIfOverPan() {
    final current = widget.transformationController.value;
    final clamped = _clampMatrix(current);
    final dx = (clamped.storage[12] - current.storage[12]).abs();
    final dy = (clamped.storage[13] - current.storage[13]).abs();
    if (dx < 0.5 && dy < 0.5) return;
    _snapBackTween = Matrix4Tween(begin: current.clone(), end: clamped);
    _snapBackController
      ..reset()
      ..forward();
  }

  // ---------------- pinch / pan / rotate ---------------- //

  void _onScaleStart(ScaleStartDetails d) {
    _stopFling();
    _stopSnapBack();
    _startMatrix = widget.transformationController.value.clone();
    _startFocalViewport = d.localFocalPoint;
    _inGesture = true;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_inGesture) return;

    final focalCurrent = d.localFocalPoint;
    final scale = widget.scaleEnabled ? d.scale : 1.0;
    final rotation = widget.rotateEnabled ? d.rotation : 0.0;

    // Delta = T(focalCurrent) · R(rotation) · S(scale) · T(-focalStart)
    //
    // Pinning the scene point the user grabbed at gesture start to the
    // live focal position, while applying cumulative scale/rotation
    // around that same grabbed point.
    Matrix4 buildDelta(double effectiveScale) {
      final tx = widget.panEnabled ? focalCurrent.dx : _startFocalViewport.dx;
      final ty = widget.panEnabled ? focalCurrent.dy : _startFocalViewport.dy;
      return Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..rotateZ(rotation)
        ..scaleByDouble(effectiveScale, effectiveScale, 1, 1)
        ..translateByDouble(
          -_startFocalViewport.dx,
          -_startFocalViewport.dy,
          0,
          1,
        );
    }

    var next = buildDelta(scale).multiplied(_startMatrix);

    // Clamp scale.
    final actualScale = next.getMaxScaleOnAxis();
    if (actualScale < widget.minScale || actualScale > widget.maxScale) {
      final target = actualScale.clamp(widget.minScale, widget.maxScale);
      next = buildDelta(scale * target / actualScale).multiplied(_startMatrix);
    }

    widget.transformationController.value = _clampMatrix(
      next,
      reportEdge: true,
      elastic: true,
    );
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _inGesture = false;
    if (!widget.fling) {
      _snapBackIfOverPan();
      return;
    }
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < kMinFlingVelocity) {
      _snapBackIfOverPan();
      return;
    }
    final m = widget.transformationController.value;
    if (m.getMaxScaleOnAxis() <= 1.01) {
      _snapBackIfOverPan();
      return;
    }
    _startFling(m, v);
  }

  void _startFling(Matrix4 from, Offset velocity) {
    final start = from.clone();
    final runner = _FlingRunner(
      startMatrix: start,
      position: Offset(start.storage[12], start.storage[13]),
      velocity: velocity,
      drag: widget.interactionEndFrictionCoefficient,
    );
    _runner = runner;
    _flingController
      ..stop()
      ..animateWith(_FlingTimeDriver(runner.simX, runner.simY));
  }

  // ---------------- double-tap-drag ---------------- //

  void _onDoubleTapDragStart(Offset localPosition) {
    _stopFling();
    _stopSnapBack();
    _dtdStartMatrix = widget.transformationController.value.clone();
    _dtdFocal = localPosition;
    _dtdStartDragPoint = localPosition;
  }

  void _onDoubleTapDragUpdate(Offset localPosition) {
    final start = _dtdStartMatrix;
    if (start == null) return;
    final dy = localPosition.dy - _dtdStartDragPoint.dy;
    // Down = zoom in, up = zoom out.
    final factor = math.pow(2.0, -dy / _kDoubleTapDragPixelsPerUnit).toDouble();
    final currentScaleAtStart = start.getMaxScaleOnAxis();
    final targetScale = (currentScaleAtStart * factor).clamp(
      widget.minScale,
      widget.maxScale,
    );
    final effective = targetScale / currentScaleAtStart;

    final delta = Matrix4.identity()
      ..translateByDouble(_dtdFocal.dx, _dtdFocal.dy, 0, 1)
      ..scaleByDouble(effective, effective, 1, 1)
      ..translateByDouble(-_dtdFocal.dx, -_dtdFocal.dy, 0, 1);

    widget.transformationController.value = _clampMatrix(
      delta.multiplied(start),
    );
  }

  void _onDoubleTapDragEnd() {
    _dtdStartMatrix = null;
  }

  // ---------------- mouse wheel ---------------- //

  /// Pixels of scroll wheel deltaY that correspond to a 1× scale change.
  /// Chosen so typical mouse wheels zoom in/out at a comfortable pace.
  static const double _kMouseWheelPixelsPerUnit = 200.0;

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableMouseWheelZoom) return;
    if (event is! PointerScrollEvent) return;
    if (!widget.scaleEnabled) return;

    _stopFling();
    _stopSnapBack();
    final focal = event.localPosition;
    final start = widget.transformationController.value;
    final currentScale = start.getMaxScaleOnAxis();
    final factor = math
        .pow(2.0, -event.scrollDelta.dy / _kMouseWheelPixelsPerUnit)
        .toDouble();
    final targetScale = (currentScale * factor).clamp(
      widget.minScale,
      widget.maxScale,
    );
    if ((targetScale - currentScale).abs() < 1e-6) return;
    final effective = targetScale / currentScale;
    final delta = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(effective, effective, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
    widget.transformationController.value = _clampMatrix(
      delta.multiplied(start),
    );
    // Consume so scrollables above us don't also handle it.
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {});
  }

  // ---------------- clamping ---------------- //

  /// Standard iOS rubber-band coefficient: at the edge, the user moves
  /// the content by ~`c × delta` for small `delta`, with diminishing
  /// returns as `delta → ∞`.
  static const double _kRubberBandCoefficient = 0.55;

  /// Maps a raw over-pan distance to the elastic displacement actually
  /// shown on screen. The asymptote is the viewport dimension, so the
  /// content can never be pulled fully off-screen.
  static double _rubberBand(double rawOverPan, double viewportDim) {
    if (rawOverPan <= 0 || viewportDim <= 0) return 0;
    return (1 - 1 / (rawOverPan * _kRubberBandCoefficient / viewportDim + 1)) *
        viewportDim;
  }

  Matrix4 _clampMatrix(
    Matrix4 m, {
    bool reportEdge = false,
    bool elastic = false,
  }) {
    if (_viewport.isEmpty) return m;

    // Compute the axis-aligned bounding box of the transformed content
    // (which is originally a 0..viewport.width × 0..viewport.height rect).
    final corners = <Offset>[
      _apply(m, Offset.zero),
      _apply(m, Offset(_viewport.width, 0)),
      _apply(m, Offset(0, _viewport.height)),
      _apply(m, Offset(_viewport.width, _viewport.height)),
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
    final bboxW = maxX - minX;
    final bboxH = maxY - minY;

    double dx = 0;
    double dy = 0;

    if (bboxW <= _viewport.width) {
      // Content horizontally smaller than viewport → center it.
      final targetMin = (_viewport.width - bboxW) / 2;
      dx = targetMin - minX;
    } else {
      // Allow bbox to span full width; nudge back when off-edge.
      if (minX > 0) {
        // Content's left has been pulled past the viewport's left.
        dx = elastic ? -minX + _rubberBand(minX, _viewport.width) : -minX;
        if (reportEdge) widget.onEdgeHit?.call(Axis.horizontal, -1);
      } else if (maxX < _viewport.width) {
        // Content's right has been pulled past the viewport's right.
        final overshoot = _viewport.width - maxX;
        dx = elastic
            ? overshoot - _rubberBand(overshoot, _viewport.width)
            : overshoot;
        if (reportEdge) widget.onEdgeHit?.call(Axis.horizontal, 1);
      }
    }

    if (bboxH <= _viewport.height) {
      final targetMin = (_viewport.height - bboxH) / 2;
      dy = targetMin - minY;
    } else {
      if (minY > 0) {
        dy = elastic ? -minY + _rubberBand(minY, _viewport.height) : -minY;
        if (reportEdge) widget.onEdgeHit?.call(Axis.vertical, -1);
      } else if (maxY < _viewport.height) {
        final overshoot = _viewport.height - maxY;
        dy = elastic
            ? overshoot - _rubberBand(overshoot, _viewport.height)
            : overshoot;
        if (reportEdge) widget.onEdgeHit?.call(Axis.vertical, 1);
      }
    }

    if (dx == 0 && dy == 0) return m;
    final out = m.clone();
    out.storage[12] += dx;
    out.storage[13] += dy;
    return out;
  }

  Offset _apply(Matrix4 m, Offset p) {
    final v = m.storage;
    return Offset(
      v[0] * p.dx + v[4] * p.dy + v[12],
      v[1] * p.dx + v[5] * p.dy + v[13],
    );
  }

  // ---------------- gestures plumbing ---------------- //

  bool _canPanAt(Axis axis, int sign) {
    final gate = widget.canPan;
    if (gate == null) return true;
    return gate(axis, sign);
  }

  Map<Type, GestureRecognizerFactory> _buildGestures() {
    // Registration order is also arena priority. Put double-tap-drag
    // FIRST so that, when a user has double-tapped and begun dragging,
    // it wins the pointer over the single-pointer pan path of
    // ScaleGestureRecognizer.
    return <Type, GestureRecognizerFactory>{
      if (widget.doubleTapDragZoom && widget.scaleEnabled)
        _DoubleTapDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_DoubleTapDragRecognizer>(
              () => _DoubleTapDragRecognizer(debugOwner: this),
              (r) {
                r
                  ..onDragStart = _onDoubleTapDragStart
                  ..onDragUpdate = _onDoubleTapDragUpdate
                  ..onDragEnd = _onDoubleTapDragEnd;
              },
            ),
      _ArenaAwareScaleRecognizer:
          GestureRecognizerFactoryWithHandlers<_ArenaAwareScaleRecognizer>(
            () => _ArenaAwareScaleRecognizer(
              debugOwner: this,
              canPanAt: _canPanAt,
            ),
            (r) {
              r
                ..onStart = _onScaleStart
                ..onUpdate = _onScaleUpdate
                ..onEnd = _onScaleEnd;
            },
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _viewport) _viewport = size;
        return ClipRect(
          clipBehavior: widget.clipBehavior,
          child: Listener(
            onPointerSignal: widget.enableMouseWheelZoom
                ? _onPointerSignal
                : null,
            child: RawGestureDetector(
              gestures: _buildGestures(),
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: widget.transformationController,
                builder: (_, child) => Transform(
                  transform: widget.transformationController.value,
                  alignment: Alignment.topLeft,
                  child: child,
                ),
                child: SizedBox.fromSize(size: size, child: widget.child),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Arena-aware scale recognizer.
//
// Behaves like [ScaleGestureRecognizer] but, once direction is resolvable,
// if [canPanHorizontallyAt] reports horizontal movement in the detected
// direction is not allowed (e.g. image already at edge, parent PageView
// should take over), stops tracking the pointer so it falls through to
// the next arena candidate.
// ---------------------------------------------------------------------------

class _ArenaAwareScaleRecognizer extends ScaleGestureRecognizer {
  _ArenaAwareScaleRecognizer({super.debugOwner, required this.canPanAt})
    : super(
        // Trackpad two-finger-swipe should zoom (matches macOS / web
        // photo-viewer expectation).
        trackpadScrollCausesScale: true,
        supportedDevices: const <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
      );

  final ZoomableCanPan canPanAt;

  final Map<int, _TrackedPointer> _tracked = <int, _TrackedPointer>{};
  bool _resolved = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _tracked[event.pointer] = _TrackedPointer(
      startPosition: event.localPosition,
      kind: event.kind,
    );
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_resolved && event is PointerMoveEvent && _tracked.length == 1) {
      final tp = _tracked[event.pointer];
      if (tp != null) {
        final delta = event.localPosition - tp.startPosition;
        final slop = computeHitSlop(tp.kind, gestureSettings);
        if (delta.distance > slop) {
          _resolved = true;
          // Flutter's own convention: strict dominance (no weighting).
          // Strict axis dominance: test the axis that moved more, and
          // yield the pointer if the gate says that direction isn't
          // consumable (image at edge, parent scroller should win).
          if (delta.dx.abs() > delta.dy.abs()) {
            final sign = delta.dx >= 0 ? 1 : -1;
            if (!canPanAt(Axis.horizontal, sign)) {
              resolvePointer(event.pointer, GestureDisposition.rejected);
              stopTrackingPointer(event.pointer);
              _tracked.remove(event.pointer);
              return;
            }
          } else if (delta.dy.abs() > delta.dx.abs()) {
            final sign = delta.dy >= 0 ? 1 : -1;
            if (!canPanAt(Axis.vertical, sign)) {
              resolvePointer(event.pointer, GestureDisposition.rejected);
              stopTrackingPointer(event.pointer);
              _tracked.remove(event.pointer);
              return;
            }
          }
        }
      }
    }
    super.handleEvent(event);
  }

  @override
  void rejectGesture(int pointer) {
    _tracked.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracked.clear();
    _resolved = false;
    super.didStopTrackingLastPointer(pointer);
  }
}

class _TrackedPointer {
  _TrackedPointer({required this.startPosition, required this.kind});
  final Offset startPosition;
  final PointerDeviceKind kind;
}

// ---------------------------------------------------------------------------
// Double-tap-drag recognizer.
//
// State machine: idle → tap1Down → tap1Up (within double-tap window) →
// tap2Down (within double-tap window) → dragging.  Once dragging, every
// pointer move is forwarded to [onDragUpdate] until release.
//
// Semantics match iOS Photos: double-tap and hold, then slide the finger
// up or down to zoom continuously.
// ---------------------------------------------------------------------------

typedef _DoubleTapDragStart = void Function(Offset localPosition);
typedef _DoubleTapDragUpdate = void Function(Offset localPosition);
typedef _DoubleTapDragEnd = void Function();

const _kDoubleTapSlop = 100.0;
const _kDoubleTapWindow = Duration(milliseconds: 300);

class _DoubleTapDragRecognizer extends OneSequenceGestureRecognizer {
  _DoubleTapDragRecognizer({super.debugOwner});

  _DoubleTapDragStart? onDragStart;
  _DoubleTapDragUpdate? onDragUpdate;
  _DoubleTapDragEnd? onDragEnd;

  _State _state = _State.idle;
  Offset? _firstTapPosition;
  Duration? _firstTapUpTimestamp;
  Offset? _secondTapStart;
  int? _activePointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_state == _State.idle) {
      _state = _State.tap1Down;
      _firstTapPosition = event.localPosition;
      _activePointer = event.pointer;
      startTrackingPointer(event.pointer, event.transform);
    } else if (_state == _State.tap1Up) {
      // Use the pointer event's own timeStamp so we're not subject to
      // system clock skew or fake-async in tests.
      final elapsed = event.timeStamp - _firstTapUpTimestamp!;
      final drift = (event.localPosition - _firstTapPosition!).distance;
      if (elapsed <= _kDoubleTapWindow && drift <= _kDoubleTapSlop) {
        // Don't accept yet — wait to see if the user starts dragging.
        // If they release without moving, resolve rejected so the
        // surrounding GestureDetector.onDoubleTap can win instead.
        _state = _State.tap2Down;
        _secondTapStart = event.localPosition;
        _activePointer = event.pointer;
        startTrackingPointer(event.pointer, event.transform);
      } else {
        _reset();
        _state = _State.tap1Down;
        _firstTapPosition = event.localPosition;
        _activePointer = event.pointer;
        startTrackingPointer(event.pointer, event.transform);
      }
    } else if (_state == _State.tap2Down || _state == _State.dragging) {
      // A second pointer arrived mid-tap2 or mid-drag. That means the
      // user is actually trying to pinch, not single-finger-drag after
      // a double tap. Yield immediately so ScaleGestureRecognizer can
      // claim both pointers.
      resolve(GestureDisposition.rejected);
      _reset();
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _activePointer) return;

    if (event is PointerMoveEvent) {
      if (_state == _State.dragging) {
        onDragUpdate?.call(event.localPosition);
      } else if (_state == _State.tap2Down && _secondTapStart != null) {
        final drift = (event.localPosition - _secondTapStart!).distance;
        if (drift > kTouchSlop) {
          _state = _State.dragging;
          resolve(GestureDisposition.accepted);
          onDragStart?.call(_secondTapStart!);
          onDragUpdate?.call(event.localPosition);
        }
      } else if (_state == _State.tap1Down && _firstTapPosition != null) {
        final drift = (event.localPosition - _firstTapPosition!).distance;
        // If the user moved more than a touch-slop during tap 1, this
        // is a pan, not a tap. Yield so the scale recognizer can claim.
        if (drift > kTouchSlop) {
          resolve(GestureDisposition.rejected);
          _reset();
          stopTrackingPointer(event.pointer);
        }
      }
    } else if (event is PointerUpEvent) {
      if (_state == _State.tap1Down) {
        _state = _State.tap1Up;
        _firstTapUpTimestamp = event.timeStamp;
        // Yield pointer 1's arena so ambient Tap/DoubleTap recognizers
        // can fire for a plain single tap. DTD's own state survives
        // across the gap, ready to claim a possible second tap (which
        // starts its own arena).
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
      } else if (_state == _State.tap2Down) {
        // Second tap released without drag → this is a plain double-tap.
        // Back out so the parent GestureDetector's onDoubleTap can win.
        resolve(GestureDisposition.rejected);
        _reset();
        stopTrackingPointer(event.pointer);
      } else if (_state == _State.dragging) {
        onDragEnd?.call();
        _reset();
        stopTrackingPointer(event.pointer);
      } else {
        stopTrackingPointer(event.pointer);
      }
    } else if (event is PointerCancelEvent) {
      if (_state == _State.dragging) onDragEnd?.call();
      resolve(GestureDisposition.rejected);
      _reset();
      stopTrackingPointer(event.pointer);
    }
  }

  void _reset() {
    _state = _State.idle;
    _firstTapPosition = null;
    _firstTapUpTimestamp = null;
    _secondTapStart = null;
    _activePointer = null;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'doubleTapDrag';

  @override
  void rejectGesture(int pointer) {
    // Arena rejection: another recognizer won this pointer.
    // Preserve the "between taps" state so a still-pending second tap
    // can still upgrade us; otherwise clear local state.
    if (_state == _State.dragging) onDragEnd?.call();
    if (_state != _State.tap1Up) _reset();
    super.rejectGesture(pointer);
  }
}

enum _State { idle, tap1Down, tap1Up, tap2Down, dragging }

// ---------------------------------------------------------------------------
// Fling: two Flutter FrictionSimulations (X/Y), driven by an unbounded
// AnimationController through a time-driver Simulation.
// ---------------------------------------------------------------------------

class _FlingRunner {
  _FlingRunner({
    required this.startMatrix,
    required Offset position,
    required Offset velocity,
    required double drag,
  }) : simX = FrictionSimulation(drag, position.dx, velocity.dx),
       simY = FrictionSimulation(drag, position.dy, velocity.dy);

  final Matrix4 startMatrix;
  final FrictionSimulation simX;
  final FrictionSimulation simY;

  bool isDoneAt(double t) => simX.isDone(t) && simY.isDone(t);

  Matrix4 matrixAt(double t) {
    final m = startMatrix.clone();
    m.storage[12] = simX.x(t);
    m.storage[13] = simY.x(t);
    return m;
  }
}

class _FlingTimeDriver extends Simulation {
  _FlingTimeDriver(this.simX, this.simY);
  final FrictionSimulation simX;
  final FrictionSimulation simY;
  @override
  double x(double time) => time;
  @override
  double dx(double time) => 1.0;
  @override
  bool isDone(double time) => simX.isDone(time) && simY.isDone(time);
}
