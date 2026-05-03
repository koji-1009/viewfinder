import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chrome.dart';
import 'dismiss.dart';
import 'hero.dart';
import 'image.dart';
import 'initial_scale.dart';
import 'internal/chrome_fade.dart';
import 'internal/dismissible.dart';
import 'internal/page_indicator_overlay.dart';
import 'internal/thumbnail_bar.dart';
import 'internal/thumbnail_frame.dart';
import 'internal/viewfinder_page.dart';
import 'item.dart';
import 'page_indicator.dart';
import 'thumbnails.dart';

/// A swipeable gallery of zoomable photos — the main public widget.
///
/// Built on [PageView.builder] + [ViewfinderImage]. Every affordance —
/// thumbnails, page indicator, drag-to-dismiss, adjacent-page precache —
/// is opt-in via a dedicated config object.
class Viewfinder extends StatefulWidget {
  /// Creates a swipeable photo gallery. [itemCount] and [itemBuilder]
  /// are required; every other parameter is opt-in.
  const Viewfinder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.thumbnails,
    this.indicator,
    this.dismiss,
    this.defaultInitialScale = const .contain(),
    this.minScale = 1.0,
    this.maxScale = 8.0,
    this.doubleTapScales = const [1.0, 2.5, 5.0],
    this.backgroundColor = Colors.black,
    this.onPageChanged,
    this.pageSpacing = 0,
    this.precacheAdjacent = 1,
    this.allowImplicitScrolling = true,
    this.scrollPhysics,
    this.enableKeyboardShortcuts = true,
    this.autofocus = true,
    this.rotateEnabled = false,
    this.interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    this.chromeController,
    this.chromeOverlays = const <Widget>[],
    this.chromeFadeDuration = const .new(milliseconds: 220),
    this.pagerAxis = .horizontal,
    this.swipeDragDevices = kViewfinderDefaultSwipeDragDevices,
    this.reverse = false,
    this.allowEdgeHandoff = true,
    this.rubberBandPan = true,
  }) : assert(itemCount >= 0),
       assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(precacheAdjacent >= 0),
       assert(
         pagerAxis != Axis.vertical || dismiss == null,
         'Axis.vertical pagerAxis conflicts with ViewfinderDismiss: both '
         'consume vertical drags. Pick one (use a horizontal pager, or '
         'drop dismiss when running a vertical pager).',
       );

  /// Quick gallery from a flat list of [ImageProvider]s.
  ///
  /// Equivalent to passing `itemCount: images.length` and an
  /// `itemBuilder` that wraps each provider in a [ViewfinderItem]. The
  /// per-item callbacks ([loadingBuilder], [errorBuilder], [hero],
  /// [semanticLabel], [thumbImage]) and the image-display knobs
  /// ([gaplessPlayback], [thumbCrossFadeDuration], [thumbCrossFadeCurve])
  /// apply to every page; for per-page overrides on `initialScale` /
  /// `minScale` / `maxScale` etc., use the main constructor with a
  /// custom `itemBuilder`.
  factory Viewfinder.images(
    List<ImageProvider> images, {
    Key? key,
    ViewfinderController? controller,
    ViewfinderThumbnails? thumbnails,
    ViewfinderPageIndicator? indicator,
    ViewfinderDismiss? dismiss,
    ViewfinderInitialScale defaultInitialScale = const .contain(),
    double minScale = 1.0,
    double maxScale = 8.0,
    List<double> doubleTapScales = const [1.0, 2.5, 5.0],
    Color backgroundColor = Colors.black,
    ValueChanged<int>? onPageChanged,
    double pageSpacing = 0,
    int precacheAdjacent = 1,
    bool allowImplicitScrolling = true,
    ScrollPhysics? scrollPhysics,
    bool enableKeyboardShortcuts = true,
    bool autofocus = true,
    bool rotateEnabled = false,
    double interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    ViewfinderChromeController? chromeController,
    List<Widget> chromeOverlays = const <Widget>[],
    Duration chromeFadeDuration = const .new(milliseconds: 220),
    Axis pagerAxis = .horizontal,
    Set<PointerDeviceKind> swipeDragDevices =
        kViewfinderDefaultSwipeDragDevices,
    bool reverse = false,
    bool allowEdgeHandoff = true,
    bool rubberBandPan = true,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ViewfinderHero Function(int index)? hero,
    String Function(int index)? semanticLabel,
    ImageProvider Function(int index)? thumbImage,
    Duration thumbCrossFadeDuration = const .new(milliseconds: 200),
    Curve thumbCrossFadeCurve = Curves.easeOut,
    bool gaplessPlayback = true,
  }) {
    return Viewfinder(
      key: key,
      itemCount: images.length,
      itemBuilder: (context, i) => ViewfinderItem(
        image: images[i],
        thumbImage: thumbImage?.call(i),
        hero: hero?.call(i),
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        semanticLabel: semanticLabel?.call(i),
        thumbCrossFadeDuration: thumbCrossFadeDuration,
        thumbCrossFadeCurve: thumbCrossFadeCurve,
        gaplessPlayback: gaplessPlayback,
      ),
      controller: controller,
      thumbnails: thumbnails,
      indicator: indicator,
      dismiss: dismiss,
      defaultInitialScale: defaultInitialScale,
      minScale: minScale,
      maxScale: maxScale,
      doubleTapScales: doubleTapScales,
      backgroundColor: backgroundColor,
      onPageChanged: onPageChanged,
      pageSpacing: pageSpacing,
      precacheAdjacent: precacheAdjacent,
      allowImplicitScrolling: allowImplicitScrolling,
      scrollPhysics: scrollPhysics,
      enableKeyboardShortcuts: enableKeyboardShortcuts,
      autofocus: autofocus,
      rotateEnabled: rotateEnabled,
      interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
      chromeController: chromeController,
      chromeOverlays: chromeOverlays,
      chromeFadeDuration: chromeFadeDuration,
      pagerAxis: pagerAxis,
      swipeDragDevices: swipeDragDevices,
      reverse: reverse,
      allowEdgeHandoff: allowEdgeHandoff,
      rubberBandPan: rubberBandPan,
    );
  }

  /// Quick single-image viewer with optional drag-to-dismiss and chrome.
  ///
  /// Equivalent to a 1-item gallery. Strips out the gallery-only knobs
  /// (`thumbnails`, `indicator`, `pagerAxis`, paging-related options)
  /// since they have no effect with a single page; everything that still
  /// matters — `dismiss`, `chromeController`, `chromeOverlays`,
  /// `controller`, scale knobs — is forwarded.
  factory Viewfinder.single({
    Key? key,
    required ImageProvider image,
    ImageProvider? thumbImage,
    ViewfinderHero? hero,
    String? semanticLabel,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ViewfinderController? controller,
    ViewfinderDismiss? dismiss,
    ViewfinderInitialScale defaultInitialScale = const .contain(),
    double minScale = 1.0,
    double maxScale = 8.0,
    List<double> doubleTapScales = const [1.0, 2.5, 5.0],
    Color backgroundColor = Colors.black,
    bool enableKeyboardShortcuts = true,
    bool autofocus = true,
    bool rotateEnabled = false,
    double interactionEndFrictionCoefficient = kViewfinderDefaultFlingDrag,
    ViewfinderChromeController? chromeController,
    List<Widget> chromeOverlays = const <Widget>[],
    Duration chromeFadeDuration = const .new(milliseconds: 220),
    Duration thumbCrossFadeDuration = const .new(milliseconds: 200),
    Curve thumbCrossFadeCurve = Curves.easeOut,
    bool gaplessPlayback = true,
  }) {
    return Viewfinder(
      key: key,
      itemCount: 1,
      itemBuilder: (context, _) => ViewfinderItem(
        image: image,
        thumbImage: thumbImage,
        hero: hero,
        semanticLabel: semanticLabel,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        thumbCrossFadeDuration: thumbCrossFadeDuration,
        thumbCrossFadeCurve: thumbCrossFadeCurve,
        gaplessPlayback: gaplessPlayback,
      ),
      controller: controller,
      dismiss: dismiss,
      defaultInitialScale: defaultInitialScale,
      minScale: minScale,
      maxScale: maxScale,
      doubleTapScales: doubleTapScales,
      backgroundColor: backgroundColor,
      enableKeyboardShortcuts: enableKeyboardShortcuts,
      autofocus: autofocus,
      rotateEnabled: rotateEnabled,
      interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
      chromeController: chromeController,
      chromeOverlays: chromeOverlays,
      chromeFadeDuration: chromeFadeDuration,
    );
  }

  /// Number of pages in the gallery.
  final int itemCount;

  /// Builds the [ViewfinderItem] shown at the given page index.
  final ViewfinderItem Function(BuildContext context, int index) itemBuilder;

  /// Optional [ViewfinderController] for programmatic page changes
  /// (`jumpTo` / `animateTo`) and zoom reset.
  final ViewfinderController? controller;

  /// Optional thumbnail strip — see [ViewfinderThumbnails].
  final ViewfinderThumbnails? thumbnails;

  /// Optional page indicator — see [ViewfinderPageIndicator].
  final ViewfinderPageIndicator? indicator;

  /// Optional drag-to-dismiss configuration.
  final ViewfinderDismiss? dismiss;

  /// Initial scale applied to every page unless overridden by the item's
  /// own [ViewfinderItem.initialScale].
  final ViewfinderInitialScale defaultInitialScale;

  /// Smallest allowed scale (relative to the initial-scale baseline).
  final double minScale;

  /// Largest allowed scale (relative to the initial-scale baseline).
  final double maxScale;

  /// Ladder of scales cycled by double-tap. `[]` disables double-tap;
  /// a two-element list behaves as a toggle; three or more cycle.
  final List<double> doubleTapScales;

  /// Color painted behind every page.
  final Color backgroundColor;

  /// Fired with the new index whenever the displayed page changes.
  final ValueChanged<int>? onPageChanged;

  /// Spacing in logical pixels between adjacent pages within the pager.
  final double pageSpacing;

  /// Number of pages to `precacheImage` on each side of the current page.
  /// Setting to 0 disables precaching.
  final int precacheAdjacent;

  /// Forwarded to [PageView.allowImplicitScrolling].
  final bool allowImplicitScrolling;

  /// Optional custom physics. When null, a standard `PageScrollPhysics`
  /// is used — and swapped out for [NeverScrollableScrollPhysics] while
  /// any page is zoomed.
  final ScrollPhysics? scrollPhysics;

  /// When true, hardware keyboards can drive the gallery:
  /// - Left / Right arrows: previous / next page
  /// - Escape: fire the configured `dismiss.onDismiss` (if any)
  ///
  /// Useful primarily on desktop and web.
  final bool enableKeyboardShortcuts;

  /// Whether the gallery should grab focus automatically so keyboard
  /// shortcuts work without the user tapping first.
  final bool autofocus;

  /// When true, a two-finger rotation gesture rotates the photo in
  /// place (`Matrix4.rotateZ`). Boundary clamping continues to apply
  /// against the rotated content's axis-aligned bounding box, so the
  /// photo cannot be panned fully off-screen even at odd rotations.
  /// Default `false` because most photo-viewer UX expects upright
  /// photos.
  final bool rotateEnabled;

  /// Drag coefficient for the post-release fling animation on each
  /// page. Same role and default as on [ViewfinderImage].
  final double interactionEndFrictionCoefficient;

  /// Optional [ViewfinderChromeController] that drives visibility of
  /// thumbnails, the page indicator, and [chromeOverlays]. When `null`,
  /// the gallery keeps chrome visible unconditionally.
  final ViewfinderChromeController? chromeController;

  /// Extra widgets (AppBar, caption, close button, …) whose visibility
  /// is tied to [chromeController]. They're painted over the pager in
  /// a [Stack], each respecting its own [Positioned]ing.
  final List<Widget> chromeOverlays;

  /// Cross-fade duration when [chromeController] toggles visibility.
  final Duration chromeFadeDuration;

  /// Axis on which the gallery's [PageView] scrolls. Passed to the
  /// underlying `PageView.scrollDirection` and also consulted by the
  /// image's boundary-yield logic so zoom→swipe hand-off works on the
  /// correct axis.
  ///
  /// `Axis.vertical` competes with [ViewfinderDismiss] (which also reads
  /// vertical drags) in the gesture arena. Combining them produces
  /// non-deterministic gesture pickup; use one or the other.
  final Axis pagerAxis;

  /// Pointer kinds that can drag the underlying [PageView] to switch
  /// pages. Defaults to [kViewfinderDefaultSwipeDragDevices], which
  /// includes every kind — so on Flutter web/desktop a mouse drag
  /// swipes between pages, matching native photo-viewer expectations.
  /// Flutter's default `ScrollBehavior` excludes mouse from drag
  /// devices, hence the override.
  ///
  /// Pass a narrower set to restrict — for example, drop
  /// [PointerDeviceKind.mouse] if the gallery is embedded in a layout
  /// where mouse-drag should select surrounding text instead.
  final Set<PointerDeviceKind> swipeDragDevices;

  /// Reverses the order pages are shown in. Forwarded to
  /// [PageView.reverse]. Useful for right-to-left galleries.
  final bool reverse;

  /// When `true` (default), a zoomed image's pan against its boundary
  /// yields the gesture so the parent [PageView] takes over (zoom-to-
  /// next-page handoff). When `false`, the image consumes all pan
  /// gestures while zoomed; the user must reset zoom before swiping
  /// to the next page.
  final bool allowEdgeHandoff;

  /// When `true` (default), every page allows live elastic over-pan
  /// at its edges that snaps back on release. When `false`, every
  /// page hard-clamps with no elastic give. Forwarded to each
  /// page's [ViewfinderImage.rubberBandPan].
  final bool rubberBandPan;

  @override
  State<Viewfinder> createState() => _ViewfinderState();
}

/// Default value for [Viewfinder.swipeDragDevices]: every pointer kind.
const Set<PointerDeviceKind> kViewfinderDefaultSwipeDragDevices =
    <PointerDeviceKind>{
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    };

class _ViewfinderState extends State<Viewfinder> {
  late ViewfinderController _controller;
  late PageController _pageController;
  bool _ownsController = false;
  int _currentIndex = 0;
  bool _swipeLocked = false;
  final Set<int> _precached = {};
  // Index-keyed: each PageView slot owns a distinct controller, so the
  // single-state-attached invariant of `ViewfinderImageController` is
  // preserved even when two slots happen to render the same content.
  // The "transform follows the photo" guarantee on re-order is handled
  // separately by `ViewfinderImage`'s own content-swap reset.
  final Map<int, ViewfinderImageController> _imageControllers = {};

  ViewfinderChromeController? get _chrome => widget.chromeController;

  void _onChromeToggleRequested() {
    final chrome = _chrome;
    if (chrome == null) return;
    chrome.toggle();
  }

  void _bumpChrome() {
    _chrome?.bumpAutoHide();
  }

  void _syncChromeWithZoom() {
    final chrome = _chrome;
    if (chrome == null) return;
    if (!chrome.autoHideWhileZoomed) return;
    final zoomed = _imageControllers[_currentIndex]?.scaleState == .zoomed;
    if (zoomed && chrome.visible) {
      chrome.hide();
    }
  }

  ViewfinderImageController _imageControllerFor(int index) {
    return _imageControllers.putIfAbsent(index, () {
      final c = ViewfinderImageController();
      c.addListener(() => _onImageControllerUpdate(index));
      return c;
    });
  }

  void _onImageControllerUpdate(int index) {
    if (index != _currentIndex) return;
    final c = _imageControllers[index];
    if (c == null) return;
    final lock = !_canSwipeAlongPager(c);
    if (lock != _swipeLocked) {
      setState(() => _swipeLocked = lock);
    }
    _syncChromeWithZoom();
  }

  bool _canSwipeAlongPager(ViewfinderImageController c) =>
      c.canSwipe(widget.pagerAxis);

  /// Reset the current image's zoom if it's zoomed in. Returns true when
  /// a reset was performed — useful for intercepting custom back-button
  /// navigation.
  bool resetCurrentImage() {
    final c = _imageControllers[_currentIndex];
    if (c != null && c.scaleState == .zoomed) {
      c.reset();
      return true;
    }
    return false;
  }

  /// Instantly (no animation) snap every page's transform back to its
  /// initial state. Called on pop so Hero transitions don't fly from a
  /// zoomed source rect.
  void _jumpAllImagesToInitial() {
    for (final c in _imageControllers.values) {
      c.jumpToInitial();
    }
  }

  int _clampIndex(int index) {
    if (widget.itemCount == 0) return 0;
    return index.clamp(0, widget.itemCount - 1);
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ViewfinderController();
    _ownsController = widget.controller == null;
    _currentIndex = _clampIndex(_controller.currentIndex);
    _pageController = PageController(initialPage: _currentIndex);
    _controller._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAround(_currentIndex);
  }

  @override
  void didUpdateWidget(covariant Viewfinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      if (_ownsController) _controller.dispose();
      _controller = widget.controller ?? ViewfinderController();
      _ownsController = widget.controller == null;
      _controller._attach(this);
    }
    if (oldWidget.itemCount != widget.itemCount) {
      _precached.clear();
      // Dispose per-slot controllers that fell off the right edge.
      final toRemove = <int>[];
      for (final entry in _imageControllers.entries) {
        if (entry.key >= widget.itemCount) toRemove.add(entry.key);
      }
      for (final k in toRemove) {
        _imageControllers.remove(k)!.dispose();
      }
      // The current page may have fallen off the right edge (itemCount
      // shrank) or the gallery may now be empty. Re-clamp so the
      // semantic label, scroll position, and PageView builder stay in
      // a consistent state.
      final clamped = _clampIndex(_currentIndex);
      if (clamped != _currentIndex) {
        _currentIndex = clamped;
        _controller._setIndex(clamped);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(clamped);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _imageControllers.values) {
      c.dispose();
    }
    _imageControllers.clear();
    _controller._detach(this);
    if (_ownsController) _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Pages are not cached: the user-supplied closure is typically a
  // fresh allocation per rebuild, so caching the first result would
  // pin the gallery to stale content if the underlying list changes
  // (re-order, swap-in) while `itemCount` stays the same. Calling
  // through is cheap because the builder returns a config object.
  ViewfinderItem _itemAt(int index) => widget.itemBuilder(context, index);

  void _precacheAround(int index) {
    if (widget.precacheAdjacent == 0) return;
    for (var delta = 1; delta <= widget.precacheAdjacent; delta++) {
      for (final i in [index - delta, index + delta]) {
        if (i < 0 || i >= widget.itemCount) continue;
        if (_precached.contains(i)) continue;
        if (_itemAt(i) case ViewfinderImageItem(:final image)) {
          _precached.add(i);
          precacheImage(
            image,
            context,
            onError: (_, _) {
              _precached.remove(i);
            },
          );
        }
      }
    }
  }

  void _onPageChanged(int index) {
    final previous = _currentIndex;
    setState(() {
      _currentIndex = index;
      // Re-derive swipe lock for the new page's current state.
      final c = _imageControllers[index];
      _swipeLocked = c != null && !_canSwipeAlongPager(c);
    });
    // The page we just left keeps its own TransformationController
    // alive (PageView retains adjacent pages). If the user had zoomed
    // it, a later swipe back would reveal the stale zoom. Snap it
    // back instantly — matches photo-viewer convention of presenting
    // every page at its initial scale.
    if (previous != index) {
      _imageControllers[previous]?.jumpToInitial();
    }
    _controller._setIndex(index);
    widget.onPageChanged?.call(index);
    _precacheAround(index);
    _bumpChrome();
  }

  void _goTo(int index, {bool animate = true}) {
    final max = widget.itemCount - 1;
    final i = max < 0 ? 0 : index.clamp(0, max);
    if (!_pageController.hasClients) return;
    if (animate) {
      _pageController.animateToPage(
        i,
        duration: const .new(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(i);
    }
  }

  void _handleEscape() {
    // Two-stage Esc: first collapse any zoom so the Hero transition
    // from here back out stays coherent. Only then dismiss.
    if (resetCurrentImage()) return;
    widget.dismiss?.onDismiss();
  }

  /// Gate: reject single-pointer pan along the pager axis when the parent
  /// [PageView] should take over. Returning `false` yields the gesture so
  /// the pager's drag recognizer can claim it. Pinches (two-pointer
  /// gestures) bypass this gate inside the recognizer.
  bool _canPanForPage(
    int index,
    ViewfinderImageController c,
    Axis axis,
    int sign,
  ) {
    // Only consult for the axis the PageView scrolls on; the other
    // axis is always allowed inside the image.
    if (axis != widget.pagerAxis) return true;
    // Adjacent pre-built pages always allow their own pan.
    if (index != _currentIndex) return true;
    // Not zoomed: yield to the pager — unconditional, regardless of
    // handoff setting. The handoff knob only governs the zoomed-edge
    // case; unzoomed swipe is part of the basic PageView contract.
    //
    // For touch this is symmetric with the previous "let scale handle
    // it as usual" behavior because the pager's drag recognizer wins
    // the arena at touch-slop, well before the scale recognizer
    // accepts at the larger pan-slop. For mouse the precise pointer
    // pan-slop (4 px) is small enough that the scale recognizer
    // would otherwise race and steal the gesture, blocking
    // mouse-drag page swipes on web/desktop.
    if (c.scaleState == .initial) return false;
    // Zoomed: handoff disabled means the image consumes all pan even
    // at the edge — user must reset zoom before swiping.
    if (!widget.allowEdgeHandoff) return true;
    // Zoomed and at the relevant edge: cede to PageView only if a
    // page exists in the drag direction (otherwise stay inside).
    if (!_canSwipeAlongPager(c)) return true;
    final targetIndex = _currentIndex + (sign > 0 ? -1 : 1);
    // sign > 0 = finger moved positive → content pulled right/down →
    // user wants previous page. Mirror for sign < 0.
    return targetIndex < 0 || targetIndex >= widget.itemCount;
  }

  @override
  Widget build(BuildContext context) {
    Widget pager = ColoredBox(
      color: widget.backgroundColor,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: widget.swipeDragDevices),
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: widget.pagerAxis,
          reverse: widget.reverse,
          itemCount: widget.itemCount,
          onPageChanged: _onPageChanged,
          allowImplicitScrolling: widget.allowImplicitScrolling,
          physics: _swipeLocked
              ? const NeverScrollableScrollPhysics()
              : widget.scrollPhysics ?? const PageScrollPhysics(),
          itemBuilder: (context, index) {
            final imageController = _imageControllerFor(index);
            return ViewfinderPage(
              item: _itemAt(index),
              isCurrent: index == _currentIndex,
              controller: imageController,
              canPan: (axis, sign) =>
                  _canPanForPage(index, imageController, axis, sign),
              defaultInitialScale: widget.defaultInitialScale,
              doubleTapScales: widget.doubleTapScales,
              defaultMinScale: widget.minScale,
              defaultMaxScale: widget.maxScale,
              rotateEnabled: widget.rotateEnabled,
              interactionEndFrictionCoefficient:
                  widget.interactionEndFrictionCoefficient,
              rubberBandPan: widget.rubberBandPan,
              pageSpacing: widget.pageSpacing,
            );
          },
        ),
      ),
    );

    // Tap anywhere on the pager area toggles chrome visibility.
    if (_chrome != null) {
      pager = GestureDetector(
        behavior: .translucent,
        onTap: _onChromeToggleRequested,
        child: pager,
      );
    }

    // `slideType: onlyImage` wraps Dismissible around the pager so the
    // thumbnails / indicator / chromeOverlays stay put during the
    // drag-to-dismiss gesture.
    if (widget.dismiss case final dismiss?
        when dismiss.slideType == .onlyImage) {
      pager = ViewfinderDismissible(
        config: dismiss,
        enabled: !_swipeLocked,
        child: pager,
      );
    }

    Widget body = pager;

    final overlayChildren = <Widget>[
      if (widget.indicator case final indicator?)
        ViewfinderPageIndicatorOverlay(
          config: indicator,
          itemCount: widget.itemCount,
          currentIndex: _currentIndex,
        ),
      ...widget.chromeOverlays,
    ];

    if (overlayChildren.isNotEmpty) {
      Widget overlayStack = Stack(fit: .expand, children: overlayChildren);
      if (_chrome case final chrome?) {
        overlayStack = ChromeFade(
          chrome: chrome,
          fadeDuration: widget.chromeFadeDuration,
          child: overlayStack,
        );
      }
      body = Stack(fit: .expand, children: [body, overlayStack]);
    }

    if (widget.thumbnails case final thumbs?) {
      Widget bar = ViewfinderThumbnailBar(
        config: thumbs,
        itemCount: widget.itemCount,
        currentIndex: _currentIndex,
        itemAt: _itemAt,
        onSelect: _goTo,
      );
      if (_chrome case final chrome?) {
        bar = ChromeFade(
          chrome: chrome,
          fadeDuration: widget.chromeFadeDuration,
          child: bar,
        );
      }
      body = ThumbnailFrame(position: thumbs.position, bar: bar, child: body);
    }

    // `slideType: wholePage` (default) wraps Dismissible around the
    // full body so thumbnails and overlays slide together.
    if (widget.dismiss case final dismiss?
        when dismiss.slideType == .wholePage) {
      body = ViewfinderDismissible(
        config: dismiss,
        enabled: !_swipeLocked,
        child: body,
      );
    }

    if (widget.enableKeyboardShortcuts) {
      body = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _goTo(_currentIndex - 1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _goTo(_currentIndex + 1),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _goTo(_currentIndex - 1),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _goTo(_currentIndex + 1),
          const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
        },
        child: Focus(autofocus: widget.autofocus, child: body),
      );
    }

    // PopScope does two things:
    //
    // 1. When a page is zoomed in, block the pop entirely so the first
    //    Android back-press / iOS back-swipe acts like the first Esc:
    //    it resets the zoom instead of leaving the gallery. A second
    //    back-press (now with scale==1) lets the pop through.
    // 2. When the pop does go through, snap all pages to identity in
    //    the callback *before* the Hero flight reads the source rect,
    //    so hero transitions stay coherent.
    final isCurrentZoomed =
        _imageControllers[_currentIndex]?.scaleState == .zoomed;
    body = PopScope<Object?>(
      canPop: !isCurrentZoomed,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _jumpAllImagesToInitial();
        } else {
          // Pop was blocked because we were zoomed. Consume the press
          // by resetting the current image's transform.
          resetCurrentImage();
        }
      },
      child: body,
    );

    final semanticLabel = widget.itemCount == 0
        ? 'Photo gallery, empty'
        : 'Photo gallery, ${_currentIndex + 1} of ${widget.itemCount}';
    return Semantics(container: true, label: semanticLabel, child: body);
  }
}

/// Controls a [Viewfinder] and publishes the current page index.
class ViewfinderController extends ChangeNotifier {
  /// Creates a controller starting at [initialIndex].
  ViewfinderController({int initialIndex = 0}) : _currentIndex = initialIndex;

  _ViewfinderState? _state;
  int _currentIndex;

  /// Index of the page currently shown by the attached [Viewfinder].
  int get currentIndex => _currentIndex;

  void _attach(_ViewfinderState s) => _state = s;
  void _detach(_ViewfinderState s) {
    if (identical(_state, s)) _state = null;
  }

  void _setIndex(int i) {
    if (_currentIndex == i) return;
    _currentIndex = i;
    notifyListeners();
  }

  /// Jump to [index] without animation. No-op if not attached.
  void jumpTo(int index) => _state?._goTo(index, animate: false);

  /// Animate to [index]. No-op if not attached.
  void animateTo(int index) => _state?._goTo(index, animate: true);

  /// Reset the current page's zoom if it is zoomed in.
  ///
  /// Returns `true` when a reset actually happened — useful for
  /// intercepting a back-button press so the first press collapses the
  /// zoom and only the second one actually navigates away.
  bool resetCurrentImage() => _state?.resetCurrentImage() ?? false;
}
