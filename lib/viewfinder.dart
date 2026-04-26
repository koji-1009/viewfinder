/// viewfinder — a modern Flutter photo viewer.
///
/// Built on top of [PageView], [Hero], and [Image] — just the standard
/// Flutter widgets. Provides pinch / double-tap zoom, optional
/// drag-to-dismiss, a thumbnail strip, a page indicator, adjacent-page
/// precache, and decode-time `ResizeImage` integration.
library;

import 'package:flutter/widgets.dart' show PageView, Hero, Image;

export 'src/chrome.dart';
export 'src/dismiss.dart';
export 'src/image.dart';
export 'src/initial_scale.dart';
export 'src/item.dart';
export 'src/page_indicator.dart';
export 'src/resize.dart';
export 'src/thumbnails.dart';
export 'src/viewfinder.dart';
