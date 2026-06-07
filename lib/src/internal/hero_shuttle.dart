import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Hero flight shuttle that interpolates the image's painted rect
/// between the launcher thumbnail's [BoxFit] and the viewer's, so the
/// flight lands on each end's own rendering. Built by
/// `ViewfinderImage`'s default shuttle when
/// `ViewfinderHero.thumbnailFit` is set.
///
/// Falls back to the viewer fit until the (already-cached, by flight
/// time) provider reports its intrinsic size.
class HeroCrossFitShuttle extends StatefulWidget {
  const HeroCrossFitShuttle({
    super.key,
    required this.image,
    required this.viewerFit,
    required this.thumbnailFit,
    required this.animation,
    required this.direction,
    required this.filterQuality,
  });

  final ImageProvider image;
  final BoxFit viewerFit;
  final BoxFit thumbnailFit;

  /// The raw route animation: runs 0→1 on push and 1→0 on pop (the
  /// framework only reverses its internal position proxy, not the
  /// animation handed to the shuttle builder).
  final Animation<double> animation;

  final HeroFlightDirection direction;
  final FilterQuality filterQuality;

  @override
  State<HeroCrossFitShuttle> createState() => _HeroCrossFitShuttleState();
}

class _HeroCrossFitShuttleState extends State<HeroCrossFitShuttle> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    if (mounted && _imageSize == null) {
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    }
    info.dispose();
  });
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key != _stream?.key) {
      _stream?.removeListener(_listener);
      // A new key can decode at different dimensions; drop the old size.
      _imageSize = null;
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  /// The image's centered painted rect for [fit] — computed from the
  /// uniform fit scale rather than [applyBoxFit], whose cover result
  /// crops the source instead of overflowing the destination.
  Rect _rectFor(BoxFit fit, Size imageSize, Size box) {
    final containScale = math.min(
      box.width / imageSize.width,
      box.height / imageSize.height,
    );
    final scale = switch (fit) {
      .contain => containScale,
      .cover => math.max(
        box.width / imageSize.width,
        box.height / imageSize.height,
      ),
      .fitWidth => box.width / imageSize.width,
      .fitHeight => box.height / imageSize.height,
      .none => 1.0,
      .scaleDown => math.min(1.0, containScale),
      // Aspect-breaking by definition; the rect is the box.
      .fill => null,
    };
    if (scale == null) return Offset.zero & box;
    return Alignment.center.inscribe(imageSize * scale, Offset.zero & box);
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    // Stable widget identity: the flight rect resizes every frame, so
    // the LayoutBuilder below re-runs per frame — keep the Image (and
    // its element) out of that loop.
    final child = RepaintBoundary(
      child: Image(
        image: widget.image,
        // The lerped rect carries the uniform fit scale, so fill
        // renders it without distortion.
        fit: imageSize == null ? widget.viewerFit : BoxFit.fill,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
      ),
    );
    if (imageSize == null || imageSize.isEmpty) return child;
    final (fromFit, toFit) = widget.direction == HeroFlightDirection.push
        ? (widget.thumbnailFit, widget.viewerFit)
        : (widget.viewerFit, widget.thumbnailFit);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        if (box.isEmpty) return const SizedBox.shrink();
        final fromRect = _rectFor(fromFit, imageSize, box);
        final toRect = _rectFor(toFit, imageSize, box);
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) {
            // The raw animation runs toward 0 on pop; normalize t so 0
            // is always the `from` end.
            final v = widget.animation.value;
            final t = widget.direction == HeroFlightDirection.push
                ? v
                : 1.0 - v;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fromRect(
                  rect: Rect.lerp(fromRect, toRect, t)!,
                  child: child!,
                ),
              ],
            );
          },
          child: child,
        );
      },
    );
  }
}
