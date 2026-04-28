import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:taro/taro.dart';
import 'package:viewfinder/viewfinder.dart';

void main() => runApp(const _ExampleApp());

class _ExampleApp extends StatefulWidget {
  const _ExampleApp();

  @override
  State<_ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<_ExampleApp> {
  final _settings = _Settings();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScope(
      settings: _settings,
      child: const MaterialApp(
        title: 'viewfinder example',
        debugShowCheckedModeBanner: false,
        home: _HomePage(),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  // TaroImage caches bytes on disk, so the grid thumbnail decode and the
  // larger gallery decode share a single HTTP fetch — and the gallery's
  // first-open Hero lands on a real frame instead of a loading spinner.
  // 14 photos at mixed aspect ratios — enough to push the page indicator
  // past its `maxDots` default of 12 (so the numeric `1 / N` fallback
  // kicks in for free), and enough to make the thumbnail strip's
  // auto-scroll visible during a swipe demo.
  static final List<ImageProvider> _images = [
    const TaroImage('https://picsum.photos/id/1015/4000/3000'),
    const TaroImage('https://picsum.photos/id/1018/4000/2666'),
    const TaroImage('https://picsum.photos/id/1019/4000/2666'),
    const TaroImage('https://picsum.photos/id/1025/3000/2000'),
    const TaroImage('https://picsum.photos/id/1029/3500/2333'),
    const TaroImage('https://picsum.photos/id/1037/4000/2666'),
    const TaroImage('https://picsum.photos/id/1039/4000/2500'),
    const TaroImage('https://picsum.photos/id/1041/3000/4000'),
    const TaroImage('https://picsum.photos/id/1043/2000/3000'),
    const TaroImage('https://picsum.photos/id/1050/4000/2666'),
    const TaroImage('https://picsum.photos/id/1055/3000/2000'),
    const TaroImage('https://picsum.photos/id/1059/3000/3000'),
    const TaroImage('https://picsum.photos/id/1074/4000/2666'),
    const TaroImage('https://picsum.photos/id/1080/4000/2250'),
  ];

  @override
  Widget build(BuildContext context) {
    final heroEnabled = _Settings.of(context).heroEnabled;
    return Scaffold(
      appBar: AppBar(
        title: const Text('viewfinder — demo'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const .all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _images.length,
        itemBuilder: (ctx, i) {
          final thumb = Image(image: _images[i], fit: .cover);
          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _GalleryPage(initialIndex: i),
              ),
            ),
            child: heroEnabled ? Hero(tag: 'photo-$i', child: thumb) : thumb,
          );
        },
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({required this.initialIndex});

  final int initialIndex;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  late final ViewfinderController _controller;
  ViewfinderChromeController? _chrome;
  bool _chromeBound = false;

  @override
  void initState() {
    super.initState();
    _controller = ViewfinderController(initialIndex: widget.initialIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read settings once via the InheritedNotifier, then capture the
    // chrome controller config. Mirrors the previous behaviour where
    // chrome setup snapshots settings at gallery-open time and ignores
    // later changes — only the initial values matter for lifecycle.
    if (_chromeBound) return;
    _chromeBound = true;
    final s = _Settings.of(context);
    if (s.chromeEnabled) {
      _chrome = ViewfinderChromeController(
        autoHideAfter: s.chromeAutoHideAfter,
        autoHideWhileZoomed: s.chromeAutoHideWhileZoomed,
      );
    }
  }

  @override
  void dispose() {
    _chrome?.dispose();
    _controller.dispose();
    super.dispose();
  }

  ViewfinderThumbnails? _buildThumbnails(_Settings s) {
    if (!s.thumbnailsEnabled) return null;
    if (s.thumbnailsCustomBuilder) {
      return ViewfinderThumbnails.custom(
        position: s.thumbnailsPosition,
        size: 64,
        safeArea: s.thumbnailsSafeArea,
        itemBuilder: (context, index, selected) => Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.amber : Colors.transparent,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: .hardEdge,
          child: Image(
            image: _HomePage._images[index],
            fit: .cover,
            width: 64,
            height: 64,
          ),
        ),
      );
    }
    return ViewfinderThumbnails(
      position: s.thumbnailsPosition,
      safeArea: s.thumbnailsSafeArea,
      size: 64,
    );
  }

  ViewfinderPageIndicator? _buildIndicator(_Settings s) {
    if (!s.indicatorEnabled) return null;
    return ViewfinderPageIndicator(maxDots: s.indicatorForceNumeric ? 0 : 12);
  }

  ViewfinderDismiss? _buildDismiss(_Settings s) {
    if (!s.dismissEnabled) return null;
    return ViewfinderDismiss(
      onDismiss: () => Navigator.of(context).maybePop(),
      slideType: s.dismissSlide,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _Settings.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Photo')),
      body: Viewfinder(
        itemCount: _HomePage._images.length,
        controller: _controller,
        defaultInitialScale: s.initialScale.resolve(),
        precacheAdjacent: s.precacheAdjacent,
        pagerAxis: s.pagerAxis,
        rotateEnabled: s.rotateEnabled,
        swipeDragDevices: s.dragDevices.resolve(),
        doubleTapScales: const [1.0, 2.5, 5.0],
        indicator: _buildIndicator(s),
        thumbnails: _buildThumbnails(s),
        dismiss: _buildDismiss(s),
        chromeController: _chrome,
        itemBuilder: (context, index) => ViewfinderItem(
          image: _HomePage._images[index],
          hero: s.heroEnabled ? ViewfinderHero('photo-$index') : null,
          semanticLabel: 'Photo ${index + 1}',
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Settings UI and model — secondary boilerplate that drives the demo's tuning
// panel. Skipped when reading top-down for the headline Viewfinder usage above.
// -----------------------------------------------------------------------------

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = _Settings.of(context);
    return ListView(
      padding: const .symmetric(horizontal: 16),
      children: [
        const _SectionLabel('Pager'),
        ListTile(
          dense: true,
          title: const Text('pagerAxis'),
          trailing: SegmentedButton<Axis>(
            segments: const [
              ButtonSegment(value: .horizontal, label: Text('horiz')),
              ButtonSegment(value: .vertical, label: Text('vert')),
            ],
            selected: {settings.pagerAxis},
            onSelectionChanged: (s) =>
                settings.update(() => settings.pagerAxis = s.first),
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('precacheAdjacent'),
          subtitle: Slider(
            value: settings.precacheAdjacent.toDouble(),
            min: 0,
            max: 3,
            divisions: 3,
            label: '${settings.precacheAdjacent}',
            onChanged: (v) =>
                settings.update(() => settings.precacheAdjacent = v.round()),
          ),
        ),
        ListTile(
          dense: true,
          title: const Text('swipeDragDevices'),
          subtitle: DropdownButton<_DragDevicesPreset>(
            isExpanded: true,
            value: settings.dragDevices,
            items: [
              for (final p in _DragDevicesPreset.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => v == null
                ? null
                : settings.update(() => settings.dragDevices = v),
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('rotateEnabled'),
          value: settings.rotateEnabled,
          onChanged: (v) => settings.update(() => settings.rotateEnabled = v),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('heroEnabled'),
          subtitle: const Text(
            'Wraps grid thumbnails and the gallery image in Hero. Off '
            'to compare against the route transition alone.',
          ),
          value: settings.heroEnabled,
          onChanged: (v) => settings.update(() => settings.heroEnabled = v),
        ),
        ListTile(
          dense: true,
          title: const Text('defaultInitialScale'),
          subtitle: SegmentedButton<_InitialScalePreset>(
            segments: const [
              ButtonSegment(value: .contain, label: Text('contain')),
              ButtonSegment(value: .cover, label: Text('cover')),
              ButtonSegment(value: .value15, label: Text('1.5x')),
            ],
            selected: {settings.initialScale},
            onSelectionChanged: (s) =>
                settings.update(() => settings.initialScale = s.first),
          ),
        ),
        const _SectionLabel('Thumbnails'),
        SwitchListTile(
          dense: true,
          title: const Text('enabled'),
          value: settings.thumbnailsEnabled,
          onChanged: (v) =>
              settings.update(() => settings.thumbnailsEnabled = v),
        ),
        if (settings.thumbnailsEnabled) ...[
          ListTile(
            dense: true,
            title: const Text('position'),
            subtitle: SegmentedButton<ViewfinderThumbnailPosition>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: .top,
                  icon: Icon(Icons.keyboard_arrow_up),
                  tooltip: 'top',
                ),
                ButtonSegment(
                  value: .bottom,
                  icon: Icon(Icons.keyboard_arrow_down),
                  tooltip: 'bottom',
                ),
                ButtonSegment(
                  value: .left,
                  icon: Icon(Icons.keyboard_arrow_left),
                  tooltip: 'left',
                ),
                ButtonSegment(
                  value: .right,
                  icon: Icon(Icons.keyboard_arrow_right),
                  tooltip: 'right',
                ),
              ],
              selected: {settings.thumbnailsPosition},
              onSelectionChanged: (s) =>
                  settings.update(() => settings.thumbnailsPosition = s.first),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('safeArea'),
            value: settings.thumbnailsSafeArea,
            onChanged: (v) =>
                settings.update(() => settings.thumbnailsSafeArea = v),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('custom builder (highlight selected)'),
            value: settings.thumbnailsCustomBuilder,
            onChanged: (v) =>
                settings.update(() => settings.thumbnailsCustomBuilder = v),
          ),
        ],
        const _SectionLabel('Page indicator'),
        SwitchListTile(
          dense: true,
          title: const Text('enabled'),
          value: settings.indicatorEnabled,
          onChanged: (v) =>
              settings.update(() => settings.indicatorEnabled = v),
        ),
        if (settings.indicatorEnabled)
          SwitchListTile(
            dense: true,
            title: const Text('force numeric (maxDots=0)'),
            value: settings.indicatorForceNumeric,
            onChanged: (v) =>
                settings.update(() => settings.indicatorForceNumeric = v),
          ),
        const _SectionLabel('Drag-to-dismiss'),
        SwitchListTile(
          dense: true,
          title: const Text('enabled'),
          value: settings.dismissEnabled,
          onChanged: (v) => settings.update(() => settings.dismissEnabled = v),
        ),
        if (settings.dismissEnabled)
          ListTile(
            dense: true,
            title: const Text('slideType'),
            subtitle: SegmentedButton<ViewfinderDismissSlideType>(
              segments: const [
                ButtonSegment(value: .wholePage, label: Text('wholePage')),
                ButtonSegment(value: .onlyImage, label: Text('onlyImage')),
              ],
              selected: {settings.dismissSlide},
              onSelectionChanged: (s) =>
                  settings.update(() => settings.dismissSlide = s.first),
            ),
          ),
        const _SectionLabel('Chrome controller'),
        SwitchListTile(
          dense: true,
          title: const Text('enabled (tap to toggle)'),
          value: settings.chromeEnabled,
          onChanged: (v) => settings.update(() => settings.chromeEnabled = v),
        ),
        if (settings.chromeEnabled) ...[
          SwitchListTile(
            dense: true,
            title: const Text('autoHideWhileZoomed'),
            value: settings.chromeAutoHideWhileZoomed,
            onChanged: (v) =>
                settings.update(() => settings.chromeAutoHideWhileZoomed = v),
          ),
          ListTile(
            dense: true,
            title: const Text('autoHideAfter'),
            subtitle: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -1, label: Text('off')),
                ButtonSegment(value: 1, label: Text('1s')),
                ButtonSegment(value: 3, label: Text('3s')),
              ],
              selected: {settings.chromeAutoHideAfter?.inSeconds ?? -1},
              onSelectionChanged: (s) => settings.update(() {
                final v = s.first;
                settings.chromeAutoHideAfter = v < 0
                    ? null
                    : Duration(seconds: v);
              }),
            ),
          ),
        ],
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(0, 16, 0, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _SettingsScope extends InheritedNotifier<_Settings> {
  const _SettingsScope({required _Settings settings, required super.child})
    : super(notifier: settings);
}

class _Settings extends ChangeNotifier {
  static _Settings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SettingsScope>()!.notifier!;

  Axis pagerAxis = .horizontal;
  int precacheAdjacent = 2;
  _DragDevicesPreset dragDevices = .all;
  bool rotateEnabled = false;
  _InitialScalePreset initialScale = .contain;
  bool heroEnabled = false;

  bool thumbnailsEnabled = true;
  ViewfinderThumbnailPosition thumbnailsPosition = .bottom;
  bool thumbnailsCustomBuilder = false;
  bool thumbnailsSafeArea = true;

  bool indicatorEnabled = true;
  bool indicatorForceNumeric = false;

  bool dismissEnabled = true;
  ViewfinderDismissSlideType dismissSlide = .wholePage;

  bool chromeEnabled = false;
  bool chromeAutoHideWhileZoomed = true;
  Duration? chromeAutoHideAfter = const Duration(seconds: 3);

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }
}

enum _DragDevicesPreset { all, touchOnly, noMouse }

extension on _DragDevicesPreset {
  Set<PointerDeviceKind> resolve() => switch (this) {
    .all => kViewfinderDefaultSwipeDragDevices,
    .touchOnly => const {.touch, .stylus, .invertedStylus},
    .noMouse => const {.touch, .stylus, .invertedStylus, .trackpad, .unknown},
  };

  String get label => switch (this) {
    .all => 'all kinds (default)',
    .touchOnly => 'touch / stylus only',
    .noMouse => 'all except mouse',
  };
}

enum _InitialScalePreset { contain, cover, value15 }

extension on _InitialScalePreset {
  ViewfinderInitialScale resolve() => switch (this) {
    .contain => const ViewfinderInitialScale.contain(),
    .cover => const ViewfinderInitialScale.cover(),
    .value15 => const ViewfinderInitialScale.value(1.5),
  };
}
