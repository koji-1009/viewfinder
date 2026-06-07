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
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3B6EA5),
        brightness: Brightness.dark,
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
    subtitle:
        'rotateEnabled: true — two-finger rotation, plus a slider for '
        'mouse / trackpad.',
    icon: Icons.rotate_right_outlined,
    builder: (_) => const RotationPage(),
  ),
];

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('viewfinder')),
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
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: scenario.builder));
        },
        title: Text(scenario.title),
        subtitle: Text(scenario.subtitle, maxLines: 3, overflow: .ellipsis),
        leading: Material(
          color: scheme.primaryContainer,
          borderRadius: .circular(12),
          clipBehavior: .antiAlias,
          child: SizedBox.square(dimension: 44, child: Icon(scenario.icon)),
        ),
        trailing: Icon(Icons.chevron_right),
      ),
    );
  }
}
