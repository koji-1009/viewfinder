import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 4 — embedded zoom inside ordinary scrollable content.
///
/// Shows [ViewfinderImage] dropped into an article layout (no chrome, no
/// dismiss — just a zoomable figure), and [ViewfinderImage.child] zooming
/// a non-image widget via the required `contentKey`.
class EmbeddedZoomPage extends StatelessWidget {
  const EmbeddedZoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Cap the article width with the ListView's own padding — an outer
    // ConstrainedBox would leave the side margins outside the scrollable.
    final inset = ((MediaQuery.sizeOf(context).width - 720) / 2).clamp(
      16.0,
      double.infinity,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Embedded zoom')),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.article_outlined,
            message:
                'ViewfinderImage works inline, not just full-screen. Scroll '
                'the article; pinch / double-tap / wheel-zoom either figure. '
                'The second figure uses ViewfinderImage.child to zoom a '
                'non-image widget.',
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 16),
              children: [
                Text('A scrollable article', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'The figure below is a ViewfinderImage with '
                  'panEnabled / scaleEnabled left on. It lives inside this '
                  'ListView like any other widget — drag-to-dismiss and '
                  'chrome are gallery-only concerns, so an embedded image '
                  'just zooms in place.',
                  style: text.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                _Figure(
                  caption: 'Figure 1 — ViewfinderImage (image-backed)',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ViewfinderImage(
                        image: DemoPhotos.landscape,
                        initialScale: const ViewfinderInitialScale.cover(),
                        doubleTapScales: const [1, 2.5, 5],
                        maxScale: 8,
                        backgroundColor: Colors.black12,
                        semanticLabel: 'Embedded landscape photo',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Zooming a non-image widget', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'ViewfinderImage.child applies the same pan / zoom '
                  'machinery to any widget. The contentKey gives the slot '
                  'a stable identity so a rebuild does not leak the '
                  'previous transform — for one static child a constant '
                  "string ('chart') is enough.",
                  style: text.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                _Figure(
                  caption: 'Figure 2 — ViewfinderImage.child (widget)',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: ViewfinderImage.child(
                        contentKey: 'chart',
                        initialScale: const ViewfinderInitialScale.contain(0.9),
                        doubleTapScales: const [1, 2, 4],
                        maxScale: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
                        child: const _ZoomableCard(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Both figures share the package default double-tap '
                  'ladder feel, rubber-band over-pan, and wheel-to-zoom on '
                  'desktop and web — without a single full-screen route.',
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.caption, required this.child});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A styled, content-rich card used as the zoom target for
/// [ViewfinderImage.child] — text small enough to reward zooming in.
class _ZoomableCard extends StatelessWidget {
  const _ZoomableCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = [
      ('minScale', '1.0', 'Hard lower bound'),
      ('maxScale', '8.0', 'Hard upper bound'),
      ('doubleTapScales', '[1, 2.5, 5]', 'Double-tap ladder'),
      ('rubberBandPan', 'true', 'Elastic over-pan'),
      ('rotateEnabled', 'false', 'Two-finger rotate'),
    ];
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ViewfinderImage knobs (package defaults)',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(4),
              },
              border: TableBorder.symmetric(
                inside: BorderSide(color: scheme.outlineVariant),
              ),
              children: [
                for (final (name, value, desc) in rows)
                  TableRow(
                    children: [
                      _Cell(name, mono: true, color: scheme.primary),
                      _Cell(value, mono: true, color: scheme.onSurfaceVariant),
                      _Cell(desc, color: scheme.onSurfaceVariant),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pinch or double-tap to read the fine print.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.mono = false, required this.color});

  final String text;
  final bool mono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontFamily: mono ? 'monospace' : null,
          color: color,
        ),
      ),
    );
  }
}
