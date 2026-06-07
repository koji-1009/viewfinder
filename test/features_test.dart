import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewfinder/src/internal/dismissible.dart';
import 'package:viewfinder/src/internal/hero_shuttle.dart';
import 'package:viewfinder/src/internal/zoomable_viewport.dart';
import 'package:viewfinder/viewfinder.dart';

import 'image_support.dart';

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
  setUpAll(prepareTestImage);

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
            image: memoryImage(),
            onLongPress: () => longPressed++,
            onLongPressStart: (d) => startAt = d.localPosition,
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            image: memoryImage(),
            onSecondaryTapUp: (d) => details = d,
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            [memoryImage('a'), memoryImage('b'), memoryImage('c')],
            controller: controller,
            onLongPress: pressed.add,
          ),
        ),
      ),
    );
    await settleImages(tester);

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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(tester.takeAnnouncements().last.message, '写真 3 / 3');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            announcePageChanges: false,
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
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

  testWidgets('mouseWheelBehavior.paging: pager-axis scroll turns pages', (
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
              mouseWheelBehavior: ViewfinderMouseWheelBehavior.paging,
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(120, 0)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendEventToBinding(pointer.scroll(const Offset(-120, 0)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
  });

  testWidgets('mouseWheelBehavior.paging: cross-axis scroll zooms the '
      'current page', (tester) async {
    final controller = ViewfinderController();
    final scaleEvents = <ViewfinderScaleState>[];
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
              onScaleStateChanged: (_, s) => scaleEvents.add(s),
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
    expect(scaleEvents, [ViewfinderScaleState.zoomed]);
  });

  testWidgets('mouseWheelBehavior.paging: a trackpad scroll stream with '
      'momentum turns exactly one page', (tester) async {
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
              mouseWheelBehavior: ViewfinderMouseWheelBehavior.paging,
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    // A swipe plus its momentum tail: many small deltas over ~400 ms,
    // far exceeding the page threshold in total.
    for (var i = 0; i < 50; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(24, 0)));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    // After the stream pauses, the next gesture pages again.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendEventToBinding(pointer.scroll(const Offset(120, 0)));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
  });

  testWidgets('mouseWheelBehavior.paging: a new swipe merged into the '
      'momentum tail pages again without a pause', (tester) async {
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
              mouseWheelBehavior: ViewfinderMouseWheelBehavior.paging,
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(Viewfinder));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    // One continuous stream, no pause: swipe (30,30 → page turn), a
    // decaying momentum tail, then a second deliberate swipe whose
    // magnitude jumps against the decay.
    const deltas = [30, 30, 20, 16, 12, 8, 6, 5, 4, 3, 40, 45, 50];
    for (final d in deltas) {
      await tester.sendEventToBinding(pointer.scroll(Offset(d * 1.0, 0)));
      await tester.pump(const Duration(milliseconds: 8));
    }
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
  });

  testWidgets('vertical pager: a tap followed by a vertical drag swipes '
      'the page instead of double-tap-drag zooming', (tester) async {
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
              pagerAxis: Axis.vertical,
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    final p = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await p.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await p.up();
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
  });

  testWidgets('a tap followed by a horizontal drag swipes the page '
      'instead of double-tap-drag zooming', (tester) async {
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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 80));
    // Within the double-tap window: down → horizontal drag. The DTD
    // recognizer must yield this to the pager.
    final p = await tester.startGesture(center);
    for (var i = 0; i < 8; i++) {
      await p.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await p.up();
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
    final image = memoryImage('hero-shuttle');
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
    await settleImages(tester);

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

  testWidgets('ViewfinderHero.thumbnailFit flies a cross-fit shuttle', (
    tester,
  ) async {
    final image = memoryImage('cross-fit');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Viewfinder.single(
                    image: image,
                    hero: const ViewfinderHero(
                      'cross-fit-test',
                      thumbnailFit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Hero(
                  tag: 'cross-fit-test',
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight
    expect(find.byType(HeroCrossFitShuttle), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Pop flight uses it too and settles cleanly.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HeroCrossFitShuttle), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      );
      await settleImages(tester);
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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
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
              image: memoryImage(),
              controller: controller,
              doubleTapScales: const [1.0, 2.5],
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            image: memoryImage(),
            controller: controller,
            doubleTapScales: const [],
          ),
        ),
      ),
    );
    await settleImages(tester);

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
              image: memoryImage(),
              doubleTapScales: const [1.0, 5.0],
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

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
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);

    controller.jumpTo(2);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);

    await tester.restartAndRestore();
    await settleImages(tester);
    expect(
      find.bySemanticsLabel('Photo gallery, 3 of 3'),
      findsOneWidget,
      reason: 'the PageView position should survive restoration',
    );
  });

  // -------------------------------------------------------------------
  // 1.0.0 regression fixes
  // -------------------------------------------------------------------

  testWidgets('cross-fit shuttle starts the pop flight at the viewer fit', (
    tester,
  ) async {
    final image = memoryImage('pop-fit');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Viewfinder.single(
                    image: image,
                    hero: const ViewfinderHero(
                      'pop-fit-test',
                      thumbnailFit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Hero(
                  tag: 'pop-fit-test',
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20)); // flight start
    // The 1×1 square image in the ~800×600 flight box: contain ≈ 600
    // wide, cover ≈ 800. An inverted lerp would start at cover.
    final rect = tester.widget<Positioned>(
      find.descendant(
        of: find.byType(HeroCrossFitShuttle),
        matching: find.byType(Positioned),
      ),
    );
    expect(rect.width, lessThan(700));
    await tester.pumpAndSettle();
  });

  testWidgets('swapping the zoomed current page\'s provider does not throw', (
    tester,
  ) async {
    var image = memoryImage('swap-a');
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Viewfinder(
                itemCount: 1,
                itemBuilder: (_, _) => ViewfinderItem(image: image),
              );
            },
          ),
        ),
      ),
    );
    await settleImages(tester);

    final center = tester.getCenter(
      find.byWidgetPredicate((w) => w is ViewfinderImage),
    );
    await tester.tapAt(center);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    rebuild(() => image = memoryImage('swap-b'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await settleImages(tester);
  });

  testWidgets('turning loop on at runtime keeps the current page', (
    tester,
  ) async {
    final controller = ViewfinderController();
    final changes = <int>[];
    var loop = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Viewfinder(
                itemCount: 10,
                loop: loop,
                controller: controller,
                onPageChanged: changes.add,
                itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
              );
            },
          ),
        ),
      ),
    );
    await settleImages(tester);
    controller.jumpTo(2);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
    changes.clear();

    rebuild(() => loop = true);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);
    expect(changes, isEmpty);

    // The loop still works from the rebased position.
    controller.animateTo(1);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
  });

  testWidgets('zoomed page re-clamps when maxScale narrows at runtime', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    var maxScale = 8.0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ViewfinderImage(
                image: memoryImage(),
                controller: controller,
                maxScale: maxScale,
              );
            },
          ),
        ),
      ),
    );
    await settleImages(tester);
    controller.animateToScale(4.0);
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(4.0, 0.01));

    rebuild(() => maxScale = 2.0);
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(2.0, 0.01));
  });

  testWidgets(
    'gapless provider swap keeps the main image visible over the thumb',
    (tester) async {
      var image = memoryImage('gapless-a');
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return ViewfinderImage(
                  image: image,
                  thumbImage: memoryImage('gapless-thumb'),
                );
              },
            ),
          ),
        ),
      );
      await settleImages(tester);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );

      rebuild(() => image = memoryImage('gapless-b'));
      await tester.pump();
      // gaplessPlayback keeps painting the previous frame; the fade
      // must not drop to 0 and flash the thumb.
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );
      await settleImages(tester);
    },
  );

  testWidgets('thumbnail strip centers the selected tile despite a leading '
      'padding', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 30,
            controller: controller,
            thumbnails: const ViewfinderThumbnails(
              padding: EdgeInsets.only(left: 40),
              safeArea: false,
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
    controller.jumpTo(15);
    await tester.pumpAndSettle();

    // The keyed tile includes its trailing 4-px spacing; with the
    // visual tile centered, the slot center sits spacing/2 right of
    // the viewport center.
    final center = tester.getCenter(find.byKey(ViewfinderKeys.thumbnail(15)));
    expect(center.dx, closeTo(402.0, 1.0));
  });

  testWidgets('Viewfinder.filterQuality reaches every page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            filterQuality: FilterQuality.high,
            itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
          ),
        ),
      ),
    );
    await settleImages(tester);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.filterQuality, FilterQuality.high);
  });

  testWidgets('jumpToRotation rotates about the viewport center, '
      'preserving scale', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: memoryImage(),
              controller: controller,
              rotateEnabled: true,
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    controller.jumpToRotation(math.pi / 2);
    await tester.pump();
    expect(controller.rotation, closeTo(math.pi / 2, 1e-6));
    expect(controller.scale, closeTo(1.0, 1e-6));
    // The viewport center stays fixed.
    final m = controller.currentTransform.storage;
    expect(m[0] * 200 + m[4] * 200 + m[12], closeTo(200, 1e-6));
    expect(m[1] * 200 + m[5] * 200 + m[13], closeTo(200, 1e-6));
  });

  testWidgets('animateToRotation animates in angle space without scale '
      'wobble', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: memoryImage(),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    controller.animateToRotation(math.pi / 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight
    // A Matrix4Tween would dip toward ~0.71× here; angle-space stays 1.
    expect(controller.scale, closeTo(1.0, 0.001));
    expect(controller.rotation, greaterThan(0.0));
    expect(controller.rotation, lessThan(math.pi / 2));
    await tester.pumpAndSettle();
    expect(controller.rotation, closeTo(math.pi / 2, 1e-3));
  });

  testWidgets('jumpToScale sets the scale instantly', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: memoryImage(),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    controller.jumpToScale(2.0);
    await tester.pump();
    expect(controller.scale, closeTo(2.0, 1e-6));
    // Clamped to maxScale like animateToScale.
    controller.jumpToScale(99.0);
    await tester.pump();
    expect(controller.scale, closeTo(8.0, 1e-6));
  });

  testWidgets('animateToTransform lands exactly on a non-similarity '
      'target matrix', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: memoryImage(),
              controller: controller,
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    // Non-uniform scale: not decomposable as a similarity; the tween
    // must fall back to the entry lerp and still land on the target.
    final target = Matrix4.identity()..scaleByDouble(2.0, 1.0, 1, 1);
    controller.animateToTransform(target);
    await tester.pumpAndSettle();
    final m = controller.currentTransform.storage;
    expect(m[0], closeTo(2.0, 1e-9));
    expect(m[5], closeTo(1.0, 1e-9));
    expect(m[12], closeTo(0.0, 1e-9));
  });

  testWidgets('reset from a rotated state keeps the scale steady', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: memoryImage(),
              controller: controller,
              rotateEnabled: true,
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    controller.jumpToRotation(math.pi / 2);
    await tester.pump();
    controller.reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // mid-flight
    // A Matrix4Tween would dip toward ~0.71× here.
    expect(controller.scale, closeTo(1.0, 0.001));
    await tester.pumpAndSettle();
    expect(controller.rotation, closeTo(0.0, 1e-3));
    expect(controller.scale, closeTo(1.0, 1e-3));
  });

  testWidgets('a pinch with a slight first-finger drift zooms instead of '
      'dragging the dismissible', (tester) async {
    final events = <ViewfinderScaleState>[];
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 2,
              dismiss: ViewfinderDismiss(onDismiss: () => dismissed++),
              onScaleStateChanged: (_, s) => events.add(s),
              itemBuilder: (_, _) => ViewfinderItem(image: memoryImage()),
            ),
          ),
        ),
      ),
    );
    await settleImages(tester);

    // Android-style pinch: the first finger lands and drifts a little
    // before the second finger arrives, then both spread. The dismiss
    // recognizer must not claim the drift.
    final center = tester.getCenter(find.byType(ZoomableViewport).first);
    final p1 = await tester.startGesture(center - const Offset(20, 0));
    await p1.moveBy(const Offset(0, 12)); // below touch slop
    await tester.pump(const Duration(milliseconds: 30));
    final p2 = await tester.startGesture(center + const Offset(20, 0));
    await tester.pump();
    await p1.moveBy(const Offset(-50, -10));
    await p2.moveBy(const Offset(50, 10));
    await tester.pump();
    await p1.up();
    await p2.up();
    await tester.pumpAndSettle();

    expect(events, contains(ViewfinderScaleState.zoomed));
    expect(dismissed, 0);
    // The page was not left translated by a stolen drag.
    final dismissible = tester.widget<Transform>(
      find.descendant(
        of: find.byType(ViewfinderDismissible),
        matching: find.byType(Transform).first,
      ),
    );
    expect(dismissible.transform.getTranslation().y, closeTo(0, 0.5));
  });

  testWidgets('dismiss drag springs back when disabled mid-drag', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ViewfinderDismissible(
              config: ViewfinderDismiss(onDismiss: () {}),
              enabled: enabled,
              child: const ColoredBox(color: Colors.black),
            );
          },
        ),
      ),
    );

    final p = await tester.startGesture(const Offset(400, 300));
    for (var i = 0; i < 4; i++) {
      await p.moveBy(const Offset(0, 30));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Disabling tears down the recognizer without firing onEnd; the
    // widget must spring back on its own.
    rebuild(() => enabled = false);
    await tester.pump();
    await p.up();
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(ViewfinderDismissible),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.getTranslation().y, closeTo(0, 0.5));
  });

  testWidgets('Viewfinder.images forwards onLongPressStart with the index', (
    tester,
  ) async {
    final pressed = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder.images([
            memoryImage(),
          ], onLongPressStart: (i, details) => pressed.add(i)),
        ),
      ),
    );
    await settleImages(tester);
    await tester.longPress(find.byWidgetPredicate((w) => w is ViewfinderImage));
    await tester.pumpAndSettle();
    expect(pressed, [0]);
  });
}
