# viewfinder

[![pub package](https://img.shields.io/pub/v/viewfinder.svg)](https://pub.dev/packages/viewfinder)
[![GitHub license](https://img.shields.io/github/license/koji-1009/viewfinder)](https://github.com/koji-1009/viewfinder/blob/main/LICENSE)
[![CI](https://github.com/koji-1009/viewfinder/actions/workflows/ci.yaml/badge.svg)](https://github.com/koji-1009/viewfinder/actions/workflows/ci.yaml)
[![codecov](https://codecov.io/gh/koji-1009/viewfinder/graph/badge.svg)](https://codecov.io/gh/koji-1009/viewfinder)

A photo viewer for Flutter. Pinch / double-tap / rotation zoom, an arena-aware gesture layer that hands off edge pans to a parent `PageView`, drag-to-dismiss, loop paging, a synchronized thumbnail strip, a page indicator, keyboard shortcuts, screen-reader announcements, and a chrome controller for tap-to-toggle UX.

Accepts any `ImageProvider` (`NetworkImage`, `AssetImage`, `FileImage`, `MemoryImage`, …) and feeds it straight to `Image()`. No runtime dependencies beyond the Flutter SDK.

## Live demo

[https://koji-1009.github.io/viewfinder/](https://koji-1009.github.io/viewfinder/)

A hosted build of the example app — try the gallery, single-photo viewer, vertical pager, embedded zoom, and rotation scenarios in the browser.


<p align="center">
  <img src="doc/screenshots/zoom.webp" alt="Pinch and double-tap zoom" width="280">
  &nbsp;&nbsp;
  <img src="doc/screenshots/swipe.webp" alt="Swipe between pages with thumbnail sync" width="280">
</p>

## Highlights

* **Native-feel gestures** — pinch, pan, fling on translation and scale, double-tap ladder, double-tap-and-drag continuous zoom (iOS Photos style), opt-in two-finger rotation, rubber-band over-pan with snap-back on release, long-press / right-click hooks for save-and-share menus.
* **Built for every input** — touch, stylus, trackpad, mouse, mouse wheel (zoom or page-turn), hardware keyboard. Mouse-drag swipes pages on web and desktop out of the box.
* **Widgets layer only** — imports nothing from Material, so it drops into Material, Cupertino, and plain-widgets apps alike (and is ready for the Flutter 3.44 material/SDK split).
* **Plays well with parents** — an arena-aware gesture layer hands edge pans back to a parent `PageView` so a zoomed photo can swipe to the next page without lifting the finger, on either axis — and only in the direction the photo has actually run out of content.
* **Gallery affordances included** — `Viewfinder.images([...])` covers the common case; thumbnail strip overlaying the full-bleed viewer (4 positions or fully custom), page indicator (dots / label / adaptive), drag-to-dismiss with overscroll-to-dismiss, loop paging, tap-to-toggle chrome controller with optional immersive system UI. All opt-in.
* **Accessible by default** — page changes are announced to screen readers, thumbnails and indicators carry semantics, the platform reduce-motion setting is honored, and RTL locales get correctly mirrored paging and arrow keys.
* **Robust pop / back-button** — pop while zoomed snaps every page back to its initial transform first, so any Hero flight starts from a sensible source rect; the first back / Esc on a zoomed photo resets the zoom, the second pops.
* **No runtime dependencies** beyond the Flutter SDK.

## Quick start

### Gallery from a list

```dart
Viewfinder.images(
  photos, // List<ImageProvider>
  dismiss: ViewfinderDismiss(onDismiss: () => Navigator.pop(context)),
)
```

### Single photo, full-screen

```dart
Viewfinder.single(
  image: const NetworkImage('https://example.com/photo.jpg'),
  dismiss: ViewfinderDismiss(onDismiss: () => Navigator.pop(context)),
  maxScale: 10,
)
```

### Custom per-page (gallery builder)

```dart
Viewfinder(
  itemCount: photos.length,
  precacheAdjacent: 2,
  thumbnails: const ViewfinderThumbnails(size: 64),
  indicator: const ViewfinderPageIndicatorAdaptive(),
  dismiss: ViewfinderDismiss(onDismiss: () => Navigator.pop(context)),
  itemBuilder: (context, index) => ViewfinderItem(
    image: photos[index],
    thumbImage: photosLowRes[index], // optional progressive load
    semanticLabel: 'Vacation photo ${index + 1}',
  ),
)
```

### Embedded zoomable image

For a single zoomable image _inside_ another scrollable layout (no chrome, no dismiss), use `ViewfinderImage` directly:

```dart
ViewfinderImage(
  image: const NetworkImage('https://example.com/photo.jpg'),
  initialScale: const ViewfinderInitialScale.contain(),
  doubleTapScales: const [1, 2.5, 5],
  maxScale: 8.0,
)
```

For non-image content, `ViewfinderImage.child(child: …, contentKey: …)` zooms any widget. The required `contentKey` is any `Object` whose `==` identifies the rendered content; for a single static `.child`, a constant string works (`contentKey: 'main'`).

## Initial scale

Two flavors, each accepting an optional multiplier:

```dart
const ViewfinderInitialScale.contain()      // fit-in-viewport (default)
const ViewfinderInitialScale.contain(0.8)   // 80% of fit, leaves margin
const ViewfinderInitialScale.cover()        // fill-viewport, crop overflow
const ViewfinderInitialScale.cover(1.2)     // 120% of fill
```

For an "always 2×" feel, use `contain(2.0)`.

## Zoom & pan

Knobs on `ViewfinderImage` that control how a single image responds to gestures. `Viewfinder` forwards the same knobs (`defaultInitialScale` / `minScale` / `maxScale` / `doubleTapScales` / `rotateEnabled` / `rubberBandPan` / `interactionEndFrictionCoefficient`) to every page.

All scale knobs are **relative to the initial scale** — `1.0` always means "exactly as first shown", whatever `initialScale` resolves to.

| Knob                                | Default                       | What it does                                                                                                                                                                                     |
| ----------------------------------- | ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `minScale` / `maxScale`             | `1.0` / `8.0`                 | Hard zoom bounds, relative to the initial scale. `minScale` must be `<= 1.0` and `maxScale >= 1.0` so the initial state stays in bounds.                                                         |
| `doubleTapScales`                   | `[1.0, 2.5, 5.0]`             | Cycle through these on each double-tap, relative to the initial scale. Pass `[]` to disable double-tap zoom (including double-tap-drag). Per-item override via `ViewfinderItem.doubleTapScales`. |
| `rubberBandPan`                     | `true`                        | When zoomed and panned past an edge, the displacement diminishes elastically and snaps back on release. Pass `false` for hard edge clamping.                                                     |
| `rotateEnabled`                     | `false`                       | Two-finger rotation. Off by default because Flutter's `ScaleGestureRecognizer` reports rotation only when explicitly enabled.                                                                    |
| `interactionEndFrictionCoefficient` | `kViewfinderDefaultFlingDrag` | Friction for post-release fling on translation and scale. Lower = longer glide. Defaults to `0.0000135`.                                                                                         |
| `panEnabled` / `scaleEnabled`       | `true` / `true`               | Disable pan or scale individually. Useful for embedded read-only zoom.                                                                                                                           |
| `doubleTapDragZoom`                 | `true`                        | Double-tap-and-hold, then slide to zoom continuously (iOS Photos style).                                                                                                                         |
| `enableMouseWheelZoom`              | `true`                        | Wheel zooms around the pointer. Disable for viewers embedded in scrollable pages.                                                                                                                |
| `onScaleStart` / `onScaleEnd`       | —                             | Gesture lifecycle callbacks. Useful for haptics and analytics.                                                                                                                                   |
| `onScaleChanged`                    | —                             | Fires on every scale update with the current scale relative to the initial (1.0 = initial).                                                                                                      |
| `onTap` / `onTapUp` / `onTapDown`   | —                             | Tap callbacks; `onTap` waits for double-tap disambiguation.                                                                                                                                      |
| `onLongPress` / `onLongPressStart`  | —                             | Long-press hooks — the standard mobile entry point for save / share / context menus. `onLongPressStart` carries the press position.                                                              |
| `onSecondaryTapUp`                  | —                             | Mouse right-click with position — the desktop / web counterpart of `onLongPress`. Also available per-item and (index-aware) on `Viewfinder.images`.                                              |

## Gallery & paging

Knobs on `Viewfinder` that control how pages flow.

| Knob                      | Default                              | What it does                                                                                                                                                                                                              |
| ------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pagerAxis`               | `Axis.horizontal`                    | Page direction. Vertical galleries also work, with the edge-handoff axis flipped accordingly (and Up/Down arrow keys bound).                                                                                              |
| `reverse`                 | `false`                              | Forwarded to `PageView.reverse`. Note a horizontal pager already mirrors under RTL `Directionality`; `reverse` flips whatever the base direction is.                                                                      |
| `loop`                    | `false`                              | Wrap-around paging: swiping past the last page lands on the first and vice versa. `jumpTo` / `animateTo` travel the shortest way around. Needs ≥ 2 items.                                                                 |
| `pageSpacing`             | `0`                                  | Pixels between pages, along the pager axis.                                                                                                                                                                               |
| `precacheAdjacent`        | `1`                                  | Warm the `imageCache` for ±N pages around the current one. Image-backed items only (`.child` pages are skipped); cache keys match what `Image()` resolves at paint.                                                       |
| `allowEdgeHandoff`        | `true`                               | When zoomed and panned to the edge, yields to the parent `PageView` so the user can swipe to the next page without lifting — only in the direction the photo has no content left. `false` clamps inside the current page. |
| `swipeDragDevices`        | `kViewfinderDefaultSwipeDragDevices` | Pointer kinds allowed to swipe the underlying `PageView`. Default includes mouse / trackpad / touch / stylus. Pass a narrower set to opt out.                                                                             |
| `enableKeyboardShortcuts` | `true`                               | Arrow keys (visual order — RTL/`reverse`-aware), PageUp/Down (logical order), Esc (two-stage). Disable to take over the keyboard.                                                                                         |
| `allowImplicitScrolling`  | `true`                               | Forwarded to `PageView.allowImplicitScrolling` for accessible focus traversal.                                                                                                                                            |
| `mouseWheelBehavior`      | `.zoom`                              | `.zoom` zooms around the pointer; `.paging` splits scrolling by axis — along the pager turns pages (one per gesture), across it zooms.                                                                                    |
| `onScaleStateChanged`     | —                                    | Fires when the current page transitions initial ⇄ zoomed — the hook for app chrome that reacts to zoom. Coalesced, not per-frame.                                                                                         |
| `keepAlivePages`          | `false`                              | Keep off-screen pages' `State` alive (e.g. a `.child` page's video position). The pan/zoom transform still resets on page leave.                                                                                          |
| `restorationId`           | —                                    | Forwarded to `PageView.restorationId`; the page position survives state restoration.                                                                                                                                      |
| `immersiveSystemUi`       | `false`                              | Manage system status/navigation bars: follows chrome visibility with a `chromeController`, plain immersive otherwise; restores edge-to-edge on unmount.                                                                   |
| `decodeSizeMultiplier`    | `null`                               | Decode every image-backed page at viewport size × N physical pixels instead of native resolution. See [Decode size and memory](#decode-size-and-memory).                                                                  |
| `dismissOnOverscroll`     | `false`                              | Pulling ~100 px past the first/last page fires `dismiss.onDismiss` — the "swipe out of the gallery" gesture. Requires `dismiss`; incompatible with `loop`.                                                                |
| `announcePageChanges`     | `true`                               | Announce page changes to screen readers. Localize via `pageAnnouncementBuilder`.                                                                                                                                          |

## Image loading

| Knob                                    | Default    | What it does                                                                                         |
| --------------------------------------- | ---------- | ---------------------------------------------------------------------------------------------------- |
| `thumbImage` / `thumbCrossFadeDuration` | — / 200 ms | Low-res preview that cross-fades into the main image once the first frame lands.                     |
| `gaplessPlayback`                       | `true`     | Forwarded to `Image.gaplessPlayback`. Keeps the previous frame visible while a new provider decodes. |
| `loadingBuilder` / `errorBuilder`       | —          | Forwarded straight to `Image()`.                                                                     |
| `filterQuality`                         | `medium`   | Image filter quality.                                                                                |

## Drag-to-dismiss

`ViewfinderDismiss(onDismiss: …)`. Auto-disabled while zoomed. Background fades with drag.

> Drag-to-dismiss reads vertical drags, so pairing it with `pagerAxis: Axis.vertical` would put both into the same gesture arena. The combination is rejected at construction time (debug assert). Pick one — horizontal pager + dismiss, or vertical pager without dismiss.

| Knob                 | Default      | What it does                                                                                                                        |
| -------------------- | ------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `direction`          | `.vertical`  | `.vertical` accepts both, or restrict to `.up` / `.down`.                                                                           |
| `threshold`          | `0.25`       | Fraction of viewport height past which release triggers dismissal.                                                                  |
| `slideType`          | `.wholePage` | `wholePage` slides thumbnails too; `onlyImage` keeps thumbnails / indicator / overlays anchored.                                    |
| `fadeBackground`     | `true`       | Fade the background color in step with the drag.                                                                                    |
| `onProgress`         | —            | Reports normalized drag progress (incl. spring-back). Useful for fading external chrome in sync.                                    |
| `onThresholdCrossed` | —            | Edge-triggered: `true` when the drag crosses `threshold`, `false` when it recedes. The natural hook for a haptic "far enough" tick. |

For the complementary "swipe past the last page to leave" gesture, see `dismissOnOverscroll` in [Gallery & paging](#gallery--paging).

## Page indicator

Sealed `ViewfinderPageIndicator`, three variants:

* `ViewfinderPageIndicatorDots` — one dot per page. Exposes a "Page i of N" label to screen readers (`semanticLabelBuilder` to localize).
* `ViewfinderPageIndicatorLabel` — single text label, default `"i / N"`. Pass `labelBuilder` for full control.
* `ViewfinderPageIndicatorAdaptive` — dots up to `maxDots`, then falls back to the label. The most common pick.

All variants take `alignment`, `padding`, and `safeArea` (default `true` — a bottom-aligned indicator stays above the home indicator / browser chrome).

## Inputs

* **Touch / stylus / trackpad / mouse** — wired by default.
* **Mouse wheel / trackpad scroll** — zooms around the pointer location. With `mouseWheelBehavior: .paging`, scrolling along the pager axis turns pages while cross-axis scrolling keeps zooming. Browser pinch zooms regardless.
* **Trackpad pinch (macOS)** — wired in.
* **Mouse drag on web/desktop** — swipes pages out of the box (`swipeDragDevices` includes mouse).
* **Mouse right-click / long-press** — `onSecondaryTapUp` / `onLongPress` hooks for context menus and save/share actions.
* **Hardware keyboard** — Arrow keys move to the page visually in that direction (RTL / `reverse`-aware; Up/Down for vertical pagers), PageUp/Down move in logical order, Escape is two-stage: first press resets zoom on a zoomed photo, second press pops / dismisses. Android back behaves the same.

## Accessibility

* **Page announcements** — every page change is spoken by TalkBack / VoiceOver (`'Photo 2 of 12'` by default; localize with `pageAnnouncementBuilder`, silence with `announcePageChanges: false`).
* **Semantics everywhere** — pages take `semanticLabel`, thumbnail tiles are buttons with a selected state (`ViewfinderThumbnails.semanticLabelBuilder` to localize), the dots indicator carries a position label.
* **Reduce motion** — when the platform requests reduced motion (`MediaQuery.disableAnimations`), double-tap zoom, page animations, flings, rubber-band snap-backs, thumbnail scrolling, and chrome fades all jump instead of animating.
* **RTL** — a horizontal pager follows the ambient `Directionality`; edge handoff and arrow keys track the visual order.

## Imperative control

### `ViewfinderController` — page navigation

```dart
final controller = ViewfinderController(initialIndex: 0);

controller.jumpTo(3);
controller.animateTo(3);
controller.currentIndex;          // int
controller.resetCurrentImage();   // returns true if a zoom was reset
```

`resetCurrentImage()` is the hook for two-stage back behavior — call it before your own `Navigator.pop` to reset zoom on the first press and pop on the second.

### `ViewfinderImageController` — per-image transform

```dart
final controller = ViewfinderImageController();

// Zoom. Scales are relative to the initial scale (1.0 = as first shown).
controller.animateToScale(3.0);
controller.animateToScale(2.0, focal: tapPosition);
controller.jumpToScale(2.0);          // instant — for slider-style control
controller.reset();
controller.scale;                     // double, 1.0 = initial

// Rotation (radians, 0 = upright). Works regardless of rotateEnabled,
// which gates only the gesture; scale and pan are preserved.
controller.jumpToRotation(math.pi / 2);
controller.animateToRotation(0, focal: tapPosition);
controller.rotation;                  // double

// Direct matrix control (absolute matrices).
final m = controller.currentTransform;
controller.jumpToTransform(m..translate(20.0, 0.0));
controller.animateToTransform(targetMatrix);

// Edge-state introspection.
controller.canSwipe(Axis.horizontal); // bool — at either edge of that axis
controller.canSwipe(Axis.vertical);   // bool
controller.canSwipeToward(AxisDirection.left); // direction-aware: no more room for a leftward drag
controller.scaleState;                // ViewfinderScaleState
```

`canSwipeToward` takes the direction of the _finger motion_: a finger moving right pulls the content right and is exhausted once the content's left edge meets the viewport's left. The check runs in screen space (the rotated content's AABB against the viewport), matching what a screen-axis pager needs. The bundled gallery uses exactly this to hand off pans to the pager only in the direction the photo has run out of content.

Embedding a standalone `ViewfinderImage` in your own scrollable? `panGate` is the other half of the handoff: once a single-pointer pan's dominant direction is known, return a `ViewfinderPanVerdict` — `release` hands the drag to your pager, `claim` keeps a zoomed pan away from ancestor recognizers that would win at their smaller hit-slop, `compete` leaves normal arena rules in place.

```dart
ViewfinderImage(
  image: provider,
  controller: controller,
  panGate: (direction) {
    if (controller.scaleState == ViewfinderScaleState.initial) {
      return ViewfinderPanVerdict.release;       // pager owns unzoomed drags
    }
    return controller.canSwipeToward(direction)
        ? ViewfinderPanVerdict.release           // at the edge: hand off
        : ViewfinderPanVerdict.claim;            // zoomed pan stays inside
  },
)
```

### `ViewfinderChromeController` — chrome visibility

```dart
final chrome = ViewfinderChromeController(
  autoHideAfter: const Duration(seconds: 3),
  autoHideWhileZoomed: true,
);

Viewfinder(
  chromeController: chrome,
  thumbnails: const ViewfinderThumbnails(),
  indicator: const ViewfinderPageIndicatorAdaptive(),
  chromeOverlays: [
    Positioned(top: 0, left: 0, right: 0, child: myAppBar),
  ],
  // …
)
```

Tap the photo: toggle. Zoom in: auto-hide. Page change: auto-hide timer restarts. `chromeOverlays` fade in sync with thumbnails and indicator.

## Hero

`ViewfinderHero` forwards every option Flutter's `Hero` exposes (`createRectTween`, `flightShuttleBuilder`, `placeholderBuilder`, `transitionOnUserGestures`). Three known Hero-with-photo-viewer pitfalls are handled internally:

* **Source rect coherence on pop** — when the route pops while a page is zoomed in, every page jumps back to its initial transform _before_ the Hero flight captures its source rect. The flight starts from the photo's natural bounds, never from a visibly zoomed crop.
* **Adjacent-page Hero leak** — only the currently-visible page carries its Hero tag. `PageView` pre-builds neighbors (especially with `allowImplicitScrolling`); without this rule, every pre-built page would fly on pop.
* **Fit-mismatch flicker** — Flutter's default flight shuttle is the destination hero's child, so a pop flight renders your (typically cover-fit) thumbnail stretched across the viewer's rect. Provider-backed heroes instead fly the viewer's own rendering by default. Declare your thumbnail's fit (`ViewfinderHero('tag', thumbnailFit: BoxFit.cover)`) and the shuttle interpolates between the two fits, landing exactly on the thumbnail's crop at the other end too; pass `flightShuttleBuilder` to take over entirely.

These together let the back button stay two-stage by design: the first press on a zoomed photo resets the zoom; the second pops. If you drive navigation yourself, check the reset status first:

```dart
if (galleryController.resetCurrentImage()) return; // zoom was reset
Navigator.of(context).pop();
```

Hero flights look cleanest when the destination route doesn't itself animate horizontally; the photo's flight has to compete with the sliding page otherwise.

| Route                                                 | Hero advice                                                                                                                                                                                                   |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MaterialPageRoute` (Android fade-up)                 | Hero is fine — destination stays roughly centered while it fades in.                                                                                                                                          |
| `CupertinoPageRoute` (right-to-left slide)            | Skip Hero. The slide already animates the destination horizontally for the entire transition; adding a Hero on top fights with it. Pass `hero: null` to `ViewfinderItem` and don't wrap the source thumbnail. |
| Custom `PageRouteBuilder` with a fade-only transition | Hero is the main motion. iOS Photos uses this — the route transition is just background chrome fading, the photo's flight does the rest.                                                                      |

Custom flight options work the same as Flutter's `Hero`:

```dart
ViewfinderItem(
  image: photo,
  hero: ViewfinderHero(
    'photo-1',
    createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
    flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) => toCtx.widget,
    transitionOnUserGestures: true,
  ),
)
```

## Decode size and memory

By default the library does **not** wrap your `ImageProvider` with `ResizeImage`. The provider you pass is the provider that decodes — at the source's native resolution. For a zoom-capable photo viewer that's usually what you want, because zoom past 1× immediately runs out of pixels otherwise.

When memory matters more than maximum zoom quality, set `decodeSizeMultiplier` on the gallery: every image-backed page (and its adjacent-page precache, with matching cache keys) decodes at viewport size × N physical pixels instead:

```dart
Viewfinder(
  decodeSizeMultiplier: 2.0, // 2× viewport: sharp up to ~2× zoom
  // …
)
```

Upscaling is never forced (`ResizeImagePolicy.fit`), so small sources keep decoding at their native size. For full manual control — or for a standalone `ViewfinderImage` — wrap the provider yourself:

```dart
ViewfinderItem(
  image: ResizeImage(
    NetworkImage(url),
    width: targetPx,
    height: targetPx,
  ),
)
```

For thumbnail-style usage at small sizes, multiply your logical pixel size by `MediaQuery.devicePixelRatioOf(context)` — `ResizeImage.width` / `.height` are interpreted as physical pixels in current Flutter.

Other levers for very large galleries: `precacheAdjacent: 0` disables warm-up decodes entirely, and `allowImplicitScrolling: false` stops `PageView` from keeping neighbor pages built. The defaults (`1` / `true`) hold up to three decoded full-size neighbors alive around the current page — multiply that by your source resolution to estimate peak decode memory.

A note on orientation: the provider is handed to `Image()` untouched, so EXIF orientation is applied (or not) by the codec exactly as it would be in any other Flutter `Image`. A sideways `FileImage` of a phone photo is an EXIF question, not a viewer one.

## Network images: pair with a byte-caching provider

`NetworkImage` has no persistent HTTP cache. Each distinct `ImageProvider` cache key triggers a fresh HTTP GET on remount.

Pair viewfinder with an `ImageProvider` that caches bytes on disk so a single HTTP fetch serves every later decode — for example [`taro`](https://pub.dev/packages/taro):

```dart
ViewfinderItem(
  image: TaroImage('https://example.com/photo.jpg'),
)
```

The provider must be a pure `ImageProvider` that delegates to the `ImageDecoderCallback` passed to `loadImage`, so any `ResizeImage` you put on top of it can still flow `getTargetSize` through to the codec.

The layers compose cleanly:

| Layer         | Job                          | Provided by                  |
| ------------- | ---------------------------- | ---------------------------- |
| Decode size   | Decode at the requested size | your `ResizeImage` (or none) |
| Decoded frame | Reuse across same cache key  | Flutter `imageCache`         |
| Bytes / HTTP  | Reuse across decode sizes    | your byte-caching provider   |

## Video and other non-image pages

`ViewfinderItem.child` gives any widget the same zoom / pan / dismiss machinery as a photo. For a page that handles its own taps — a video player whose single tap toggles play/pause and whose double-tap seeks — disable the viewer's double-tap zoom for that page only and let the child's own gesture detectors win the arena (they sit deeper, so they do):

```dart
ViewfinderItem.child(
  contentKey: video.id,
  doubleTapScales: const [], // double-tap (and double-tap-drag) zoom off for this page
  child: MyVideoPlayer(video),
)
```

Pinch-zoom still works on the page; drags inside the child's own controls (a scrub bar, for instance) stay with the child because its recognizers accept at the same slop as the pager's but sit closer to the pointer. Pair with `keepAlivePages: true` so playback position survives swiping away and back.

## Browser back / URL sync (web)

The gallery doesn't write to the browser history itself — which router owns the URL is an app decision. Syncing is two lines in each direction: report page changes to your router, and drive the controller from the route:

```dart
final controller = ViewfinderController(initialIndex: initialFromUrl);

Viewfinder(
  controller: controller,
  onPageChanged: (index) {
    // e.g. go_router: context.replace('/photos/$index');
    // or:  Router.neglect(context, () => context.go('/photos/$index'));
  },
  // …
)

// When the route changes (browser back / deep link):
controller.jumpTo(indexFromUrl);
```

Use your router's "replace, don't push" flavor per swipe so the back button leaves the gallery rather than replaying every photo.

## Testing your gallery

Stable keys are attached for widget tests — no fishing through internal types:

```dart
await tester.tap(find.byKey(ViewfinderKeys.thumbnail(3)));
expect(find.byKey(ViewfinderKeys.page(3)), findsOneWidget);
```

`ViewfinderImage`'s runtime type is a package-internal subclass, so `find.byType(ViewfinderImage)` does not match; when you need the widget itself use `find.byWidgetPredicate((w) => w is ViewfinderImage)`. To drive zoom programmatically in a test, pass a `ViewfinderImageController` and call `animateToScale` / `jumpToTransform`.

## License

MIT.
