import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../pan_gate.dart';
import 'matrix_utils.dart';
import 'pager_scope.dart';

/// Callback fired when panning hits a boundary.
///
/// [axis] is the axis along which the pan was clamped. [sign] is +1 when
/// the pan would have moved content in the positive direction (i.e., the
/// user is pulling content past the right / bottom edge) and -1 for the
/// opposite.
typedef ZoomableEdgeCallback = void Function(Axis axis, int sign);

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

/// Minimum pinch scale velocity (factor / second) required to start a
/// scale fling on release. Below this the scale snaps to where the user
/// released. Symmetric with [kMinFlingVelocity] (50 px/sec) for pan.
const double _kMinScaleFlingVelocity = 0.3;

/// The zoom-and-pan surface that backs the photo viewer.
///
/// - Focal-preserving pinch/pan/rotate via a custom
///   [_ArenaAwareScaleRecognizer] that yields horizontal drags back to
///   the gesture arena (so a parent [PageView] can take over) when the
///   image is already against the relevant edge.
/// - Double-tap-drag continuous zoom (iOS Photos style) via
///   [DoubleTapDragRecognizer].
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
    this.clipBehavior = .none,
    this.onEdgeHit,
    this.panGate,
    this.doubleTapDragZoom = true,
    this.interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    this.enableMouseWheelZoom = true,
    this.rubberBandPan = true,
    this.onScaleStart,
    this.onScaleEnd,
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

  /// Consulted once a single-pointer pan's dominant direction is
  /// known. `null` behaves as [ViewfinderPanVerdict.compete].
  final ViewfinderPanGate? panGate;

  /// When true, a double-tap followed by a vertical drag (without
  /// releasing) continuously scales around the first tap location —
  /// the standard iOS Photos "magic tap" gesture.
  final bool doubleTapDragZoom;

  /// Drag coefficient passed to [FrictionSimulation] for the
  /// post-release fling animation. Higher values decelerate more
  /// quickly. See [kViewfinderDefaultFlingDrag] for the default.
  final double interactionEndFrictionCoefficient;

  /// Whether scroll-style input — mouse wheel and trackpad two-finger
  /// scroll — zooms around the pointer location. Defaults to `true`
  /// because the enclosing gallery is typically a full-screen photo
  /// viewer; callers embedding [ZoomableViewport] in a scrollable page
  /// can disable it to let scrolling bubble. Pinch (touch, trackpad,
  /// or browser pinch) zooms regardless.
  final bool enableMouseWheelZoom;

  /// When `true` (default), pulling a zoomed image past its boundary
  /// shows live elastic over-pan that diminishes with distance, then
  /// snaps back on release. When `false`, the image hard-clamps at the
  /// boundary with no elastic give.
  final bool rubberBandPan;

  /// Fired when a pinch / pan / rotate gesture begins.
  final GestureScaleStartCallback? onScaleStart;

  /// Fired when a pinch / pan / rotate gesture ends. Carries the
  /// release velocity (used internally to drive the fling simulation).
  final GestureScaleEndCallback? onScaleEnd;

  @override
  State<ZoomableViewport> createState() => _ZoomableViewportState();
}

class _ZoomableViewportState extends State<ZoomableViewport>
    with TickerProviderStateMixin {
  // Gesture-start snapshot for scale/pan/rotate.
  Matrix4 _startMatrix = Matrix4.identity();
  Offset _startFocalViewport = Offset.zero;
  // Most recent focal during the live gesture. Captured because
  // ScaleEndDetails carries velocity but not the final focal — and the
  // post-release scale fling needs to know what to anchor scaling to.
  Offset _lastGestureFocal = Offset.zero;
  bool _inGesture = false;

  // Double-tap-drag snapshot.
  Matrix4? _dtdStartMatrix;
  Offset _dtdFocal = Offset.zero;
  Offset _dtdStartDragPoint = Offset.zero;

  // Viewport size captured by LayoutBuilder.
  Size _viewport = Size.zero;

  // Fling.
  late final AnimationController _flingController;
  FlingRunner? _runner;

  // Rubber-band snap-back.
  late final AnimationController _snapBackController;
  Matrix4Tween? _snapBackTween;

  // Guards the transformation-controller listener: `true` while this
  // state itself is writing, so only external writes (the enclosing
  // viewer's reset / jumpToTransform / double-tap animation) stop the
  // fling and snap-back.
  bool _selfWrite = false;

  // From the enclosing gallery page's PagerScope, if any.
  Axis? _pagerAxis;
  Axis? _wheelPagingAxis;

  @override
  void initState() {
    super.initState();
    _flingController = AnimationController.unbounded(vsync: this)
      ..addListener(_onFlingTick);
    _snapBackController = AnimationController(
      vsync: this,
      duration: const .new(milliseconds: 220),
    )..addListener(_onSnapBackTick);
    widget.transformationController.addListener(_onTransformChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = PagerScope.maybeOf(context);
    _pagerAxis = scope?.axis;
    _wheelPagingAxis = (scope?.wheelPaging ?? false) ? scope?.axis : null;
  }

  @override
  void didUpdateWidget(covariant ZoomableViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transformationController != widget.transformationController) {
      oldWidget.transformationController.removeListener(_onTransformChanged);
      widget.transformationController.addListener(_onTransformChanged);
      _stopFling();
      _stopSnapBack();
    }
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onTransformChanged);
    _flingController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  /// Writes [m] to the transformation controller, marked as our own so
  /// [_onTransformChanged] can tell it apart from external writes.
  void _setTransform(Matrix4 m) {
    _selfWrite = true;
    try {
      widget.transformationController.value = m;
    } finally {
      _selfWrite = false;
    }
  }

  /// An external write (e.g. the viewer's programmatic `reset()` /
  /// `jumpToInitial()` while a fling is still running) takes over the
  /// transform. Stop the fling / snap-back so the two don't fight over
  /// the controller on every subsequent frame.
  void _onTransformChanged() {
    if (_selfWrite) return;
    _stopFling();
    _stopSnapBack();
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
    final m = _clampMatrix(runner.matrixAt(t), elastic: widget.rubberBandPan);
    _setTransform(m);
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
    _setTransform(tween.transform(t));
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

  /// Whether the platform asks for reduced motion; decorative
  /// animations (fling glide, rubber-band snap-back) jump instead.
  bool get _reduceMotion =>
      mounted && MediaQuery.maybeDisableAnimationsOf(context) == true;

  /// If the current matrix sits in rubber-band over-pan territory,
  /// animate it back to the strict-clamp position.
  void _snapBackIfOverPan() {
    final current = widget.transformationController.value;
    final clamped = _clampMatrix(current);
    final dx = (clamped.storage[12] - current.storage[12]).abs();
    final dy = (clamped.storage[13] - current.storage[13]).abs();
    if (dx < 0.5 && dy < 0.5) return;
    if (_reduceMotion) {
      _setTransform(clamped);
      return;
    }
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
    _lastGestureFocal = d.localFocalPoint;
    _inGesture = true;
    widget.onScaleStart?.call(d);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_inGesture) return;

    final focalCurrent = d.localFocalPoint;
    _lastGestureFocal = focalCurrent;
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
    final actualScale = xyScale(next);
    if (actualScale < widget.minScale || actualScale > widget.maxScale) {
      final target = actualScale.clamp(widget.minScale, widget.maxScale);
      next = buildDelta(scale * target / actualScale).multiplied(_startMatrix);
    }

    _setTransform(
      _clampMatrix(next, reportEdge: true, elastic: widget.rubberBandPan),
    );
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _inGesture = false;
    widget.onScaleEnd?.call(d);
    final v = d.velocity.pixelsPerSecond;
    final scaleV = d.scaleVelocity;
    final m = widget.transformationController.value;
    final currentScale = xyScale(m);

    // Pan fling only meaningful when the content actually overflows the
    // viewport — at content == viewport size there is no over-pan room.
    final hasPanFling = v.distance >= kMinFlingVelocity && currentScale > 1.01;
    // Scale fling: any time the user released with meaningful pinch
    // velocity, regardless of current scale (including when starting
    // exactly at minScale).
    final hasScaleFling = scaleV.abs() >= _kMinScaleFlingVelocity;

    if ((!hasPanFling && !hasScaleFling) || _reduceMotion) {
      _snapBackIfOverPan();
      return;
    }

    _startFling(
      from: m,
      velocity: hasPanFling ? v : Offset.zero,
      scaleVelocity: hasScaleFling ? scaleV : 0.0,
      startScale: currentScale,
    );
  }

  void _startFling({
    required Matrix4 from,
    required Offset velocity,
    required double scaleVelocity,
    required double startScale,
  }) {
    final start = from.clone();
    final runner = FlingRunner(
      startMatrix: start,
      position: Offset(start.storage[12], start.storage[13]),
      velocity: velocity,
      drag: widget.interactionEndFrictionCoefficient,
      startScale: startScale,
      scaleVelocity: scaleVelocity,
      focal: _lastGestureFocal,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
    );
    _runner = runner;
    _flingController
      ..stop()
      ..animateWith(FlingTimeDriver(runner.simX, runner.simY, runner.simScale));
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
    // Up = zoom in, down = zoom out (iOS Photos convention).
    final factor = math.pow(2.0, -dy / _kDoubleTapDragPixelsPerUnit).toDouble();
    final currentScaleAtStart = xyScale(start);
    final targetScale = (currentScaleAtStart * factor).clamp(
      widget.minScale,
      widget.maxScale,
    );
    final effective = targetScale / currentScaleAtStart;
    final delta = scaleAroundFocal(focal: _dtdFocal, scale: effective);
    _setTransform(_clampMatrix(delta.multiplied(start)));
  }

  void _onDoubleTapDragEnd() {
    _dtdStartMatrix = null;
  }

  // ---------------- mouse wheel ---------------- //

  /// Pixels of scroll wheel deltaY that correspond to a 1× scale change.
  /// Chosen so typical mouse wheels zoom in/out at a comfortable pace.
  static const double _kMouseWheelPixelsPerUnit = 200.0;

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.scaleEnabled) return;
    // Browser pinch (web trackpads / ctrl+wheel) arrives as a scale
    // signal, not a PanZoom gesture — a deliberate zoom, so it is not
    // gated by the wheel knob.
    final double factor;
    switch (event) {
      case PointerScaleEvent(:final scale):
        factor = scale;
      case PointerScrollEvent(:final scrollDelta)
          when widget.enableMouseWheelZoom:
        final double zoomDelta;
        if (_wheelPagingAxis case final axis?) {
          final (:along, :cross) = splitScrollDelta(scrollDelta, axis);
          // Pager-axis-dominant scroll belongs to the pager.
          if (along.abs() > cross.abs()) return;
          zoomDelta = cross;
        } else {
          zoomDelta = scrollDelta.dy;
        }
        factor = math
            .pow(2.0, -zoomDelta / _kMouseWheelPixelsPerUnit)
            .toDouble();
      default:
        return;
    }

    _stopFling();
    _stopSnapBack();
    final focal = event.localPosition;
    final start = widget.transformationController.value;
    final currentScale = xyScale(start);
    final targetScale = (currentScale * factor).clamp(
      widget.minScale,
      widget.maxScale,
    );
    if ((targetScale - currentScale).abs() < 1e-6) return;
    final effective = targetScale / currentScale;
    final delta = scaleAroundFocal(focal: focal, scale: effective);
    _setTransform(_clampMatrix(delta.multiplied(start)));
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

  /// Translation delta that keeps one axis of the content's bbox
  /// (`min..max`) inside a viewport of [viewportDim]: content smaller
  /// than the viewport is centered; otherwise an off-edge bound is
  /// nudged back — elastically when [elastic] — and the hit edge is
  /// reported when [reportEdge].
  double _clampAxisDelta({
    required double min,
    required double max,
    required double viewportDim,
    required Axis axis,
    required bool reportEdge,
    required bool elastic,
  }) {
    final extent = max - min;
    if (extent <= viewportDim) {
      // Content smaller than viewport on this axis → center it.
      return (viewportDim - extent) / 2 - min;
    }
    // Allow the bbox to span the full viewport; nudge back when
    // off-edge.
    if (min > 0) {
      // Content's low edge pulled past the viewport's low edge.
      if (reportEdge) widget.onEdgeHit?.call(axis, -1);
      return elastic ? -min + _rubberBand(min, viewportDim) : -min;
    }
    if (max < viewportDim) {
      // Content's high edge pulled past the viewport's high edge.
      final overshoot = viewportDim - max;
      if (reportEdge) widget.onEdgeHit?.call(axis, 1);
      return elastic
          ? overshoot - _rubberBand(overshoot, viewportDim)
          : overshoot;
    }
    return 0;
  }

  Matrix4 _clampMatrix(
    Matrix4 m, {
    bool reportEdge = false,
    bool elastic = false,
  }) {
    if (_viewport.isEmpty) return m;

    // Axis-aligned bounding box of the transformed content (which is
    // originally a 0..viewport.width × 0..viewport.height rect). Correct
    // under rotation because all four projected corners drive it.
    final bbox = contentBbox(m, _viewport);
    final dx = _clampAxisDelta(
      min: bbox.minX,
      max: bbox.maxX,
      viewportDim: _viewport.width,
      axis: .horizontal,
      reportEdge: reportEdge,
      elastic: elastic,
    );
    final dy = _clampAxisDelta(
      min: bbox.minY,
      max: bbox.maxY,
      viewportDim: _viewport.height,
      axis: .vertical,
      reportEdge: reportEdge,
      elastic: elastic,
    );

    if (dx == 0 && dy == 0) return m;
    final out = m.clone();
    out.storage[12] += dx;
    out.storage[13] += dy;
    return out;
  }

  // ---------------- gestures plumbing ---------------- //

  ViewfinderPanVerdict _verdictAt(AxisDirection direction) =>
      widget.panGate?.call(direction) ?? ViewfinderPanVerdict.compete;

  Map<Type, GestureRecognizerFactory> _buildGestures() {
    // Registration order is also arena priority. Put double-tap-drag
    // FIRST so that, when a user has double-tapped and begun dragging,
    // it wins the pointer over the single-pointer pan path of
    // ScaleGestureRecognizer. The order also lets DTD reject itself on
    // a second pointer before the scale recognizer's two-finger claim
    // sees that pointer's events.
    return <Type, GestureRecognizerFactory>{
      if (widget.doubleTapDragZoom && widget.scaleEnabled)
        DoubleTapDragRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapDragRecognizer>(
              () => DoubleTapDragRecognizer(debugOwner: this),
              (r) {
                r
                  ..yieldAxis = _pagerAxis
                  ..onDragStart = _onDoubleTapDragStart
                  ..onDragUpdate = _onDoubleTapDragUpdate
                  ..onDragEnd = _onDoubleTapDragEnd;
              },
            ),
      _ArenaAwareScaleRecognizer:
          GestureRecognizerFactoryWithHandlers<_ArenaAwareScaleRecognizer>(
            () => _ArenaAwareScaleRecognizer(
              debugOwner: this,
              verdictAt: _verdictAt,
            ),
            (r) {
              r
                // Trackpad two-finger scroll zooms only when wheel
                // scroll does — both are scroll-style input. Pinch
                // zooms regardless.
                ..trackpadScrollCausesScale = widget.enableMouseWheelZoom
                ..onStart = _onScaleStart
                ..onUpdate = _onScaleUpdate
                ..onEnd = _onScaleEnd;
            },
          ),
    };
  }

  /// Re-clamps the current transform after the viewport changed size
  /// (device rotation, window resize, split-screen). Without this the
  /// matrix that was clamped against the old viewport stays verbatim —
  /// leaving the content mis-positioned (gap at an edge, off-center)
  /// until the next gesture happens to run the clamp.
  void _reclampAfterResize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Live gestures and animations clamp on every tick against the
      // fresh viewport already; rewriting under them would fight.
      if (_inGesture ||
          _flingController.isAnimating ||
          _snapBackController.isAnimating) {
        return;
      }
      final current = widget.transformationController.value;
      final clamped = _clampMatrix(current);
      if (!identical(clamped, current) && clamped != current) {
        _setTransform(clamped);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _viewport) {
          final isResize = !_viewport.isEmpty;
          _viewport = size;
          if (isResize) _reclampAfterResize();
        }
        return ClipRect(
          clipBehavior: widget.clipBehavior,
          child: Listener(
            onPointerSignal: widget.scaleEnabled ? _onPointerSignal : null,
            child: RawGestureDetector(
              gestures: _buildGestures(),
              behavior: .opaque,
              child: AnimatedBuilder(
                animation: widget.transformationController,
                builder: (_, child) => Transform(
                  transform: widget.transformationController.value,
                  alignment: .topLeft,
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
// Behaves like [ScaleGestureRecognizer] but, once a single pointer's
// dominant direction is resolvable, applies the [verdictAt] gate:
// release → stop tracking so the next arena candidate (e.g. a parent
// PageView) wins; claim → accept immediately at hit-slop, before
// ancestor drag recognizers; compete → normal arena rules.
// ---------------------------------------------------------------------------

class _ArenaAwareScaleRecognizer extends ScaleGestureRecognizer {
  // trackpadScrollCausesScale is set by the owning state, mirroring
  // its wheel-zoom knob.
  _ArenaAwareScaleRecognizer({super.debugOwner, required this.verdictAt})
    : super(
        supportedDevices: const <PointerDeviceKind>{
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.unknown,
        },
      );

  final ViewfinderPanGate verdictAt;

  final Map<int, _TrackedPointer> _tracked = <int, _TrackedPointer>{};
  bool _resolved = false;
  // Set once the arena has been won (either by the base recognizer's
  // own movement acceptance or by the eager claim below). An accepted
  // gesture can no longer be yielded — rejecting a pointer whose arena
  // is already closed would just kill the drag without handing it to
  // anyone — so the gate must not re-engage, e.g. for the remaining
  // finger after a two-finger pinch lifts down to one.
  bool _accepted = false;

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    super.acceptGesture(pointer);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _tracked[event.pointer] = _TrackedPointer(
      startPosition: event.localPosition,
      kind: event.kind,
    );
    super.addAllowedPointer(event);
  }

  /// Movement that confirms two fingers as a pinch/pan. Well under an
  /// ancestor drag's kTouchSlop (18) — without the eager claim the
  /// pager would win the arena off finger 1's drift, because the scale
  /// recognizer's own acceptance waits for the focal point (the finger
  /// average) to cross the larger pan-slop.
  static const double _kTwoFingerClaimSlop = 6.0;

  @override
  void handleEvent(PointerEvent event) {
    if (!_resolved &&
        !_accepted &&
        event is PointerMoveEvent &&
        _tracked.length == 1 &&
        _gateYieldedPointer(event)) {
      // The pointer was handed to the arena; don't forward the event.
      return;
    }
    // Two fingers on the content are never a page swipe; claim as soon
    // as the gesture demonstrably moves. Not on the second pointer's
    // down: a motionless two-finger touch must not fire
    // onScaleStart/onScaleEnd or steal taps.
    if (!_accepted && _tracked.length >= 2 && event is PointerMoveEvent) {
      final tp = _tracked[event.pointer];
      if (tp != null &&
          (event.localPosition - tp.startPosition).distance >
              _kTwoFingerClaimSlop) {
        resolve(GestureDisposition.accepted);
      }
    }
    super.handleEvent(event);
  }

  /// Runs the direction gate once the single tracked pointer crosses
  /// hit-slop. Returns `true` when the pointer was yielded to the
  /// arena (the caller must stop processing the event).
  bool _gateYieldedPointer(PointerMoveEvent event) {
    final tp = _tracked[event.pointer];
    if (tp == null) return false;
    final delta = event.localPosition - tp.startPosition;
    final slop = computeHitSlop(tp.kind, gestureSettings);
    if (delta.distance <= slop) return false;
    // Flutter's own convention: strict axis dominance (no weighting);
    // an exact diagonal has no dominant direction — leave the gate
    // armed for the next move instead of latching unresolved.
    final AxisDirection? dominant = switch (delta) {
      _ when delta.dx.abs() > delta.dy.abs() =>
        delta.dx >= 0 ? AxisDirection.right : AxisDirection.left,
      _ when delta.dy.abs() > delta.dx.abs() =>
        delta.dy >= 0 ? AxisDirection.down : AxisDirection.up,
      _ => null,
    };
    if (dominant == null) return false;
    _resolved = true;
    switch (verdictAt(dominant)) {
      case ViewfinderPanVerdict.release:
        resolvePointer(event.pointer, .rejected);
        stopTrackingPointer(event.pointer);
        _tracked.remove(event.pointer);
        return true;
      case ViewfinderPanVerdict.claim:
        resolve(.accepted);
      case ViewfinderPanVerdict.compete:
        break;
    }
    return false;
  }

  @override
  void rejectGesture(int pointer) {
    _tracked.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void stopTrackingPointer(int pointer) {
    // The base ScaleGestureRecognizer stops tracking a pointer when it
    // goes up mid-gesture (e.g. one finger of a pinch lifting while the
    // other stays down) — without this hook the lifted pointer's entry
    // would leak in [_tracked], so the `length == 1` gate above would
    // never re-engage for the remaining finger.
    _tracked.remove(pointer);
    super.stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracked.clear();
    _resolved = false;
    _accepted = false;
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

typedef DoubleTapDragStart = void Function(Offset localPosition);
typedef DoubleTapDragUpdate = void Function(Offset localPosition);
typedef DoubleTapDragEnd = void Function();

const _kDoubleTapSlop = 100.0;
const _kDoubleTapWindow = Duration(milliseconds: 300);

@visibleForTesting
class DoubleTapDragRecognizer extends OneSequenceGestureRecognizer {
  DoubleTapDragRecognizer({super.debugOwner});

  DoubleTapDragStart? onDragStart;
  DoubleTapDragUpdate? onDragUpdate;
  DoubleTapDragEnd? onDragEnd;

  /// Axis a surrounding pager scrolls on; a drag dominant along it is
  /// yielded as a page swipe instead of becoming a zoom drag. Null
  /// (standalone viewer) keeps every direction.
  Axis? yieldAxis;

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
      resolve(.rejected);
      _reset();
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _activePointer) return;

    switch (event) {
      case final PointerMoveEvent move:
        _handleMove(move);
      case final PointerUpEvent up:
        _handleUp(up);
      case PointerCancelEvent():
        if (_state == _State.dragging) onDragEnd?.call();
        resolve(.rejected);
        stopTrackingPointer(event.pointer);
      default:
        break;
    }
  }

  void _handleMove(PointerMoveEvent event) {
    if (_state == _State.dragging) {
      onDragUpdate?.call(event.localPosition);
    } else if (_state == _State.tap2Down && _secondTapStart != null) {
      final delta = event.localPosition - _secondTapStart!;
      if (delta.distance > kTouchSlop) {
        // A pager-axis-dominant motion is a page swipe that merely
        // followed a tap (chrome toggle) within the double-tap window
        // — yield it. The zoom drag itself stays vertical by
        // convention regardless of the pager axis.
        final dominant = delta.dx.abs() > delta.dy.abs()
            ? Axis.horizontal
            : Axis.vertical;
        if (dominant == yieldAxis) {
          resolve(.rejected);
          stopTrackingPointer(event.pointer);
          _reset();
          return;
        }
        _state = _State.dragging;
        resolve(.accepted);
        onDragStart?.call(_secondTapStart!);
        onDragUpdate?.call(event.localPosition);
      }
    } else if (_state == _State.tap1Down && _firstTapPosition != null) {
      final drift = (event.localPosition - _firstTapPosition!).distance;
      // If the user moved more than a touch-slop during tap 1, this
      // is a pan, not a tap. Yield so the scale recognizer can claim.
      if (drift > kTouchSlop) {
        resolve(.rejected);
        stopTrackingPointer(event.pointer);
      }
    }
  }

  void _handleUp(PointerUpEvent event) {
    if (_state == _State.tap1Down) {
      _state = _State.tap1Up;
      _firstTapUpTimestamp = event.timeStamp;
      // Yield pointer 1's arena so ambient Tap/DoubleTap recognizers
      // can fire for a plain single tap. DTD's own state survives
      // across the gap, ready to claim a possible second tap (which
      // starts its own arena).
      resolve(.rejected);
      stopTrackingPointer(event.pointer);
    } else if (_state == _State.tap2Down) {
      // Second tap released without drag → this is a plain double-tap.
      // Back out so the parent GestureDetector's onDoubleTap can win.
      resolve(.rejected);
      stopTrackingPointer(event.pointer);
    } else if (_state == _State.dragging) {
      onDragEnd?.call();
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
  void didStopTrackingLastPointer(int pointer) {
    // [tap1Up] is intentionally preserved across the inter-tap gap — no
    // pointer is tracked while we wait for the second tap. All other
    // states are "done" when the last pointer stops.
    if (_state != _State.tap1Up) _reset();
  }

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

@visibleForTesting
class FlingRunner {
  FlingRunner({
    required this.startMatrix,
    required Offset position,
    required Offset velocity,
    required double drag,
    required this.startScale,
    required double scaleVelocity,
    required this.focal,
    required this.minScale,
    required this.maxScale,
  }) : simX = FrictionSimulation(drag, position.dx, velocity.dx),
       simY = FrictionSimulation(drag, position.dy, velocity.dy),
       simScale = FrictionSimulation(drag, startScale, scaleVelocity);

  final Matrix4 startMatrix;
  final FrictionSimulation simX;
  final FrictionSimulation simY;
  final FrictionSimulation simScale;
  final double startScale;
  final double minScale;
  final double maxScale;
  final Offset focal;

  bool isDoneAt(double t) =>
      simX.isDone(t) && simY.isDone(t) && simScale.isDone(t);

  Matrix4 matrixAt(double t) {
    // Scale change since release, applied as a delta around the focal
    // point captured at release.
    final scaleNow = simScale.x(t).clamp(minScale, maxScale);
    final scaleFactor = scaleNow / startScale;
    final delta = scaleAroundFocal(focal: focal, scale: scaleFactor);
    final m = delta.multiplied(startMatrix);

    // Pan displacement from gesture-end to t, layered on top of the
    // scaled matrix's translation.
    m.storage[12] += simX.x(t) - simX.x(0);
    m.storage[13] += simY.x(t) - simY.x(0);

    return m;
  }
}

@visibleForTesting
class FlingTimeDriver extends Simulation {
  FlingTimeDriver(this.simX, this.simY, this.simScale);
  final FrictionSimulation simX;
  final FrictionSimulation simY;
  final FrictionSimulation simScale;
  @override
  double x(double time) => time;
  @override
  double dx(double time) => 1.0;
  @override
  bool isDone(double time) =>
      simX.isDone(time) && simY.isDone(time) && simScale.isDone(time);
}
