## 0.1.0

* Initial release.
* `Viewfinder` gallery (`PageView`-backed, horizontal or vertical `pagerAxis`) and `ViewfinderImage` / `.child` single viewer.
* Pinch, pan, double-tap ladder, double-tap-drag continuous zoom, opt-in two-finger rotation; fling via `FrictionSimulation`.
* Rubber-band elastic edges — pulling a zoomed image past its boundary shows live elastic over-pan with diminishing returns, then animates back on release.
* Custom `ZoomableViewport` gesture layer that yields edge pans to the parent scrollable via `canPan(Axis, int)`. Yields single-pointer drags along the pager axis when not zoomed, so mouse-drag and trackpad-drag swipe pages on web/desktop.
* `Viewfinder.swipeDragDevices` — explicit pointer-kind set for the underlying `PageView`. Defaults to all kinds (`kViewfinderDefaultSwipeDragDevices`) — overrides Flutter's default `ScrollBehavior` which excludes mouse on web/desktop.
* `ViewfinderItem.thumbImage` — low-res preview that cross-fades into the main image on first frame.
* `ViewfinderThumbnails` (4 positions, `.custom()`), `ViewfinderPageIndicator` (dots or `1 / N`).
* `ViewfinderDismiss` drag-to-dismiss with `slideType: wholePage | onlyImage` and an `onProgress` callback that reports normalized drag progress through the spring-back.
* `ViewfinderChromeController` — tap-to-toggle, auto-hide after idle, auto-hide while zoomed.
* Keyboard (arrows, PageUp/Down, two-stage Escape), Android back-button two-stage, `PopScope`-based Hero coherence on pop.
* Mouse wheel + trackpad pinch zoom.
* `precacheAdjacent` warms `imageCache` for pages ±N around the current one, using the user's `ImageProvider` directly so cache keys match what `Image()` will resolve.
* `kViewfinderDefaultFlingDrag = 0.0000135`, overridable via `interactionEndFrictionCoefficient`.
* Semantics labels per image and at gallery level.
