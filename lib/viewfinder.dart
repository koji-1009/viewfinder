/// viewfinder — a modern Flutter photo viewer.
///
/// Built on top of [PageView], [Hero], and [Image] — just the standard
/// Flutter widgets. Provides pinch / double-tap zoom, optional
/// drag-to-dismiss, a thumbnail strip, a page indicator, and
/// adjacent-page precache.
library;

import 'package:flutter/widgets.dart' show PageView, Hero, Image;

export 'src/chrome.dart';
// ViewfinderDismissible is an internal wrapper used by Viewfinder; users
// configure drag-to-dismiss via the public ViewfinderDismiss config.
export 'src/dismiss.dart' hide ViewfinderDismissible;
export 'src/hero.dart';
export 'src/image.dart';
export 'src/initial_scale.dart';
export 'src/item.dart';
// ViewfinderPageIndicatorOverlay is an internal renderer; users configure
// the indicator via the sealed ViewfinderPageIndicator hierarchy.
export 'src/page_indicator.dart' hide ViewfinderPageIndicatorOverlay;
// ViewfinderThumbnailBar is an internal renderer; users configure
// thumbnails via the public ViewfinderThumbnails config.
export 'src/thumbnails.dart' hide ViewfinderThumbnailBar;
export 'src/viewfinder.dart';
