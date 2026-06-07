import 'package:flutter/widgets.dart';

import '../page_indicator.dart';
import 'colors.dart' as colors;

/// Internal widget that renders the configured indicator.
///
/// Driven by `Viewfinder` from the public sealed [ViewfinderPageIndicator]
/// hierarchy.
class ViewfinderPageIndicatorOverlay extends StatelessWidget {
  const ViewfinderPageIndicatorOverlay({
    super.key,
    required this.config,
    required this.itemCount,
    required this.currentIndex,
    this.reverse = false,
  });

  final ViewfinderPageIndicator config;
  final int itemCount;
  final int currentIndex;

  /// Mirrors the dot order to match a `reverse: true` pager. Pass the
  /// raw flag, not the reverse×RTL combination: ambient
  /// `Directionality` already mirrors the underlying [Row] for RTL,
  /// exactly as it mirrors the `PageView` — combining would mirror
  /// twice.
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final cfg = config;
    if (cfg is ViewfinderPageIndicatorAdaptive) {
      assert(
        cfg.dots.alignment == cfg.alignment && cfg.dots.padding == cfg.padding,
        'Inner dots alignment/padding on a ViewfinderPageIndicatorAdaptive '
        'are ignored at runtime — set them on the Adaptive instance '
        'instead. (Debug-only check; release builds silently ignore.)',
      );
      assert(
        cfg.label.alignment == cfg.alignment &&
            cfg.label.padding == cfg.padding,
        'Inner label alignment/padding on a ViewfinderPageIndicatorAdaptive '
        'are ignored at runtime — set them on the Adaptive instance '
        'instead. (Debug-only check; release builds silently ignore.)',
      );
    }
    final content = switch (cfg) {
      ViewfinderPageIndicatorDots() => _DotsView(
        dots: cfg,
        itemCount: itemCount,
        currentIndex: currentIndex,
        reverse: reverse,
      ),
      ViewfinderPageIndicatorLabel() => _LabelView(
        builder: cfg.labelBuilder,
        currentIndex: currentIndex,
        itemCount: itemCount,
      ),
      ViewfinderPageIndicatorAdaptive() =>
        itemCount > cfg.maxDots
            ? _LabelView(
                builder: cfg.label.labelBuilder,
                currentIndex: currentIndex,
                itemCount: itemCount,
              )
            : _DotsView(
                dots: cfg.dots,
                itemCount: itemCount,
                currentIndex: currentIndex,
                reverse: reverse,
              ),
    };
    final aligned = Align(
      alignment: cfg.alignment,
      child: Padding(padding: cfg.padding, child: content),
    );
    return cfg.safeArea ? SafeArea(child: aligned) : aligned;
  }
}

class _DotsView extends StatelessWidget {
  const _DotsView({
    required this.dots,
    required this.itemCount,
    required this.currentIndex,
    required this.reverse,
  });

  final ViewfinderPageIndicatorDots dots;
  final int itemCount;
  final int currentIndex;
  final bool reverse;

  @override
  Widget build(BuildContext context) => Semantics(
    // The dot row is purely visual; give screen readers the position.
    // `container: true` keeps the label its own node instead of
    // merging into the gallery's.
    container: true,
    label:
        dots.semanticLabelBuilder?.call(currentIndex, itemCount) ??
        'Page ${currentIndex + 1} of $itemCount',
    child: Row(
      mainAxisSize: .min,
      children: [
        for (final i in [
          for (var k = 0; k < itemCount; k++) reverse ? itemCount - 1 - k : k,
        ])
          Padding(
            padding: .symmetric(horizontal: dots.spacing / 2),
            child: AnimatedContainer(
              duration: const .new(milliseconds: 180),
              width: i == currentIndex ? dots.activeDotSize : dots.dotSize,
              height: i == currentIndex ? dots.activeDotSize : dots.dotSize,
              decoration: BoxDecoration(
                shape: .circle,
                color: i == currentIndex ? dots.activeColor : dots.color,
              ),
            ),
          ),
      ],
    ),
  );
}

class _LabelView extends StatelessWidget {
  const _LabelView({
    required this.builder,
    required this.currentIndex,
    required this.itemCount,
  });

  final ViewfinderPageIndicatorLabelBuilder? builder;
  final int currentIndex;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final builder = this.builder;
    if (builder != null) return builder(context, currentIndex, itemCount);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: colors.black54,
        borderRadius: .all(.circular(16)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 12, vertical: 6),
        child: Text(
          '${currentIndex + 1} / $itemCount',
          style: const .new(color: colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
