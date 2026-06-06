import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewfinder/src/internal/zoomable_viewport.dart';
import 'package:viewfinder/viewfinder.dart';

// Same codec-free image plumbing as viewfinder_test.dart.
late ui.Image _testImage;

@immutable
class _SyncImageProvider extends ImageProvider<_SyncImageProvider> {
  const _SyncImageProvider(this._tag);
  final Object _tag;

  @override
  Future<_SyncImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SyncImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: _testImage.clone())),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _SyncImageProvider && other._tag == _tag;

  @override
  int get hashCode => _tag.hashCode;
}

ImageProvider _memoryImage([Object tag = 'default']) => _SyncImageProvider(tag);

Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}

/// A page child whose State carries a mutable marker, for keep-alive
/// verification.
class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe();

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  int marker = 0;

  @override
  Widget build(BuildContext context) =>
      Text('marker:$marker', textDirection: TextDirection.ltr);
}

void main() {
  setUpAll(() async {
    _testImage = await createTestImage(width: 1, height: 1);
  });

  // -------------------------------------------------------------------
  // Long-press / secondary tap
  // -------------------------------------------------------------------

  testWidgets('ViewfinderImage: onLongPress and onLongPressStart fire', (
    tester,
  ) async {
    var longPressed = 0;
    Offset? startAt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            onLongPress: () => longPressed++,
            onLongPressStart: (d) => startAt = d.localPosition,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    await tester.longPressAt(tester.getCenter(find.byType(ZoomableViewport)));
    await tester.pumpAndSettle();
    expect(longPressed, 1);
    expect(startAt, isNotNull);
  });

  testWidgets('ViewfinderImage: onSecondaryTapUp fires on right-click', (
    tester,
  ) async {
    TapUpDetails? details;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            onSecondaryTapUp: (d) => details = d,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(details, isNotNull);
  });

  testWidgets('Viewfinder.images: onLongPress receives the page index', (
    tester,
  ) async {
    final pressed = <int>[];
    final controller = ViewfinderController(initialIndex: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder.images(
            [_memoryImage('a'), _memoryImage('b'), _memoryImage('c')],
            controller: controller,
            onLongPress: pressed.add,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    await tester.longPressAt(
      tester.getCenter(find.byType(ZoomableViewport).first),
    );
    await tester.pumpAndSettle();
    expect(pressed, [1]);
  });

  // -------------------------------------------------------------------
  // onScaleStateChanged
  // -------------------------------------------------------------------

  testWidgets('Viewfinder.onScaleStateChanged fires on zoom transitions', (
    tester,
  ) async {
    final events = <(int, ViewfinderScaleState)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 2,
              onScaleStateChanged: (i, s) => events.add((i, s)),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(events, isEmpty);

    // Pinch in.
    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveBy(const Offset(-60, 0));
    await b.moveBy(const Offset(60, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(events, [(0, ViewfinderScaleState.zoomed)]);

    // Esc resets → back to initial.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(events.last, (0, ViewfinderScaleState.initial));
  });

  // -------------------------------------------------------------------
  // Page-change announcements
  // -------------------------------------------------------------------

  testWidgets('Viewfinder announces page changes to screen readers', (
    tester,
  ) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    controller.animateTo(1);
    await tester.pumpAndSettle();

    final announcements = tester.takeAnnouncements();
    expect(announcements, isNotEmpty);
    expect(announcements.last.message, 'Photo 2 of 3');
  });

  testWidgets('Viewfinder: pageAnnouncementBuilder customizes the message '
      'and announcePageChanges=false silences it', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            pageAnnouncementBuilder: (i, n) => '写真 ${i + 1} / $n',
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements().last.message, '写真 3 / 3');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            announcePageChanges: false,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final pv = tester.widget<PageView>(find.byType(PageView));
    pv.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements(), isEmpty);
  });

  // -------------------------------------------------------------------
  // Immersive system UI
  // -------------------------------------------------------------------

  testWidgets('immersiveSystemUi syncs SystemChrome with chrome '
      'visibility and restores on dispose', (tester) async {
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final chrome = ViewfinderChromeController(autoHideAfter: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            immersiveSystemUi: true,
            chromeController: chrome,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    // Chrome starts visible → edge-to-edge.
    expect(modes.last, 'SystemUiMode.edgeToEdge');

    chrome.hide();
    await tester.pumpAndSettle();
    expect(modes.last, 'SystemUiMode.immersiveSticky');

    chrome.show();
    await tester.pumpAndSettle();
    expect(modes.last, 'SystemUiMode.edgeToEdge');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(modes.last, 'SystemUiMode.edgeToEdge');
    chrome.dispose();
  });

  // -------------------------------------------------------------------
  // keepAlivePages
  // -------------------------------------------------------------------

  testWidgets('keepAlivePages preserves a child page\'s State across '
      'far swipes; default does not', (tester) async {
    Future<ViewfinderController> pump({required bool keepAlive}) async {
      final controller = ViewfinderController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: Viewfinder(
                itemCount: 5,
                controller: controller,
                keepAlivePages: keepAlive,
                precacheAdjacent: 0,
                allowImplicitScrolling: false,
                itemBuilder: (_, i) => ViewfinderItem.child(
                  contentKey: 'probe-$i',
                  child: i == 0
                      ? const _StatefulProbe()
                      : Text('page $i', textDirection: TextDirection.ltr),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    // keepAlive: marker survives leaving and returning.
    var controller = await pump(keepAlive: true);
    tester.state<_StatefulProbeState>(find.byType(_StatefulProbe)).marker = 42;
    controller.jumpTo(3);
    await tester.pumpAndSettle();
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.state<_StatefulProbeState>(find.byType(_StatefulProbe)).marker,
      42,
    );

    // Default: the page is disposed once it leaves the cache extent.
    await tester.pumpWidget(const SizedBox.shrink());
    controller = await pump(keepAlive: false);
    tester.state<_StatefulProbeState>(find.byType(_StatefulProbe)).marker = 42;
    controller.jumpTo(3);
    await tester.pumpAndSettle();
    controller.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.state<_StatefulProbeState>(find.byType(_StatefulProbe)).marker,
      0,
    );
  });

  // -------------------------------------------------------------------
  // Mouse wheel behavior
  // -------------------------------------------------------------------

  testWidgets('mouseWheelBehavior.paging: wheel turns pages instead of '
      'zooming', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 3,
              controller: controller,
              mouseWheelBehavior: ViewfinderMouseWheelBehavior.paging,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
  });

  // -------------------------------------------------------------------
  // decodeSizeMultiplier
  // -------------------------------------------------------------------

  testWidgets('decodeSizeMultiplier wraps the page provider in a '
      'ResizeImage targeting viewport × multiplier', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            decodeSizeMultiplier: 2.0,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final images = tester
        .widgetList<Image>(find.byType(Image))
        .where((w) => w.image is ResizeImage)
        .toList();
    expect(images, isNotEmpty);
    final resize = images.first.image as ResizeImage;
    final dpr = tester.view.devicePixelRatio;
    expect(resize.width, (800 * dpr * 2.0).round());
    expect(resize.height, (600 * dpr * 2.0).round());
    expect(resize.policy, ResizeImagePolicy.fit);
  });

  // -------------------------------------------------------------------
  // dismissOnOverscroll
  // -------------------------------------------------------------------

  testWidgets('dismissOnOverscroll fires after pulling past the last '
      'page', (tester) async {
    var dismissed = 0;
    final controller = ViewfinderController(initialIndex: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 2,
              controller: controller,
              dismissOnOverscroll: true,
              dismiss: ViewfinderDismiss(onDismiss: () => dismissed++),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(controller.currentIndex, 1);

    // Drag left far past the last page: clamping physics reports the
    // blocked distance as overscroll, which accumulates past the
    // 100-px trigger.
    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final p = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await p.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await p.up();
    await tester.pumpAndSettle();
    expect(dismissed, 1);

    // An ordinary in-range swipe does not dismiss.
    final p2 = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await p2.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await p2.up();
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
    expect(dismissed, 1);
  });

  // -------------------------------------------------------------------
  // onThresholdCrossed
  // -------------------------------------------------------------------

  testWidgets('ViewfinderDismiss.onThresholdCrossed fires once per '
      'crossing in each direction', (tester) async {
    final crossings = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            dismiss: ViewfinderDismiss(
              onDismiss: () {},
              threshold: 0.2, // 120 px of the 600-px viewport
              onThresholdCrossed: crossings.add,
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Drag past the threshold, then back above it, then release.
    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final g = await tester.startGesture(center);
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(crossings, [true]);
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(crossings, [true, false]);
    await g.up();
    await tester.pumpAndSettle();
    expect(crossings, [true, false]);
  });

  // -------------------------------------------------------------------
  // Loop paging
  // -------------------------------------------------------------------

  testWidgets('loop: swiping past the last page wraps to the first and '
      'back', (tester) async {
    final log = <int>[];
    final controller = ViewfinderController(initialIndex: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 3,
              loop: true,
              controller: controller,
              onPageChanged: log.add,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(controller.currentIndex, 2);
    expect(find.bySemanticsLabel('Photo gallery, 3 of 3'), findsOneWidget);

    Future<void> swipe(double dx) async {
      final center = tester.getCenter(find.byType(ZoomableViewport).first);
      final p = await tester.startGesture(center);
      for (var i = 0; i < 8; i++) {
        await p.moveBy(Offset(dx, 0));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await p.up();
      await tester.pumpAndSettle();
    }

    // Forward off the end → wraps to 0.
    await swipe(-40);
    expect(controller.currentIndex, 0);
    expect(log, [0]);
    expect(find.bySemanticsLabel('Photo gallery, 1 of 3'), findsOneWidget);

    // Backward from 0 → wraps to 2.
    await swipe(40);
    expect(controller.currentIndex, 2);
    expect(log, [0, 2]);
  });

  testWidgets('loop: arrow keys wrap around the ends', (tester) async {
    final controller = ViewfinderController(initialIndex: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            loop: true,
            controller: controller,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
  });

  testWidgets('loop: animateTo travels the shortest way around', (
    tester,
  ) async {
    final log = <int>[];
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 4,
            loop: true,
            controller: controller,
            onPageChanged: log.add,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // 0 → 3 is one step backward around the loop, not three forward —
    // a single page change lands directly on 3.
    controller.animateTo(3);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 3);
    expect(log, [3]);
  });

  testWidgets('loop: itemCount < 2 behaves as a plain bounded pager', (
    tester,
  ) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            loop: true,
            controller: controller,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.bySemanticsLabel('Photo gallery, 1 of 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------------
  // Semantics & keys
  // -------------------------------------------------------------------

  testWidgets('thumbnail tiles expose button semantics and stable keys', (
    tester,
  ) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 3,
              controller: controller,
              thumbnails: const ViewfinderThumbnails(size: 40),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(find.bySemanticsLabel('Thumbnail 2'), findsOneWidget);
    expect(find.byKey(ViewfinderKeys.thumbnail(2)), findsOneWidget);
    expect(find.byKey(ViewfinderKeys.page(0)), findsOneWidget);

    await tester.tap(find.byKey(ViewfinderKeys.thumbnail(2)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
  });

  testWidgets('hero flights fly a viewer-fit shuttle by default', (
    tester,
  ) async {
    final image = _memoryImage('hero-shuttle');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Viewfinder.single(
                    image: image,
                    hero: const ViewfinderHero('shuttle-test'),
                  ),
                ),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Hero(
                  tag: 'shuttle-test',
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight

    // The overlay shuttle renders the viewer's fit (contain), not the
    // cover-fit source thumbnail Flutter's default would fly.
    final shuttles = tester
        .widgetList<Image>(find.byType(Image))
        .where((w) => w.image == image && w.fit == BoxFit.contain);
    expect(shuttles, isNotEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('page indicator respects the bottom safe-area inset', (
    tester,
  ) async {
    Future<Rect> pump({required bool safeArea}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(bottom: 48),
            ),
            child: Viewfinder(
              itemCount: 3,
              indicator: ViewfinderPageIndicatorDots(safeArea: safeArea),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);
      return tester.getRect(find.bySemanticsLabel('Page 1 of 3'));
    }

    // 600 viewport − 48 inset − 16 indicator padding.
    final inset = await pump(safeArea: true);
    expect(inset.bottom, lessThanOrEqualTo(600 - 48 - 16 + 0.01));

    final flush = await pump(safeArea: false);
    expect(flush.bottom, greaterThan(600.0 - 48));
  });

  testWidgets('dots indicator exposes a position label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            indicator: const ViewfinderPageIndicatorDots(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.bySemanticsLabel('Page 1 of 3'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // Reduce motion
  // -------------------------------------------------------------------

  testWidgets('reduce-motion: double-tap zoom jumps without animating', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ViewfinderImage(
              image: _memoryImage(),
              controller: controller,
              doubleTapScales: const [1.0, 2.5],
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport));
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    // One frame after the double-tap resolves: already at the target.
    await tester.pump(const Duration(milliseconds: 350));
    expect(controller.scale, closeTo(2.5, 0.001));
  });

  // -------------------------------------------------------------------
  // Per-item doubleTapScales override / empty ladder disables DTD
  // -------------------------------------------------------------------

  testWidgets('per-item doubleTapScales: [] disables double-tap zoom for '
      'that page only', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            doubleTapScales: const [],
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport));
    // Plain double-tap: no zoom.
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(1.0, 0.001));

    // Double-tap-drag: with an empty ladder the DTD recognizer is not
    // registered either, so continuous zoom must not engage.
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    final g = await tester.startGesture(center);
    await tester.pump();
    await g.moveBy(const Offset(0, -100));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(1.0, 0.001));
  });

  testWidgets('Viewfinder: per-item doubleTapScales override reaches the '
      'page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            doubleTapScales: const [1.0, 3.0],
            itemBuilder: (_, _) => ViewfinderItem(
              image: _memoryImage(),
              doubleTapScales: const [1.0, 5.0],
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final image =
        tester.widget(find.byWidgetPredicate((w) => w is ViewfinderImage))
            as ViewfinderImage;
    expect(image.doubleTapScales, const [1.0, 5.0]);
  });

  // -------------------------------------------------------------------
  // Restoration
  // -------------------------------------------------------------------

  testWidgets('restorationId restores the page after state restoration', (
    tester,
  ) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        restorationScopeId: 'app',
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            restorationId: 'gallery',
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    controller.jumpTo(2);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);

    await tester.restartAndRestore();
    await _settleImages(tester);
    expect(
      find.bySemanticsLabel('Photo gallery, 3 of 3'),
      findsOneWidget,
      reason: 'the PageView position should survive restoration',
    );
  });
}
