# viewfinder_example

A multi-scenario demo app for the `viewfinder` package.

## Live demo

[https://koji-1009.github.io/viewfinder/](https://koji-1009.github.io/viewfinder/)

The hosted build is deployed automatically from `main` to GitHub Pages by
`.github/workflows/deploy.yaml` (`flutter build web --base-href "/viewfinder/"`).

## Scenarios

The home screen lists five scenarios, each a separate route with an in-app
description of what to try:

* **Gallery** — a responsive grid that opens a full-screen `Viewfinder` with a
thumbnail strip, page indicator, drag-to-dismiss, a tap-to-toggle chrome
overlay, Hero flight, and a live settings sheet (tune icon) that flips every
knob without restarting.
* **Single photo** — `Viewfinder.single` with drag-to-dismiss.
* **Vertical pager** — `pagerAxis: Axis.vertical` (no dismiss — the combination
asserts).
* **Embedded zoom** — `ViewfinderImage` inline in a scrollable article, plus
`ViewfinderImage.child` zooming a non-image widget via `contentKey`.
* **Rotation playground** — `rotateEnabled: true` with a rotation slider (mouse and web trackpads have no rotate gesture) and a reset button.

Images come from picsum.photos (CORS-safe) via `TaroImage`, which caches bytes
on disk so thumbnail and full-screen decodes share one HTTP fetch.

## Desktop / web inputs

Where relevant the UI hints at non-touch inputs: mouse wheel to zoom, mouse drag
to swipe, double-tap / double-tap-drag, and the Arrow / PageUp / PageDown / Esc
keyboard shortcuts (Esc is two-stage — first resets zoom, then closes).

## Run locally

```sh
flutter run            # mobile / desktop
flutter run -d chrome  # web
```
