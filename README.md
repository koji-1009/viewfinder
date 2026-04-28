# viewfinder

A photo viewer for Flutter. Pinch / double-tap / rotation zoom, an arena-aware gesture layer that hands off edge pans to a parent `PageView`, drag-to-dismiss, a synchronized thumbnail strip, a page indicator, keyboard shortcuts, and a chrome controller for tap-to-toggle UX.

Accepts any `ImageProvider` (`NetworkImage`, `AssetImage`, `FileImage`, `MemoryImage`, …) and feeds it straight to `Image()`. No runtime dependencies beyond the Flutter SDK.

## Highlights

* **Native-feel gestures end-to-end** — pinch, pan, fling, double-tap-and-drag continuous zoom (iOS Photos style), two-finger rotation (opt-in). Rubber-band over-pan with diminishing returns at the edges, `FrictionSimulation`-driven post-release fling, both tunable per widget.
* **Built for every input** — touch, stylus, trackpad, mouse, and hardware keyboard (Arrow / PageUp / PageDown / Esc) all wired in by default. Mouse wheel zooms around the pointer; mouse drag swipes pages on web and desktop out of the box.
* **Plays well with parents** — an arena-aware gesture layer hands edge pans back to a parent `PageView` so a zoomed photo can swipe to the next page without lifting the finger, on either axis.
* **Gallery affordances included** — `Viewfinder.images([...])` takes you from a list of `ImageProvider`s to a full gallery; thumbnail strip (4 positions or fully custom), page indicator (dots or `1 / N`), drag-to-dismiss with `wholePage` / `onlyImage` slide modes, tap-to-toggle chrome controller. All opt-in via dedicated config objects.
* **Robust pop and back-button behavior** — pop while zoomed snaps every page back to its initial transform first, so any Hero flight starts from a sensible source rect; the first back / Esc on a zoomed photo resets the zoom, the second pops.
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
  indicator: const ViewfinderPageIndicator(),
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
  minScale: 1.0,
  maxScale: 8.0,
)
```

### Non-image content

```dart
ViewfinderImage.child(
  child: CustomPaint(painter: MyPainter()),
  initialScale: const ViewfinderInitialScale.cover(),
)
```

## Features

* **Zoom & pan** — pinch, two-finger rotation (opt-in), double-tap ladder (`doubleTapScales: [1, 2.5, 5]`), double-tap-and-drag continuous zoom (iOS Photos style).
* **Rubber-band edges** — when a zoomed photo is pulled past its boundary, the displacement diminishes elastically and snaps back on release.
* **Arena-aware edge hand-off** — when a zoomed photo is panned against its edge, the custom gesture recognizer yields the pointer so a parent `PageView` continues the swipe without releasing. Works on `Axis.horizontal` or `Axis.vertical` via `Viewfinder.pagerAxis`.
* **Fling** — post-release inertia via Flutter's `FrictionSimulation` with `kViewfinderDefaultFlingDrag = 0.0000135`, overridable per widget through `interactionEndFrictionCoefficient`.
* **Drag-to-dismiss** — `ViewfinderDismiss(onDismiss: …)`. Auto-disabled while zoomed. Background fades with drag. `slideType` picks between `wholePage` (thumbnails slide too) and `onlyImage` (thumbnails stay anchored). `onProgress` reports normalized drag progress (incl. spring-back) so callers can fade their own chrome.
* **Thumbnail strip** — `ViewfinderThumbnails(position: …)` at top / bottom / left / right, or `.custom(itemBuilder: …)` for full control.
* **Page indicator** — `ViewfinderPageIndicator()` draws dots, switches to a `1 / N` label above `maxDots`.
* **Progressive loading** — `ViewfinderItem(thumbImage: lowRes)` shows the low-res while the full image decodes; cross-fades when the first frame lands.
* **Chrome controller** — `ViewfinderChromeController` drives tap-to-toggle visibility of thumbnails + indicator + any `chromeOverlays` widgets you plug in. Auto-hide after idle, auto-hide while zoomed.
* **Coherent pop** — on pop (Android back, iOS swipe, `Navigator.pop`) every page snaps back to its initial transform before the route exits, so any Hero flight starts from a sensible source rect.
* **Two-stage back / Esc** — via `PopScope`. First back-press on a zoomed photo resets the zoom; the second pops. Hardware Escape mirrors this on desktop and web.
* **Keyboard** — Arrow Left/Right, PageUp/Down, Escape (two-stage). Matches the Android back button semantics for desktop and web.
* **Mouse wheel & trackpad** — scroll zooms around the pointer location; trackpad pinch (macOS) via `trackpadScrollCausesScale`.
* **Mouse-drag page swipe (web & desktop)** — `swipeDragDevices` ships with mouse / trackpad / touch / stylus enabled, so mouse-drag swipes pages out of the box. Pass a narrower set to opt out.
* **Adjacent-page precache** — `precacheImage` warms the `PaintingBinding.imageCache` for pages ±N from the current one. The provider you passed in is used directly, so the cache key matches what `Image()` will resolve at paint time.
* **Semantics** — per-image labels plus a gallery-level `Photo gallery, X of N`.

## Decode size and memory

The library does **not** wrap your `ImageProvider` with `ResizeImage`. The provider you pass is the provider that decodes — at the source's native resolution. For a zoom-capable photo viewer that's usually what you want, because zoom past 1× immediately runs out of pixels otherwise.

If memory matters more than zoom quality, wrap on your side:

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

## Chrome controller

```dart
final chrome = ViewfinderChromeController(
  autoHideAfter: const Duration(seconds: 3),
  autoHideWhileZoomed: true,
);

Viewfinder(
  chromeController: chrome,
  thumbnails: const ViewfinderThumbnails(),
  indicator: const ViewfinderPageIndicator(),
  chromeOverlays: [
    Positioned(top: 0, left: 0, right: 0, child: myAppBar),
  ],
  // …
)
```

Tap the photo area: toggle chrome. Zoom in: chrome auto-hides. Page change: auto-hide timer restarts. `chromeOverlays` fade in sync with thumbnails and indicator.

## Hero

`ViewfinderHero` forwards every option Flutter's `Hero` exposes (`createRectTween`, `flightShuttleBuilder`, `placeholderBuilder`, `transitionOnUserGestures`). Two known Hero-with-photo-viewer pitfalls are handled internally:

* **Source rect coherence on pop** — when the route pops while a page is zoomed in, every page jumps back to its initial transform _before_ the Hero flight captures its source rect. The flight starts from the photo's natural bounds, never from a visibly zoomed crop.
* **Adjacent-page Hero leak** — only the currently-visible page carries its Hero tag. `PageView` pre-builds neighbors (especially with `allowImplicitScrolling`); without this rule, every pre-built page would fly on pop.

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

## License

MIT.
