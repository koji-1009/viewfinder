import 'package:flutter/material.dart';

import 'hero.dart';
import 'initial_scale.dart';
import 'internal/matrix_utils.dart';
import 'internal/zoomable_viewport.dart';

export 'internal/zoomable_viewport.dart' show kViewfinderDefaultFlingDrag;

/// Callback fired with the current transformation scale.
typedef ViewfinderScaleChanged = void Function(double scale);

/// A single zoomable, pannable viewer for images or arbitrary widgets.
///
/// Pinch zoom, pan, and double-tap zoom are delegated to
/// [InteractiveViewer] + a light custom double-tap handler. Suitable as a
/// standalone viewer or as a page inside `Viewfinder`.
class ViewfinderImage extends StatefulWidget {
  /// Displays an [ImageProvider]. The most common constructor.
  const ViewfinderImage({
    super.key,
    required ImageProvider this.image,
    this.thumbImage,
    this.initialScale = const .contain(),
    this.doubleTapScales = const [1.0, 2.5, 5.0],
    this.minScale = 1.0,
    this.maxScale = 8.0,
    this.backgroundColor = Colors.black,
    this.hero,
    this.filterQuality = .medium,
    this.loadingBuilder,
    this.errorBuilder,
    this.onScaleChanged,
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
    this.thumbCrossFadeDuration = const Duration(milliseconds: 200),
  }) : child = null,
       assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(interactionEndFrictionCoefficient > 0);

  /// Displays an arbitrary [child] widget instead of an image.
  const ViewfinderImage.child({
    super.key,
    required Widget this.child,
    this.initialScale = const .contain(),
    this.doubleTapScales = const [1.0, 2.5, 5.0],
    this.minScale = 1.0,
    this.maxScale = 8.0,
    this.backgroundColor = Colors.black,
    this.hero,
    this.onScaleChanged,
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
  }) : image = null,
       thumbImage = null,
       filterQuality = .medium,
       loadingBuilder = null,
       errorBuilder = null,
       thumbCrossFadeDuration = const Duration(milliseconds: 200),
       assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(interactionEndFrictionCoefficient > 0);

  final ImageProvider? image;
  final Widget? child;

  /// Optional low-resolution image displayed while [image] is loading.
  /// As soon as the main image's first frame decodes, we cross-fade to
  /// it. Nothing is shown if both thumb and main fail to load — the
  /// usual [errorBuilder] still fires for the main image.
  final ImageProvider? thumbImage;

  /// Cross-fade duration from [thumbImage] to [image].
  final Duration thumbCrossFadeDuration;

  final ViewfinderInitialScale initialScale;

  /// Ladder of scales cycled by double-tap. `[]` disables double-tap;
  /// a two-element list behaves as a toggle; three or more cycle.
  final List<double> doubleTapScales;

  final double minScale;
  final double maxScale;
  final Color backgroundColor;
  final ViewfinderHero? hero;
  final FilterQuality filterQuality;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ViewfinderScaleChanged? onScaleChanged;

  /// Tap callbacks forwarded to the internal [GestureDetector] using
  /// Flutter's standard typedefs, so callers can listen for taps without
  /// stacking another [GestureDetector] on top.
  final GestureTapCallback? onTap;
  final GestureTapUpCallback? onTapUp;
  final GestureTapDownCallback? onTapDown;
  final ViewfinderImageController? controller;
  final bool panEnabled;
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

  final String? semanticLabel;

  @override
  State<ViewfinderImage> createState() => _ViewfinderImageState();
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
      duration: const Duration(milliseconds: 220),
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
    if (oldWidget.initialScale != widget.initialScale) {
      _transformation.value = _initialMatrix();
    }
  }

  @override
  void dispose() {
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

  double get currentScale => _transformation.value.getMaxScaleOnAxis();

  ViewfinderScaleState get scaleState {
    const eps = 0.01;
    return currentScale > widget.initialScale.baseScale + eps
        ? ViewfinderScaleState.zoomed
        : ViewfinderScaleState.initial;
  }

  /// True when a horizontal page swipe can reasonably take over: either
  /// the image is at its initial scale, or it is panned against one of
  /// its horizontal edges so further horizontal pan inside the image
  /// has no effect.
  bool get canSwipeHorizontally {
    if (scaleState == ViewfinderScaleState.initial) return true;
    if (_viewportSize.isEmpty) return true;
    final m = _transformation.value;
    final scale = m.getMaxScaleOnAxis();
    final tx = m.storage[12];
    final minTx = _viewportSize.width - scale * _viewportSize.width;
    const epsilon = 0.5;
    return tx >= -epsilon || tx <= minTx + epsilon;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewportSize != viewport) {
          _viewportSize = viewport;
          // Recompute derived state after layout settles so controller
          // listeners see the fresh canSwipeHorizontally.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.controller?._bump();
          });
        }
        return _buildContent(ctx, viewport);
      },
    );
  }

  Widget _buildContent(BuildContext context, Size viewport) {
    Widget content = switch (widget.image) {
      final ImageProvider image => LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          Widget img = Image(
            image: image,
            fit: widget.initialScale.boxFit,
            width: size.width,
            height: size.height,
            filterQuality: widget.filterQuality,
            loadingBuilder: widget.loadingBuilder,
            errorBuilder: widget.errorBuilder,
            gaplessPlayback: true,
            // When a thumb is provided, wrap the main image in a
            // frame-aware fade-in so the thumb shows through until the
            // main's first frame arrives.
            frameBuilder: widget.thumbImage == null
                ? null
                : (context, child, frame, wasSyncLoaded) {
                    return AnimatedOpacity(
                      opacity: frame == null ? 0.0 : 1.0,
                      duration: widget.thumbCrossFadeDuration,
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
          );
          if (widget.thumbImage case final thumb?) {
            img = Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: thumb,
                  fit: widget.initialScale.boxFit,
                  width: size.width,
                  height: size.height,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                img,
              ],
            );
          }
          if (widget.semanticLabel case final label?) {
            img = Semantics(label: label, image: true, child: img);
          }
          return img;
        },
      ),
      _ => widget.child!,
    };

    if (widget.hero case final hero?) {
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
      color: widget.backgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapUp: widget.onTapUp,
        onTapDown: widget.onTapDown,
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: ZoomableViewport(
          transformationController: _transformation,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          panEnabled: widget.panEnabled,
          scaleEnabled: widget.scaleEnabled,
          rotateEnabled: widget.rotateEnabled,
          clipBehavior: Clip.none,
          interactionEndFrictionCoefficient:
              widget.interactionEndFrictionCoefficient,
          canPan: widget.canPan,
          child: content,
        ),
      ),
    );
  }
}

/// External control surface for a [ViewfinderImage].
///
/// Extends [ChangeNotifier] so callers can subscribe to transform changes
/// (scale, translation, edge state) and react — for example, to unlock a
/// parent [PageView] when the image is panned against its horizontal edge.
class ViewfinderImageController extends ChangeNotifier {
  _ViewfinderImageState? _state;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _attach(_ViewfinderImageState s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  void _detach(_ViewfinderImageState s) {
    if (_disposed) return;
    if (identical(_state, s)) {
      _state = null;
      notifyListeners();
    }
  }

  /// Called by the view whenever the transformation changes.
  void _bump() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Current magnification (1.0 = initial).
  double get scale => _state?.currentScale ?? 1.0;

  /// Whether the user has zoomed in past the initial scale.
  ViewfinderScaleState get scaleState =>
      _state?.scaleState ?? ViewfinderScaleState.initial;

  /// True when a horizontal page swipe can reasonably take over.
  /// See [_ViewfinderImageState.canSwipeHorizontally] for the exact rule.
  bool get canSwipeHorizontally => _state?.canSwipeHorizontally ?? true;

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
}
