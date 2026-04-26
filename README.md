# viewfinder

A photo viewer for Flutter. Pinch / double-tap / rotation zoom, an arena-aware gesture layer that hands off edge pans to a parent `PageView`, drag-to-dismiss, a synchronized thumbnail strip, a page indicator, keyboard shortcuts, a chrome controller for tap-to-toggle UX, and decode-time `ResizeImage` wiring so 4K photos don't blow up your memory budget.

Accepts any `ImageProvider` (`NetworkImage`, `AssetImage`, `FileImage`, `MemoryImage`, …). No runtime dependencies beyond the Flutter SDK.

## Quick start

### Single photo

```dart
ViewfinderImage(
  image: const NetworkImage('https://example.com/photo.jpg'),
  resize: const ViewfinderResize.targetSize(),
  initialScale: const ViewfinderInitialScale.contain(),
  doubleTapScales: const [1, 2.5, 5],
  minScale: 1.0,
  maxScale: 8.0,
)
```

### Gallery

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
    heroTag: 'photo-$index',
    semanticLabel: 'Vacation photo ${index + 1}',
  ),
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
* **Adjacent-page precache** — `precacheImage` warms the `PaintingBinding.imageCache` for pages ±N from the current one, wrapped with the same `ViewfinderResize` the gallery renders with so cache keys match.
* **Semantics** — per-image labels plus a gallery-level `Photo gallery, X of N`.

## Resize strategies

`ViewfinderResize` wraps your `ImageProvider` with `ResizeImage` so images decode at the size actually displayed, not their native resolution:

| Variant                             | Decoded size                       |
| ----------------------------------- | ---------------------------------- |
| `ViewfinderResize.targetSize()`     | widget layout × device pixel ratio |
| `ViewfinderResize.fixed(width: …)`  | explicit pixel dimensions          |
| `ViewfinderResize.custom(resolver)` | whatever your callback returns     |
| `ViewfinderResize.none`             | no resize                          |

All constructors accept `allowUpscaling: true` if you explicitly want to upsample small images to the viewport.

## Network images: pair with a byte-caching provider

viewfinder's `precacheAdjacent` warms the `imageCache` for the _decoded frame_ at the right size. It does **not** cache raw bytes.

`NetworkImage` has no persistent HTTP cache. Each distinct `ResizeImage` cache key (different size, different page, different re-mount) triggers a fresh HTTP GET.

Pair viewfinder with an `ImageProvider` that caches bytes on disk so a single HTTP fetch serves every decode size — for example [`taro`](https://pub.dev/packages/taro):

```dart
ViewfinderItem(
  image: TaroImage('https://example.com/photo.jpg'),
)
```

For the resize hint to reach the codec, the provider must be a pure `ImageProvider` that delegates to the `ImageDecoderCallback` passed to `loadImage` — that's what lets `ResizeImage`'s `getTargetSize` flow through.

The layers compose cleanly:

| Layer         | Job                          | Provided by              |
| ------------- | ---------------------------- | ------------------------ |
| Display size  | Decode at layout × DPR       | **viewfinder**           |
| Decoded frame | Reuse across same cache key  | Flutter `imageCache`     |
| Bytes / HTTP  | Reuse across all decode sizes| your byte-caching provider |

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

## Hero + back button

The first Escape (or Android back, or iOS back swipe) on a zoomed photo resets the zoom instead of popping. The second pops. If you drive navigation from your own code, check first:

```dart
if (galleryController.resetCurrentImage()) return; // consumed
Navigator.of(context).pop();
```

On actual pop, `PopScope` snaps every page to its initial transform before the Hero flight begins, so the flight source rect is correct.

## License

MIT.
