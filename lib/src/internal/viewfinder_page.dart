import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../image.dart';
import '../initial_scale.dart';
import '../item.dart';
import '../pan_gate.dart';
import 'colors.dart' as colors;

/// One page of a `Viewfinder` gallery.
///
/// Translates a [ViewfinderItem] (image-backed or child-backed) into a
/// matching [ViewfinderImage] / [ViewfinderImage.child], threading the
/// per-gallery defaults, the per-page transform [controller], the
/// edge-handoff [panGate], and (only for the currently visible page)
/// the per-item Hero. Internal — driven by `Viewfinder.build`.
class ViewfinderPage extends StatelessWidget {
  const ViewfinderPage({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.controller,
    required this.panGate,
    required this.defaultInitialScale,
    required this.doubleTapScales,
    required this.defaultMinScale,
    required this.defaultMaxScale,
    required this.rotateEnabled,
    required this.interactionEndFrictionCoefficient,
    required this.rubberBandPan,
    required this.pageSpacing,
    required this.pagerAxis,
    required this.filterQuality,
    this.onWheelDelta,
    this.wrapProvider,
  });

  final ViewfinderItem item;
  final bool isCurrent;
  final ViewfinderImageController controller;
  final ViewfinderPanGate panGate;
  final ViewfinderInitialScale defaultInitialScale;
  final List<double> doubleTapScales;
  final double defaultMinScale;
  final double defaultMaxScale;
  final bool rotateEnabled;
  final double interactionEndFrictionCoefficient;
  final bool rubberBandPan;
  final double pageSpacing;
  final Axis pagerAxis;
  final FilterQuality filterQuality;

  /// When non-null, pager-axis-dominant scroll-wheel events over this
  /// page are consumed and reported here (the gallery's wheel-paging
  /// mode); cross-axis scroll keeps zooming.
  final void Function(PointerScrollEvent event, double along)? onWheelDelta;

  /// Applied to an image-backed item's main provider before display —
  /// the gallery's decode-size policy. The thumb provider is left
  /// alone (it is already low-res).
  final ImageProvider Function(ImageProvider provider)? wrapProvider;

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
        image: wrapProvider?.call(item.image) ?? item.image,
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
        panGate: panGate,
        rotateEnabled: rotateEnabled,
        interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
        backgroundColor: colors.transparent,
        filterQuality: filterQuality,
        thumbCrossFadeDuration: item.thumbCrossFadeDuration,
        thumbCrossFadeCurve: item.thumbCrossFadeCurve,
        gaplessPlayback: item.gaplessPlayback,
        rubberBandPan: rubberBandPan,
        wheelPagingAxis: onWheelDelta != null ? pagerAxis : null,
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
        panGate: panGate,
        rotateEnabled: rotateEnabled,
        interactionEndFrictionCoefficient: interactionEndFrictionCoefficient,
        backgroundColor: colors.transparent,
        rubberBandPan: rubberBandPan,
        wheelPagingAxis: onWheelDelta != null ? pagerAxis : null,
        contentKey: item.contentKey,
        child: item.child,
      ),
    };

    // Wheel-paging mode: scroll dominant along the pager axis turns
    // pages; cross-axis scroll falls to the viewer's zoom (the deeper
    // ZoomableViewport skips pager-axis-dominant events, so the two
    // split the resolver cleanly). Registered from this leaf-side
    // Listener, so it wins over the enclosing scrollable's own wheel
    // handling.
    if (onWheelDelta case final onWheel?) {
      page = Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          final d = event.scrollDelta;
          final along = pagerAxis == .horizontal ? d.dx : d.dy;
          final cross = pagerAxis == .horizontal ? d.dy : d.dx;
          if (along.abs() <= cross.abs()) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            onWheel(event, along);
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
