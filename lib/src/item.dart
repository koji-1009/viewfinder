import 'package:flutter/widgets.dart';

import 'initial_scale.dart';
import 'resize.dart';
import 'viewfinder.dart' show Viewfinder;

/// Describes a single page of a [Viewfinder] gallery.
///
/// Pass either [image] *or* [child]. When [image] is given the page is
/// built as an `Image(provider)` honoring the gallery-wide
/// [ViewfinderResize] strategy (per-item override via [resize]).
@immutable
class ViewfinderItem {
  const ViewfinderItem({
    required ImageProvider this.image,
    this.thumbImage,
    this.resize,
    this.heroTag,
    this.loadingBuilder,
    this.errorBuilder,
    this.initialScale,
    this.minScale,
    this.maxScale,
    this.semanticLabel,
  }) : child = null;

  const ViewfinderItem.child({
    required Widget this.child,
    this.heroTag,
    this.initialScale,
    this.minScale,
    this.maxScale,
    this.semanticLabel,
  }) : image = null,
       thumbImage = null,
       resize = null,
       loadingBuilder = null,
       errorBuilder = null;

  final ImageProvider? image;
  final Widget? child;

  /// Low-resolution image shown while [image] is still loading.
  /// Cross-faded to the main image as soon as the first frame decodes.
  final ImageProvider? thumbImage;

  final ViewfinderResize? resize;
  final Object? heroTag;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ViewfinderInitialScale? initialScale;
  final double? minScale;
  final double? maxScale;
  final String? semanticLabel;
}
