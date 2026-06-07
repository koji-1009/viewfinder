/// viewfinder — a modern Flutter photo viewer.
///
/// Built on top of [PageView], [Hero], and [Image] — just the standard
/// Flutter widgets. Provides pinch / double-tap zoom, optional
/// drag-to-dismiss, a thumbnail strip, a page indicator, and
/// adjacent-page precache.
library;

import 'package:flutter/widgets.dart' show PageView, Hero, Image;

export 'src/chrome.dart';
export 'src/dismiss.dart';
export 'src/hero.dart';
// Variant subclasses are public-named within the package so internal
// renderers can pattern-match across files, but the names are not part
// of the published API (no verified external use case).
export 'src/image.dart' hide ViewfinderProviderImage, ViewfinderChildImage;
export 'src/initial_scale.dart';
export 'src/item.dart' hide ViewfinderImageItem, ViewfinderChildItem;
export 'src/keys.dart';
export 'src/page_indicator.dart';
export 'src/pan_gate.dart';
export 'src/thumbnails.dart';
export 'src/viewfinder.dart';
