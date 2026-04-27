# viewfinder_example

A demo gallery for the `viewfinder` package.

The home grid opens any image in a full-screen `Viewfinder`. Tap the
gear icon in the AppBar to toggle every configurable knob without
restarting:

* Pager — `pagerAxis`, `precacheAdjacent`, `swipeDragDevices`,
`rotateEnabled`, `defaultInitialScale`
* Thumbnails — enable / position / `safeArea` / custom selected-tile
builder
* Page indicator — enable / force numeric fallback
* Drag-to-dismiss — enable / `slideType` (live progress shown in the
AppBar)
* Chrome controller — enable / `autoHideAfter` / auto-hide-while-zoomed

Run with `flutter run` from this directory.
