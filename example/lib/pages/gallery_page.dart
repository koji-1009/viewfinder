import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 1 — the full gallery demo.
///
/// A responsive thumbnail grid opens into a full-screen [Viewfinder] with
/// a thumbnail strip, page indicator, drag-to-dismiss, a tap-to-toggle
/// chrome overlay, Hero flight, and a live settings sheet (tune icon)
/// that flips every knob without restarting.
class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsScope(settings: _Settings(), child: const _GalleryGrid());
  }
}

class _GalleryGrid extends StatelessWidget {
  const _GalleryGrid();

  @override
  Widget build(BuildContext context) {
    final heroEnabled = _Settings.of(context).heroEnabled;
    final images = DemoPhotos.images;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.touch_app_outlined,
            message:
                'Tap a photo to open the full-screen gallery. Swipe between '
                'pages, pinch / double-tap to zoom, drag down to dismiss, and '
                'tap the photo to toggle chrome. The tune icon flips every '
                'knob live.',
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 180).floor().clamp(
                  2,
                  6,
                );
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: images.length,
                  itemBuilder: (ctx, i) {
                    final thumb = ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(image: images[i], fit: BoxFit.cover),
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _GalleryViewer(initialIndex: i),
                        ),
                      ),
                      child: heroEnabled
                          ? Hero(tag: 'gallery-photo-$i', child: thumb)
                          : thumb,
                    );
                  },
                );
              },
            ),
          ),
        ],
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

class _GalleryViewer extends StatefulWidget {
  const _GalleryViewer({required this.initialIndex});

  final int initialIndex;

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
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
    // Snapshot settings once at gallery-open time; only the initial
    // values matter for chrome lifecycle.
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
          clipBehavior: Clip.hardEdge,
          child: Image(
            image: DemoPhotos.images[index],
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

  ViewfinderPageIndicator? _buildIndicator(_Settings s) {
    if (!s.indicatorEnabled) return null;
    if (s.indicatorForceNumeric) return const ViewfinderPageIndicatorLabel();
    return const ViewfinderPageIndicatorAdaptive();
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
    final images = DemoPhotos.images;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Viewfinder(
        itemCount: images.length,
        controller: _controller,
        defaultInitialScale: s.initialScale,
        precacheAdjacent: s.precacheAdjacent,
        pagerAxis: s.pagerAxis,
        rotateEnabled: s.rotateEnabled,
        swipeDragDevices: s.dragDevices,
        doubleTapScales: const [1.0, 2.5, 5.0],
        indicator: _buildIndicator(s),
        thumbnails: _buildThumbnails(s),
        dismiss: _buildDismiss(s),
        chromeController: _chrome,
        chromeOverlays: _chrome == null
            ? const []
            : [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _ChromeBar(controller: _controller),
                ),
              ],
        itemBuilder: (context, index) => ViewfinderItem(
          image: images[index],
          hero: s.heroEnabled ? ViewfinderHero('gallery-photo-$index') : null,
          semanticLabel: 'Photo ${index + 1}',
          errorBuilder: (_, _, _) => const DemoBrokenImage(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

/// A translucent top bar shown as a chrome overlay, demonstrating that
/// [Viewfinder.chromeOverlays] fade in sync with the thumbnails and
/// indicator.
class _ChromeBar extends StatelessWidget {
  const _ChromeBar({required this.controller});

  final ViewfinderController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Two-stage back: reset zoom first, then pop.
                  if (controller.resetCurrentImage()) return;
                  Navigator.of(context).maybePop();
                },
              ),
              const Expanded(
                child: Text(
                  'Tap photo to toggle this bar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Settings UI and model — drives the live tuning panel.
// -----------------------------------------------------------------------------

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = _Settings.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            onSelectionChanged: (value) => settings.update(() {
              settings.pagerAxis = value.first;
              // Vertical pager + dismiss assert together; drop dismiss
              // automatically so the live toggle never crashes.
              if (settings.pagerAxis == Axis.vertical) {
                settings.dismissEnabled = false;
              }
            }),
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
          subtitle: DropdownButton<Set<PointerDeviceKind>>(
            isExpanded: true,
            value: settings.dragDevices,
            items: const [
              DropdownMenuItem(
                value: kViewfinderDefaultSwipeDragDevices,
                child: Text('all kinds (default)'),
              ),
              DropdownMenuItem(
                value: _touchLikeDevices,
                child: Text('touch / stylus only'),
              ),
              DropdownMenuItem(
                value: _allButMouseDevices,
                child: Text('all except mouse'),
              ),
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
          subtitle: SegmentedButton<ViewfinderInitialScale>(
            segments: const [
              ButtonSegment(
                value: ViewfinderInitialScale.contain(),
                label: Text('contain'),
              ),
              ButtonSegment(
                value: ViewfinderInitialScale.cover(),
                label: Text('cover'),
              ),
              ButtonSegment(
                value: ViewfinderInitialScale.contain(1.5),
                label: Text('contain(1.5)'),
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
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ViewfinderThumbnailPosition.top,
                  icon: Icon(Icons.keyboard_arrow_up),
                  tooltip: 'top',
                ),
                ButtonSegment(
                  value: ViewfinderThumbnailPosition.bottom,
                  icon: Icon(Icons.keyboard_arrow_down),
                  tooltip: 'bottom',
                ),
                ButtonSegment(
                  value: ViewfinderThumbnailPosition.left,
                  icon: Icon(Icons.keyboard_arrow_left),
                  tooltip: 'left',
                ),
                ButtonSegment(
                  value: ViewfinderThumbnailPosition.right,
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
            title: const Text('force numeric (label)'),
            value: settings.indicatorForceNumeric,
            onChanged: (v) =>
                settings.update(() => settings.indicatorForceNumeric = v),
          ),
        const _SectionLabel('Drag-to-dismiss'),
        SwitchListTile(
          dense: true,
          title: const Text('enabled'),
          subtitle: settings.pagerAxis == Axis.vertical
              ? const Text(
                  'Disabled while pagerAxis is vertical — both read '
                  'vertical drags.',
                )
              : null,
          value: settings.dismissEnabled,
          onChanged: settings.pagerAxis == Axis.vertical
              ? null
              : (v) => settings.update(() => settings.dismissEnabled = v),
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
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
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

  Axis pagerAxis = Axis.horizontal;
  int precacheAdjacent = 2;
  Set<PointerDeviceKind> dragDevices = kViewfinderDefaultSwipeDragDevices;
  bool rotateEnabled = false;
  ViewfinderInitialScale initialScale = const ViewfinderInitialScale.contain();
  bool heroEnabled = true;

  bool thumbnailsEnabled = true;
  ViewfinderThumbnailPosition thumbnailsPosition =
      ViewfinderThumbnailPosition.bottom;
  bool thumbnailsCustomBuilder = false;
  bool thumbnailsSafeArea = true;

  bool indicatorEnabled = true;
  bool indicatorForceNumeric = false;

  bool dismissEnabled = true;
  ViewfinderDismissSlideType dismissSlide =
      ViewfinderDismissSlideType.wholePage;

  bool chromeEnabled = true;
  bool chromeAutoHideWhileZoomed = true;
  Duration? chromeAutoHideAfter = const Duration(seconds: 3);

  void update(VoidCallback f) {
    f();
    notifyListeners();
  }
}

/// Preset device sets for the swipeDragDevices dropdown. Const so the
/// dropdown's identity-based selection works.
const Set<PointerDeviceKind> _touchLikeDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
};

const Set<PointerDeviceKind> _allButMouseDevices = {
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
};
