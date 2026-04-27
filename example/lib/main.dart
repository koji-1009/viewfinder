import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

void main() => runApp(const _ExampleApp());

// ---------------------------------------------------------------------------
// Settings model — every togglable knob the gallery exposes lives here so the
// example app can flip combinations without rebuilding the widget tree.
// ---------------------------------------------------------------------------

enum _DragDevicesPreset { all, touchOnly, noMouse }

extension on _DragDevicesPreset {
  Set<PointerDeviceKind> resolve() => switch (this) {
    _DragDevicesPreset.all => kViewfinderDefaultSwipeDragDevices,
    _DragDevicesPreset.touchOnly => const {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
    },
    _DragDevicesPreset.noMouse => const {
      PointerDeviceKind.touch,
      PointerDeviceKind.stylus,
      PointerDeviceKind.invertedStylus,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.unknown,
    },
  };

  String get label => switch (this) {
    _DragDevicesPreset.all => 'all kinds (default)',
    _DragDevicesPreset.touchOnly => 'touch / stylus only',
    _DragDevicesPreset.noMouse => 'all except mouse',
  };
}

enum _InitialScalePreset { contain, cover, value15 }

extension on _InitialScalePreset {
  ViewfinderInitialScale resolve() => switch (this) {
    _InitialScalePreset.contain => const ViewfinderInitialScale.contain(),
    _InitialScalePreset.cover => const ViewfinderInitialScale.cover(),
    _InitialScalePreset.value15 => const ViewfinderInitialScale.value(1.5),
  };
}

class _Settings extends ChangeNotifier {
  // Pager
  Axis pagerAxis = Axis.horizontal;
  int precacheAdjacent = 2;
  _DragDevicesPreset dragDevices = _DragDevicesPreset.all;
  bool rotateEnabled = false;
  _InitialScalePreset initialScale = _InitialScalePreset.contain;

  // Thumbnails
  bool thumbnailsEnabled = true;
  ViewfinderThumbnailPosition thumbnailsPosition =
      ViewfinderThumbnailPosition.bottom;
  bool thumbnailsCustomBuilder = false;
  bool thumbnailsSafeArea = true;

  // Indicator
  bool indicatorEnabled = true;
  bool indicatorForceNumeric = false;

  // Dismiss
  bool dismissEnabled = true;
  ViewfinderDismissSlideType dismissSlide =
      ViewfinderDismissSlideType.wholePage;

  // Chrome
  bool chromeEnabled = false;
  bool chromeAutoHideWhileZoomed = true;
  Duration? chromeAutoHideAfter = const Duration(seconds: 3);

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

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
    return MaterialApp(
      title: 'viewfinder example',
      home: _HomePage(settings: _settings),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.settings});
  final _Settings settings;

  static final List<ImageProvider> _images = [
    const NetworkImage('https://picsum.photos/id/1015/4000/3000'),
    const NetworkImage('https://picsum.photos/id/1025/3000/2000'),
    const NetworkImage('https://picsum.photos/id/1039/4000/2500'),
    const NetworkImage('https://picsum.photos/id/1043/2000/3000'),
    const NetworkImage('https://picsum.photos/id/1055/3000/2000'),
  ];

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: _images.length,
        itemBuilder: (_, i) => InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _GalleryPage(initialIndex: i, settings: settings),
            ),
          ),
          child: Hero(
            tag: 'photo-$i',
            child: Image(
              image: ResizeImage(_images[i], width: 360),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(settings: settings),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings sheet
// ---------------------------------------------------------------------------

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet({required this.settings});
  final _Settings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _SectionLabel('Pager'),
            ListTile(
              dense: true,
              title: const Text('pagerAxis'),
              trailing: SegmentedButton<Axis>(
                segments: const [
                  ButtonSegment(value: Axis.horizontal, label: Text('horiz')),
                  ButtonSegment(value: Axis.vertical, label: Text('vert')),
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
                onChanged: (v) => settings.update(
                  () => settings.precacheAdjacent = v.round(),
                ),
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
              onChanged: (v) =>
                  settings.update(() => settings.rotateEnabled = v),
            ),
            ListTile(
              dense: true,
              title: const Text('defaultInitialScale'),
              subtitle: SegmentedButton<_InitialScalePreset>(
                segments: const [
                  ButtonSegment(
                    value: _InitialScalePreset.contain,
                    label: Text('contain'),
                  ),
                  ButtonSegment(
                    value: _InitialScalePreset.cover,
                    label: Text('cover'),
                  ),
                  ButtonSegment(
                    value: _InitialScalePreset.value15,
                    label: Text('1.5×'),
                  ),
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
                  segments: const [
                    ButtonSegment(
                      value: ViewfinderThumbnailPosition.top,
                      label: Text('top'),
                    ),
                    ButtonSegment(
                      value: ViewfinderThumbnailPosition.bottom,
                      label: Text('bottom'),
                    ),
                    ButtonSegment(
                      value: ViewfinderThumbnailPosition.left,
                      label: Text('left'),
                    ),
                    ButtonSegment(
                      value: ViewfinderThumbnailPosition.right,
                      label: Text('right'),
                    ),
                  ],
                  selected: {settings.thumbnailsPosition},
                  onSelectionChanged: (s) => settings.update(
                    () => settings.thumbnailsPosition = s.first,
                  ),
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
              onChanged: (v) =>
                  settings.update(() => settings.dismissEnabled = v),
            ),
            if (settings.dismissEnabled)
              ListTile(
                dense: true,
                title: const Text('slideType'),
                subtitle: SegmentedButton<ViewfinderDismissSlideType>(
                  segments: const [
                    ButtonSegment(
                      value: ViewfinderDismissSlideType.wholePage,
                      label: Text('wholePage'),
                    ),
                    ButtonSegment(
                      value: ViewfinderDismissSlideType.onlyImage,
                      label: Text('onlyImage'),
                    ),
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
              onChanged: (v) =>
                  settings.update(() => settings.chromeEnabled = v),
            ),
            if (settings.chromeEnabled) ...[
              SwitchListTile(
                dense: true,
                title: const Text('autoHideWhileZoomed'),
                value: settings.chromeAutoHideWhileZoomed,
                onChanged: (v) => settings.update(
                  () => settings.chromeAutoHideWhileZoomed = v,
                ),
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
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Gallery page
// ---------------------------------------------------------------------------

class _GalleryPage extends StatefulWidget {
  const _GalleryPage({required this.initialIndex, required this.settings});

  final int initialIndex;
  final _Settings settings;

  @override
  State<_GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<_GalleryPage> {
  ViewfinderChromeController? _chrome;
  double _dismissProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _maybeInitChrome();
  }

  void _maybeInitChrome() {
    if (!widget.settings.chromeEnabled) return;
    _chrome = ViewfinderChromeController(
      autoHideAfter: widget.settings.chromeAutoHideAfter,
      autoHideWhileZoomed: widget.settings.chromeAutoHideWhileZoomed,
    );
  }

  @override
  void dispose() {
    _chrome?.dispose();
    super.dispose();
  }

  ViewfinderThumbnails? _buildThumbnails() {
    final s = widget.settings;
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
          clipBehavior: Clip.hardEdge,
          child: Image(
            image: ResizeImage(_HomePage._images[index], width: 128),
            fit: BoxFit.cover,
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

  ViewfinderPageIndicator? _buildIndicator() {
    final s = widget.settings;
    if (!s.indicatorEnabled) return null;
    return ViewfinderPageIndicator(maxDots: s.indicatorForceNumeric ? 0 : 12);
  }

  ViewfinderDismiss? _buildDismiss() {
    final s = widget.settings;
    if (!s.dismissEnabled) return null;
    return ViewfinderDismiss(
      onDismiss: () => Navigator.of(context).maybePop(),
      slideType: s.dismissSlide,
      onProgress: (p) => setState(() => _dismissProgress = p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'dismiss progress: ${(_dismissProgress * 100).toStringAsFixed(0)}%',
        ),
      ),
      body: Viewfinder(
        itemCount: _HomePage._images.length,
        controller: ViewfinderController(initialIndex: widget.initialIndex),
        defaultResize: const ViewfinderResize.targetSize(),
        defaultInitialScale: s.initialScale.resolve(),
        precacheAdjacent: s.precacheAdjacent,
        pagerAxis: s.pagerAxis,
        rotateEnabled: s.rotateEnabled,
        swipeDragDevices: s.dragDevices.resolve(),
        doubleTapScales: const [1.0, 2.5, 5.0],
        indicator: _buildIndicator(),
        thumbnails: _buildThumbnails(),
        dismiss: _buildDismiss(),
        chromeController: _chrome,
        chromeOverlays: _chrome == null
            ? const []
            : [
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'tap photo to toggle chrome',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
        itemBuilder: (context, index) => ViewfinderItem(
          image: _HomePage._images[index],
          heroTag: 'photo-$index',
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
