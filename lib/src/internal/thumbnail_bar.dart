import 'package:flutter/material.dart';

import '../item.dart';
import '../thumbnails.dart';

/// Thumbnail strip — internal renderer driven by `Viewfinder` from the
/// public [ViewfinderThumbnails] config.
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
      duration: const .new(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final list = ListView.builder(
      controller: _scrollController,
      scrollDirection: cfg.isHorizontal ? .horizontal : .vertical,
      padding: cfg.padding,
      itemCount: widget.itemCount,
      itemExtent: cfg.size + cfg.spacing,
      itemBuilder: (context, i) => _ThumbnailTile(
        config: cfg,
        item: widget.itemAt(i),
        index: i,
        selected: i == widget.currentIndex,
        dpr: dpr,
        onTap: () => widget.onSelect(i),
      ),
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
        top: pos == .top || !cfg.isHorizontal,
        bottom: pos == .bottom || !cfg.isHorizontal,
        left: pos == .left || cfg.isHorizontal,
        right: pos == .right || cfg.isHorizontal,
        child: content,
      );
    }

    return ColoredBox(color: cfg.backgroundColor, child: content);
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.config,
    required this.item,
    required this.index,
    required this.selected,
    required this.dpr,
    required this.onTap,
  });

  final ViewfinderThumbnails config;
  final ViewfinderItem item;
  final int index;
  final bool selected;
  final double dpr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inner = switch (config.itemBuilder) {
      final builder? => builder(context, index, selected),
      _ => _DefaultThumbnailTile(
        config: config,
        item: item,
        selected: selected,
        dpr: dpr,
      ),
    };
    return Padding(
      padding: config.isHorizontal
          ? .only(right: config.spacing)
          : .only(bottom: config.spacing),
      child: GestureDetector(behavior: .opaque, onTap: onTap, child: inner),
    );
  }
}

class _DefaultThumbnailTile extends StatelessWidget {
  const _DefaultThumbnailTile({
    required this.config,
    required this.item,
    required this.selected,
    required this.dpr,
  });

  final ViewfinderThumbnails config;
  final ViewfinderItem item;
  final bool selected;
  final double dpr;

  @override
  Widget build(BuildContext context) {
    // Thumbnails are visually constrained to `config.size` logical px on
    // both axes, so we decode at that size × DPR regardless of the
    // source resolution. The main viewer's decode size is left alone.
    final thumbPx = (config.size * dpr).ceil();
    final Widget img = switch (item) {
      ViewfinderImageItem(:final image) => Image(
        image: ResizeImage(image, width: thumbPx, height: thumbPx),
        fit: .cover,
        width: config.size,
        height: config.size,
        gaplessPlayback: true,
        errorBuilder:
            config.errorBuilder ??
            (_, _, _) => Container(color: Colors.white12),
      ),
      ViewfinderChildItem(:final child) => SizedBox(
        width: config.size,
        height: config.size,
        child: child,
      ),
    };
    return AnimatedOpacity(
      duration: const .new(milliseconds: 150),
      opacity: selected ? 1.0 : config.unselectedOpacity,
      child: Container(
        width: config.size,
        height: config.size,
        decoration: BoxDecoration(
          border: selected ? config.selectedBorder : null,
        ),
        clipBehavior: .hardEdge,
        child: img,
      ),
    );
  }
}
