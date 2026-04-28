# viewfinder

A photo viewer for Flutter. Pinch / double-tap / rotation zoom, an arena-aware gesture layer that hands off edge pans to a parent `PageView`, drag-to-dismiss, a synchronized thumbnail strip, a page indicator, keyboard shortcuts, and a chrome controller for tap-to-toggle UX.

Accepts any `ImageProvider` (`NetworkImage`, `AssetImage`, `FileImage`, `MemoryImage`, …) and feeds it straight to `Image()`. No runtime dependencies beyond the Flutter SDK.

## Quick start

### Gallery from a list

```dart
Viewfinder.images(
  photos, // List<ImageProvider>
  dismiss: ViewfinderDismiss(onDismiss: () => Navigator.pop(context)),
  hero: (i) => ViewfinderHero('photo-$i'),
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
    hero: ViewfinderHero('photo-$index'),
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
* **Hero coherence** — on pop (Android back, iOS swipe, `Navigator.pop`) the current photo snaps to its initial transform _before_ the Hero flight captures its source rect, so flights never start from a visibly zoomed rect.
* **Android back button 2-stage** — via `PopScope`. First back-press on a zoomed photo resets it; the second actually pops.
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

## Hero animation and route transitions

Hero flies a widget's bounds from a fixed source rect (in the outgoing route) to a fixed destination rect (in the incoming route). It looks clean when the destination is _visually stable_ during the route transition. When the destination is itself translating during the transition, the flight aims at a moving target and the trajectory looks bent.

| Route                                                 | Hero advice                                                                                                                                                                                                   |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MaterialPageRoute` (Android fade-up)                 | Hero is fine — destination stays roughly centered while it fades in.                                                                                                                                          |
| `CupertinoPageRoute` (right-to-left slide)            | Skip Hero. The slide already animates the destination horizontally for the entire transition; adding a Hero on top fights with it. Pass `hero: null` to `ViewfinderItem` and don't wrap the source thumbnail. |
| Custom `PageRouteBuilder` with a fade-only transition | Hero is the main motion. iOS Photos and similar viewers use this — the route transition is just background chrome fading, the photo's flight does the rest.                                                   |

`ViewfinderHero` exposes Flutter's full [Hero] API, so you can override the rect tween, swap in a flight shuttle, or opt into in-flight gestures:

```dart
ViewfinderItem(
  image: photo,
  hero: ViewfinderHero(
    'photo-1',
    createRectTween: (begin, end) => MaterialRectArcTween(begin: begin, end: end),
    flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) =>
        toCtx.widget,
    transitionOnUserGestures: true,
  ),
)
```

## Hero + back button

The first Escape (or Android back, or iOS back swipe) on a zoomed photo resets the zoom instead of popping. The second pops. If you drive navigation from your own code, check first:

```dart
if (galleryController.resetCurrentImage()) return; // consumed
Navigator.of(context).pop();
```

On actual pop, `PopScope` snaps every page to its initial transform before the Hero flight begins, so the flight source rect is correct.

## License

MIT.
