import 'package:flutter/material.dart';

import 'pages/embedded_zoom_page.dart';
import 'pages/gallery_page.dart';
import 'pages/rotation_page.dart';
import 'pages/single_photo_page.dart';
import 'pages/vertical_pager_page.dart';

void main() => runApp(const ViewfinderDemoApp());

class ViewfinderDemoApp extends StatelessWidget {
  const ViewfinderDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'viewfinder demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B6EA5),
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B6EA5),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _HomePage(),
    );
  }
}

/// One demo scenario shown as a card on the home screen.
class _Scenario {
  const _Scenario({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

final List<_Scenario> _scenarios = [
  _Scenario(
    title: 'Gallery',
    subtitle:
        'Grid → full-screen pager with thumbnails, indicator, '
        'drag-to-dismiss, chrome overlay, Hero, and a live settings sheet.',
    icon: Icons.photo_library_outlined,
    builder: (_) => const GalleryPage(),
  ),
  _Scenario(
    title: 'Single photo',
    subtitle: 'Viewfinder.single — one zoomable photo with drag-to-dismiss.',
    icon: Icons.image_outlined,
    builder: (_) => const SinglePhotoPage(),
  ),
  _Scenario(
    title: 'Vertical pager',
    subtitle:
        'pagerAxis: Axis.vertical — swipe up / down. Dismiss is off (it '
        'would clash with the vertical pager).',
    icon: Icons.swap_vert_outlined,
    builder: (_) => const VerticalPagerPage(),
  ),
  _Scenario(
    title: 'Embedded zoom',
    subtitle:
        'ViewfinderImage inline in an article, plus ViewfinderImage.child '
        'zooming a non-image widget.',
    icon: Icons.article_outlined,
    builder: (_) => const EmbeddedZoomPage(),
  ),
  _Scenario(
    title: 'Rotation playground',
    subtitle: 'rotateEnabled: true — two-finger rotation with a reset button.',
    icon: Icons.rotate_right_outlined,
    builder: (_) => const RotationPage(),
  ),
];

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _Header()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 1100
                    ? 3
                    : width >= 680
                    ? 2
                    : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 132,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ScenarioCard(scenario: _scenarios[i]),
                    childCount: _scenarios.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  static const _pubUrl = 'https://pub.dev/packages/viewfinder';
  static const _githubUrl = 'https://github.com/koji-1009/viewfinder';
  static const _demoUrl = 'https://koji-1009.github.io/viewfinder/';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.camera_outlined,
                        size: 36,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'viewfinder',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A photo viewer for Flutter — pinch / double-tap / rotation '
                    'zoom, an arena-aware gesture layer that hands edge pans to '
                    'a parent PageView, drag-to-dismiss, a synchronized '
                    'thumbnail strip, a page indicator, and keyboard shortcuts.',
                    style: text.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _LinkChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'pub.dev',
                        url: _pubUrl,
                      ),
                      _LinkChip(
                        icon: Icons.code_outlined,
                        label: 'GitHub',
                        url: _githubUrl,
                      ),
                      _LinkChip(
                        icon: Icons.public_outlined,
                        label: 'Live demo',
                        url: _demoUrl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pick a scenario',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A link shown as a copyable URL. No url_launcher dependency — the URL
/// is rendered as selectable text so visitors can copy it, and the icon
/// gives it a button-like affordance.
class _LinkChip extends StatelessWidget {
  const _LinkChip({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: url,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          SelectableText(url, style: TextStyle(color: scheme.primary)),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({required this.scenario});

  final _Scenario scenario;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: scenario.builder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(scenario.icon, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        scenario.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
