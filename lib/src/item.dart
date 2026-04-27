import 'package:flutter/widgets.dart';

import 'initial_scale.dart';
import 'viewfinder.dart' show Viewfinder;

/// Describes a single page of a [Viewfinder] gallery.
///
/// Pass either [image] *or* [child]. The provider is fed straight to
/// `Image(provider)`; if you want to cap decode size for memory you
/// can wrap with `ResizeImage` yourself before passing.
@immutable
class ViewfinderItem {
  const ViewfinderItem({
    required ImageProvider this.image,
    this.thumbImage,
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
       loadingBuilder = null,
       errorBuilder = null;

  final ImageProvider? image;
  final Widget? child;

  /// Low-resolution image shown while [image] is still loading.
  /// Cross-faded to the main image as soon as the first frame decodes.
  final ImageProvider? thumbImage;

  final Object? heroTag;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ViewfinderInitialScale? initialScale;
  final double? minScale;
  final double? maxScale;
  final String? semanticLabel;
}
