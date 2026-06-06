import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'chrome.dart';
import 'dismiss.dart';
import 'hero.dart';
import 'image.dart';
import 'initial_scale.dart';
import 'internal/chrome_fade.dart';
import 'internal/dismissible.dart';
import 'internal/keep_alive_page.dart';
import 'internal/page_indicator_overlay.dart';
import 'internal/thumbnail_bar.dart';
import 'internal/thumbnail_frame.dart';
import 'internal/viewfinder_page.dart';
import 'item.dart';
import 'keys.dart';
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
    this.onScaleStateChanged,
    this.announcePageChanges = true,
    this.pageAnnouncementBuilder,
    this.restorationId,
    this.immersiveSystemUi = false,
    this.keepAlivePages = false,
    this.mouseWheelBehavior = .zoom,
    this.decodeSizeMultiplier,
    this.dismissOnOverscroll = false,
    this.loop = false,
  }) : assert(itemCount >= 0),
       assert(minScale > 0),
       assert(maxScale >= minScale),
       assert(
         minScale <= 1.0,
         'minScale is relative to the initial scale (1.0 = the '
         'defaultInitialScale baseline). A value above 1.0 would put '
         'the initial state below the minimum bound.',
       ),
       assert(
         maxScale >= 1.0,
         'maxScale is relative to the initial scale (1.0 = the '
         'defaultInitialScale baseline). A value below 1.0 would put '
         'the initial state above the maximum bound.',
       ),
       assert(precacheAdjacent >= 0),
       assert(
         pagerAxis != Axis.vertical || dismiss == null,
         'Axis.vertical pagerAxis conflicts with ViewfinderDismiss: both '
         'consume vertical drags. Pick one (use a horizontal pager, or '
         'drop dismiss when running a vertical pager).',
       ),
       assert(decodeSizeMultiplier == null || decodeSizeMultiplier > 0),
       assert(
         !dismissOnOverscroll || dismiss != null,
         'dismissOnOverscroll fires the dismiss callback — supply a '
         'ViewfinderDismiss config to use it.',
       ),
       assert(
         !(loop && dismissOnOverscroll),
         'A looping gallery has no first/last page to overscroll past; '
         'dismissOnOverscroll can never fire with loop: true.',
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
    ViewfinderScaleStateChanged? onScaleStateChanged,
    bool announcePageChanges = true,
    ViewfinderPageAnnouncementBuilder? pageAnnouncementBuilder,
    String? restorationId,
    bool immersiveSystemUi = false,
    bool keepAlivePages = false,
    ViewfinderMouseWheelBehavior mouseWheelBehavior = .zoom,
    double? decodeSizeMultiplier,
    bool dismissOnOverscroll = false,
    bool loop = false,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ViewfinderHero Function(int index)? hero,
    String Function(int index)? semanticLabel,
    ImageProvider Function(int index)? thumbImage,
    void Function(int index)? onLongPress,
    void Function(int index, TapUpDetails details)? onSecondaryTapUp,
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
        onLongPress: onLongPress == null ? null : () => onLongPress(i),
        onSecondaryTapUp: onSecondaryTapUp == null
            ? null
            : (details) => onSecondaryTapUp(i, details),
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
      onScaleStateChanged: onScaleStateChanged,
      announcePageChanges: announcePageChanges,
      pageAnnouncementBuilder: pageAnnouncementBuilder,
      restorationId: restorationId,
      immersiveSystemUi: immersiveSystemUi,
      keepAlivePages: keepAlivePages,
      mouseWheelBehavior: mouseWheelBehavior,
      decodeSizeMultiplier: decodeSizeMultiplier,
      dismissOnOverscroll: dismissOnOverscroll,
      loop: loop,
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
    GestureLongPressCallback? onLongPress,
    GestureLongPressStartCallback? onLongPressStart,
    GestureTapUpCallback? onSecondaryTapUp,
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
    ViewfinderScaleStateChanged? onScaleStateChanged,
    bool immersiveSystemUi = false,
    ViewfinderMouseWheelBehavior mouseWheelBehavior = .zoom,
    double? decodeSizeMultiplier,
    bool dismissOnOverscroll = false,
  }) {
    return Viewfinder(
      key: key,
      itemCount: 1,
      itemBuilder: (context, _) => ViewfinderItem(
        image: image,
        thumbImage: thumbImage,
        hero: hero,
        semanticLabel: semanticLabel,
        onLongPress: onLongPress,
        onLongPressStart: onLongPressStart,
        onSecondaryTapUp: onSecondaryTapUp,
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
      onScaleStateChanged: onScaleStateChanged,
      immersiveSystemUi: immersiveSystemUi,
      mouseWheelBehavior: mouseWheelBehavior,
      decodeSizeMultiplier: decodeSizeMultiplier,
      dismissOnOverscroll: dismissOnOverscroll,
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

  /// Smallest allowed scale (relative to the initial-scale baseline;
  /// must be `<= 1.0` so the initial state stays within bounds).
  final double minScale;

  /// Largest allowed scale (relative to the initial-scale baseline;
  /// must be `>= 1.0` so the initial state stays within bounds).
  final double maxScale;

  /// Ladder of scales cycled by double-tap, relative to the
  /// initial-scale baseline. `[]` disables double-tap; a two-element
  /// list behaves as a toggle; three or more cycle.
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
  /// - Left / Right arrows: the page visually to the left / right
  ///   (follows [reverse] and, for horizontal pagers, the ambient
  ///   [Directionality]). Up / Down arrows do the same for a
  ///   vertical [pagerAxis].
  /// - PageUp / PageDown: previous / next page in logical order.
  /// - Escape: two-stage — the first press resets the current page's
  ///   zoom (if zoomed); the next fires the configured
  ///   `dismiss.onDismiss` (if any).
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
  /// [PageView.reverse].
  ///
  /// Note that a horizontal [PageView] already follows the ambient
  /// [Directionality] — under [TextDirection.rtl] pages lay out
  /// right-to-left without this flag. [reverse] flips whatever that
  /// base direction is; the gallery's edge-handoff and arrow-key
  /// mappings track the combination.
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

  /// Fired when the current page's [ViewfinderScaleState] transitions
  /// (initial ⇄ zoomed) — the hook for app chrome that reacts to zoom,
  /// e.g. hiding an AppBar or disabling a share button. Also fires on
  /// a page change when the new page's state differs from the last
  /// reported one. Coalesced: not a per-frame scale stream.
  final ViewfinderScaleStateChanged? onScaleStateChanged;

  /// When `true` (default), page changes are announced to screen
  /// readers via [SemanticsService.sendAnnouncement] — the container
  /// label update alone is not reliably spoken by TalkBack / VoiceOver
  /// on swipe. Customize (or localize) the message with
  /// [pageAnnouncementBuilder].
  final bool announcePageChanges;

  /// Builds the screen-reader announcement for a page change. Receives
  /// the new index and [itemCount]; defaults to
  /// `'Photo ${index + 1} of $itemCount'`.
  final ViewfinderPageAnnouncementBuilder? pageAnnouncementBuilder;

  /// Restoration ID forwarded to the underlying [PageView], preserving
  /// the page position across state restoration (e.g. Android process
  /// death).
  final String? restorationId;

  /// When `true`, the gallery manages the system UI overlays for a
  /// full-screen viewing experience: with a [chromeController], the
  /// status/navigation bars follow chrome visibility
  /// ([SystemUiMode.edgeToEdge] while visible,
  /// [SystemUiMode.immersiveSticky] while hidden); without one, the
  /// gallery enters immersive mode on mount. On unmount
  /// [SystemUiMode.edgeToEdge] is restored. Default `false`.
  final bool immersiveSystemUi;

  /// When `true`, pages that scroll out of view keep their [State]
  /// alive (e.g. a `.child` page's video position or scroll offset).
  /// The pan/zoom transform is still reset when leaving a page —
  /// that's the photo-viewer convention. Default `false`: pages are
  /// disposed as [PageView] normally would.
  final bool keepAlivePages;

  /// What the mouse scroll wheel does over a page. Defaults to
  /// [ViewfinderMouseWheelBehavior.zoom].
  final ViewfinderMouseWheelBehavior mouseWheelBehavior;

  /// When non-null, every image-backed page's provider is wrapped in
  /// a [ResizeImage] targeting the viewport size × this multiplier
  /// (in physical pixels), capping decode memory for large sources.
  /// `1.0` decodes at viewport size — cheapest, but zooming past 1×
  /// runs out of pixels; `2.0`–`3.0` keeps zoom headroom. Upscaling
  /// is never forced ([ResizeImagePolicy.fit]). Adjacent-page
  /// precaching uses the same target so cache keys match. `null`
  /// (default) decodes at the source's native resolution.
  final double? decodeSizeMultiplier;

  /// When `true`, overscrolling past the first or last page by
  /// ~100 logical pixels fires [ViewfinderDismiss.onDismiss] — the
  /// "swipe out of the gallery" gesture. Requires [dismiss].
  /// Default `false`.
  final bool dismissOnOverscroll;

  /// When `true`, the gallery wraps around: swiping past the last
  /// page lands on the first and vice versa. [ViewfinderController]
  /// indices, [onPageChanged], the indicator, and thumbnails all keep
  /// reporting logical indices (`0..itemCount-1`); `jumpTo` /
  /// `animateTo` travel the shortest direction around the loop.
  /// Ignored when [itemCount] < 2. Default `false`.
  final bool loop;

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

/// What the mouse scroll wheel does over a [Viewfinder] page.
enum ViewfinderMouseWheelBehavior {
  /// Wheel zooms the photo around the pointer (default).
  zoom,

  /// Wheel navigates pages: scroll down/right goes to the next page,
  /// up/left to the previous. Wheel zoom is disabled; pinch,
  /// double-tap, and double-tap-drag still zoom.
  paging,
}

/// Callback signature for [Viewfinder.onScaleStateChanged]: the current
/// page's index and its new [ViewfinderScaleState].
typedef ViewfinderScaleStateChanged =
    void Function(int index, ViewfinderScaleState state);

/// Builds the message announced to screen readers when the page
/// changes. See [Viewfinder.pageAnnouncementBuilder].
typedef ViewfinderPageAnnouncementBuilder =
    String Function(int index, int itemCount);

/// Accumulated overscroll past the first/last page that triggers
/// [ViewfinderDismiss.onDismiss] when
/// [Viewfinder.dismissOnOverscroll] is enabled.
const double _kOverscrollDismissExtent = 100.0;

class _ViewfinderState extends State<Viewfinder> {
  late ViewfinderController _controller;
  late PageController _pageController;
  bool _ownsController = false;
  // Logical index (0..itemCount-1) — what controllers, callbacks, the
  // indicator, and thumbnails see.
  int _currentIndex = 0;
  // The PageView's own page. Equal to [_currentIndex] except in loop
  // mode, where the pager runs on an unbounded index that maps to
  // logical pages modulo itemCount.
  int _currentRawIndex = 0;
  bool _swipeLocked = false;
  // Raw-index-keyed: each PageView slot owns a distinct controller, so
  // the single-state-attached invariant of `ViewfinderImageController`
  // is preserved even when two slots happen to render the same content
  // (possible in loop mode with small galleries). The "transform
  // follows the photo" guarantee on re-order is handled separately by
  // `ViewfinderImage`'s own content-swap reset.
  final Map<int, ViewfinderImageController> _imageControllers = {};
  ViewfinderScaleState _lastReportedScaleState = .initial;
  // Overscroll-to-dismiss bookkeeping (see _handlePagerNotification).
  double _overscrollAccum = 0;
  bool _overscrollDismissed = false;
  // The chrome controller the system-UI sync is currently listening to.
  ViewfinderChromeController? _systemUiChrome;

  /// How many raw pages the looping pager starts in from 0 — large
  /// enough that swiping backward never reaches the hard 0 boundary
  /// in practice.
  static const int _kLoopBaseCycles = 10000;

  bool get _loopEnabled => widget.loop && widget.itemCount >= 2;

  int _logicalFor(int raw) =>
      widget.itemCount == 0 ? 0 : raw % widget.itemCount;

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
    final zoomed = _imageControllers[_currentRawIndex]?.scaleState == .zoomed;
    if (zoomed && chrome.visible) {
      chrome.hide();
    }
  }

  // ---------------- system UI (immersive mode) ---------------- //

  void _attachSystemUi() {
    if (!widget.immersiveSystemUi) return;
    final chrome = _chrome;
    if (chrome != null) {
      _systemUiChrome = chrome;
      chrome.addListener(_syncSystemUiWithChrome);
    }
    _syncSystemUiWithChrome();
  }

  void _detachSystemUi({required bool restore}) {
    _systemUiChrome?.removeListener(_syncSystemUiWithChrome);
    _systemUiChrome = null;
    if (restore) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _syncSystemUiWithChrome() {
    // Without a chrome controller the gallery is permanently immersive
    // while mounted; with one, system bars follow chrome visibility.
    final visible = _chrome?.visible ?? false;
    SystemChrome.setEnabledSystemUIMode(
      visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  ViewfinderImageController _imageControllerFor(int index) {
    return _imageControllers.putIfAbsent(index, () {
      final c = ViewfinderImageController();
      c.addListener(() => _onImageControllerUpdate(index));
      return c;
    });
  }

  void _onImageControllerUpdate(int rawIndex) {
    if (rawIndex != _currentRawIndex) return;
    final c = _imageControllers[rawIndex];
    if (c == null) return;
    final lock = !_canSwipeAlongPager(c);
    if (lock != _swipeLocked) {
      setState(() => _swipeLocked = lock);
    }
    _emitScaleState(_currentIndex, c.scaleState);
    _syncChromeWithZoom();
  }

  void _emitScaleState(int logicalIndex, ViewfinderScaleState state) {
    if (state == _lastReportedScaleState) return;
    _lastReportedScaleState = state;
    widget.onScaleStateChanged?.call(logicalIndex, state);
  }

  bool _canSwipeAlongPager(ViewfinderImageController c) =>
      c.canSwipe(widget.pagerAxis);

  /// Reset the current image's zoom if it's zoomed in. Returns true when
  /// a reset was performed — useful for intercepting custom back-button
  /// navigation.
  bool resetCurrentImage() {
    final c = _imageControllers[_currentRawIndex];
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
    final n = widget.itemCount;
    if (n == 0) return 0;
    // A looping gallery wraps out-of-range indices instead of clamping.
    if (_loopEnabled) return ((index % n) + n) % n;
    return index.clamp(0, n - 1);
  }

  /// The raw PageView page that shows [logical] when (re)basing the
  /// pager — loop mode starts deep inside the unbounded index space.
  int _rawBaseFor(int logical) =>
      _loopEnabled ? widget.itemCount * _kLoopBaseCycles + logical : logical;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ViewfinderController();
    _ownsController = widget.controller == null;
    _currentIndex = _clampIndex(_controller.currentIndex);
    // Write the clamped index back silently (no notify — we're inside
    // the build phase): PageView.onPageChanged does not fire for the
    // initial page, so an out-of-range initialIndex would otherwise
    // keep reading back unclamped through `controller.currentIndex`.
    _controller._currentIndex = _currentIndex;
    _currentRawIndex = _rawBaseFor(_currentIndex);
    _pageController = PageController(initialPage: _currentRawIndex);
    _controller._attach(this);
    _attachSystemUi();
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
      // Adopt the gallery's current page into the incoming controller
      // (silently — we're inside the build phase). A swap is not a
      // navigation request: without this, the new controller would
      // keep reporting its construction-time index until the next
      // user-driven page change.
      _controller._currentIndex = _currentIndex;
    }
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.loop != widget.loop) {
      final wasLoop = oldWidget.loop && oldWidget.itemCount >= 2;
      if (!wasLoop && !_loopEnabled) {
        // Plain (non-looping) itemCount change.
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
          _currentRawIndex = clamped;
          _controller._setIndex(clamped);
          if (_pageController.hasClients) {
            _pageController.jumpToPage(clamped);
          }
        }
      } else {
        // The raw↔logical mapping changed (loop toggled, or the modulus
        // under a looping pager). Rebase: drop every per-slot controller
        // (raw keys from the old mapping are meaningless now — disposal
        // is guarded, so still-mounted pages detach harmlessly) and jump
        // the pager to a fresh raw base for the preserved logical page.
        for (final c in _imageControllers.values) {
          c.dispose();
        }
        _imageControllers.clear();
        _currentIndex = _clampIndex(_currentIndex);
        _controller._currentIndex = _currentIndex;
        _currentRawIndex = _rawBaseFor(_currentIndex);
        if (_pageController.hasClients) {
          _pageController.jumpToPage(_currentRawIndex);
        }
      }
    }
    if (oldWidget.immersiveSystemUi != widget.immersiveSystemUi ||
        oldWidget.chromeController != widget.chromeController) {
      _detachSystemUi(
        restore: oldWidget.immersiveSystemUi && !widget.immersiveSystemUi,
      );
      _attachSystemUi();
    }
  }

  @override
  void dispose() {
    if (widget.immersiveSystemUi) {
      _detachSystemUi(restore: true);
    }
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

  /// Wraps [provider] in a [ResizeImage] targeting the viewport ×
  /// [Viewfinder.decodeSizeMultiplier] when the knob is set. The same
  /// wrapping runs for display and precache so cache keys match.
  ImageProvider _decodeWrapped(ImageProvider provider) {
    final m = widget.decodeSizeMultiplier;
    if (m == null) return provider;
    final size = MediaQuery.sizeOf(context);
    if (size.isEmpty) return provider;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ResizeImage(
      provider,
      width: (size.width * dpr * m).round(),
      height: (size.height * dpr * m).round(),
      policy: .fit,
    );
  }

  /// The item for [index] with the decode-size policy applied to its
  /// main provider. The thumbnail strip keeps using the raw item — it
  /// already decodes tiles at tile size.
  ViewfinderItem _resolvedItemAt(int index) {
    final item = _itemAt(index);
    if (widget.decodeSizeMultiplier == null) return item;
    return switch (item) {
      final ViewfinderImageItem i => ViewfinderImageItem(
        image: _decodeWrapped(i.image),
        thumbImage: i.thumbImage,
        hero: i.hero,
        loadingBuilder: i.loadingBuilder,
        errorBuilder: i.errorBuilder,
        initialScale: i.initialScale,
        minScale: i.minScale,
        maxScale: i.maxScale,
        doubleTapScales: i.doubleTapScales,
        semanticLabel: i.semanticLabel,
        onLongPress: i.onLongPress,
        onLongPressStart: i.onLongPressStart,
        onSecondaryTapUp: i.onSecondaryTapUp,
        thumbCrossFadeDuration: i.thumbCrossFadeDuration,
        thumbCrossFadeCurve: i.thumbCrossFadeCurve,
        gaplessPlayback: i.gaplessPlayback,
      ),
      final ViewfinderChildItem i => i,
    };
  }

  void _precacheAround(int index) {
    if (widget.precacheAdjacent == 0) return;
    for (var delta = 1; delta <= widget.precacheAdjacent; delta++) {
      for (final i in [index - delta, index + delta]) {
        int effective = i;
        if (_loopEnabled) {
          effective = _clampIndex(i);
        } else if (i < 0 || i >= widget.itemCount) {
          continue;
        }
        if (_itemAt(effective) case ViewfinderImageItem(:final image)) {
          precacheImage(_decodeWrapped(image), context);
        }
      }
    }
  }

  void _announcePage(int logical) {
    if (!widget.announcePageChanges || widget.itemCount == 0) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.pageAnnouncementBuilder?.call(logical, widget.itemCount) ??
          'Photo ${logical + 1} of ${widget.itemCount}',
      Directionality.of(context),
    );
  }

  /// Loop mode visits an unbounded raw-index space; controllers for
  /// slots far outside the live window would otherwise accumulate for
  /// the whole session. Pages beyond the PageView's cache extent are
  /// already unmounted (and detached), so pruning is safe.
  void _pruneLoopControllers() {
    if (!_loopEnabled) return;
    final keep = widget.precacheAdjacent + 3;
    final stale = [
      for (final k in _imageControllers.keys)
        if ((k - _currentRawIndex).abs() > keep) k,
    ];
    for (final k in stale) {
      _imageControllers.remove(k)!.dispose();
    }
  }

  void _onPageChanged(int rawIndex) {
    final previousRaw = _currentRawIndex;
    final logical = _logicalFor(rawIndex);
    setState(() {
      _currentRawIndex = rawIndex;
      _currentIndex = logical;
      // Re-derive swipe lock for the new page's current state.
      final c = _imageControllers[rawIndex];
      _swipeLocked = c != null && !_canSwipeAlongPager(c);
    });
    // The page we just left keeps its own TransformationController
    // alive (PageView retains adjacent pages). If the user had zoomed
    // it, a later swipe back would reveal the stale zoom. Snap it
    // back instantly — matches photo-viewer convention of presenting
    // every page at its initial scale.
    if (previousRaw != rawIndex) {
      _imageControllers[previousRaw]?.jumpToInitial();
    }
    _controller._setIndex(logical);
    widget.onPageChanged?.call(logical);
    _emitScaleState(
      logical,
      _imageControllers[rawIndex]?.scaleState ?? .initial,
    );
    _announcePage(logical);
    _precacheAround(logical);
    _pruneLoopControllers();
    _bumpChrome();
  }

  void _goTo(int index, {bool animate = true}) {
    if (!_pageController.hasClients) return;
    final int targetRaw;
    if (_loopEnabled) {
      // Wrap the target and travel the shortest way around the loop.
      final n = widget.itemCount;
      final targetLogical = ((index % n) + n) % n;
      var delta = targetLogical - _currentIndex;
      if (delta > n / 2) delta -= n;
      if (delta < -n / 2) delta += n;
      targetRaw = _currentRawIndex + delta;
    } else {
      final max = widget.itemCount - 1;
      targetRaw = max < 0 ? 0 : index.clamp(0, max);
    }
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (animate && !reduceMotion) {
      _pageController.animateToPage(
        targetRaw,
        duration: const .new(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _pageController.jumpToPage(targetRaw);
    }
  }

  /// Wheel-paging handler ([ViewfinderMouseWheelBehavior.paging]):
  /// positive deltas (scroll down / right) go to the next logical
  /// page, negative to the previous. Ignored while a page transition
  /// is still settling so one wheel notch turns one page.
  void _onWheelPageDelta(double delta) {
    if (delta == 0) return;
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null && (page - page.round()).abs() > 0.02) return;
    }
    _goTo(_currentIndex + (delta > 0 ? 1 : -1));
  }

  /// Overscroll-to-dismiss: accumulate how far the pager was pulled
  /// past its first/last page within one scroll activity and fire the
  /// dismiss callback once past [_kOverscrollDismissExtent]. Handles
  /// both clamping physics (OverscrollNotification) and bouncing
  /// physics (pixels beyond the extents).
  bool _handlePagerNotification(ScrollNotification n) {
    if (n.metrics.axis != widget.pagerAxis) return false;
    switch (n) {
      case ScrollStartNotification() || ScrollEndNotification():
        _overscrollAccum = 0;
        _overscrollDismissed = false;
      case final OverscrollNotification o:
        _overscrollAccum += o.overscroll.abs();
      case final ScrollUpdateNotification u:
        final m = u.metrics;
        final over = m.pixels < m.minScrollExtent
            ? m.minScrollExtent - m.pixels
            : m.pixels > m.maxScrollExtent
            ? m.pixels - m.maxScrollExtent
            : 0.0;
        if (over > _overscrollAccum) _overscrollAccum = over;
      default:
        break;
    }
    if (!_overscrollDismissed &&
        _overscrollAccum >= _kOverscrollDismissExtent) {
      _overscrollDismissed = true;
      widget.dismiss?.onDismiss();
    }
    return false;
  }

  void _handleEscape() {
    // Two-stage Esc: first collapse any zoom so the Hero transition
    // from here back out stays coherent. Only then dismiss.
    if (resetCurrentImage()) return;
    widget.dismiss?.onDismiss();
  }

  /// Whether the pager's visual order is flipped relative to logical
  /// indices. [Viewfinder.reverse] flips it explicitly; a horizontal
  /// [PageView] additionally lays out right-to-left under an RTL
  /// [Directionality], so the two XOR.
  bool get _effectiveReverse {
    final rtl =
        widget.pagerAxis == .horizontal &&
        Directionality.of(context) == TextDirection.rtl;
    return widget.reverse != rtl;
  }

  /// Index of the page a drag with the given [sign] (+1 = finger
  /// moving right/down) navigates to. May be out of range — callers
  /// bounds-check.
  int _dragTargetIndex(int sign) =>
      _currentIndex + ((sign > 0) != _effectiveReverse ? -1 : 1);

  /// Maps a drag along [axis] with [sign] (+1 = finger moving
  /// right/down) to the finger-motion direction used by
  /// [ViewfinderImageController.canSwipeToward].
  static AxisDirection _dragDirection(Axis axis, int sign) =>
      switch ((axis, sign > 0)) {
        (.horizontal, true) => .right,
        (.horizontal, false) => .left,
        (.vertical, true) => .down,
        (.vertical, false) => .up,
      };

  /// Gate: reject single-pointer pan along the pager axis when the parent
  /// [PageView] should take over. Returning `false` yields the gesture so
  /// the pager's drag recognizer can claim it. Pinches (two-pointer
  /// gestures) bypass this gate inside the recognizer.
  bool _canPanForPage(
    int rawIndex,
    ViewfinderImageController c,
    Axis axis,
    int sign,
  ) {
    // Only consult for the axis the PageView scrolls on; the other
    // axis is always allowed inside the image.
    if (axis != widget.pagerAxis) return true;
    // Adjacent pre-built pages always allow their own pan.
    if (rawIndex != _currentRawIndex) return true;
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
    // Zoomed: cede to PageView only when the content has no more room
    // to pan in the drag's own direction. The check is directional —
    // a photo flush against its left edge still pans (not swipes)
    // when the finger moves left to reveal the photo's right side.
    if (c.canSwipeToward(_dragDirection(axis, sign))) {
      // At the directional edge: hand off only if a page exists in
      // the drag's navigation direction (otherwise stay inside). A
      // looping pager always has one.
      if (_loopEnabled) return false;
      final targetIndex = _dragTargetIndex(sign);
      return targetIndex < 0 || targetIndex >= widget.itemCount;
    }
    return true;
  }

  /// Claim gate: a zoomed page's pan that [_canPanForPage] keeps
  /// inside must also *win* the arena — the pager's drag recognizer
  /// (and the dismiss wrapper's) accept at hit-slop, before the scale
  /// recognizer's pan-slop, and would steal the drag otherwise. Never
  /// claims while unzoomed so taps/swipes/dismiss compete normally.
  bool _claimPanForPage(
    int rawIndex,
    ViewfinderImageController c,
    Axis axis,
    int sign,
  ) {
    if (c.scaleState != .zoomed) return false;
    return _canPanForPage(rawIndex, c, axis, sign);
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = PageView.builder(
      controller: _pageController,
      scrollDirection: widget.pagerAxis,
      reverse: widget.reverse,
      // A looping pager runs on an unbounded raw index space; pages
      // map to logical indices modulo itemCount.
      itemCount: _loopEnabled ? null : widget.itemCount,
      onPageChanged: _onPageChanged,
      allowImplicitScrolling: widget.allowImplicitScrolling,
      restorationId: widget.restorationId,
      physics: _swipeLocked
          ? const NeverScrollableScrollPhysics()
          : widget.scrollPhysics ?? const PageScrollPhysics(),
      itemBuilder: (context, rawIndex) {
        final logical = _logicalFor(rawIndex);
        final imageController = _imageControllerFor(rawIndex);
        Widget page = ViewfinderPage(
          item: _resolvedItemAt(logical),
          isCurrent: rawIndex == _currentRawIndex,
          controller: imageController,
          canPan: (axis, sign) =>
              _canPanForPage(rawIndex, imageController, axis, sign),
          claimPan: (axis, sign) =>
              _claimPanForPage(rawIndex, imageController, axis, sign),
          defaultInitialScale: widget.defaultInitialScale,
          doubleTapScales: widget.doubleTapScales,
          defaultMinScale: widget.minScale,
          defaultMaxScale: widget.maxScale,
          rotateEnabled: widget.rotateEnabled,
          interactionEndFrictionCoefficient:
              widget.interactionEndFrictionCoefficient,
          rubberBandPan: widget.rubberBandPan,
          pageSpacing: widget.pageSpacing,
          pagerAxis: widget.pagerAxis,
          enableMouseWheelZoom: widget.mouseWheelBehavior == .zoom,
          onWheelDelta: widget.mouseWheelBehavior == .paging
              ? _onWheelPageDelta
              : null,
        );
        if (widget.keepAlivePages) {
          page = KeepAlivePage(child: page);
        }
        // In loop mode two raw slots can show the same logical page
        // (small galleries), so the public per-logical-index key is
        // only safe on a bounded pager.
        return KeyedSubtree(
          key: _loopEnabled
              ? ValueKey<String>('viewfinder-raw-page-$rawIndex')
              : ViewfinderKeys.page(logical),
          child: page,
        );
      },
    );

    if (widget.dismissOnOverscroll) {
      pageView = NotificationListener<ScrollNotification>(
        onNotification: _handlePagerNotification,
        child: pageView,
      );
    }

    Widget pager = ColoredBox(
      color: widget.backgroundColor,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: widget.swipeDragDevices),
        child: pageView,
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
      // Arrow keys are spatial: they move to the page visually in that
      // direction, so they track reverse / RTL. PageUp / PageDown stay
      // logical (previous / next index).
      final visualStep = _effectiveReverse ? -1 : 1;
      body = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _goTo(_currentIndex - visualStep),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _goTo(_currentIndex + visualStep),
          if (widget.pagerAxis == .vertical) ...{
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _goTo(_currentIndex - visualStep),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _goTo(_currentIndex + visualStep),
          },
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
        _imageControllers[_currentRawIndex]?.scaleState == .zoomed;
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
