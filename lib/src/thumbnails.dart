import 'package:flutter/material.dart';

import 'item.dart';
import 'viewfinder.dart' show Viewfinder;

enum ViewfinderThumbnailPosition { top, bottom, left, right }

/// Signature for fully custom thumbnail builders.
typedef ViewfinderThumbnailItemBuilder =
    Widget Function(BuildContext context, int index, bool selected);

/// Configures the optional thumbnail strip shown alongside a [Viewfinder].
@immutable
class ViewfinderThumbnails {
  const ViewfinderThumbnails({
    this.position = .bottom,
    this.size = 56,
    this.spacing = 4,
    this.padding = const .all(8),
    this.safeArea = true,
    this.selectedBorder = const Border.fromBorderSide(
      BorderSide(color: Colors.white, width: 2),
    ),
    this.unselectedOpacity = 0.55,
    this.backgroundColor = const Color(0x8A000000),
    this.itemBuilder,
  });

  const factory ViewfinderThumbnails.custom({
    ViewfinderThumbnailPosition position,
    double size,
    double spacing,
    EdgeInsets padding,
    bool safeArea,
    Color backgroundColor,
    required ViewfinderThumbnailItemBuilder itemBuilder,
  }) = _CustomThumbnails;

  final ViewfinderThumbnailPosition position;
  final double size;
  final double spacing;

  /// Internal content padding for the thumbnail strip. Combined with
  /// [safeArea] to produce the final inset.
  final EdgeInsets padding;

  /// When `true` (default), the outer edge of the strip respects the
  /// platform's safe-area inset — for example, a `.bottom` strip clears
  /// the iOS home indicator and a landscape notch on the sides. The
  /// [backgroundColor] still paints edge-to-edge through the inset.
  /// Set `false` to opt out and manage the inset yourself via [padding].
  final bool safeArea;

  /// Applied to the default tile only. Ignored when [itemBuilder] is
  /// provided — the builder owns the entire visual treatment.
  final Border selectedBorder;

  /// Applied to the default tile only. See [selectedBorder].
  final double unselectedOpacity;

  final Color backgroundColor;

  /// Optional fully custom tile builder. When provided, [selectedBorder]
  /// and [unselectedOpacity] are skipped — the builder receives the
  /// `selected` flag and renders the tile exactly as returned.
  final ViewfinderThumbnailItemBuilder? itemBuilder;

  bool get isHorizontal =>
      position == ViewfinderThumbnailPosition.top ||
      position == ViewfinderThumbnailPosition.bottom;
}

class _CustomThumbnails extends ViewfinderThumbnails {
  const _CustomThumbnails({
    super.position = ViewfinderThumbnailPosition.bottom,
    super.size = 56,
    super.spacing = 4,
    super.padding = const EdgeInsets.all(8),
    super.safeArea = true,
    super.backgroundColor = const Color(0x8A000000),
    required ViewfinderThumbnailItemBuilder itemBuilder,
  }) : super(itemBuilder: itemBuilder);
}

/// Thumbnail strip. Used internally by [Viewfinder].
class ViewfinderThumbnailBar extends StatefulWidget {
  const ViewfinderThumbnailBar({
    super.key,
    required this.config,
    required this.itemCount,
    required this.currentIndex,
    required this.itemAt,
    required this.onSelect,
  });

  final ViewfinderThumbnails config;
  final int itemCount;
  final int currentIndex;
  final ViewfinderItem Function(int index) itemAt;
  final ValueChanged<int> onSelect;

  @override
  State<ViewfinderThumbnailBar> createState() => _ViewfinderThumbnailBarState();
}

class _ViewfinderThumbnailBarState extends State<ViewfinderThumbnailBar> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ViewfinderThumbnailBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    final cfg = widget.config;
    final extent = cfg.size + cfg.spacing;
    final viewport = _scrollController.position.viewportDimension;
    final target = widget.currentIndex * extent;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final desired = (target - viewport / 2 + cfg.size / 2).clamp(
      0.0,
      maxScroll,
    );
    _scrollController.animateTo(
      desired,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTile(BuildContext context, int i, double dpr) {
    final cfg = widget.config;
    final selected = i == widget.currentIndex;
    final Widget inner = switch (cfg.itemBuilder) {
      final ViewfinderThumbnailItemBuilder builder => builder(
        context,
        i,
        selected,
      ),
      _ => _defaultDecoratedTile(widget.itemAt(i), dpr, selected),
    };
    return Padding(
      padding: cfg.isHorizontal
          ? EdgeInsets.only(right: cfg.spacing)
          : EdgeInsets.only(bottom: cfg.spacing),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(i),
        child: inner,
      ),
    );
  }

  Widget _defaultDecoratedTile(ViewfinderItem item, double dpr, bool selected) {
    final cfg = widget.config;
    // Thumbnails are visually constrained to `cfg.size` logical px on
    // both axes, so we decode at that size × DPR regardless of the
    // source resolution. The main viewer's decode size is left alone.
    final thumbPx = (cfg.size * dpr).ceil();
    final Widget img = switch (item.image) {
      final ImageProvider image => Image(
        image: ResizeImage(image, width: thumbPx, height: thumbPx),
        fit: .cover,
        width: cfg.size,
        height: cfg.size,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Container(color: Colors.white12),
      ),
      _ => SizedBox(width: cfg.size, height: cfg.size, child: item.child),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: selected ? 1.0 : cfg.unselectedOpacity,
      child: Container(
        width: cfg.size,
        height: cfg.size,
        decoration: BoxDecoration(border: selected ? cfg.selectedBorder : null),
        clipBehavior: .hardEdge,
        child: img,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final list = ListView.builder(
      controller: _scrollController,
      scrollDirection: cfg.isHorizontal ? Axis.horizontal : Axis.vertical,
      padding: cfg.padding,
      itemCount: widget.itemCount,
      itemExtent: cfg.size + cfg.spacing,
      itemBuilder: (context, i) => _buildTile(context, i, dpr),
    );

    final barH = cfg.size + cfg.padding.top + cfg.padding.bottom;
    final barW = cfg.size + cfg.padding.left + cfg.padding.right;

    Widget content = SizedBox(
      height: cfg.isHorizontal ? barH : null,
      width: cfg.isHorizontal ? null : barW,
      child: list,
    );

    if (cfg.safeArea) {
      final pos = cfg.position;
      content = SafeArea(
        // Only the outer edge (the one facing away from the main viewer)
        // plus the perpendicular edges get the inset — so the bar hugs
        // the main content on the inner edge but keeps clear of notches
        // and the home indicator.
        top: pos == ViewfinderThumbnailPosition.top || !cfg.isHorizontal,
        bottom: pos == ViewfinderThumbnailPosition.bottom || !cfg.isHorizontal,
        left: pos == ViewfinderThumbnailPosition.left || cfg.isHorizontal,
        right: pos == ViewfinderThumbnailPosition.right || cfg.isHorizontal,
        child: content,
      );
    }

    return ColoredBox(color: cfg.backgroundColor, child: content);
  }
}
