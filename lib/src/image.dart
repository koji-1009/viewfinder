import 'package:flutter/material.dart';

import 'hero.dart';
import 'initial_scale.dart';
import 'internal/hero_shuttle.dart';
import 'internal/matrix_utils.dart';
import 'internal/zoomable_viewport.dart';

export 'internal/zoomable_viewport.dart'
    show kViewfinderDefaultFlingDrag, ZoomableCanPan, ZoomableClaimPan;

/// Callback fired with the current transformation scale, expressed
/// relative to the initial scale (`1.0` = the [ViewfinderInitialScale]
/// baseline).
typedef ViewfinderScaleChanged = void Function(double scale);

/// Coalesced per-tick snapshot shared between the view state and
/// [ViewfinderImageController]: the scale state plus the eight
/// direction × [SwipeEdgeMode] swipe gates.
typedef _SwipeSignals = ({
  ViewfinderScaleState scale,
  bool leftScreen,
  bool rightScreen,
  bool upScreen,
  bool downScreen,
  bool leftContent,
  bool rightContent,
  bool upContent,
  bool downContent,
});

/// Frame of reference used by [ViewfinderImageController.canSwipe] when
/// asking whether a page swipe along a given axis can take over.
///
/// At zero rotation the two modes agree. They diverge under rotation:
/// pick the one that matches what the receiving handoff target (pager,
/// custom gesture, etc.) is aligned with.
enum SwipeEdgeMode {
  /// Check the rotated content's axis-aligned bounding box against the
  /// viewport, in screen coordinates. Symmetric with the internal
  /// boundary clamp; matches the screen-axis intent of a pager whose
  /// own axis is screen-aligned. The bundled gallery uses this and it
  /// is the default for [ViewfinderImageController.canSwipe].
  screen,

  /// Check the photo's own logical edges (`x = 0` and `x = viewport.width`
  /// for horizontal; `y = 0` and `y = viewport.height` for vertical) in
  /// the photo's frame. Implemented by inverse-projecting the viewport
  /// into photo space and asking whether the viewport has reached or
  /// crossed those logical extents.
  ///
  /// Use when the consumer wants handoff aligned to the photo's frame
  /// rather than the screen — for instance, a custom pager that
  /// follows the photo's axes through rotation. The semantic is
  /// "the user has reached the photo's logical edge" regardless of
  /// rotation; at 90° the photo's logical-H corresponds to screen-V,
  /// at 180° axes are reversed, and so on. The check is correct at
  /// every angle (no special-casing of cardinal rotations).
  content,
}

/// A single zoomable, pannable viewer for images or arbitrary widgets.
///
/// Pinch zoom, pan, and double-tap zoom are delegated to
/// [InteractiveViewer] + a light custom double-tap handler. Suitable as a
/// standalone viewer or as a page inside `Viewfinder`.
///
/// Construct via the [ViewfinderImage.new] (image-backed) or
/// [ViewfinderImage.child] factories. The runtime type of an instance
/// is a package-internal subclass; `find.byType(ViewfinderImage)` in
/// widget tests will therefore not match — use
/// `find.byWidgetPredicate((w) => w is ViewfinderImage)`.
sealed class ViewfinderImage extends StatefulWidget {
  const ViewfinderImage._({
    super.key,
    this.initialScale = const .contain(),
    this.doubleTapScales = const [1.0, 2.5, 5.0],
    this.minScale = 1.0,
    this.maxScale = 8.0,
    this.backgroundColor = Colors.black,
    this.hero,
    this.onScaleChanged,
    this.onScaleStart,
    this.onScaleEnd,
    this.onTap,
    this.onTapUp,
    this.onTapDown,
    this.onLongPress,
    this.onLongPressStart,
    this.onSecondaryTapUp,
    this.controller,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.rotateEnabled = false,
    this.canPan,
    this.claimPan,
    this.interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    this.semanticLabel,
    this.rubberBandPan = true,
    this.doubleTapDragZoom = true,
    this.enableMouseWheelZoom = true,
  }) : assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(
         minScale <= 1.0,
         'minScale is relative to the initial scale (1.0 = the '
         'ViewfinderInitialScale baseline). A value above 1.0 would put '
         'the initial state below the minimum bound.',
       ),
       assert(
         maxScale >= 1.0,
         'maxScale is relative to the initial scale (1.0 = the '
         'ViewfinderInitialScale baseline). A value below 1.0 would put '
         'the initial state above the maximum bound.',
       ),
       assert(interactionEndFrictionCoefficient > 0);

  /// Displays an [ImageProvider]. The most common constructor.
  const factory ViewfinderImage({
    Key? key,
    required ImageProvider image,
    ImageProvider? thumbImage,
    ViewfinderInitialScale initialScale,
    List<double> doubleTapScales,
    double minScale,
    double maxScale,
    Color backgroundColor,
    ViewfinderHero? hero,
    FilterQuality filterQuality,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ViewfinderScaleChanged? onScaleChanged,
    GestureScaleStartCallback? onScaleStart,
    GestureScaleEndCallback? onScaleEnd,
    GestureTapCallback? onTap,
    GestureTapUpCallback? onTapUp,
    GestureTapDownCallback? onTapDown,
    GestureLongPressCallback? onLongPress,
    GestureLongPressStartCallback? onLongPressStart,
    GestureTapUpCallback? onSecondaryTapUp,
    ViewfinderImageController? controller,
    bool panEnabled,
    bool scaleEnabled,
    bool rotateEnabled,
    ZoomableCanPan? canPan,
    ZoomableClaimPan? claimPan,
    double interactionEndFrictionCoefficient,
    String? semanticLabel,
    Duration thumbCrossFadeDuration,
    Curve thumbCrossFadeCurve,
    bool gaplessPlayback,
    bool rubberBandPan,
    bool doubleTapDragZoom,
    bool enableMouseWheelZoom,
  }) = ViewfinderProviderImage;

  /// Displays an arbitrary [child] widget instead of an image.
  ///
  /// [contentKey] identifies the rendered content. When the parent
  /// rebuilds with a different [contentKey] the in-page pan/zoom is
  /// reset, so a re-ordered slot does not leak the previous photo's
  /// transform. The image-backed variant gets this for free from the
  /// `ImageProvider`'s `==`; for `.child` the rendered widget identity
  /// is unreliable (inline `Text(...)` etc. are fresh every rebuild),
  /// so the caller supplies a stable handle. For a single static
  /// `.child`, any constant works (e.g. `contentKey: 'main'`).
  const factory ViewfinderImage.child({
    Key? key,
    required Widget child,
    required Object contentKey,
    ViewfinderInitialScale initialScale,
    List<double> doubleTapScales,
    double minScale,
    double maxScale,
    Color backgroundColor,
    ViewfinderHero? hero,
    ViewfinderScaleChanged? onScaleChanged,
    GestureScaleStartCallback? onScaleStart,
    GestureScaleEndCallback? onScaleEnd,
    GestureTapCallback? onTap,
    GestureTapUpCallback? onTapUp,
    GestureTapDownCallback? onTapDown,
    GestureLongPressCallback? onLongPress,
    GestureLongPressStartCallback? onLongPressStart,
    GestureTapUpCallback? onSecondaryTapUp,
    ViewfinderImageController? controller,
    bool panEnabled,
    bool scaleEnabled,
    bool rotateEnabled,
    ZoomableCanPan? canPan,
    ZoomableClaimPan? claimPan,
    double interactionEndFrictionCoefficient,
    String? semanticLabel,
    bool rubberBandPan,
    bool doubleTapDragZoom,
    bool enableMouseWheelZoom,
  }) = ViewfinderChildImage;

  /// Initial scale applied before any user interaction.
  final ViewfinderInitialScale initialScale;

  /// Ladder of scales cycled by double-tap, relative to the initial
  /// scale (`1.0` = the [ViewfinderInitialScale] baseline). `[]`
  /// disables double-tap; a two-element list behaves as a toggle;
  /// three or more cycle.
  final List<double> doubleTapScales;

  /// Smallest allowed scale, relative to the initial scale (`1.0` =
  /// the [ViewfinderInitialScale] baseline). Must be `<= 1.0` so the
  /// initial state itself stays within bounds.
  final double minScale;

  /// Largest allowed scale, relative to the initial scale (`1.0` =
  /// the [ViewfinderInitialScale] baseline). Must be `>= 1.0` so the
  /// initial state itself stays within bounds.
  final double maxScale;

  /// Color painted behind the image.
  final Color backgroundColor;

  /// Optional Hero animation config.
  final ViewfinderHero? hero;

  /// Per-frame scale callback. See [ViewfinderScaleChanged].
  final ViewfinderScaleChanged? onScaleChanged;

  /// Fired when a pinch / pan / rotate gesture begins. Useful for
  /// haptic feedback or analytics.
  final GestureScaleStartCallback? onScaleStart;

  /// Fired when a pinch / pan / rotate gesture ends. Useful for
  /// analytics or paired-haptic feedback.
  final GestureScaleEndCallback? onScaleEnd;

  /// Tap callbacks forwarded to the internal [GestureDetector] using
  /// Flutter's standard typedefs, so callers can listen for taps without
  /// stacking another [GestureDetector] on top.
  final GestureTapCallback? onTap;

  /// See [onTap].
  final GestureTapUpCallback? onTapUp;

  /// See [onTap].
  final GestureTapDownCallback? onTapDown;

  /// Fired on a long-press — the standard mobile entry point for
  /// save / share / context actions. Only registered when non-null,
  /// so the default gesture arena is unchanged otherwise.
  final GestureLongPressCallback? onLongPress;

  /// Like [onLongPress] but carries the press position, for anchoring
  /// a context menu.
  final GestureLongPressStartCallback? onLongPressStart;

  /// Fired on a secondary-button tap (mouse right-click) with the tap
  /// position — the desktop / web counterpart of [onLongPress].
  final GestureTapUpCallback? onSecondaryTapUp;

  /// Optional [ViewfinderImageController] for state-level observation
  /// and programmatic transform changes.
  final ViewfinderImageController? controller;

  /// Whether single-pointer panning is honored.
  final bool panEnabled;

  /// Whether pinch / wheel scaling is honored.
  final bool scaleEnabled;

  /// When true, two-finger rotation is honored. Default false to keep
  /// the photo upright, matching standard photo-viewer behavior.
  final bool rotateEnabled;

  /// Gate for single-pointer pan, consulted per axis. Called with
  /// `(Axis.horizontal, +1)` when the finger is moving right,
  /// `(Axis.vertical, -1)` for upward, etc. Return `false` to yield
  /// the gesture to an ancestor scroll view — used by the gallery to
  /// hand drags to the parent `PageView` when the image is panned
  /// against its edge.
  final ZoomableCanPan? canPan;

  /// Consulted after [canPan] allowed the pan. Return `true` to claim
  /// the gesture arena immediately at hit-slop instead of waiting for
  /// the scale recognizer's larger pan-slop — required when an
  /// ancestor scrollable also competes for the drag and would
  /// otherwise win first. The gallery claims pans that must stay
  /// inside a zoomed page (e.g. revealing the photo's hidden side
  /// while flush against the opposite edge).
  final ZoomableClaimPan? claimPan;

  /// Post-release fling drag coefficient. Default
  /// [kViewfinderDefaultFlingDrag] = `0.0000135` is tuned for a smooth,
  /// gradual deceleration on a zoomed photo. Higher values decelerate
  /// more quickly (e.g. `0.135` for an iOS-scroll-style snap, `0.015`
  /// for an Android-scroll-style snap).
  final double interactionEndFrictionCoefficient;

  /// Semantic label used by screen readers when this image is image-backed.
  final String? semanticLabel;

  /// When `true` (default), pulling a zoomed image past its boundary
  /// shows live elastic over-pan that diminishes with distance, then
  /// snaps back on release. When `false`, the image hard-clamps at the
  /// boundary with no elastic give.
  final bool rubberBandPan;

  /// When `true` (default), a double-tap followed by a vertical drag
  /// continuously zooms around the tap point (iOS Photos style). Has
  /// no effect when [doubleTapScales] is empty — an empty ladder
  /// disables both double-tap flavors.
  final bool doubleTapDragZoom;

  /// Whether mouse scroll-wheel events zoom around the pointer.
  /// Disable when embedding the viewer in a scrollable page that
  /// should keep receiving wheel events, or when a surrounding
  /// gallery repurposes the wheel for page navigation.
  final bool enableMouseWheelZoom;

  @override
  State<ViewfinderImage> createState() => _ViewfinderImageState();
}

/// `ImageProvider`-backed [ViewfinderImage] variant.
final class ViewfinderProviderImage extends ViewfinderImage {
  /// Creates a provider-backed [ViewfinderImage]. Most callers go
  /// through the [ViewfinderImage.new] factory instead.
  const ViewfinderProviderImage({
    super.key,
    required this.image,
    this.thumbImage,
    super.initialScale,
    super.doubleTapScales,
    super.minScale,
    super.maxScale,
    super.backgroundColor,
    super.hero,
    this.filterQuality = .medium,
    this.loadingBuilder,
    this.errorBuilder,
    super.onScaleChanged,
    super.onScaleStart,
    super.onScaleEnd,
    super.onTap,
    super.onTapUp,
    super.onTapDown,
    super.onLongPress,
    super.onLongPressStart,
    super.onSecondaryTapUp,
    super.controller,
    super.panEnabled,
    super.scaleEnabled,
    super.rotateEnabled,
    super.canPan,
    super.claimPan,
    super.interactionEndFrictionCoefficient,
    super.semanticLabel,
    super.rubberBandPan,
    super.doubleTapDragZoom,
    super.enableMouseWheelZoom,
    this.thumbCrossFadeDuration = const .new(milliseconds: 200),
    this.thumbCrossFadeCurve = Curves.easeOut,
    this.gaplessPlayback = true,
  }) : super._();

  /// Provider rendered as the main image.
  final ImageProvider image;

  /// Optional low-resolution image displayed while [image] is loading.
  /// As soon as the main image's first frame decodes, we cross-fade to
  /// it. Nothing is shown if both thumb and main fail to load — the
  /// usual [errorBuilder] still fires for the main image.
  final ImageProvider? thumbImage;

  /// Filter quality forwarded to the underlying [Image]. See
  /// [Image.filterQuality].
  final FilterQuality filterQuality;

  /// Loading builder forwarded to the underlying [Image]. See
  /// [Image.loadingBuilder].
  final ImageLoadingBuilder? loadingBuilder;

  /// Error builder forwarded to the underlying [Image]. See
  /// [Image.errorBuilder].
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Cross-fade duration from [thumbImage] to [image].
  final Duration thumbCrossFadeDuration;

  /// Easing curve applied to the [thumbImage] -> [image] cross-fade.
  /// Defaults to [Curves.easeOut].
  final Curve thumbCrossFadeCurve;

  /// Forwarded to [Image.gaplessPlayback]. When `true` (default), keeps
  /// showing the previous frame while a new [image] decodes; when
  /// `false`, briefly shows nothing during the swap.
  final bool gaplessPlayback;
}

/// Custom-widget [ViewfinderImage] variant.
final class ViewfinderChildImage extends ViewfinderImage {
  /// Creates a child-widget [ViewfinderImage]. Most callers go through
  /// the [ViewfinderImage.child] factory instead.
  const ViewfinderChildImage({
    super.key,
    required this.child,
    required this.contentKey,
    super.initialScale,
    super.doubleTapScales,
    super.minScale,
    super.maxScale,
    super.backgroundColor,
    super.hero,
    super.onScaleChanged,
    super.onScaleStart,
    super.onScaleEnd,
    super.onTap,
    super.onTapUp,
    super.onTapDown,
    super.onLongPress,
    super.onLongPressStart,
    super.onSecondaryTapUp,
    super.controller,
    super.panEnabled,
    super.scaleEnabled,
    super.rotateEnabled,
    super.canPan,
    super.claimPan,
    super.interactionEndFrictionCoefficient,
    super.semanticLabel,
    super.rubberBandPan,
    super.doubleTapDragZoom,
    super.enableMouseWheelZoom,
  }) : super._();

  /// Widget rendered for this view.
  final Widget child;

  /// Stable identity for [child]; see [ViewfinderImage.child].
  final Object contentKey;
}

class _ViewfinderImageState extends State<ViewfinderImage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformation;
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  Offset _lastTapLocalPos = Offset.zero;
  Size _viewportSize = Size.zero;
  // Guards the transformation listener: `true` while this state itself
  // is writing, so only external writes (a live gesture inside the
  // viewport, or a raw write through the shared controller) stop an
  // in-flight double-tap / reset animation.
  bool _selfWrite = false;

  @override
  void initState() {
    super.initState();
    _transformation = TransformationController(_initialMatrix());
    _animController = AnimationController(
      vsync: this,
      duration: const .new(milliseconds: 220),
    )..addListener(_tickAnimation);
    _transformation.addListener(_notifyScaleChange);
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ViewfinderImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    // Reset on either an explicit initial-scale change or a content
    // swap. The latter handles the slot-reuse case in galleries: when
    // the parent rebuilds the same index with a different photo,
    // Element reuse keeps this State alive — without an explicit reset
    // the previous photo's pan/zoom would carry over to the new one.
    // Jump (rather than a bare write) so an in-flight double-tap /
    // reset animation can't keep ticking over the fresh content.
    if (oldWidget.initialScale != widget.initialScale ||
        _isContentSwap(oldWidget, widget)) {
      jumpToInitial();
    }
  }

  static bool _isContentSwap(ViewfinderImage a, ViewfinderImage b) =>
      switch ((a, b)) {
        (
          ViewfinderProviderImage(image: final ai),
          ViewfinderProviderImage(image: final bi),
        ) =>
          ai != bi,
        (
          ViewfinderChildImage(contentKey: final ak),
          ViewfinderChildImage(contentKey: final bk),
        ) =>
          ak != bk,
        // Different runtime variants (provider <-> child) is a swap.
        _ => true,
      };

  @override
  void deactivate() {
    // Detach here (not in dispose) so a tree rearrangement that
    // mounts a new ViewfinderImage at the same controller before the
    // outgoing one is disposed does not leave both states attached
    // briefly. If the framework reactivates this State, [activate]
    // re-attaches.
    widget.controller?._detach(this);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.controller?._attach(this);
  }

  @override
  void dispose() {
    // Idempotent — `_detach` is a no-op when this state is already
    // detached, which it normally is by this point (deactivate ran).
    widget.controller?._detach(this);
    _transformation
      ..removeListener(_notifyScaleChange)
      ..dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Initial-scale baseline. The public scale knobs
  /// ([ViewfinderImage.minScale], [ViewfinderImage.maxScale],
  /// [ViewfinderImage.doubleTapScales], the controller's `scale` /
  /// `animateToScale`) are all expressed relative to this; the
  /// transform matrix itself stores the absolute product.
  double get _baseScale => widget.initialScale.baseScale;

  double get _absMinScale => widget.minScale * _baseScale;

  double get _absMaxScale => widget.maxScale * _baseScale;

  Matrix4 _initialMatrix() {
    final s = _baseScale;
    return (s - 1.0).abs() < 0.001
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(s, s, 1, 1));
  }

  /// Writes [m] to the transformation controller, marked as our own so
  /// [_notifyScaleChange] can tell it apart from external writes.
  void _writeTransform(Matrix4 m) {
    _selfWrite = true;
    try {
      _transformation.value = m;
    } finally {
      _selfWrite = false;
    }
  }

  void _tickAnimation() {
    final anim = _animation;
    if (anim != null) _writeTransform(anim.value);
  }

  void _notifyScaleChange() {
    // An external write (a live gesture in the viewport, or a raw
    // write through the shared controller) takes precedence over an
    // in-flight double-tap / reset animation — stop the animation so
    // the two don't fight over the transform on every frame.
    if (!_selfWrite && _animController.isAnimating) {
      _animController.stop();
      _animation = null;
    }
    widget.onScaleChanged?.call(relativeScale);
    widget.controller?._bump();
  }

  double get currentScale => xyScale(_transformation.value);

  /// Current scale relative to the initial baseline (1.0 = initial).
  double get relativeScale => currentScale / _baseScale;

  ViewfinderScaleState get scaleState {
    const eps = 0.01;
    return currentScale > _baseScale + eps ? .zoomed : .initial;
  }

  /// All eight [ViewfinderImageController.canSwipeToward] outcomes
  /// (direction × mode), bundled with [scaleState] so the controller's
  /// coalescer can consume one value. Computes the screen-space AABB
  /// and the photo-space AABB once, then derives the eight booleans —
  /// so a transform tick pays for one forward bbox, one matrix
  /// inversion, and one inverse bbox regardless of how many
  /// `canSwipe` / `canSwipeToward` queries follow.
  ///
  /// Field names are the direction of the finger motion of the
  /// would-be swipe. A finger moving right pulls the content right and
  /// reveals what lies beyond the content's *left* edge — so
  /// `rightScreen` is true when there is no such room left (the
  /// content's left edge has met the viewport's left, or the content
  /// fits entirely).
  ///
  /// `screen` is the AABB of the transformed content rect against the
  /// viewport (forward projection). `content` is the AABB of the
  /// viewport rect pulled back into photo space (inverse projection),
  /// checked against the photo's logical extents `[0, viewport.width]`
  /// / `[0, viewport.height]`. The latter answers "has the user
  /// reached the photo's logical edge in the photo's own frame?",
  /// independent of rotation — including past 90° where forward-
  /// projecting the photo's edges would give the wrong answer.
  /// Surrendered gates: every direction reports "swipe may take over".
  /// Built lazily so the common zoomed path doesn't allocate it on
  /// every transform tick.
  _SwipeSignals _allFreeSignals(ViewfinderScaleState scale) => (
    scale: scale,
    leftScreen: true,
    rightScreen: true,
    upScreen: true,
    downScreen: true,
    leftContent: true,
    rightContent: true,
    upContent: true,
    downContent: true,
  );

  _SwipeSignals _swipeSignals() {
    final scale = scaleState;
    if (scale == .initial || _viewportSize.isEmpty) {
      return _allFreeSignals(scale);
    }
    const epsilon = 0.5;
    final m = _transformation.value;
    final viewport = _viewportSize;
    // Singular matrices (e.g., scale 0 forced via jumpToTransform) have
    // no inverse; surrender all gates rather than throwing inside the
    // transform listener. The clamp keeps regular gestures away from
    // this state, so this only fires for caller-supplied transforms.
    if (m.determinant() == 0) {
      return _allFreeSignals(scale);
    }
    final bbox = contentBbox(m, viewport);
    final photoBbox = contentBbox(Matrix4.inverted(m), viewport);
    final fitsH = bbox.maxX - bbox.minX <= viewport.width + epsilon;
    final fitsV = bbox.maxY - bbox.minY <= viewport.height + epsilon;
    return (
      scale: scale,
      // Screen mode: checked against the rotated content's AABB in
      // screen space.
      rightScreen: fitsH || bbox.minX >= -epsilon,
      leftScreen: fitsH || bbox.maxX <= viewport.width + epsilon,
      downScreen: fitsV || bbox.minY >= -epsilon,
      upScreen: fitsV || bbox.maxY <= viewport.height + epsilon,
      // Content mode: the same question asked in the photo's own
      // frame — a finger moving (photo-)right reveals the photo's
      // left region, exhausted once the viewport reaches the photo's
      // logical left extent.
      rightContent: photoBbox.minX <= epsilon,
      leftContent: photoBbox.maxX >= viewport.width - epsilon,
      downContent: photoBbox.minY <= epsilon,
      upContent: photoBbox.maxY >= viewport.height - epsilon,
    );
  }

  void _animateTo(Matrix4 target) {
    // Honor the platform's reduce-motion setting: jump instead of
    // animating (double-tap zoom, reset, animateToScale/Transform).
    if (mounted && MediaQuery.maybeDisableAnimationsOf(context) == true) {
      jumpToTransform(target);
      return;
    }
    _animation = Matrix4Tween(begin: _transformation.value, end: target)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController
      ..reset()
      ..forward();
  }

  void _handleDoubleTapDown(TapDownDetails d) =>
      _lastTapLocalPos = d.localPosition;

  void _handleDoubleTap() {
    if (widget.doubleTapScales.isEmpty) return;
    final base = _baseScale;
    // The ladder is expressed relative to the initial baseline; walk it
    // in absolute terms so `1.0` always lands back on the initial state.
    final target = nextDoubleTapScale(
      scales: [for (final s in widget.doubleTapScales) s * base],
      currentScale: currentScale,
    );
    final clamped = target.clamp(_absMinScale, _absMaxScale).toDouble();
    _animateTo(
      (clamped - base).abs() < 0.001
          ? _initialMatrix()
          : scaleAroundFocal(focal: _lastTapLocalPos, scale: clamped),
    );
  }

  void reset() => _animateTo(_initialMatrix());

  void jumpToInitial() {
    _animController.stop();
    _animation = null;
    _writeTransform(_initialMatrix());
  }

  void animateToScale(double scale, {Offset? focal}) {
    final base = _baseScale;
    final clamped = (scale * base).clamp(_absMinScale, _absMaxScale).toDouble();
    final size = switch (context.findRenderObject()) {
      final RenderBox b => b.size,
      _ => Size.zero,
    };
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    _animateTo(
      (clamped - base).abs() < 0.001
          ? _initialMatrix()
          : scaleAroundFocal(focal: f, scale: clamped),
    );
  }

  Matrix4 get currentTransform => _transformation.value.clone();

  void jumpToTransform(Matrix4 target) {
    _animController.stop();
    _animation = null;
    _writeTransform(target);
  }

  void animateToTransform(Matrix4 target) => _animateTo(target);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, constraints) {
      final viewport = Size(constraints.maxWidth, constraints.maxHeight);
      if (_viewportSize != viewport) {
        _viewportSize = viewport;
        // Recompute derived state after layout settles so controller
        // listeners see the fresh canSwipe results.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.controller?._bump();
        });
      }
      return _ImageBody(
        spec: widget,
        transformation: _transformation,
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
      );
    },
  );
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({
    required this.spec,
    required this.transformation,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
  });

  final ViewfinderImage spec;
  final TransformationController transformation;
  final GestureTapDownCallback onDoubleTapDown;
  final GestureTapCallback onDoubleTap;

  /// Default flight shuttle for provider-backed viewers. Flutter's own
  /// default flies the destination hero's child, so a pop flight
  /// renders the app-side widget (typically a cover-fit thumbnail)
  /// stretched across the viewer's rect — a visible jump against the
  /// viewer's fit. Fly the viewer's rendering instead; with
  /// [ViewfinderHero.thumbnailFit] set, interpolate toward the
  /// thumbnail's fit so the other end lands exactly too.
  HeroFlightShuttleBuilder? _defaultShuttle(ViewfinderHero hero) {
    if (spec case final ViewfinderProviderImage spec) {
      return (context, animation, direction, fromContext, toContext) {
        if (hero.thumbnailFit case final thumbnailFit?) {
          return HeroCrossFitShuttle(
            image: spec.image,
            viewerFit: spec.initialScale.boxFit,
            thumbnailFit: thumbnailFit,
            animation: animation,
            direction: direction,
            filterQuality: spec.filterQuality,
          );
        }
        return Image(
          image: spec.image,
          fit: spec.initialScale.boxFit,
          filterQuality: spec.filterQuality,
          gaplessPlayback: true,
        );
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = switch (spec) {
      ViewfinderProviderImage(
        :final image,
        :final thumbImage,
        :final filterQuality,
        :final loadingBuilder,
        :final errorBuilder,
        :final thumbCrossFadeDuration,
        :final thumbCrossFadeCurve,
        :final gaplessPlayback,
      ) =>
        _ImageWithOptionalThumb(
          image: image,
          thumb: thumbImage,
          boxFit: spec.initialScale.boxFit,
          filterQuality: filterQuality,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
          thumbCrossFadeDuration: thumbCrossFadeDuration,
          thumbCrossFadeCurve: thumbCrossFadeCurve,
          semanticLabel: spec.semanticLabel,
          gaplessPlayback: gaplessPlayback,
        ),
      ViewfinderChildImage(:final child) => child,
    };

    if (spec.hero case final hero?) {
      content = Hero(
        tag: hero.tag,
        createRectTween: hero.createRectTween,
        flightShuttleBuilder:
            hero.flightShuttleBuilder ?? _defaultShuttle(hero),
        placeholderBuilder: hero.placeholderBuilder,
        transitionOnUserGestures: hero.transitionOnUserGestures,
        child: content,
      );
    }

    return ColoredBox(
      color: spec.backgroundColor,
      child: GestureDetector(
        behavior: .opaque,
        onTap: spec.onTap,
        onTapUp: spec.onTapUp,
        onTapDown: spec.onTapDown,
        onLongPress: spec.onLongPress,
        onLongPressStart: spec.onLongPressStart,
        onSecondaryTapUp: spec.onSecondaryTapUp,
        onDoubleTapDown: onDoubleTapDown,
        onDoubleTap: onDoubleTap,
        child: ZoomableViewport(
          transformationController: transformation,
          // The public knobs are relative to the initial baseline; the
          // viewport clamps the absolute matrix scale.
          minScale: spec.minScale * spec.initialScale.baseScale,
          maxScale: spec.maxScale * spec.initialScale.baseScale,
          panEnabled: spec.panEnabled,
          scaleEnabled: spec.scaleEnabled,
          rotateEnabled: spec.rotateEnabled,
          clipBehavior: .none,
          interactionEndFrictionCoefficient:
              spec.interactionEndFrictionCoefficient,
          canPan: spec.canPan,
          claimPan: spec.claimPan,
          rubberBandPan: spec.rubberBandPan,
          // An empty double-tap ladder means "double-tap zoom is off" —
          // including the double-tap-drag flavor.
          doubleTapDragZoom:
              spec.doubleTapDragZoom && spec.doubleTapScales.isNotEmpty,
          enableMouseWheelZoom: spec.enableMouseWheelZoom,
          onScaleStart: spec.onScaleStart,
          onScaleEnd: spec.onScaleEnd,
          child: content,
        ),
      ),
    );
  }
}

class _ImageWithOptionalThumb extends StatelessWidget {
  const _ImageWithOptionalThumb({
    required this.image,
    required this.thumb,
    required this.boxFit,
    required this.filterQuality,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.thumbCrossFadeDuration,
    required this.thumbCrossFadeCurve,
    required this.semanticLabel,
    required this.gaplessPlayback,
  });

  final ImageProvider image;
  final ImageProvider? thumb;
  final BoxFit boxFit;
  final FilterQuality filterQuality;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Duration thumbCrossFadeDuration;
  final Curve thumbCrossFadeCurve;
  final String? semanticLabel;
  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    // Parent (`ZoomableViewport`) wraps us in a tight-sized `SizedBox`,
    // so `Image.fit` already lays out against the viewport — no
    // `LayoutBuilder` / explicit width/height needed here.
    Widget img = Image(
      image: image,
      fit: boxFit,
      filterQuality: filterQuality,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      gaplessPlayback: gaplessPlayback,
      frameBuilder: thumb == null
          ? null
          : (context, child, frame, wasSyncLoaded) => AnimatedOpacity(
              opacity: frame == null ? 0.0 : 1.0,
              duration: thumbCrossFadeDuration,
              curve: thumbCrossFadeCurve,
              child: child,
            ),
    );
    if (thumb case final t?) {
      img = Stack(
        fit: .expand,
        children: [
          Image(
            image: t,
            fit: boxFit,
            filterQuality: .low,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          img,
        ],
      );
    }
    if (semanticLabel case final label?) {
      img = Semantics(label: label, image: true, child: img);
    }
    return img;
  }
}

/// External control surface for a [ViewfinderImage].
///
/// Extends [ChangeNotifier] so callers can subscribe to *state-level*
/// changes (zoomed in/out, edge transitions). Notifications are coalesced
/// to fire only when [scaleState] or any [canSwipe] result transitions —
/// not on every transform frame. For per-frame scale callbacks, use
/// [ViewfinderImage.onScaleChanged].
///
/// Each controller drives a single [ViewfinderImage]. Passing the same
/// instance to multiple widgets is rejected by a debug assert; create a
/// fresh controller per viewer.
class ViewfinderImageController extends ChangeNotifier {
  /// Creates a detached controller. Pass it to a [ViewfinderImage] to
  /// observe and drive that image's transform.
  ViewfinderImageController();

  _ViewfinderImageState? _state;
  bool _disposed = false;
  _SwipeSignals? _lastSignal;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Lifecycle hooks do not call notifyListeners — neither attach nor
  // detach changes any user-observable property at the moment they fire.
  // Real state changes (transform, scaleState, canSwipe results) flow
  // through [_bump] from the transform-controller listener.
  void _attach(_ViewfinderImageState s) {
    if (_disposed) return;
    assert(
      _state == null || identical(_state, s),
      'A ViewfinderImageController was attached to multiple ViewfinderImage '
      'widgets at once. Each controller can drive only one viewer — create a '
      'separate controller per widget. (Debug-only check; release builds '
      'silently overwrite the previous binding, which produces incorrect '
      'reads through the controller.)',
    );
    _state = s;
    _lastSignal = null;
  }

  void _detach(_ViewfinderImageState s) {
    if (_disposed) return;
    if (identical(_state, s)) {
      _state = null;
      _lastSignal = null;
    }
  }

  /// Called by the view whenever the transformation or viewport changes.
  /// Coalesces per-frame ticks into a single notification per state
  /// transition. Tracks both edge modes so a listener reading either
  /// `screen` or `content` results sees its own transitions.
  void _bump() {
    if (_disposed) return;
    final next = _state?._swipeSignals();
    if (next == _lastSignal) return;
    _lastSignal = next;
    notifyListeners();
  }

  /// Current magnification relative to the initial scale
  /// (1.0 = initial, whatever the [ViewfinderInitialScale] baseline).
  double get scale => _state?.relativeScale ?? 1.0;

  /// Whether the user has zoomed in past the initial scale.
  ViewfinderScaleState get scaleState => _state?.scaleState ?? .initial;

  /// True when a page swipe along [axis] — in either direction — can
  /// reasonably take over; returns `true` while detached. See
  /// [SwipeEdgeMode] for how rotation is interpreted.
  ///
  /// For the direction-aware variant (needed to tell "flush against
  /// the left edge" apart from "flush against the right edge"), use
  /// [canSwipeToward].
  ///
  /// Reads from the coalesced snapshot the controller's listeners
  /// observed, so a listener that calls `canSwipe` right after being
  /// notified does not pay for the bbox/inverse-bbox computation a
  /// second time. Falls back to the live state for the rare pre-first-
  /// bump read (controller attached, no transform tick yet).
  bool canSwipe(Axis axis, {SwipeEdgeMode mode = SwipeEdgeMode.screen}) {
    return switch (axis) {
      .horizontal =>
        canSwipeToward(.left, mode: mode) || canSwipeToward(.right, mode: mode),
      .vertical =>
        canSwipeToward(.up, mode: mode) || canSwipeToward(.down, mode: mode),
    };
  }

  /// True when a page swipe whose finger motion points in [direction]
  /// can reasonably take over — i.e. the content has no more room to
  /// pan that way; returns `true` while detached.
  ///
  /// [direction] is the direction of the *finger motion* (drag), not
  /// of the page navigation: a finger moving [AxisDirection.right]
  /// pulls the content right and is exhausted once the content's left
  /// edge meets the viewport's left. With [SwipeEdgeMode.content] the
  /// direction refers to the photo's own logical frame, which tracks
  /// the photo through rotation. See [SwipeEdgeMode].
  bool canSwipeToward(
    AxisDirection direction, {
    SwipeEdgeMode mode = SwipeEdgeMode.screen,
  }) {
    final signal = _lastSignal ?? _state?._swipeSignals();
    if (signal == null) return true;
    return switch ((direction, mode)) {
      (.left, .screen) => signal.leftScreen,
      (.right, .screen) => signal.rightScreen,
      (.up, .screen) => signal.upScreen,
      (.down, .screen) => signal.downScreen,
      (.left, .content) => signal.leftContent,
      (.right, .content) => signal.rightContent,
      (.up, .content) => signal.upContent,
      (.down, .content) => signal.downContent,
    };
  }

  /// Animate back to the initial transform.
  void reset() => _state?.reset();

  /// Jump back to the initial transform instantly, without animation.
  /// Intended for Hero-transition coherence: if the user is popping the
  /// route while zoomed, animation would leave the Hero source rect out
  /// of sync with the target; jumping avoids the glitch.
  void jumpToInitial() => _state?.jumpToInitial();

  /// Animate to a specific scale — relative to the initial baseline,
  /// like [scale] — optionally around a focal point.
  void animateToScale(double scale, {Offset? focal}) =>
      _state?.animateToScale(scale, focal: focal);

  /// Current transform matrix. Returns the identity when not attached.
  Matrix4 get currentTransform =>
      _state?.currentTransform ?? Matrix4.identity();

  /// Set the transform matrix without animation. No-op when not attached.
  /// Bypasses the boundary clamp — caller is responsible for keeping the
  /// content visible.
  void jumpToTransform(Matrix4 target) => _state?.jumpToTransform(target);

  /// Animate to [target] using the same easing/duration as
  /// [animateToScale] / [reset]. No-op when not attached.
  void animateToTransform(Matrix4 target) => _state?.animateToTransform(target);
}
