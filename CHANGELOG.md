# Changelog

## 1.0.0

First stable release; the public API is now covered by semantic versioning. Includes the unpublished 0.4.0 changes.

The library imports only `package:flutter/widgets.dart` — no Material dependency, ready for the Flutter 3.44 material/SDK split.

### Breaking changes

* `minScale` / `maxScale` / `doubleTapScales`, `ViewfinderImageController.scale` / `animateToScale`, and `onScaleChanged` are relative to the initial scale (`1.0` = initial). Raw-matrix APIs stay absolute. Out-of-range bounds are rejected at construction, including per-item overrides.
* `SwipeEdgeMode` is removed. `canSwipe` / `canSwipeToward` answer the swipe-handoff question in screen space, the frame a pager scrolls in.
* `ViewfinderImage.canPan` / `claimPan` are replaced by a single `panGate` returning `ViewfinderPanVerdict` (`release` / `compete` / `claim`). The `ZoomableCanPan` / `ZoomableClaimPan` typedefs are gone.
* An empty `doubleTapScales` also disables double-tap-drag zoom.

### Bug fixes

* Edge handoff is direction-aware: a zoomed photo flush against one edge pans toward its hidden side instead of swiping pages, and such pans are no longer stolen by the pager or dismiss recognizers. Drag-to-dismiss is disabled while zoomed.
* `reverse: true` and RTL layouts hand off to the correct neighbor page.
* Lifting one finger of a two-finger gesture keeps edge handoff for the remaining finger.
* Programmatic transform writes stop an in-flight fling/snap-back; starting a gesture stops a double-tap animation.
* The transform re-clamps when the viewport resizes and when `minScale` / `maxScale` narrow at runtime.
* Swapping the current page's provider while zoomed no longer throws during build.
* Turning `loop` on at runtime keeps the current page.
* Provider-backed heroes fly a viewer-fit shuttle by default, so a pop flight no longer flickers against a differently-fitted source thumbnail.
* `gaplessPlayback` with a `thumbImage` no longer flashes the thumb on a provider swap.
* Page indicators keep clear of system intrusions (`ViewfinderPageIndicator.safeArea`, default `true`).
* The thumbnail strip scrolls the selected tile to center on first render, including the strip's leading padding.
* Disabling dismiss mid-drag springs back instead of leaving the page displaced; the dismiss threshold signal re-arms when `onDismiss` keeps the widget mounted.
* `ViewfinderController.currentIndex` is clamped after an out-of-range `initialIndex`; a swapped-in controller adopts the current page.
* `pageSpacing` pads along the pager axis on vertical pagers.
* Dismiss `threshold` / `onProgress` divide by the viewport height in `slideType: onlyImage`, matching the visuals.
* Browser pinch zoom (`PointerScaleEvent`) is handled; trackpad two-finger scroll follows the wheel-zoom setting, so `mouseWheelBehavior: paging` pages on trackpads too.
* `mouseWheelBehavior: paging` turns one page per scroll gesture — a trackpad stream and its momentum tail no longer stutter the transition or skip pages.
* A tap followed by a horizontal drag swipes the page; double-tap-drag zoom claims only vertically dominant drags.

### API additions

* `loop: true` — wrap-around paging; `jumpTo` / `animateTo` travel the shortest direction.
* `ViewfinderHero.thumbnailFit` — the default shuttle interpolates between the thumbnail's fit and the viewer's over the flight, landing exactly on the thumbnail's crop.
* `Viewfinder.filterQuality` — sampling quality for every page.
* `onLongPress` / `onLongPressStart` / `onSecondaryTapUp` on `ViewfinderImage` and `ViewfinderItem`; forwarded by `Viewfinder.images` (index-aware) and `Viewfinder.single`.
* `Viewfinder.onScaleStateChanged` — coalesced initial ⇄ zoomed transitions of the current page.
* `ViewfinderImageController.canSwipeToward(AxisDirection)`.
* Screen-reader page announcements (`announcePageChanges`, `pageAnnouncementBuilder`); semantics on thumbnail tiles and the dots indicator (`semanticLabelBuilder`).
* Reduce-motion support: animations jump when `MediaQuery.disableAnimations` is set.
* `mouseWheelBehavior` (`.zoom` / `.paging`); `ViewfinderImage.enableMouseWheelZoom` and `doubleTapDragZoom` are public.
* `decodeSizeMultiplier` — decode pages and their precache at viewport × N physical pixels.
* `dismissOnOverscroll` — overscrolling past the first/last page dismisses.
* `ViewfinderDismiss.onThresholdCrossed` — edge-triggered threshold signal for haptics.
* `keepAlivePages`, `restorationId`, `immersiveSystemUi`.
* Per-item `doubleTapScales` override.
* `ViewfinderKeys` — stable `page(i)` / `thumbnail(i)` keys for widget tests.
* Up/Down arrow keys navigate vertical pagers.

## 0.3.2

### Bug fixes

* `mounted` guard on the thumbnail bar's post-frame scroll callback.

## 0.3.1

### API additions

* `ViewfinderThumbnails.errorBuilder` — custom placeholder for thumbnail tiles whose provider fails to decode (default tile only; `itemBuilder` owns its own error handling).

## 0.3.0

### Breaking changes

* `ViewfinderImageController.canSwipeHorizontally` / `canSwipeVertically` getters are replaced by `canSwipe(Axis axis)`. Migration: `c.canSwipeHorizontally` → `c.canSwipe(Axis.horizontal)`.

### API additions

* `SwipeEdgeMode` — frame-of-reference selector for `canSwipe` under rotation (removed again in 1.0.0).

## 0.2.1

### API additions

* `thumbCrossFadeCurve` on `ViewfinderImage` / `ViewfinderItem` (default `Curves.easeOut`).
* `Viewfinder.images` / `Viewfinder.single` forward `thumbCrossFadeDuration`, `thumbCrossFadeCurve`, and `gaplessPlayback`.

## 0.2.0

### Breaking changes

* Removed `ViewfinderInitialScale.value(scale)` — identical to `contain(scale)`; use that instead.
* `ViewfinderImage.child` / `ViewfinderItem.child` require a `contentKey` so the gallery can reset the in-page transform on a content swap. Any constant works for a single static child.

### Bug fixes

* `canSwipeHorizontally` / `canSwipeVertically` report the correct edge state under rotation.
* Built `ViewfinderItem`s are no longer cached by index; dynamic galleries (re-order, swap-in) rebuild lazily.
* The in-page transform resets when the content identity changes (provider `==` / `contentKey`), instead of leaking to the new content.

### API additions

* `Viewfinder.images` forwards `reverse`, `allowEdgeHandoff`, and `rubberBandPan`.

### Validation

* `pagerAxis: Axis.vertical` with a non-null `dismiss` is rejected (both consume vertical drags).
* Attaching one `ViewfinderImageController` to multiple viewers trips a debug assert.

## 0.1.0

* Initial release.
* `Viewfinder` gallery (`PageView`-backed, horizontal or vertical) and `ViewfinderImage` / `.child` single viewer.
* Pinch, pan, double-tap ladder, double-tap-drag continuous zoom, opt-in two-finger rotation; post-release fling on pan and scale; rubber-band elastic edges.
* `ViewfinderInitialScale.contain([factor])` / `.cover([factor])`.
* Edge pans yield to the parent scrollable; mouse/trackpad drags swipe pages on web/desktop (`swipeDragDevices`).
* `ViewfinderItem.thumbImage` low-res preview cross-fade.
* `ViewfinderThumbnails` (4 positions, `.custom()`); sealed `ViewfinderPageIndicator` with `Dots` / `Label` / `Adaptive` variants.
* `ViewfinderDismiss` drag-to-dismiss (`wholePage` / `onlyImage`, `onProgress`).
* `ViewfinderChromeController` — tap-to-toggle, auto-hide.
* Keyboard navigation, two-stage Escape / Android back, `PopScope`-based Hero coherence on pop.
* Mouse wheel + trackpad pinch zoom; `precacheAdjacent`; semantics labels; `reverse`; `allowEdgeHandoff`; `rubberBandPan`; `onScaleStart` / `onScaleEnd`; `gaplessPlayback`; `currentTransform` / `jumpToTransform` / `animateToTransform`.
