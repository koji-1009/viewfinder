import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Signature for custom resize strategies.
typedef ViewfinderResizeResolver =
    ImageProvider Function(
      ImageProvider base,
      Size layout,
      double devicePixelRatio,
    );

/// Controls how the source [ImageProvider] is wrapped with [ResizeImage]
/// so that images are decoded at the size actually needed on screen.
///
/// Without this wiring, a 4000×3000 JPEG is decoded into a ~48 MB ARGB
/// buffer even when it's only displayed at 400×300 logical pixels.
sealed class ViewfinderResize {
  const ViewfinderResize();

  /// Decode to match the widget's laid-out size × device pixel ratio.
  const factory ViewfinderResize.targetSize({
    bool allowUpscaling,
    ResizeImagePolicy policy,
  }) = _TargetSize;

  /// Decode to explicit pixel dimensions.
  /// Pass only one of [width] / [height] to preserve aspect ratio.
  const factory ViewfinderResize.fixed({
    int? width,
    int? height,
    bool allowUpscaling,
    ResizeImagePolicy policy,
  }) = _FixedSize;

  /// Delegate to a custom resolver.
  const factory ViewfinderResize.custom(ViewfinderResizeResolver resolver) =
      _CustomResize;

  /// No resize — the provider is used as-is.
  static const ViewfinderResize none = _NoResize();

  ImageProvider apply(ImageProvider base, Size layout, double devicePixelRatio);
}

class _NoResize extends ViewfinderResize {
  const _NoResize();
  @override
  ImageProvider apply(ImageProvider base, Size layout, double dpr) => base;
}

class _TargetSize extends ViewfinderResize {
  const _TargetSize({
    this.allowUpscaling = false,
    this.policy = ResizeImagePolicy.fit,
  });

  final bool allowUpscaling;
  final ResizeImagePolicy policy;

  @override
  ImageProvider apply(ImageProvider base, Size layout, double dpr) {
    if (layout.isEmpty) return base;
    final w = math.max(1, (layout.width * dpr).ceil());
    final h = math.max(1, (layout.height * dpr).ceil());
    return ResizeImage(
      base,
      width: w,
      height: h,
      allowUpscaling: allowUpscaling,
      policy: policy,
    );
  }
}

class _FixedSize extends ViewfinderResize {
  const _FixedSize({
    this.width,
    this.height,
    this.allowUpscaling = false,
    this.policy = ResizeImagePolicy.fit,
  }) : assert(
         width != null || height != null,
         'At least one of width or height must be provided.',
       );

  final int? width;
  final int? height;
  final bool allowUpscaling;
  final ResizeImagePolicy policy;

  @override
  ImageProvider apply(ImageProvider base, Size layout, double dpr) {
    return ResizeImage(
      base,
      width: width,
      height: height,
      allowUpscaling: allowUpscaling,
      policy: policy,
    );
  }
}

class _CustomResize extends ViewfinderResize {
  const _CustomResize(this.resolver);
  final ViewfinderResizeResolver resolver;

  @override
  ImageProvider apply(ImageProvider base, Size layout, double dpr) =>
      resolver(base, layout, dpr);
}
