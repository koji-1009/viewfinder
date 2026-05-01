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
///
/// Sealed: the public ctors are factories returning private final
/// subclasses ([ViewfinderProviderImage] / [ViewfinderChildImage]).
/// External code can pattern-match on the variant where useful, but
/// `find.byType(ViewfinderImage)` will not match — use
/// `find.byWidgetPredicate((w) => w is ViewfinderImage)` instead.
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
  }) = ViewfinderProviderImage;

  /// Displays an arbitrary [child] widget instead of an image.
  const factory ViewfinderImage.child({
    Key? key,
    required Widget child,
    ViewfinderInitialScale initialScale,
    List<double> doubleTapScales,
    double minScale,
    double maxScale,
    Color backgroundColor,
    ViewfinderHero? hero,
    ViewfinderScaleChanged? onScaleChanged,
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
  }) = ViewfinderChildImage;

  final ViewfinderInitialScale initialScale;

  /// Ladder of scales cycled by double-tap. `[]` disables double-tap;
  /// a two-element list behaves as a toggle; three or more cycle.
  final List<double> doubleTapScales;

  final double minScale;
  final double maxScale;
  final Color backgroundColor;
  final ViewfinderHero? hero;
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

/// `ImageProvider`-backed [ViewfinderImage] variant.
final class ViewfinderProviderImage extends ViewfinderImage {
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
    this.thumbCrossFadeDuration = const .new(milliseconds: 200),
  }) : super._();

  final ImageProvider image;

  /// Optional low-resolution image displayed while [image] is loading.
  /// As soon as the main image's first frame decodes, we cross-fade to
  /// it. Nothing is shown if both thumb and main fail to load — the
  /// usual [errorBuilder] still fires for the main image.
  final ImageProvider? thumbImage;

  final FilterQuality filterQuality;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Cross-fade duration from [thumbImage] to [image].
  final Duration thumbCrossFadeDuration;
}

/// Custom-widget [ViewfinderImage] variant.
final class ViewfinderChildImage extends ViewfinderImage {
  const ViewfinderChildImage({
    super.key,
    required this.child,
    super.initialScale,
    super.doubleTapScales,
    super.minScale,
    super.maxScale,
    super.backgroundColor,
    super.hero,
    super.onScaleChanged,
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
  }) : super._();

  final Widget child;
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

  double get currentScale => xyScale(_transformation.value);

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
    final scale = xyScale(m);
    final tx = m.storage[12];
    final minTx = _viewportSize.width - scale * _viewportSize.width;
    const epsilon = 0.5;
    return tx >= -epsilon || tx <= minTx + epsilon;
  }

  /// Vertical-axis counterpart of [canSwipeHorizontally] — true when the
  /// image is at its initial scale or panned against one of its vertical
  /// edges. The gallery consults this when its `pagerAxis` is vertical.
  bool get canSwipeVertically {
    if (scaleState == ViewfinderScaleState.initial) return true;
    if (_viewportSize.isEmpty) return true;
    final m = _transformation.value;
    final scale = xyScale(m);
    final ty = m.storage[13];
    final minTy = _viewportSize.height - scale * _viewportSize.height;
    const epsilon = 0.5;
    return ty >= -epsilon || ty <= minTy + epsilon;
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
  Widget build(BuildContext context) => LayoutBuilder(
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
      ) =>
        _ImageWithOptionalThumb(
          image: image,
          thumb: thumbImage,
          boxFit: spec.initialScale.boxFit,
          filterQuality: filterQuality,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
          thumbCrossFadeDuration: thumbCrossFadeDuration,
          semanticLabel: spec.semanticLabel,
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
    required this.semanticLabel,
  });

  final ImageProvider image;
  final ImageProvider? thumb;
  final BoxFit boxFit;
  final FilterQuality filterQuality;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final Duration thumbCrossFadeDuration;
  final String? semanticLabel;

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
        gaplessPlayback: true,
        // When a thumb is provided, wrap the main image in a
        // frame-aware fade-in so the thumb shows through until the
        // main's first frame arrives.
        frameBuilder: thumb == null
            ? null
            : (context, child, frame, wasSyncLoaded) => AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: thumbCrossFadeDuration,
                curve: Curves.easeOut,
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
/// to fire only when [scaleState], [canSwipeHorizontally], or
/// [canSwipeVertically] actually transitions — not on every transform
/// frame. For per-frame scale callbacks, use
/// [ViewfinderImage.onScaleChanged].
class ViewfinderImageController extends ChangeNotifier {
  _ViewfinderImageState? _state;
  bool _disposed = false;
  ({ViewfinderScaleState scale, bool h, bool v})? _lastSignal;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Lifecycle hooks do not call notifyListeners — neither attach nor
  // detach changes any user-observable property at the moment they fire.
  // Real state changes (transform, scaleState, canSwipe*) flow through
  // [_bump] from the transform-controller listener.
  void _attach(_ViewfinderImageState s) {
    if (_disposed) return;
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
  /// transition.
  void _bump() {
    if (_disposed) return;
    final s = _state;
    final next = s == null
        ? null
        : (
            scale: s.scaleState,
            h: s.canSwipeHorizontally,
            v: s.canSwipeVertically,
          );
    if (next == _lastSignal) return;
    _lastSignal = next;
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

  /// Vertical counterpart of [canSwipeHorizontally]; consulted when the
  /// gallery's `pagerAxis` is vertical.
  bool get canSwipeVertically => _state?.canSwipeVertically ?? true;

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
