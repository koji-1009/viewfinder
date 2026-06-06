import 'package:flutter/material.dart';

import '../image.dart';
import '../initial_scale.dart';
import '../item.dart';

/// One page of a `Viewfinder` gallery.
///
/// Translates a [ViewfinderItem] (image-backed or child-backed) into a
/// matching [ViewfinderImage] / [ViewfinderImage.child], threading the
/// per-gallery defaults, the per-page transform [controller], the
/// edge-handoff [canPan] gate, and (only for the currently visible
/// page) the per-item Hero. Internal — driven by `Viewfinder.build`.
class ViewfinderPage extends StatelessWidget {
  const ViewfinderPage({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.controller,
    required this.canPan,
    required this.claimPan,
    required this.defaultInitialScale,
    required this.doubleTapScales,
    required this.defaultMinScale,
    required this.defaultMaxScale,
    required this.rotateEnabled,
    required this.interactionEndFrictionCoefficient,
    required this.rubberBandPan,
    required this.pageSpacing,
    required this.pagerAxis,
  });

  final ViewfinderItem item;
  final bool isCurrent;
  final ViewfinderImageController controller;
  final ZoomableCanPan canPan;
  final ZoomableClaimPan claimPan;
  final ViewfinderInitialScale defaultInitialScale;
  final List<double> doubleTapScales;
  final double defaultMinScale;
  final double defaultMaxScale;
  final bool rotateEnabled;
  final double interactionEndFrictionCoefficient;
  final bool rubberBandPan;
  final double pageSpacing;
  final Axis pagerAxis;

  @override
  Widget build(BuildContext context) {
    final initialScale = item.initialScale ?? defaultInitialScale;
    final effectiveMin = item.minScale ?? defaultMinScale;
    final effectiveMax = item.maxScale ?? defaultMaxScale;
    // Only the currently-visible page carries a Hero. PageView pre-builds
    // neighbors (especially with allowImplicitScrolling), and if those
    // carried Heroes too, every adjacent-grid thumbnail would fly on pop.
    final hero = isCurrent ? item.hero : null;

    final page = switch (item) {
      final ViewfinderImageItem item => ViewfinderImage(
        image: item.image,
        thumbImage: item.thumbImage,
        initialScale: initialScale,
        doubleTapScales: doubleTapScales,
        hero: hero,
        loadingBuilder: item.loadingBuilder,
        errorBuilder: item.errorBuilder,
        minScale: effectiveMin,
        maxScale: effectiveMax,
        semanticLabel: item.semanticLabel,
        controller: controller,
        canPan: canPan,
        claimPan: claimPan,
        rotateEnabled: rotateEnabled,
        interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
        backgroundColor: Colors.transparent,
        thumbCrossFadeDuration: item.thumbCrossFadeDuration,
        thumbCrossFadeCurve: item.thumbCrossFadeCurve,
        gaplessPlayback: item.gaplessPlayback,
        rubberBandPan: rubberBandPan,
      ),
      final ViewfinderChildItem item => ViewfinderImage.child(
        initialScale: initialScale,
        doubleTapScales: doubleTapScales,
        hero: hero,
        minScale: effectiveMin,
        maxScale: effectiveMax,
        semanticLabel: item.semanticLabel,
        controller: controller,
        canPan: canPan,
        claimPan: claimPan,
        rotateEnabled: rotateEnabled,
        interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
        backgroundColor: Colors.transparent,
        rubberBandPan: rubberBandPan,
        contentKey: item.contentKey,
        child: item.child,
      ),
    };

    // Spacing goes on the pager's own axis — horizontal gaps between
    // horizontally-paged pages, vertical gaps for a vertical pager.
    return pageSpacing > 0
        ? Padding(
            padding: pagerAxis == .horizontal
                ? .symmetric(horizontal: pageSpacing / 2)
                : .symmetric(vertical: pageSpacing / 2),
            child: page,
          )
        : page;
  }
}
