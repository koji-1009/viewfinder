## 0.3.1

### API additions

* `ViewfinderThumbnails.errorBuilder` lets callers customize the placeholder rendered in the thumbnail strip when an `ImageProvider` fails to decode. When omitted, the library default (`ColoredBox(color: Colors.white12)`) is used; when provided, the caller's builder runs in its place. Applied to the default tile only — when [itemBuilder] is provided the builder owns the entire visual treatment, including error handling.

### Internal

* Removed an internal `_precached` index set that was deduping `precacheImage` calls. Successful providers are already deduped by Flutter's `ImageCache`; failed providers do get re-attempted on subsequent adjacent moves, but the cost is bounded by `precacheAdjacent`. The set never shrank, so it grew monotonically with every visited index. Its `onError` callback was also silently swallowing precache failures; precache errors now route through the normal `FlutterError.reportError` path. The actual display path still surfaces decode errors to the user-supplied `errorBuilder`.
* Dropped a redundant `LayoutBuilder` from the image-and-thumb composite. The parent `ZoomableViewport` already wraps its child in a tight-sized `SizedBox`, so `Image.fit` lays out against the viewport without an extra layout pass.

## 0.3.0

### Breaking changes

* **`ViewfinderImageController.canSwipeHorizontally` / `canSwipeVertically` getters removed** in favor of a single `canSwipe(Axis axis, {SwipeEdgeMode mode = SwipeEdgeMode.screen})` method. The default behavior is unchanged — `canSwipe(Axis.horizontal)` returns the same value as the old `canSwipeHorizontally` did — but the call site changes. Migration: `c.canSwipeHorizontally` → `c.canSwipe(Axis.horizontal)`, `c.canSwipeVertically` → `c.canSwipe(Axis.vertical)`.

### API additions

* `SwipeEdgeMode` selects the frame of reference used by `canSwipe` under rotation. `SwipeEdgeMode.screen` (the default, used by the bundled gallery) checks the rotated content's AABB against the viewport — symmetric with the internal boundary clamp and matching a screen-axis pager's intent. `SwipeEdgeMode.content` inverse-projects the viewport into photo space and checks whether it has reached the photo's logical extents `[0, viewport.width]` / `[0, viewport.height]`; the result tracks "the user has reached the photo's logical edge in the photo's own frame" at every rotation (no special-casing of cardinal angles). Use it for consumers whose handoff target follows the photo's frame, e.g. a custom pager that swipes along the photo's axes through rotation.

## 0.2.1

### API additions

* `thumbCrossFadeCurve` is now configurable on `ViewfinderImage` and `ViewfinderItem` (default `Curves.easeOut`). Previously the curve was hardcoded while `thumbCrossFadeDuration` was the only knob, so callers wanting non-default easing on the thumb-to-main fade had no way in.
* `Viewfinder.images(...)` and `Viewfinder.single(...)` now forward the per-page image-display knobs — `thumbCrossFadeDuration`, `thumbCrossFadeCurve`, `gaplessPlayback` — to every `ViewfinderItem` they construct. Previously these were reachable only by writing a custom `itemBuilder`; per-page transform overrides (`initialScale` / `minScale` / `maxScale`) still are.

## 0.2.0

### Breaking changes

* **Removed `ViewfinderInitialScale.value(scale)`.** It was behaviorally identical to `ViewfinderInitialScale.contain(scale)` — three names for two behaviors. Use `contain(scale)` instead.
* **`ViewfinderImage.child` and `ViewfinderItem.child` now require a `contentKey`.** The gallery uses it to detect content swaps and reset the in-page transform on a re-order or swap-in (the image-backed variant gets this for free from the `ImageProvider`'s `==`; for `.child` the rendered widget identity is unreliable, so the caller hands in a stable handle). For a single static `.child`, any constant works (e.g. `contentKey: 'main'`).

### Bug fixes

* `ViewfinderImageController.canSwipeHorizontally` / `canSwipeVertically` were computed from raw matrix translation components and so misreported the edge state when `rotateEnabled: true`. They now project the photo's logical left/right (and top/bottom) edges through the current transform and check whether either has been pulled into the viewport — matching the user's intent ("the photo's left side is exposed → swipe to the previous page") rather than the AABB extents (which, under rotation, are the photo's outermost corners, not its visible sides).
* `Viewfinder` no longer caches built `ViewfinderItem`s by index. The cache pinned the gallery to the first builder's output, so a dynamic gallery (re-order, swap-in) with the same `itemCount` would keep showing stale items. Pages are now rebuilt lazily through the underlying `PageView.builder` / `ListView.builder`, matching standard Flutter scrollables.
* `ViewfinderImage` now resets its in-page pan/zoom transform when the underlying content identity changes — the `ImageProvider`'s `==` for the image-backed variant, the new required `contentKey` for `.child`. Previously, slot reuse during a re-order or swap-in left the previous photo's transform applied to the new content. Pure rebuilds with the same content value still preserve the user's transform.

### API additions

* `Viewfinder.images(...)` now forwards `reverse`, `allowEdgeHandoff`, and `rubberBandPan` (previously only available on the main `Viewfinder.new` constructor).

### Validation

* Combining `pagerAxis: Axis.vertical` with a non-null `dismiss` is now rejected by a debug assert at construction. Both consume vertical drags; pick one.
* Attaching the same `ViewfinderImageController` to more than one `ViewfinderImage` at once is now rejected by a debug assert. Each controller can drive only one viewer; sharing it would silently overwrite the previous binding and produce incorrect reads through `scaleState` / `canSwipe*`. Release builds still overwrite silently — `assert` is debug-only — so callers should not rely on it as a hard guard. Internally, `ViewfinderImage` now detaches in `deactivate` and re-attaches in `activate` so tree rearrangements and `GlobalKey` moves don't trip the assert.

### Documentation

* `Viewfinder.rotateEnabled` doc said "Boundary clamping is disabled while rotated"; in fact the clamp always runs against the rotated content's AABB. Doc fixed to match the implementation.
* `ViewfinderPageIndicatorAdaptive` doc clarifies that customizing inner `dots.alignment` / `padding` / `label.alignment` / `padding` is rejected by a debug assert and silently ignored in release.

## 0.1.0

* Initial release.
* `Viewfinder` gallery (`PageView`-backed, horizontal or vertical `pagerAxis`) and `ViewfinderImage` / `.child` single viewer.
* `ViewfinderInitialScale.contain([factor])` / `.cover([factor])` accept an optional multiplier — `contain(0.8)` shows the photo at 80% of fit, `cover(1.2)` zooms to 120% of fill. `.value(scale)` remains as an absolute-multiplier shortcut.
* Pinch, pan, double-tap ladder, double-tap-drag continuous zoom, opt-in two-finger rotation; post-release fling on both pan and scale via `FrictionSimulation` (X / Y / scale axes), anchored to the focal point captured at release.
* Rubber-band elastic edges — pulling a zoomed image past its boundary shows live elastic over-pan with diminishing returns, then animates back on release.
* Custom `ZoomableViewport` gesture layer that yields edge pans to the parent scrollable via `canPan(Axis, int)`. Yields single-pointer drags along the pager axis when not zoomed, so mouse-drag and trackpad-drag swipe pages on web/desktop.
* `Viewfinder.swipeDragDevices` — explicit pointer-kind set for the underlying `PageView`. Defaults to all kinds (`kViewfinderDefaultSwipeDragDevices`) — overrides Flutter's default `ScrollBehavior` which excludes mouse on web/desktop.
* `ViewfinderItem.thumbImage` — low-res preview that cross-fades into the main image on first frame.
* `ViewfinderThumbnails` (4 positions, `.custom()`), sealed `ViewfinderPageIndicator` with `Dots` / `Label` / `Adaptive` variants (`Adaptive` falls back from dots to a `"1 / N"` label past `maxDots`; `Label` accepts a custom `labelBuilder`).
* `ViewfinderDismiss` drag-to-dismiss with `slideType: wholePage | onlyImage` and an `onProgress` callback that reports normalized drag progress through the spring-back.
* `ViewfinderChromeController` — tap-to-toggle, auto-hide after idle, auto-hide while zoomed.
* Keyboard (arrows, PageUp/Down, two-stage Escape), Android back-button two-stage, `PopScope`-based Hero coherence on pop.
* Mouse wheel + trackpad pinch zoom.
* `precacheAdjacent` warms `imageCache` for pages ±N around the current one, using the user's `ImageProvider` directly so cache keys match what `Image()` will resolve.
* `kViewfinderDefaultFlingDrag = 0.0000135`, overridable via `interactionEndFrictionCoefficient`.
* Semantics labels per image and at gallery level.
* `Viewfinder.reverse` — forwarded to `PageView.reverse` for right-to-left galleries.
* `Viewfinder.allowEdgeHandoff` (default `true`) — when `false`, a zoomed image consumes all pan and never yields to the parent `PageView`; the user must reset zoom before swiping.
* `Viewfinder.rubberBandPan` / `ViewfinderImage.rubberBandPan` (default `true`) — opt out of elastic over-pan for hard edge clamping.
* `ViewfinderImage.onScaleStart` / `onScaleEnd` — gesture lifecycle callbacks, useful for haptics and analytics.
* `ViewfinderImage.gaplessPlayback` / `ViewfinderImageItem.gaplessPlayback` (default `true`) — forwarded to the underlying `Image.gaplessPlayback`.
* `ViewfinderImageController.currentTransform` getter and `jumpToTransform` / `animateToTransform` setters for imperative position / rotation control.
