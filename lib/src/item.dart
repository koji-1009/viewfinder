import 'package:flutter/widgets.dart';

import 'hero.dart';
import 'initial_scale.dart';
import 'viewfinder.dart' show Viewfinder;

/// Describes a single page of a [Viewfinder] gallery.
///
/// Use [ViewfinderItem.new] (alias for the `image:` form) for an
/// `ImageProvider`-backed page, or [ViewfinderItem.child] for a custom
/// widget. Pattern-match on the variant ([ViewfinderImageItem] /
/// [ViewfinderChildItem]) when you need the variant-specific fields.
@immutable
sealed class ViewfinderItem {
  const ViewfinderItem._({
    this.hero,
    this.initialScale,
    this.minScale,
    this.maxScale,
    this.semanticLabel,
  });

  /// `ImageProvider`-backed page. The provider is fed straight to
  /// `Image(provider)`; wrap with `ResizeImage` yourself if you want to
  /// cap decode size for memory.
  const factory ViewfinderItem({
    required ImageProvider image,
    ImageProvider? thumbImage,
    ViewfinderHero? hero,
    ImageLoadingBuilder? loadingBuilder,
    ImageErrorWidgetBuilder? errorBuilder,
    ViewfinderInitialScale? initialScale,
    double? minScale,
    double? maxScale,
    String? semanticLabel,
  }) = ViewfinderImageItem;

  /// Custom-widget page. The [child] is wrapped with the same zoom +
  /// pan gestures as an image-backed page.
  const factory ViewfinderItem.child({
    required Widget child,
    ViewfinderHero? hero,
    ViewfinderInitialScale? initialScale,
    double? minScale,
    double? maxScale,
    String? semanticLabel,
  }) = ViewfinderChildItem;

  final ViewfinderHero? hero;
  final ViewfinderInitialScale? initialScale;
  final double? minScale;
  final double? maxScale;
  final String? semanticLabel;
}

/// `ImageProvider`-backed [ViewfinderItem] variant.
final class ViewfinderImageItem extends ViewfinderItem {
  const ViewfinderImageItem({
    required this.image,
    this.thumbImage,
    super.hero,
    this.loadingBuilder,
    this.errorBuilder,
    super.initialScale,
    super.minScale,
    super.maxScale,
    super.semanticLabel,
  }) : super._();

  final ImageProvider image;

  /// Low-resolution image shown while [image] is still loading.
  /// Cross-faded to the main image as soon as the first frame decodes.
  final ImageProvider? thumbImage;

  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;
}

/// Custom-widget [ViewfinderItem] variant.
final class ViewfinderChildItem extends ViewfinderItem {
  const ViewfinderChildItem({
    required this.child,
    super.hero,
    super.initialScale,
    super.minScale,
    super.maxScale,
    super.semanticLabel,
  }) : super._();

  final Widget child;
}
