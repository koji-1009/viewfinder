import 'package:flutter/material.dart';
import 'package:taro/taro.dart';

/// Shared photo set used across every demo scenario.
///
/// `TaroImage` caches bytes on disk, so a grid thumbnail decode and the
/// larger full-screen decode share a single HTTP fetch — and a gallery's
/// first-open Hero lands on a real frame instead of a loading spinner.
/// picsum.photos is CORS-safe, so the same URLs work on the hosted web
/// demo without a proxy.
///
/// ~1600 px sources: plenty of zoom headroom for a demo while keeping
/// the decoded textures small enough that hero flights and the grid
/// stay smooth (a 4000 px source decodes to ~48 MB RGBA — ×14 photos
/// repainting every transition frame).
///
/// 14 photos at mixed aspect ratios — enough to push the page indicator
/// past its `maxDots` default of 12 (so the numeric `i / N` fallback
/// kicks in for free), and enough to make the thumbnail strip's
/// auto-scroll visible during a swipe.
class DemoPhotos {
  const DemoPhotos._();

  static const List<String> _urls = [
    'https://picsum.photos/id/1015/1600/1200',
    'https://picsum.photos/id/1018/1600/1066',
    'https://picsum.photos/id/1019/1600/1066',
    'https://picsum.photos/id/1025/1600/1066',
    'https://picsum.photos/id/1029/1600/1066',
    'https://picsum.photos/id/1037/1600/1066',
    'https://picsum.photos/id/1039/1600/1000',
    'https://picsum.photos/id/1041/1200/1600',
    'https://picsum.photos/id/1043/1066/1600',
    'https://picsum.photos/id/1050/1600/1066',
    'https://picsum.photos/id/1055/1600/1066',
    'https://picsum.photos/id/1059/1600/1600',
    'https://picsum.photos/id/1074/1600/1066',
    'https://picsum.photos/id/1080/1600/900',
  ];

  /// Full-resolution providers, one per photo.
  static final List<ImageProvider> images = [
    for (final url in _urls) TaroImage(url),
  ];

  /// A single portrait photo, handy for the single-photo scenario.
  static final ImageProvider portrait = images[7];

  /// A single landscape photo, handy for the embedded-zoom article.
  static final ImageProvider landscape = images[0];
}

/// A muted, full-width info banner that explains what to try on a page.
///
/// Rendered above the live demo area so visitors know which gesture or
/// shortcut the scenario is showing off.
class DemoHint extends StatelessWidget {
  const DemoHint({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onSurfaceVariant;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: fg, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error placeholder shared by the viewer scenarios'
/// `errorBuilder`s.
class DemoBrokenImage extends StatelessWidget {
  const DemoBrokenImage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      Icons.broken_image,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      size: 48,
    ),
  );
}

/// A compact list of keyboard / pointer affordances, shown on scenarios
/// where desktop and web inputs matter.
class InputHints extends StatelessWidget {
  const InputHints({super.key, required this.hints});

  final List<({IconData icon, String label})> hints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final h in hints)
          Chip(
            visualDensity: .compact,
            avatar: Icon(h.icon, size: 18, color: scheme.onSurfaceVariant),
            label: Text(h.label),
            side: BorderSide(color: scheme.outlineVariant),
            backgroundColor: scheme.surfaceContainer,
          ),
      ],
    );
  }
}
