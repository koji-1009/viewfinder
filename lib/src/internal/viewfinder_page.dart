import 'package:flutter/gestures.dart';
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
    this.enableMouseWheelZoom = true,
    this.onWheelDelta,
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

  /// Forwarded to [ViewfinderImage.enableMouseWheelZoom]; `false` when
  /// the gallery repurposes the wheel for page navigation.
  final bool enableMouseWheelZoom;

  /// When non-null, scroll-wheel events over this page are consumed
  /// and reported here (the gallery's wheel-paging mode).
  final ValueChanged<double>? onWheelDelta;

  @override
  Widget build(BuildContext context) {
    final initialScale = item.initialScale ?? defaultInitialScale;
    final effectiveMin = item.minScale ?? defaultMinScale;
    final effectiveMax = item.maxScale ?? defaultMaxScale;
    final effectiveDoubleTapScales = item.doubleTapScales ?? doubleTapScales;
    // Only the currently-visible page carries a Hero. PageView pre-builds
    // neighbors (especially with allowImplicitScrolling), and if those
    // carried Heroes too, every adjacent-grid thumbnail would fly on pop.
    final hero = isCurrent ? item.hero : null;

    Widget page = switch (item) {
      final ViewfinderImageItem item => ViewfinderImage(
        image: item.image,
        thumbImage: item.thumbImage,
        initialScale: initialScale,
        doubleTapScales: effectiveDoubleTapScales,
        hero: hero,
        loadingBuilder: item.loadingBuilder,
        errorBuilder: item.errorBuilder,
        minScale: effectiveMin,
        maxScale: effectiveMax,
        semanticLabel: item.semanticLabel,
        onLongPress: item.onLongPress,
        onLongPressStart: item.onLongPressStart,
        onSecondaryTapUp: item.onSecondaryTapUp,
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
        enableMouseWheelZoom: enableMouseWheelZoom,
      ),
      final ViewfinderChildItem item => ViewfinderImage.child(
        initialScale: initialScale,
        doubleTapScales: effectiveDoubleTapScales,
        hero: hero,
        minScale: effectiveMin,
        maxScale: effectiveMax,
        semanticLabel: item.semanticLabel,
        onLongPress: item.onLongPress,
        onLongPressStart: item.onLongPressStart,
        onSecondaryTapUp: item.onSecondaryTapUp,
        controller: controller,
        canPan: canPan,
        claimPan: claimPan,
        rotateEnabled: rotateEnabled,
        interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
        backgroundColor: Colors.transparent,
        rubberBandPan: rubberBandPan,
        enableMouseWheelZoom: enableMouseWheelZoom,
        contentKey: item.contentKey,
        child: item.child,
      ),
    };

    // Wheel-paging mode: consume scroll-wheel events over the page and
    // report them to the gallery. Registered through the pointer-signal
    // resolver from this leaf-side Listener, so it wins over the
    // enclosing scrollable's own wheel handling.
    if (onWheelDelta case final onWheel?) {
      page = Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (e) {
            final scroll = e as PointerScrollEvent;
            final delta = scroll.scrollDelta.dy != 0
                ? scroll.scrollDelta.dy
                : scroll.scrollDelta.dx;
            if (delta != 0) onWheel(delta);
          });
        },
        child: page,
      );
    }

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
