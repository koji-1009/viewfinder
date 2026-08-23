import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/embedded_zoom_page.dart';
import 'pages/gallery_page.dart';
import 'pages/rotation_page.dart';
import 'pages/single_photo_page.dart';
import 'pages/vertical_pager_page.dart';

void main() => runApp(const ViewfinderDemoApp());

class ViewfinderDemoApp extends StatefulWidget {
  const ViewfinderDemoApp({super.key});

  @override
  State<ViewfinderDemoApp> createState() => _ViewfinderDemoAppState();
}

class _ViewfinderDemoAppState extends State<ViewfinderDemoApp> {
  /// Scenarios are sub-routes of `/`, so a `go` builds home → scenario →
  /// viewer and every back — AppBar, platform gesture, browser — pops one
  /// step of it.
  ///
  /// Hash URLs (`#/gallery/photo/3`) are deliberate: the demo is hosted on
  /// GitHub Pages, which serves static files only and cannot rewrite a
  /// deep link onto index.html.
  late final GoRouter _router = GoRouter(
    // A stale or mistyped demo link lands on the home screen instead of
    // go_router's exception page.
    onException: (_, _, router) => router.go('/'),
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const _HomePage(),
        routes: [
          galleryRoute,
          singlePhotoRoute,
          verticalPagerRoute,
          embeddedZoomRoute,
          rotationRoute,
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'viewfinder demo',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // The grid and the viewer are separate locations, so the settings
      // they share sit above the router.
      builder: (context, child) => GallerySettingsHost(child: child!),
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B6EA5),
        brightness: .light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B6EA5),
        brightness: .dark,
      ),
    );
  }
}

/// One demo scenario shown as a card on the home screen.
class _Scenario {
  const _Scenario({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.path,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
}

const List<_Scenario> _scenarios = [
  _Scenario(
    title: 'Gallery',
    subtitle:
        'Grid → full-screen pager with thumbnails, indicator, '
        'drag-to-dismiss, chrome overlay, Hero, and a live settings sheet.',
    icon: Icons.photo_library_outlined,
    path: GalleryPage.routePath,
  ),
  _Scenario(
    title: 'Single photo',
    subtitle: 'Viewfinder.single — one zoomable photo with drag-to-dismiss.',
    icon: Icons.image_outlined,
    path: SinglePhotoPage.routePath,
  ),
  _Scenario(
    title: 'Vertical pager',
    subtitle:
        'pagerAxis: Axis.vertical — swipe up / down. Dismiss is off (it '
        'would clash with the vertical pager).',
    icon: Icons.swap_vert_outlined,
    path: VerticalPagerPage.routePath,
  ),
  _Scenario(
    title: 'Embedded zoom',
    subtitle:
        'ViewfinderImage inline in an article, plus ViewfinderImage.child '
        'zooming a non-image widget.',
    icon: Icons.article_outlined,
    path: EmbeddedZoomPage.routePath,
  ),
  _Scenario(
    title: 'Rotation playground',
    subtitle:
        'rotateEnabled: true — two-finger rotation, plus a slider for '
        'mouse / trackpad.',
    icon: Icons.rotate_right_outlined,
    path: RotationPage.routePath,
  ),
];

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('viewfinder')),
      body: ListView.separated(
        padding: const .symmetric(horizontal: 16),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _ScenarioCard(scenario: _scenarios[index]),
        itemCount: _scenarios.length,
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
    return Card.filled(
      margin: .zero,
      clipBehavior: .antiAlias,
      child: ListTile(
        onTap: () => context.go(scenario.path),
        title: Text(scenario.title),
        subtitle: Text(scenario.subtitle, maxLines: 3, overflow: .ellipsis),
        leading: Material(
          color: scheme.primaryContainer,
          borderRadius: .circular(12),
          clipBehavior: .antiAlias,
          child: SizedBox.square(dimension: 44, child: Icon(scenario.icon)),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
