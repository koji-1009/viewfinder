import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 3 — a vertically scrolling gallery.
///
/// `pagerAxis: Axis.vertical` flips the swipe and edge-handoff axis. The
/// README notes that a vertical pager and drag-to-dismiss both consume
/// vertical drags and assert together, so this scenario opts out of
/// dismiss and pops via the chrome back button / Esc instead.
class VerticalPagerPage extends StatelessWidget {
  const VerticalPagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vertical pager')),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.swap_vert_outlined,
            message:
                'Swipe up / down to page through photos — scroll wheel and '
                'trackpad scrolling page too (mouseWheelBehavior: paging); '
                'zoom with pinch or double-tap. pagerAxis is Axis.vertical, '
                'so the zoom→swipe edge hand-off runs on the vertical axis '
                'too. Dismiss is intentionally off — it would fight the '
                'vertical pager for the same drags.',
          ),
          Expanded(
            child: Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_full),
                label: const Text('Open vertical gallery'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const _VerticalViewer(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalViewer extends StatefulWidget {
  const _VerticalViewer();

  @override
  State<_VerticalViewer> createState() => _VerticalViewerState();
}

class _VerticalViewerState extends State<_VerticalViewer> {
  late final ViewfinderController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ViewfinderController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = DemoPhotos.images;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Viewfinder(
            itemCount: images.length,
            backgroundColor: scheme.surface,
            controller: _controller,
            pagerAxis: Axis.vertical,
            precacheAdjacent: 1,
            // Scrolling down a vertical feed should page, not zoom;
            // pinch / double-tap still zoom.
            mouseWheelBehavior: ViewfinderMouseWheelBehavior.paging,
            indicator: const ViewfinderPageIndicatorAdaptive(),
            itemBuilder: (context, index) => ViewfinderItem(
              image: images[index],
              semanticLabel: 'Photo ${index + 1}',
              errorBuilder: (_, _, _) => const DemoBrokenImage(),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.close, color: scheme.onSurface),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: 0.72),
                ),
                onPressed: () {
                  if (_controller.resetCurrentImage()) return;
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
