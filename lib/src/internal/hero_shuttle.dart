import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Hero flight shuttle that interpolates the image's painted rect
/// between two [BoxFit]s — the launcher thumbnail's (typically
/// `cover`) and the viewer's (typically `contain`) — so the flight
/// lands exactly on each end's own rendering instead of snapping at
/// the thumbnail end. Internal — built by `ViewfinderImage`'s default
/// shuttle when `ViewfinderHero.thumbnailFit` is set.
///
/// The interpolation needs the image's intrinsic size to compute the
/// fitted rects; until the (already-cached, by flight time) provider
/// reports it, the shuttle falls back to the viewer fit.
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

  /// Flight progress: `0` at the `from` hero, `1` at the `to` hero
  /// (the framework reverses the route animation on pop, so this holds
  /// for both directions).
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
      _stream = stream..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null || imageSize.isEmpty) {
      return Image(
        image: widget.image,
        fit: widget.viewerFit,
        filterQuality: widget.filterQuality,
        gaplessPlayback: true,
      );
    }
    final (fromFit, toFit) = widget.direction == HeroFlightDirection.push
        ? (widget.thumbnailFit, widget.viewerFit)
        : (widget.viewerFit, widget.thumbnailFit);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = constraints.biggest;
        if (box.isEmpty) return const SizedBox.shrink();
        // The image's centered painted rect for [fit] — computed from
        // the uniform fit scale rather than [applyBoxFit], whose cover
        // result crops the source instead of overflowing the
        // destination.
        Rect rectFor(BoxFit fit) {
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
          return Alignment.center.inscribe(
            imageSize * scale,
            Offset.zero & box,
          );
        }

        final fromRect = rectFor(fromFit);
        final toRect = rectFor(toFit);
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, child) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fromRect(
                rect: Rect.lerp(fromRect, toRect, widget.animation.value)!,
                child: child!,
              ),
            ],
          ),
          // The rect already carries the uniform fit scale, so the
          // image fills it without distortion.
          child: Image(
            image: widget.image,
            fit: BoxFit.fill,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
