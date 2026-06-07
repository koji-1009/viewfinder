import 'package:flutter/widgets.dart';

import '../item.dart';
import '../keys.dart';
import '../thumbnails.dart';
import 'colors.dart' as colors;

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
    this.reverse = false,
  });

  final ViewfinderThumbnails config;
  final int itemCount;
  final int currentIndex;
  final ViewfinderItem Function(int index) itemAt;
  final ValueChanged<int> onSelect;

  /// Mirrors the tile order to match a `reverse: true` pager. Pass the
  /// raw flag, not the reverse×RTL combination: ambient
  /// `Directionality` already mirrors the underlying [ListView] for
  /// RTL, exactly as it mirrors the `PageView` — combining would
  /// mirror twice.
  final bool reverse;

  @override
  State<ViewfinderThumbnailBar> createState() => _ViewfinderThumbnailBarState();
}

class _ViewfinderThumbnailBarState extends State<ViewfinderThumbnailBar> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Bring the initially-selected tile into view on first render —
    // a gallery opened at a non-zero index would otherwise show the
    // strip scrolled to offset 0 with the highlight off-screen. Jump
    // (no animation): there is no previous position to animate from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToCurrent(animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant ViewfinderThumbnailBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToCurrent();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final cfg = widget.config;
    final extent = cfg.size + cfg.spacing;
    final viewport = _scrollController.position.viewportDimension;
    // Tile i sits at `leading padding + i * extent` in scroll
    // coordinates; offset 0 shows the padding, not tile 0. A reversed
    // list anchors its scroll origin on the opposite edge, swapping
    // which padding side leads.
    final leading = switch ((cfg.isHorizontal, widget.reverse)) {
      (true, false) => cfg.padding.left,
      (true, true) => cfg.padding.right,
      (false, false) => cfg.padding.top,
      (false, true) => cfg.padding.bottom,
    };
    final target = leading + widget.currentIndex * extent;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final desired = (target - viewport / 2 + cfg.size / 2).clamp(
      0.0,
      maxScroll,
    );
    if (!animate || MediaQuery.maybeDisableAnimationsOf(context) == true) {
      _scrollController.jumpTo(desired);
      return;
    }
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
      reverse: widget.reverse,
      padding: cfg.padding,
      itemCount: widget.itemCount,
      itemExtent: cfg.size + cfg.spacing,
      itemBuilder: (context, i) => _ThumbnailTile(
        key: ViewfinderKeys.thumbnail(i),
        config: cfg,
        item: widget.itemAt(i),
        index: i,
        selected: i == widget.currentIndex,
        dpr: dpr,
        onTap: () => widget.onSelect(i),
      ),
    );

    Widget content = SizedBox(
      height: cfg.isHorizontal ? cfg.crossExtent : null,
      width: cfg.isHorizontal ? null : cfg.crossExtent,
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
    super.key,
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
      child: Semantics(
        button: true,
        selected: selected,
        label:
            config.semanticLabelBuilder?.call(index, selected) ??
            'Thumbnail ${index + 1}',
        child: GestureDetector(behavior: .opaque, onTap: onTap, child: inner),
      ),
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
        gaplessPlayback: true,
        errorBuilder:
            config.errorBuilder ??
            (_, _, _) => const ColoredBox(color: colors.white12),
      ),
      ViewfinderChildItem(:final child) => child,
    };
    // The single sizer for the tile — both branches and the border /
    // clip below inherit its tight constraints.
    return SizedBox(
      width: config.size,
      height: config.size,
      child: AnimatedOpacity(
        duration: const .new(milliseconds: 150),
        opacity: selected ? 1.0 : config.unselectedOpacity,
        child: DecoratedBox(
          // Foreground, so the selection border stays visible over a
          // cover-fit image.
          position: .foreground,
          decoration: BoxDecoration(
            border: selected ? config.selectedBorder : null,
          ),
          // A small source decodes below the tile size (ResizeImage
          // never upscales), so the cover fit can paint past the tile.
          child: ClipRect(child: img),
        ),
      ),
    );
  }
}
