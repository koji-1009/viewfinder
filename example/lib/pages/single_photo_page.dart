import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

final RouteBase singlePhotoRoute = GoRoute(
  path: 'single',
  builder: (_, _) => const SinglePhotoPage(),
  routes: [
    GoRoute(path: 'viewer', builder: (_, _) => const _SinglePhotoViewer()),
  ],
);

/// Scenario 2 — a single full-screen photo via [Viewfinder.single].
///
/// No thumbnails, no indicator, no pager — just one zoomable photo with
/// drag-to-dismiss and a Hero flight from the launch card.
class SinglePhotoPage extends StatelessWidget {
  const SinglePhotoPage({super.key});

  static const routePath = '/single';
  static const viewerPath = '$routePath/viewer';

  static const _heroTag = 'single-photo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Single photo')),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.photo_outlined,
            message:
                'Viewfinder.single shows one zoomable photo full-screen. '
                'Pinch / double-tap to zoom, drag down to dismiss. Tap the '
                'card below to open it with a Hero flight.',
          ),
          const Padding(
            padding: .fromLTRB(16, 16, 16, 0),
            child: InputHints(
              hints: [
                (icon: Icons.mouse_outlined, label: 'Wheel to zoom'),
                (icon: Icons.touch_app_outlined, label: 'Double-tap ladder'),
                (icon: Icons.keyboard_outlined, label: 'Esc to close'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const .all(24),
                child: ConstrainedBox(
                  constraints: const .new(maxWidth: 480),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Material(
                      elevation: 2,
                      clipBehavior: .antiAlias,
                      borderRadius: .circular(16),
                      child: InkWell(
                        onTap: () => context.go(SinglePhotoPage.viewerPath),
                        child: Hero(
                          tag: _heroTag,
                          child: Image(image: DemoPhotos.portrait, fit: .cover),
                        ),
                      ),
                    ),
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

class _SinglePhotoViewer extends StatelessWidget {
  const _SinglePhotoViewer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Viewfinder.single(
        image: DemoPhotos.portrait,
        backgroundColor: scheme.surface,
        hero: const ViewfinderHero(
          SinglePhotoPage._heroTag,
          thumbnailFit: .cover,
        ),
        semanticLabel: 'Single demo photo',
        maxScale: 10,
        dismiss: ViewfinderDismiss(
          onDismiss: () => context.pop(),
          backgroundColor: scheme.surface,
        ),
        errorBuilder: (_, _, _) => const DemoBrokenImage(),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
