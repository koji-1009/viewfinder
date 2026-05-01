import 'package:flutter/material.dart';

import '../page_indicator.dart';

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
  });

  final ViewfinderPageIndicator config;
  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    final cfg = config;
    assert(() {
      if (cfg is ViewfinderPageIndicatorAdaptive) {
        if (cfg.dots.alignment != cfg.alignment ||
            cfg.dots.padding != cfg.padding) {
          throw FlutterError(
            'Inner dots alignment/padding on a ViewfinderPageIndicatorAdaptive '
            'are ignored — set them on the Adaptive instance instead.',
          );
        }
        if (cfg.label.alignment != cfg.alignment ||
            cfg.label.padding != cfg.padding) {
          throw FlutterError(
            'Inner label alignment/padding on a ViewfinderPageIndicatorAdaptive '
            'are ignored — set them on the Adaptive instance instead.',
          );
        }
      }
      return true;
    }());
    final content = switch (cfg) {
      ViewfinderPageIndicatorDots() => _DotsView(
        dots: cfg,
        itemCount: itemCount,
        currentIndex: currentIndex,
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
              ),
    };
    return Align(
      alignment: cfg.alignment,
      child: Padding(padding: cfg.padding, child: content),
    );
  }
}

class _DotsView extends StatelessWidget {
  const _DotsView({
    required this.dots,
    required this.itemCount,
    required this.currentIndex,
  });

  final ViewfinderPageIndicatorDots dots;
  final int itemCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    children: [
      for (var i = 0; i < itemCount; i++)
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
    return Container(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: .circular(16),
      ),
      child: Text(
        '${currentIndex + 1} / $itemCount',
        style: const .new(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
