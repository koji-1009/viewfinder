import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chrome.dart';
import 'dismiss.dart';
import 'image.dart';
import 'initial_scale.dart';
import 'item.dart';
import 'page_indicator.dart';
import 'resize.dart';
import 'thumbnails.dart';

/// A swipeable gallery of zoomable photos — the main public widget.
///
/// Built on [PageView.builder] + [ViewfinderImage]. Every affordance —
/// thumbnails, page indicator, drag-to-dismiss, adjacent-page precache —
/// is opt-in via a dedicated config object.
class Viewfinder extends StatefulWidget {
  const Viewfinder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.thumbnails,
    this.indicator,
    this.dismiss,
    this.defaultResize = const .targetSize(),
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
    this.chromeFadeDuration = const Duration(milliseconds: 220),
    this.pagerAxis = .horizontal,
    this.swipeDragDevices = kViewfinderDefaultSwipeDragDevices,
  }) : assert(itemCount >= 0),
       assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(precacheAdjacent >= 0);

  final int itemCount;
  final ViewfinderItem Function(BuildContext context, int index) itemBuilder;

  final ViewfinderController? controller;
  final ViewfinderThumbnails? thumbnails;
  final ViewfinderPageIndicator? indicator;
  final ViewfinderDismiss? dismiss;

  final ViewfinderResize defaultResize;
  final ViewfinderInitialScale defaultInitialScale;
  final double minScale;
  final double maxScale;

  /// Ladder of scales cycled by double-tap. `[]` disables double-tap;
  /// a two-element list behaves as a toggle; three or more cycle.
  final List<double> doubleTapScales;
  final Color backgroundColor;
  final ValueChanged<int>? onPageChanged;
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
  /// place (`Matrix4.rotateZ`). Boundary clamping is disabled while
  /// rotated, so the photo can move off-axis. Default `false` because
  /// most photo-viewer UX expects upright photos.
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
  final Map<int, ViewfinderItem> _itemCache = {};
  final Set<int> _precached = {};
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
    final lock = !c.canSwipeHorizontally;
    if (lock != _swipeLocked) {
      setState(() => _swipeLocked = lock);
    }
    _syncChromeWithZoom();
  }

  /// Reset the current image's zoom if it's zoomed in. Returns true when
  /// a reset was performed — useful for intercepting custom back-button
  /// navigation.
  bool resetCurrentImage() {
    final c = _imageControllers[_currentIndex];
    if (c != null && c.scaleState == ViewfinderScaleState.zoomed) {
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
      _itemCache.clear();
      _precached.clear();
      // Dispose per-page controllers that are now out of range.
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

  ViewfinderItem _itemAt(int index) =>
      _itemCache.putIfAbsent(index, () => widget.itemBuilder(context, index));

  Size? _viewportSize() {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  void _precacheAround(int index) {
    if (widget.precacheAdjacent == 0) return;
    final viewport = _viewportSize();
    if (viewport == null || viewport.isEmpty) {
      // Layout not ready yet — retry after the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheAround(index);
      });
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (var delta = 1; delta <= widget.precacheAdjacent; delta++) {
      for (final i in [index - delta, index + delta]) {
        if (i < 0 || i >= widget.itemCount) continue;
        if (_precached.contains(i)) continue;
        final item = _itemAt(i);
        if (item.image case final image?) {
          _precached.add(i);
          // Use the same ViewfinderResize the gallery will render with,
          // so the cache key matches what the Image widget asks for.
          final resize = item.resize ?? widget.defaultResize;
          final provider = resize.apply(image, viewport, dpr);
          precacheImage(
            provider,
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
    setState(() {
      _currentIndex = index;
      // Re-derive swipe lock for the new page's current state.
      final c = _imageControllers[index];
      _swipeLocked = c != null && !c.canSwipeHorizontally;
    });
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
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(i);
    }
  }

  // Still exposed to users through FpvPhotoView.onScaleChanged; internal
  // swipe-lock decisions go through the controller listener above.
  void _onScaleChanged(double scale) {}

  void _handleEscape() {
    // Two-stage Esc: first collapse any zoom so the Hero transition
    // from here back out stays coherent. Only then dismiss.
    if (resetCurrentImage()) return;
    widget.dismiss?.onDismiss();
  }

  Widget _buildPage(BuildContext context, int index) {
    final item = _itemAt(index);
    final initialScale = item.initialScale ?? widget.defaultInitialScale;
    final minScale = item.minScale ?? widget.minScale;
    final maxScale = item.maxScale ?? widget.maxScale;

    final imageController = _imageControllerFor(index);

    // Only the currently-visible page carries a Hero tag. PageView
    // pre-builds neighbors (especially with allowImplicitScrolling), and
    // if those carried Heroes too, every adjacent-grid thumbnail would
    // fly on pop.
    final heroTag = index == _currentIndex ? item.heroTag : null;

    // Gate: ask the gesture recognizer to reject single-pointer pan
    // along the pager axis when the parent [PageView] should take over.
    // Yielding (returning false) hands the pointer to the gesture arena
    // so the pager's drag recognizer can claim it. Pinches (two-pointer
    // gestures) bypass this gate inside the recognizer.
    bool canPan(Axis axis, int sign) {
      // Only consult for the axis the PageView scrolls on; the other
      // axis is always allowed inside the image.
      if (axis != widget.pagerAxis) return true;
      // Adjacent pre-built pages always allow their own pan.
      if (index != _currentIndex) return true;
      // Not zoomed: yield to the pager.
      //
      // For touch this is symmetric with the previous "let scale handle
      // it as usual" behavior because the pager's drag recognizer wins
      // the arena at touch-slop, well before the scale recognizer
      // accepts at the larger pan-slop. For mouse the precise pointer
      // pan-slop (4 px) is small enough that the scale recognizer
      // would otherwise race and steal the gesture, blocking
      // mouse-drag page swipes on web/desktop.
      final state = imageController.scaleState;
      if (state == ViewfinderScaleState.initial) return false;
      // Zoomed and at the relevant edge: cede to PageView only if a
      // page exists in the drag direction (otherwise stay inside).
      final atBoundary = imageController.canSwipeHorizontally;
      if (!atBoundary) return true;
      final targetIndex = _currentIndex + (sign > 0 ? -1 : 1);
      // sign > 0 = finger moved positive → content pulled right/down →
      // user wants previous page. Mirror for sign < 0.
      return targetIndex < 0 || targetIndex >= widget.itemCount;
    }

    final page = switch (item.image) {
      final ImageProvider image => ViewfinderImage(
        image: image,
        thumbImage: item.thumbImage,
        resize: item.resize ?? widget.defaultResize,
        initialScale: initialScale,
        doubleTapScales: widget.doubleTapScales,
        heroTag: heroTag,
        loadingBuilder: item.loadingBuilder,
        errorBuilder: item.errorBuilder,
        minScale: minScale,
        maxScale: maxScale,
        semanticLabel: item.semanticLabel,
        onScaleChanged: _onScaleChanged,
        controller: imageController,
        canPan: canPan,
        rotateEnabled: widget.rotateEnabled,
        interactionEndFrictionCoefficient:
            widget.interactionEndFrictionCoefficient,
        backgroundColor: Colors.transparent,
      ),
      _ => ViewfinderImage.child(
        initialScale: initialScale,
        doubleTapScales: widget.doubleTapScales,
        heroTag: heroTag,
        minScale: minScale,
        maxScale: maxScale,
        semanticLabel: item.semanticLabel,
        onScaleChanged: _onScaleChanged,
        controller: imageController,
        canPan: canPan,
        rotateEnabled: widget.rotateEnabled,
        interactionEndFrictionCoefficient:
            widget.interactionEndFrictionCoefficient,
        backgroundColor: Colors.transparent,
        child: item.child!,
      ),
    };

    return widget.pageSpacing > 0
        ? Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.pageSpacing / 2),
            child: page,
          )
        : page;
  }

  Widget _withThumbnails(
    Widget main,
    Widget bar,
    ViewfinderThumbnailPosition pos,
  ) => switch (pos) {
    ViewfinderThumbnailPosition.bottom => Column(
      children: [
        Expanded(child: main),
        bar,
      ],
    ),
    ViewfinderThumbnailPosition.top => Column(
      children: [
        bar,
        Expanded(child: main),
      ],
    ),
    ViewfinderThumbnailPosition.left => Row(
      children: [
        bar,
        Expanded(child: main),
      ],
    ),
    ViewfinderThumbnailPosition.right => Row(
      children: [
        Expanded(child: main),
        bar,
      ],
    ),
  };

  Widget _wrapChrome(Widget child) {
    final chrome = _chrome;
    if (chrome == null) return child;
    return AnimatedBuilder(
      animation: chrome,
      builder: (_, c) => IgnorePointer(
        ignoring: !chrome.visible,
        child: AnimatedOpacity(
          opacity: chrome.visible ? 1.0 : 0.0,
          duration: widget.chromeFadeDuration,
          child: c,
        ),
      ),
      child: child,
    );
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
          itemCount: widget.itemCount,
          onPageChanged: _onPageChanged,
          allowImplicitScrolling: widget.allowImplicitScrolling,
          physics: _swipeLocked
              ? const NeverScrollableScrollPhysics()
              : widget.scrollPhysics ?? const PageScrollPhysics(),
          itemBuilder: _buildPage,
        ),
      ),
    );

    // Tap anywhere on the pager area toggles chrome visibility.
    if (_chrome != null) {
      pager = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _onChromeToggleRequested,
        child: pager,
      );
    }

    // `slideType: onlyImage` wraps Dismissible around the pager so the
    // thumbnails / indicator / chromeOverlays stay put during the
    // drag-to-dismiss gesture.
    if (widget.dismiss case final dismiss?
        when dismiss.slideType == ViewfinderDismissSlideType.onlyImage) {
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
      body = Stack(
        fit: StackFit.expand,
        children: [
          body,
          _wrapChrome(Stack(fit: StackFit.expand, children: overlayChildren)),
        ],
      );
    }

    if (widget.thumbnails case final thumbs?) {
      final bar = _wrapChrome(
        ViewfinderThumbnailBar(
          config: thumbs,
          itemCount: widget.itemCount,
          currentIndex: _currentIndex,
          itemAt: _itemAt,
          onSelect: _goTo,
        ),
      );
      body = _withThumbnails(body, bar, thumbs.position);
    }

    // `slideType: wholePage` (default) wraps Dismissible around the
    // full body so thumbnails and overlays slide together.
    if (widget.dismiss case final dismiss?
        when dismiss.slideType == ViewfinderDismissSlideType.wholePage) {
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
    final anyZoomed =
        _imageControllers[_currentIndex]?.scaleState ==
        ViewfinderScaleState.zoomed;
    body = PopScope<Object?>(
      canPop: !anyZoomed,
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
  ViewfinderController({int initialIndex = 0}) : _currentIndex = initialIndex;

  _ViewfinderState? _state;
  int _currentIndex;

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

  void jumpTo(int index) => _state?._goTo(index, animate: false);
  void animateTo(int index) => _state?._goTo(index, animate: true);

  /// Reset the current page's zoom if it is zoomed in.
  ///
  /// Returns `true` when a reset actually happened — useful for
  /// intercepting a back-button press so the first press collapses the
  /// zoom and only the second one actually navigates away.
  bool resetCurrentImage() => _state?.resetCurrentImage() ?? false;
}
