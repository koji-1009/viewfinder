import 'package:flutter/material.dart';

import 'hero.dart';
import 'initial_scale.dart';
import 'internal/matrix_utils.dart';
import 'internal/zoomable_viewport.dart';

export 'internal/zoomable_viewport.dart' show kViewfinderDefaultFlingDrag;

/// Callback fired with the current transformation scale.
typedef ViewfinderScaleChanged = void Function(double scale);

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
    this.controller,
    this.panEnabled = true,
    this.scaleEnabled = true,
    this.rotateEnabled = false,
    this.canPan,
    this.interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    this.semanticLabel,
    this.rubberBandPan = true,
  }) : assert(minScale > 0),
       assert(maxScale >= minScale),
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
    ViewfinderImageController? controller,
    bool panEnabled,
    bool scaleEnabled,
    bool rotateEnabled,
    ZoomableCanPan? canPan,
    double interactionEndFrictionCoefficient,
    String? semanticLabel,
    Duration thumbCrossFadeDuration,
    Curve thumbCrossFadeCurve,
    bool gaplessPlayback,
    bool rubberBandPan,
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
    ViewfinderImageController? controller,
    bool panEnabled,
    bool scaleEnabled,
    bool rotateEnabled,
    ZoomableCanPan? canPan,
    double interactionEndFrictionCoefficient,
    String? semanticLabel,
    bool rubberBandPan,
  }) = ViewfinderChildImage;

  /// Initial scale applied before any user interaction.
  final ViewfinderInitialScale initialScale;

  /// Ladder of scales cycled by double-tap. `[]` disables double-tap;
  /// a two-element list behaves as a toggle; three or more cycle.
  final List<double> doubleTapScales;

  /// Smallest allowed scale.
  final double minScale;

  /// Largest allowed scale.
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
    super.controller,
    super.panEnabled,
    super.scaleEnabled,
    super.rotateEnabled,
    super.canPan,
    super.interactionEndFrictionCoefficient,
    super.semanticLabel,
    super.rubberBandPan,
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
    super.controller,
    super.panEnabled,
    super.scaleEnabled,
    super.rotateEnabled,
    super.canPan,
    super.interactionEndFrictionCoefficient,
    super.semanticLabel,
    super.rubberBandPan,
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
    if (oldWidget.initialScale != widget.initialScale ||
        _isContentSwap(oldWidget, widget)) {
      _transformation.value = _initialMatrix();
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

  Matrix4 _initialMatrix() {
    final s = widget.initialScale.baseScale;
    return (s - 1.0).abs() < 0.001
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(s, s, 1, 1));
  }

  void _tickAnimation() {
    final anim = _animation;
    if (anim != null) _transformation.value = anim.value;
  }

  void _notifyScaleChange() {
    widget.onScaleChanged?.call(currentScale);
    widget.controller?._bump();
  }

  double get currentScale => xyScale(_transformation.value);

  ViewfinderScaleState get scaleState {
    const eps = 0.01;
    return currentScale > widget.initialScale.baseScale + eps
        ? .zoomed
        : .initial;
  }

  /// All four [ViewfinderImageController.canSwipe] outcomes
  /// (axis × mode), bundled with [scaleState] so the controller's
  /// coalescer can consume one value. Computes the screen-space AABB
  /// and the photo-space AABB once, then derives the four booleans —
  /// so a transform tick pays for one forward bbox, one matrix
  /// inversion, and one inverse bbox regardless of how many
  /// `canSwipe` queries follow.
  ///
  /// `screen` is the AABB of the transformed content rect against the
  /// viewport (forward projection). `content` is the AABB of the
  /// viewport rect pulled back into photo space (inverse projection),
  /// checked against the photo's logical extents `[0, viewport.width]`
  /// / `[0, viewport.height]`. The latter answers "has the user
  /// reached the photo's logical edge in the photo's own frame?",
  /// independent of rotation — including past 90° where forward-
  /// projecting the photo's edges would give the wrong answer.
  ({
    ViewfinderScaleState scale,
    bool hScreen,
    bool vScreen,
    bool hContent,
    bool vContent,
  })
  _swipeSignals() {
    final scale = scaleState;
    if (scale == .initial || _viewportSize.isEmpty) {
      return (
        scale: scale,
        hScreen: true,
        vScreen: true,
        hContent: true,
        vContent: true,
      );
    }
    const epsilon = 0.5;
    final m = _transformation.value;
    final viewport = _viewportSize;
    // Singular matrices (e.g., scale 0 forced via jumpToTransform) have
    // no inverse; surrender all gates rather than throwing inside the
    // transform listener. The clamp keeps regular gestures away from
    // this state, so this only fires for caller-supplied transforms.
    if (m.determinant() == 0) {
      return (
        scale: scale,
        hScreen: true,
        vScreen: true,
        hContent: true,
        vContent: true,
      );
    }
    final bbox = contentBbox(m, viewport);
    final photoBbox = contentBbox(Matrix4.inverted(m), viewport);
    return (
      scale: scale,
      hScreen:
          bbox.maxX - bbox.minX <= viewport.width + epsilon ||
          bbox.minX >= -epsilon ||
          bbox.maxX <= viewport.width + epsilon,
      vScreen:
          bbox.maxY - bbox.minY <= viewport.height + epsilon ||
          bbox.minY >= -epsilon ||
          bbox.maxY <= viewport.height + epsilon,
      hContent:
          photoBbox.minX <= epsilon ||
          photoBbox.maxX >= viewport.width - epsilon,
      vContent:
          photoBbox.minY <= epsilon ||
          photoBbox.maxY >= viewport.height - epsilon,
    );
  }

  void _animateTo(Matrix4 target) {
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
    final target = nextDoubleTapScale(
      scales: widget.doubleTapScales,
      currentScale: currentScale,
    );
    final clamped = target.clamp(widget.minScale, widget.maxScale).toDouble();
    final base = widget.initialScale.baseScale;
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
    _transformation.value = _initialMatrix();
  }

  void animateToScale(double scale, {Offset? focal}) {
    final clamped = scale.clamp(widget.minScale, widget.maxScale).toDouble();
    final size = switch (context.findRenderObject()) {
      final RenderBox b => b.size,
      _ => Size.zero,
    };
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    final base = widget.initialScale.baseScale;
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
    _transformation.value = target;
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
        flightShuttleBuilder: hero.flightShuttleBuilder,
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
        onDoubleTapDown: onDoubleTapDown,
        onDoubleTap: onDoubleTap,
        child: ZoomableViewport(
          transformationController: transformation,
          minScale: spec.minScale,
          maxScale: spec.maxScale,
          panEnabled: spec.panEnabled,
          scaleEnabled: spec.scaleEnabled,
          rotateEnabled: spec.rotateEnabled,
          clipBehavior: .none,
          interactionEndFrictionCoefficient:
              spec.interactionEndFrictionCoefficient,
          canPan: spec.canPan,
          rubberBandPan: spec.rubberBandPan,
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (ctx, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      Widget img = Image(
        image: image,
        fit: boxFit,
        width: size.width,
        height: size.height,
        filterQuality: filterQuality,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        gaplessPlayback: gaplessPlayback,
        // When a thumb is provided, wrap the main image in a
        // frame-aware fade-in so the thumb shows through until the
        // main's first frame arrives.
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
              width: size.width,
              height: size.height,
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
    },
  );
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
  ({
    ViewfinderScaleState scale,
    bool hScreen,
    bool vScreen,
    bool hContent,
    bool vContent,
  })?
  _lastSignal;

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

  /// Current magnification (1.0 = initial).
  double get scale => _state?.currentScale ?? 1.0;

  /// Whether the user has zoomed in past the initial scale.
  ViewfinderScaleState get scaleState => _state?.scaleState ?? .initial;

  /// True when a page swipe along [axis] can reasonably take over;
  /// returns `true` while detached. See [SwipeEdgeMode] for how
  /// rotation is interpreted.
  ///
  /// Reads from the coalesced snapshot the controller's listeners
  /// observed, so a listener that calls `canSwipe` right after being
  /// notified does not pay for the bbox/inverse-bbox computation a
  /// second time. Falls back to the live state for the rare pre-first-
  /// bump read (controller attached, no transform tick yet).
  bool canSwipe(Axis axis, {SwipeEdgeMode mode = SwipeEdgeMode.screen}) {
    final signal = _lastSignal ?? _state?._swipeSignals();
    if (signal == null) return true;
    return switch ((axis, mode)) {
      (.horizontal, .screen) => signal.hScreen,
      (.vertical, .screen) => signal.vScreen,
      (.horizontal, .content) => signal.hContent,
      (.vertical, .content) => signal.vContent,
    };
  }

  /// Animate back to the initial transform.
  void reset() => _state?.reset();

  /// Jump back to the initial transform instantly, without animation.
  /// Intended for Hero-transition coherence: if the user is popping the
  /// route while zoomed, animation would leave the Hero source rect out
  /// of sync with the target; jumping avoids the glitch.
  void jumpToInitial() => _state?.jumpToInitial();

  /// Animate to a specific scale, optionally around a focal point.
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
