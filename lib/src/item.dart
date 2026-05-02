import 'package:flutter/widgets.dart';

import 'hero.dart';
import 'initial_scale.dart';
import 'viewfinder.dart' show Viewfinder;

/// Describes a single page of a [Viewfinder] gallery.
///
/// Construct via [ViewfinderItem.new] (image-backed) or
/// [ViewfinderItem.child] (custom widget).
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
    bool gaplessPlayback,
  }) = ViewfinderImageItem;

  /// Custom-widget page. The [child] is wrapped with the same zoom +
  /// pan gestures as an image-backed page.
  ///
  /// [contentKey] identifies the rendered content for the gallery's
  /// per-page transform reset logic. When the parent rebuilds the same
  /// slot with a different [contentKey] (e.g. a re-order or swap-in),
  /// the previous photo's pan/zoom is dropped instead of leaking to
  /// the new content. For the image-backed variant the provider's `==`
  /// supplies this signal automatically; for `.child` the [child]
  /// widget identity is unreliable (inline `Text(...)` etc. are fresh
  /// every rebuild), so the caller hands the gallery a stable handle.
  const factory ViewfinderItem.child({
    required Widget child,
    required Object contentKey,
    ViewfinderHero? hero,
    ViewfinderInitialScale? initialScale,
    double? minScale,
    double? maxScale,
    String? semanticLabel,
  }) = ViewfinderChildItem;

  /// Per-item Hero configuration. Null opts out.
  final ViewfinderHero? hero;

  /// Per-item override of the gallery's `defaultInitialScale`.
  final ViewfinderInitialScale? initialScale;

  /// Per-item override of the gallery's `minScale`.
  final double? minScale;

  /// Per-item override of the gallery's `maxScale`.
  final double? maxScale;

  /// Semantic label for screen readers.
  final String? semanticLabel;
}

/// `ImageProvider`-backed [ViewfinderItem] variant.
final class ViewfinderImageItem extends ViewfinderItem {
  /// Creates an image-backed item. [image] is the only required field;
  /// every other parameter is optional and forwards to the gallery.
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
    this.gaplessPlayback = true,
  }) : super._();

  /// The provider rendered as the main image.
  final ImageProvider image;

  /// Low-resolution image shown while [image] is still loading.
  /// Cross-faded to the main image as soon as the first frame decodes.
  final ImageProvider? thumbImage;

  /// Builder rendered while [image] is loading. See [Image.loadingBuilder].
  final ImageLoadingBuilder? loadingBuilder;

  /// Builder rendered when [image] fails to load. See [Image.errorBuilder].
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Forwarded to [Image.gaplessPlayback]. When `true` (default), keeps
  /// showing the previous frame while [image] decodes.
  final bool gaplessPlayback;
}

/// Custom-widget [ViewfinderItem] variant.
final class ViewfinderChildItem extends ViewfinderItem {
  /// Creates a child-widget item. [child] is rendered with the same
  /// zoom + pan + dismiss machinery as image-backed pages.
  const ViewfinderChildItem({
    required this.child,
    required this.contentKey,
    super.hero,
    super.initialScale,
    super.minScale,
    super.maxScale,
    super.semanticLabel,
  }) : super._();

  /// The widget rendered for this page.
  final Widget child;

  /// Stable identity for [child]. The gallery compares this between
  /// rebuilds (`==`) to decide whether the same slot is showing the
  /// same content; a value change resets the in-page pan/zoom so a
  /// re-ordered slot does not display the previous photo's transform.
  /// See [ViewfinderItem.child] for the rationale.
  final Object contentKey;
}
