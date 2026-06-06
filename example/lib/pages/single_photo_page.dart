import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 2 — a single full-screen photo via [Viewfinder.single].
///
/// No thumbnails, no indicator, no pager — just one zoomable photo with
/// drag-to-dismiss and a Hero flight from the launch card.
class SinglePhotoPage extends StatelessWidget {
  const SinglePhotoPage({super.key});

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
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Material(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _open(context),
                        child: Hero(
                          tag: _heroTag,
                          child: Image(
                            image: DemoPhotos.portrait,
                            fit: BoxFit.cover,
                          ),
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

  void _open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _SinglePhotoViewer()));
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
          thumbnailFit: BoxFit.cover,
        ),
        semanticLabel: 'Single demo photo',
        maxScale: 10,
        dismiss: ViewfinderDismiss(
          onDismiss: () => Navigator.of(context).maybePop(),
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
