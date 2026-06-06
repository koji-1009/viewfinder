import 'package:flutter/widgets.dart';

import '../chrome.dart';

/// Cross-fades [child] in/out in step with a [ViewfinderChromeController].
/// Used internally by `Viewfinder` to wrap thumbnails / page indicator /
/// chromeOverlays.
class ChromeFade extends StatelessWidget {
  const ChromeFade({
    super.key,
    required this.chrome,
    required this.fadeDuration,
    required this.child,
  });

  final ViewfinderChromeController chrome;
  final Duration fadeDuration;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: chrome,
    builder: (context, c) => IgnorePointer(
      ignoring: !chrome.visible,
      child: AnimatedOpacity(
        opacity: chrome.visible ? 1.0 : 0.0,
        // Honor reduce-motion: toggle instantly instead of fading.
        duration: MediaQuery.maybeDisableAnimationsOf(context) == true
            ? Duration.zero
            : fadeDuration,
        child: c,
      ),
    ),
    child: child,
  );
}
