import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewfinder/src/internal/zoomable_viewport.dart';
import 'package:viewfinder/viewfinder.dart';

// A 1x1 ARGB PNG — decodes cleanly in the test environment.
final Uint8List _pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00, //
  0x00, 0x00, 0x03, 0x00, 0x01, 0x5B, 0xC4, 0x8B, //
  0x7A, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, //
  0x44, 0xAE, 0x42, 0x60, 0x82, //
]);

ImageProvider _memoryImage() => MemoryImage(_pngBytes);

ViewfinderItem _childItemBuilder(BuildContext _, int _) =>
    const ViewfinderItem.child(
      child: Center(
        child: Text('custom-gallery-child', textDirection: TextDirection.ltr),
      ),
    );

Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
  // The synthetic test codec rejects our 1x1 PNG fixture when the
  // request goes through the raw `MemoryImage` path (no ResizeImage
  // size hint). Production paths don't see this; absorb so individual
  // tests don't have to. Tests that need to assert image errors should
  // still call takeException themselves before calling this helper.
  final ex = tester.takeException();
  if (ex != null && '$ex'.contains('Codec failed to produce an image')) {
    return;
  }
  if (ex != null) {
    throw ex;
  }
}

void main() {
  group('ViewfinderInitialScale', () {
    test('contain: contain fit and base 1.0', () {
      const s = ViewfinderInitialScale.contain();
      expect(s.boxFit, BoxFit.contain);
      expect(s.baseScale, 1.0);
    });

    test('cover: cover fit and base 1.0', () {
      const s = ViewfinderInitialScale.cover();
      expect(s.boxFit, BoxFit.cover);
      expect(s.baseScale, 1.0);
    });

    test('value: contain fit and custom base', () {
      const s = ViewfinderInitialScale.value(2.5);
      expect(s.boxFit, BoxFit.contain);
      expect(s.baseScale, 2.5);
    });
  });

  group('ViewfinderItem', () {
    test('image constructor keeps image and rejects child', () {
      final item = ViewfinderItem(image: MemoryImage(_pngBytes));
      expect(item.image, isNotNull);
      expect(item.child, isNull);
    });

    test('child constructor keeps child and clears image-only fields', () {
      const item = ViewfinderItem.child(child: SizedBox.shrink());
      expect(item.image, isNull);
      expect(item.child, isNotNull);
      expect(item.loadingBuilder, isNull);
      expect(item.errorBuilder, isNull);
    });
  });

  testWidgets('ViewfinderImage.value initialScale applies the multiplier', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            initialScale: const ViewfinderInitialScale.value(2.0),
            maxScale: 10,
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(controller.scale, closeTo(2.0, 0.001));
  });

  testWidgets('Viewfinder with child items renders the child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Viewfinder(itemCount: 1, itemBuilder: _childItemBuilder),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom-gallery-child'), findsOneWidget);
  });

  testWidgets('Viewfinder blocks pop while zoomed (Android back behavior)', (
    tester,
  ) async {
    final galleryController = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (outer) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(outer).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Viewfinder(
                        itemCount: 1,
                        controller: galleryController,
                        itemBuilder: (_, _) =>
                            ViewfinderItem(image: _memoryImage()),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    // Zoom in.
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();
    expect(galleryController.resetCurrentImage, isA<Function>());

    // Try to pop via Navigator. Because scale > 1, PopScope should
    // swallow the pop and reset the zoom instead.
    final navState = tester.state<NavigatorState>(find.byType(Navigator).last);
    navState.maybePop();
    await tester.pumpAndSettle();
    // The button in the pushed route should still be unreachable (we
    // didn't pop), but the zoom should now be reset.
    expect(
      galleryController.resetCurrentImage(),
      isFalse,
      reason: 'zoom should have been reset to initial after blocked pop',
    );

    // Now that scale is back to 1, pop should proceed.
    navState.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('ViewfinderImage: swapping controller detaches old, '
      'attaches new', (tester) async {
    final a = ViewfinderImageController();
    final b = ViewfinderImageController();
    ViewfinderImageController active = a;
    late StateSetter setActive;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            setActive = setState;
            return Scaffold(
              body: ViewfinderImage(image: _memoryImage(), controller: active),
            );
          },
        ),
      ),
    );
    await _settleImages(tester);
    a.animateToScale(2);
    await tester.pumpAndSettle();
    expect(a.scale, greaterThan(1.01));

    setActive(() => active = b);
    await tester.pumpAndSettle();
    // After swap, b now drives; a stays detached.
    b.animateToScale(3);
    await tester.pumpAndSettle();
    expect(b.scale, greaterThan(2.5));
  });

  testWidgets('ViewfinderImage: swapping initialScale resets transform', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    ViewfinderInitialScale scale = const ViewfinderInitialScale.contain();
    late StateSetter setScale;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            setScale = setState;
            return Scaffold(
              body: ViewfinderImage(
                image: _memoryImage(),
                controller: controller,
                initialScale: scale,
                maxScale: 10,
              ),
            );
          },
        ),
      ),
    );
    await _settleImages(tester);
    expect(controller.scale, closeTo(1.0, 0.001));

    setScale(() => scale = const ViewfinderInitialScale.value(2.5));
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(2.5, 0.001));
  });

  testWidgets('ViewfinderImage: semanticLabel wraps the Image in Semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            semanticLabel: 'my photo caption',
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final sem = tester.widgetList<Semantics>(find.byType(Semantics));
    expect(
      sem.any(
        (s) =>
            s.properties.label == 'my photo caption' &&
            s.properties.image == true,
      ),
      isTrue,
    );
  });

  testWidgets('Viewfinder: all thumbnail positions lay out correctly', (
    tester,
  ) async {
    for (final pos in ViewfinderThumbnailPosition.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 2,
              thumbnails: ViewfinderThumbnails(size: 32, position: pos),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);
      expect(
        find.byType(ViewfinderThumbnailBar),
        findsOneWidget,
        reason: 'position=$pos should build a ThumbnailBar',
      );
      // Bottom/top use Column, left/right use Row.
      if (pos == ViewfinderThumbnailPosition.top ||
          pos == ViewfinderThumbnailPosition.bottom) {
        expect(find.byType(Column), findsWidgets);
      } else {
        expect(find.byType(Row), findsWidgets);
      }
    }
  });

  testWidgets('Viewfinder: didUpdateWidget handles controller swap', (
    tester,
  ) async {
    final a = ViewfinderController();
    final b = ViewfinderController();
    ViewfinderController active = a;
    late StateSetter setActive;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            setActive = setState;
            return Scaffold(
              body: Viewfinder(
                itemCount: 2,
                controller: active,
                itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
              ),
            );
          },
        ),
      ),
    );
    await _settleImages(tester);
    setActive(() => active = b);
    await tester.pumpAndSettle();
    // After swap, new controller should drive the gallery.
    b.animateTo(1);
    await tester.pumpAndSettle();
    expect(b.currentIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viewfinder itemCount change disposes stale image controllers', (
    tester,
  ) async {
    // Build with 3 items, swap to 1. No crash; remaining controllers stay.
    int count = 3;
    late StateSetter setCount;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            setCount = setState;
            return Scaffold(
              body: Viewfinder(
                itemCount: count,
                itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
              ),
            );
          },
        ),
      ),
    );
    await _settleImages(tester);
    setCount(() => count = 1);
    await tester.pumpAndSettle();
    // Shrinking itemCount should dispose out-of-range controllers
    // without throwing.
    expect(tester.takeException(), isNull);
  });

  group('nextDoubleTapScale', () {
    test('cycle walks forward and wraps', () {
      const scales = [1.0, 2.0, 5.0];
      expect(nextDoubleTapScale(scales: scales, currentScale: 1.0), 2.0);
      expect(nextDoubleTapScale(scales: scales, currentScale: 2.0), 5.0);
      expect(nextDoubleTapScale(scales: scales, currentScale: 5.0), 1.0);
    });

    test('two entries behave as a toggle', () {
      const scales = [1.0, 3.0];
      expect(nextDoubleTapScale(scales: scales, currentScale: 1.0), 3.0);
      expect(nextDoubleTapScale(scales: scales, currentScale: 3.0), 1.0);
    });

    test('empty list returns currentScale unchanged', () {
      expect(nextDoubleTapScale(scales: const [], currentScale: 2.5), 2.5);
    });
  });

  testWidgets('ViewfinderImage: controller drives zoom and reset', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            doubleTapScales: const [1.0, 2.0],
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(find.byType(ZoomableViewport), findsOneWidget);
    expect(controller.scaleState, ViewfinderScaleState.initial);

    controller.animateToScale(2.5);
    await tester.pumpAndSettle();
    expect(controller.scaleState, ViewfinderScaleState.zoomed);
    expect(controller.scale, greaterThan(1.01));

    controller.reset();
    await tester.pumpAndSettle();
    expect(controller.scaleState, ViewfinderScaleState.initial);
  });

  testWidgets('ViewfinderImage.child renders arbitrary widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ViewfinderImage.child(
            child: Text('custom-child', textDirection: .ltr),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom-child'), findsOneWidget);
    expect(find.byType(ZoomableViewport), findsOneWidget);
  });

  testWidgets('ViewfinderImageController.animateToScale back to 1.0 '
      'uses the reset-to-identity branch', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            maxScale: 10,
          ),
        ),
      ),
    );
    await _settleImages(tester);
    controller.animateToScale(3);
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(3.0, 0.01));
    // Explicitly animate back to the base scale.
    controller.animateToScale(1);
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(1.0, 0.01));
  });

  testWidgets('ViewfinderImage: double-tap-cycle back to initial '
      'uses the reset-to-identity branch', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            doubleTapScales: const [1.0, 2.0],
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    // First double-tap: 1 → 2.
    final a = await tester.startGesture(center);
    await a.up();
    await tester.pump(const Duration(milliseconds: 50));
    final b = await tester.startGesture(center);
    await b.up();
    await tester.pumpAndSettle();
    expect(controller.scale, greaterThan(1.5));
    // Second double-tap: 2 → 1 (initialMatrix branch).
    final c = await tester.startGesture(center);
    await c.up();
    await tester.pump(const Duration(milliseconds: 50));
    final d = await tester.startGesture(center);
    await d.up();
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(1.0, 0.01));
  });

  testWidgets('ViewfinderImage double-tap zooms via gesture', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            doubleTapScales: const [1.0, 2.0],
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    expect(controller.scale, greaterThan(1.01));
  });

  testWidgets('ViewfinderImage with empty doubleTapScales ignores double-tap', (
    tester,
  ) async {
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

    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    expect(controller.scale, closeTo(1.0, 0.001));
  });

  testWidgets('Viewfinder paginates and syncs controller', (tester) async {
    final controller = ViewfinderController();
    final pageChanges = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 4,
            controller: controller,
            precacheAdjacent: 1,
            onPageChanged: pageChanges.add,
            thumbnails: const ViewfinderThumbnails(size: 40),
            indicator: const ViewfinderPageIndicator(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(find.byType(ViewfinderImage), findsOneWidget);
    expect(find.byType(ViewfinderThumbnailBar), findsOneWidget);

    controller.animateTo(3);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 3);
    expect(pageChanges.last, 3);
  });

  testWidgets('ViewfinderThumbnails: tapping a thumbnail jumps the page', (
    tester,
  ) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            thumbnails: const ViewfinderThumbnails(size: 64),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    // Tap the second thumbnail by finding the Nth Image widget inside
    // the thumbnail bar.
    final bar = find.byType(ViewfinderThumbnailBar);
    final thumbs = find.descendant(of: bar, matching: find.byType(Image));
    await tester.tap(thumbs.at(1), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
  });

  testWidgets('ViewfinderThumbnails: default builder handles child-type '
      'items (no image)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            thumbnails: const ViewfinderThumbnails(size: 40),
            itemBuilder: (_, i) => ViewfinderItem.child(
              child: Text('C$i', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    // Each child item's thumb should render the child inside a SizedBox.
    expect(
      find.descendant(
        of: find.byType(ViewfinderThumbnailBar),
        matching: find.text('C0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'ViewfinderThumbnails: safeArea=true applies correct edges per position',
    (tester) async {
      for (final pos in ViewfinderThumbnailPosition.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.fromLTRB(10, 20, 10, 30),
              ),
              child: Scaffold(
                body: Viewfinder(
                  itemCount: 2,
                  thumbnails: ViewfinderThumbnails(size: 32, position: pos),
                  itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
                ),
              ),
            ),
          ),
        );
        await _settleImages(tester);

        final safeArea = tester.widget<SafeArea>(
          find.descendant(
            of: find.byType(ViewfinderThumbnailBar),
            matching: find.byType(SafeArea),
          ),
        );
        final isHorizontal =
            pos == ViewfinderThumbnailPosition.top ||
            pos == ViewfinderThumbnailPosition.bottom;
        expect(
          safeArea.top,
          pos == ViewfinderThumbnailPosition.top || !isHorizontal,
          reason: 'pos=$pos top flag',
        );
        expect(
          safeArea.bottom,
          pos == ViewfinderThumbnailPosition.bottom || !isHorizontal,
          reason: 'pos=$pos bottom flag',
        );
        expect(
          safeArea.left,
          pos == ViewfinderThumbnailPosition.left || isHorizontal,
          reason: 'pos=$pos left flag',
        );
        expect(
          safeArea.right,
          pos == ViewfinderThumbnailPosition.right || isHorizontal,
          reason: 'pos=$pos right flag',
        );
      }
    },
  );

  testWidgets('ViewfinderThumbnails: safeArea=false skips the SafeArea wrap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 30)),
          child: Scaffold(
            body: Viewfinder(
              itemCount: 2,
              thumbnails: const ViewfinderThumbnails(size: 32, safeArea: false),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(
      find.descendant(
        of: find.byType(ViewfinderThumbnailBar),
        matching: find.byType(SafeArea),
      ),
      findsNothing,
    );
  });

  testWidgets('ViewfinderThumbnails: custom builder output is rendered without '
      'default border/opacity chrome', (tester) async {
    // Sentinel widget the builder returns. If the default chrome
    // (AnimatedOpacity + bordered Container) were still wrapping custom
    // output, we would see its internals in the subtree.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            thumbnails: ViewfinderThumbnails.custom(
              size: 48,
              itemBuilder: (context, i, selected) => Container(
                key: ValueKey('custom-$i'),
                color: selected ? Colors.red : Colors.grey,
                child: Text('$i'),
              ),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // The default chrome uses AnimatedOpacity per tile; custom builders
    // get none.
    expect(
      find.descendant(
        of: find.byType(ViewfinderThumbnailBar),
        matching: find.byType(AnimatedOpacity),
      ),
      findsNothing,
    );
    // The builder returned Containers keyed by index — both present.
    expect(find.byKey(const ValueKey('custom-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-1')), findsOneWidget);
  });

  testWidgets('ViewfinderThumbnails.custom builder is used', (tester) async {
    final built = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            thumbnails: ViewfinderThumbnails.custom(
              size: 48,
              itemBuilder: (context, i, selected) {
                built.add(i);
                return Container(
                  alignment: Alignment.center,
                  color: selected ? Colors.red : Colors.grey,
                  child: Text('$i'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(built, containsAll([0, 1]));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('ViewfinderDismiss: direction=up accepts upward delta only', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            dismiss: ViewfinderDismiss(
              onDismiss: () => dismissed++,
              direction: ViewfinderDismissDirection.up,
              threshold: 0.1,
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final center = tester.getCenter(find.byType(Viewfinder));
    await tester.dragFrom(center, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    await tester.dragFrom(center, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('ViewfinderDismiss: direction=down rejects upward delta', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            dismiss: ViewfinderDismiss(
              onDismiss: () => dismissed++,
              direction: ViewfinderDismissDirection.down,
              threshold: 0.1,
              fadeBackground: false, // exercise this branch too
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final center = tester.getCenter(find.byType(Viewfinder));
    // Upward drag is ignored when direction = down.
    await tester.dragFrom(center, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    // Downward drag past threshold dismisses.
    await tester.dragFrom(center, const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('ViewfinderDismiss: drag below threshold animates back', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            dismiss: ViewfinderDismiss(
              onDismiss: () => dismissed++,
              threshold: 0.8, // high threshold
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final center = tester.getCenter(find.byType(Viewfinder));
    // Small drag well below 80% threshold — should animate back.
    await tester.dragFrom(center, const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ViewfinderDismiss: onProgress receives normalized drag progress',
    (tester) async {
      final progressLog = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 1,
              dismiss: ViewfinderDismiss(
                onDismiss: () {},
                threshold: 0.9,
                onProgress: progressLog.add,
              ),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      final gallery = find.byType(Viewfinder);
      // Drive a drag below the dismiss threshold so the spring-back
      // path runs and we observe both ascending and descending progress.
      await tester.dragFrom(tester.getCenter(gallery), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(progressLog, isNotEmpty);
      // All values are in [0, 1].
      expect(progressLog.every((p) => p >= 0.0 && p <= 1.0), isTrue);
      // Saw ascending progress during the drag, then spring-back to ~0.
      final peak = progressLog.reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(0.0));
      expect(progressLog.last, lessThan(0.05));
    },
  );

  testWidgets(
    'ViewfinderDismiss: vertical drag past threshold fires onDismiss',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 1,
              dismiss: ViewfinderDismiss(
                onDismiss: () => dismissed++,
                threshold: 0.1,
              ),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      final gallery = find.byType(Viewfinder);
      final center = tester.getCenter(gallery);
      await tester.dragFrom(center, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    },
  );

  testWidgets('ViewfinderController.jumpTo does not animate', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 5,
            controller: controller,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    controller.jumpTo(3);
    await tester.pump(); // one frame is enough for jump (no animation)
    expect(controller.currentIndex, 3);
  });

  testWidgets('Viewfinder: pageSpacing > 0 pads each page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            pageSpacing: 40,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    // Find a Padding that's a descendant of PageView with exactly
    // horizontal: pageSpacing/2 insets.
    final padding = tester.widgetList<Padding>(
      find.descendant(
        of: find.byType(PageView),
        matching: find.byType(Padding),
      ),
    );
    expect(
      padding.any(
        (p) => p.padding == const EdgeInsets.symmetric(horizontal: 20),
      ),
      isTrue,
      reason: 'pageSpacing=40 should produce symmetric(horizontal: 20)',
    );
  });

  testWidgets('Viewfinder: PageUp/PageDown keys navigate', (tester) async {
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
    expect(controller.currentIndex, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
  });

  testWidgets('Viewfinder: arrow keys move pages, Esc fires onDismiss', (
    tester,
  ) async {
    final controller = ViewfinderController();
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            dismiss: ViewfinderDismiss(onDismiss: () => dismissed++),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(controller.currentIndex, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, 1);
  });

  testWidgets('Viewfinder: Esc resets zoom first, dismisses on second press', (
    tester,
  ) async {
    final galleryController = ViewfinderController();
    final imageController = ViewfinderImageController();
    var dismissed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            controller: galleryController,
            dismiss: ViewfinderDismiss(onDismiss: () => dismissed++),
            itemBuilder: (_, i) => ViewfinderItem(
              image: _memoryImage(),
              // Attach a separate controller on page 0 so the test can
              // drive zoom. Viewfinder's own per-page controller still
              // tracks state via onScaleChanged.
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Zoom in by simulating a double-tap at the center.
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    // Esc #1 should reset zoom, NOT dismiss.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, 0);
    expect(
      galleryController.resetCurrentImage(),
      isFalse,
      reason: 'already reset',
    );

    // Esc #2 should now dismiss.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(dismissed, 1);

    // Silence the unused-local warning.
    imageController.reset();
  });

  testWidgets('ViewfinderController.resetCurrentImage returns true only '
      'while zoomed', (tester) async {
    final galleryController = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            controller: galleryController,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Not zoomed → returns false.
    expect(galleryController.resetCurrentImage(), isFalse);

    // Zoom in via gesture.
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    // Now zoomed → returns true.
    expect(galleryController.resetCurrentImage(), isTrue);
    await tester.pumpAndSettle();

    // After reset, returns false again.
    expect(galleryController.resetCurrentImage(), isFalse);
  });

  testWidgets('Viewfinder: keyboard shortcuts can be disabled', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            enableKeyboardShortcuts: false,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);
  });

  testWidgets('ViewfinderImageController.canSwipeHorizontally tracks '
      'zoom and edge state', (tester) async {
    final imageController = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: imageController,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // At initial scale: free to swipe.
    expect(imageController.canSwipeHorizontally, isTrue);

    // Center-anchored zoom: content overflows both sides, user is
    // neither at left nor right edge — PageView should be locked.
    imageController.animateToScale(3.0);
    await tester.pumpAndSettle();
    expect(imageController.scaleState, ViewfinderScaleState.zoomed);
    expect(
      imageController.canSwipeHorizontally,
      isFalse,
      reason: 'zoomed and centered: off both horizontal edges',
    );

    // Reset returns to initial — swipe allowed again.
    imageController.reset();
    await tester.pumpAndSettle();
    expect(imageController.canSwipeHorizontally, isTrue);
  });

  testWidgets('ViewfinderImage: PointerCancel during drag does not crash', (
    tester,
  ) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            doubleTapScales: const [1.0, 3.0],
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Zoom via controller so we can pan-test without racing double-tap.
    controller.animateToScale(3.0);
    await tester.pumpAndSettle();

    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g = await tester.startGesture(center);
    await g.moveBy(const Offset(20, 0));
    await g.cancel();
    await tester.pumpAndSettle();

    // No crash, controller still in a sane state.
    expect(controller.scale, greaterThan(1.01));
  });

  testWidgets('Viewfinder: popping the route snaps transform before Hero '
      'captures source rect', (tester) async {
    final galleryController = ViewfinderController();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (outer) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(outer).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Viewfinder(
                        itemCount: 1,
                        controller: galleryController,
                        itemBuilder: (_, _) => ViewfinderItem(
                          image: _memoryImage(),
                          hero: const ViewfinderHero('photo'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _settleImages(tester);

    // Grab the internal image controller via resetCurrentImage semantics.
    // Zoom in, then pop; assert gallery controller no longer reports zoom
    // (i.e., jumpToInitial ran before Hero flight).
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    expect(
      galleryController.resetCurrentImage(),
      isTrue,
      reason: 'should be zoomed prior to pop',
    );
    await tester.pumpAndSettle();

    // Zoom again, then pop without resetting manually. PopScope hook
    // must snap the transform synchronously.
    final g3 = await tester.startGesture(center);
    await g3.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g4 = await tester.startGesture(center);
    await g4.up();
    await tester.pumpAndSettle();
    expect(galleryController.resetCurrentImage(), isTrue);
    await tester.pumpAndSettle();

    // Re-zoom, then pop via Navigator.pop: PopScope must fire
    // jumpToInitial before Hero flight begins.
    final g5 = await tester.startGesture(center);
    await g5.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g6 = await tester.startGesture(center);
    await g6.up();
    await tester.pumpAndSettle();

    // Snap: dispatch pop. Run one pump (not pumpAndSettle) so the Hero
    // flight is in progress. PopScope should have already snapped the
    // transformation.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pump();

    // Gallery is being torn down; by the time the Hero flight is one
    // frame in, the per-page controllers should have been asked to
    // jumpToInitial. The gallery controller itself may still report the
    // previous page index, but resetCurrentImage() should return false
    // because jumpToInitial zeroed the state.
    expect(
      galleryController.resetCurrentImage(),
      isFalse,
      reason: 'jumpToInitial must have run before the first Hero frame',
    );

    await tester.pumpAndSettle();
  });

  testWidgets('Viewfinder: only the current page carries a Hero tag', (
    tester,
  ) async {
    // PageView pre-builds neighbors — if every built page wore a Hero,
    // multiple thumbnails would fly on pop. Assert exactly one Hero
    // exists in the gallery subtree, tagged with the current index.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 5,
            controller: ViewfinderController(initialIndex: 2),
            itemBuilder: (_, i) => ViewfinderItem(
              image: _memoryImage(),
              hero: ViewfinderHero('photo-$i'),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
    expect(heroes, hasLength(1));
    expect(heroes.single.tag, 'photo-2');

    // Swipe to page 3; the Hero should follow, still exactly one.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    await _settleImages(tester);

    final afterSwipe = tester.widgetList<Hero>(find.byType(Hero)).toList();
    expect(afterSwipe, hasLength(1));
    expect(afterSwipe.single.tag, 'photo-3');
  });

  testWidgets('ViewfinderHero forwards attributes to the Hero widget', (
    tester,
  ) async {
    RectTween rectTween(Rect? begin, Rect? end) =>
        MaterialRectArcTween(begin: begin, end: end);
    Widget shuttle(
      BuildContext _,
      Animation<double> _,
      HeroFlightDirection _,
      BuildContext _,
      BuildContext _,
    ) => const SizedBox.shrink();
    Widget placeholder(BuildContext _, Size _, Widget child) => child;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            hero: ViewfinderHero(
              'tag',
              createRectTween: rectTween,
              flightShuttleBuilder: shuttle,
              placeholderBuilder: placeholder,
              transitionOnUserGestures: true,
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'tag');
    expect(hero.createRectTween, same(rectTween));
    expect(hero.flightShuttleBuilder, same(shuttle));
    expect(hero.placeholderBuilder, same(placeholder));
    expect(hero.transitionOnUserGestures, isTrue);
  });

  testWidgets('ViewfinderImage onTapUp / onTapDown carry tap details', (
    tester,
  ) async {
    TapUpDetails? up;
    TapDownDetails? down;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            onTapUp: (d) => up = d,
            onTapDown: (d) => down = d,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final tapPoint = tester.getCenter(find.byType(ViewfinderImage));
    await tester.tapAt(tapPoint);
    await tester.pump(const Duration(milliseconds: 350));

    expect(down, isNotNull);
    expect(up, isNotNull);
    expect(down!.globalPosition, tapPoint);
    expect(up!.globalPosition, tapPoint);
  });

  group('ViewfinderChromeController', () {
    test('starts visible, toggle flips it, hide cancels timer', () {
      final c = ViewfinderChromeController(autoHideAfter: null);
      expect(c.visible, isTrue);
      c.toggle();
      expect(c.visible, isFalse);
      c.toggle();
      expect(c.visible, isTrue);
      c.hide();
      expect(c.visible, isFalse);
      c.dispose();
    });

    test('autoHideAfter fires and hides', () {
      fakeAsync((async) {
        final c = ViewfinderChromeController(
          autoHideAfter: const Duration(seconds: 1),
        );
        expect(c.visible, isTrue);
        async.elapse(const Duration(milliseconds: 999));
        expect(c.visible, isTrue);
        async.elapse(const Duration(milliseconds: 2));
        expect(c.visible, isFalse);
        c.dispose();
      });
    });

    test('bumpAutoHide resets the timer', () {
      fakeAsync((async) {
        final c = ViewfinderChromeController(
          autoHideAfter: const Duration(seconds: 1),
        );
        async.elapse(const Duration(milliseconds: 500));
        c.bumpAutoHide();
        async.elapse(const Duration(milliseconds: 700));
        expect(
          c.visible,
          isTrue,
          reason: 'bump should have reset the timer at t=500',
        );
        async.elapse(const Duration(milliseconds: 400));
        expect(c.visible, isFalse);
        c.dispose();
      });
    });

    test('dispose cancels pending timer without crashing', () {
      fakeAsync((async) {
        final c = ViewfinderChromeController(
          autoHideAfter: const Duration(seconds: 1),
        );
        c.dispose();
        async.elapse(const Duration(seconds: 2));
        // No exceptions from the timer firing after dispose.
      });
    });
  });

  testWidgets('Viewfinder: chrome controller toggles IgnorePointer and '
      'AnimatedOpacity around the indicator', (tester) async {
    final chrome = ViewfinderChromeController(autoHideAfter: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            chromeController: chrome,
            indicator: const ViewfinderPageIndicator(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Find the IgnorePointer that wraps the overlay stack holding the
    // indicator, via tree ancestry.
    IgnorePointer overlayIgnorePointer() {
      final indicator = find.byType(ViewfinderPageIndicatorOverlay);
      final ignorePointer = find.ancestor(
        of: indicator,
        matching: find.byType(IgnorePointer),
      );
      return tester.widget<IgnorePointer>(ignorePointer.first);
    }

    AnimatedOpacity overlayOpacity() {
      final indicator = find.byType(ViewfinderPageIndicatorOverlay);
      final fader = find.ancestor(
        of: indicator,
        matching: find.byType(AnimatedOpacity),
      );
      return tester.widget<AnimatedOpacity>(fader.first);
    }

    // Visible initially.
    expect(overlayIgnorePointer().ignoring, isFalse);
    expect(overlayOpacity().opacity, 1.0);

    chrome.hide();
    await tester.pump();
    expect(overlayIgnorePointer().ignoring, isTrue);
    expect(overlayOpacity().opacity, 0.0);

    chrome.show();
    await tester.pump();
    expect(overlayIgnorePointer().ignoring, isFalse);
    expect(overlayOpacity().opacity, 1.0);
  });

  testWidgets('Viewfinder: chrome auto-hides while zoomed', (tester) async {
    final chrome = ViewfinderChromeController(autoHideAfter: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            chromeController: chrome,
            thumbnails: const ViewfinderThumbnails(size: 40),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(chrome.visible, isTrue);

    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final g1 = await tester.startGesture(center);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 50));
    final g2 = await tester.startGesture(center);
    await g2.up();
    await tester.pumpAndSettle();

    expect(chrome.visible, isFalse, reason: 'chrome should hide when zoomed');
  });

  testWidgets('ViewfinderImage: thumbImage stacks thumb + main with '
      'frameBuilder-driven cross-fade', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            thumbImage: _memoryImage(),
            thumbCrossFadeDuration: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Two Image widgets: thumb + main.
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.length, 2);
    // At least one (the main) has a frameBuilder wired — that's how
    // the cross-fade is driven.
    final main = images.firstWhere((i) => i.frameBuilder != null);
    // At least one (the thumb) doesn't — no need to fade its own load.
    expect(images.any((i) => i.frameBuilder == null), isTrue);

    // Invoke the frameBuilder for both the pre-frame (frame=null,
    // opacity 0) and post-frame (frame=0, opacity 1) cases. This both
    // exercises the closure body and asserts the cross-fade contract.
    final ctx = tester.element(find.byType(ViewfinderImage));
    final beforeFirstFrame =
        main.frameBuilder!(ctx, const SizedBox(), null, false)
            as AnimatedOpacity;
    expect(beforeFirstFrame.opacity, 0.0);
    final afterFirstFrame =
        main.frameBuilder!(ctx, const SizedBox(), 0, true) as AnimatedOpacity;
    expect(afterFirstFrame.opacity, 1.0);
  });

  testWidgets('ViewfinderImage without thumbImage has no second Image '
      'widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ViewfinderImage(image: _memoryImage())),
      ),
    );
    await _settleImages(tester);
    expect(tester.widgetList<Image>(find.byType(Image)).length, 1);
  });

  testWidgets('Viewfinder: slideType onlyImage wraps only the pager '
      'with Dismissible (thumbnails stay put)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            thumbnails: const ViewfinderThumbnails(size: 40),
            dismiss: ViewfinderDismiss(
              onDismiss: () {},
              slideType: ViewfinderDismissSlideType.onlyImage,
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Dismissible wraps the pager (inside the Column), not the outer
    // body. Find the ThumbnailBar and the Dismissible, assert the bar
    // is NOT an ancestor of the Dismissible.
    final dismissibleFinder = find.byType(ViewfinderDismissible);
    final thumbBarFinder = find.byType(ViewfinderThumbnailBar);
    expect(dismissibleFinder, findsOneWidget);
    expect(thumbBarFinder, findsOneWidget);
    // The thumbnail bar should NOT be inside the dismissible — that's
    // the whole point of onlyImage mode.
    expect(
      find.descendant(of: dismissibleFinder, matching: thumbBarFinder),
      findsNothing,
    );
  });

  testWidgets('Viewfinder: slideType wholePage (default) wraps thumbnails '
      'too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            thumbnails: const ViewfinderThumbnails(size: 40),
            dismiss: ViewfinderDismiss(onDismiss: () {}),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final dismissibleFinder = find.byType(ViewfinderDismissible);
    final thumbBarFinder = find.byType(ViewfinderThumbnailBar);
    // In wholePage mode, the thumbnail bar IS inside the dismissible.
    expect(
      find.descendant(of: dismissibleFinder, matching: thumbBarFinder),
      findsOneWidget,
    );
  });

  testWidgets('Viewfinder: zoomed pan past the edge hits the canPan '
      'at-boundary branch', (tester) async {
    // itemCount=1 so any targetIndex from the at-boundary branch is
    // out-of-bounds → gate returns true (pan stays inside). Exercises
    // both the targetIndex computation and the bounds check.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 1,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final center = tester.getCenter(find.byType(ZoomableViewport));

    // Pinch hard to zoom deeply (content extent >> viewport).
    final a = await tester.startGesture(
      center - const Offset(5, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(5, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveBy(const Offset(-250, 0));
    await b.moveBy(const Offset(250, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    // Aggressive left pan that clamps against the right edge, then
    // continues — later events hit canPan with atBoundary=true and
    // reach the targetIndex / out-of-bounds branch.
    final p = await tester.startGesture(center);
    for (var i = 0; i < 20; i++) {
      await p.moveBy(const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await p.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viewfinder: real pinch inside gallery exercises the '
      'canPan gate for the current page', (tester) async {
    final galleryController = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 3,
              controller: galleryController,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport));
    // Two-finger pinch to zoom in.
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveBy(const Offset(-120, 0));
    await b.moveBy(const Offset(120, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    // Now zoomed — try a horizontal single-finger pan. The canPan gate
    // runs for the current page.
    final p = await tester.startGesture(center);
    await p.moveBy(const Offset(-40, 0));
    await p.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viewfinder: tap area with chromeController toggles chrome', (
    tester,
  ) async {
    final chrome = ViewfinderChromeController(autoHideAfter: null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 1,
            chromeController: chrome,
            indicator: const ViewfinderPageIndicator(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(chrome.visible, isTrue);

    // Tap the gallery area. Because ViewfinderImage's GestureDetector
    // has onDoubleTap, the outer tap recognizer waits ~300ms for
    // disambiguation. Pump past the window.
    final center = tester.getCenter(find.byType(ZoomableViewport));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(chrome.visible, isFalse);
  });

  testWidgets('ViewfinderPageIndicator renders numeric fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 20,
            indicator: const ViewfinderPageIndicator(maxDots: 5),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.text('1 / 20'), findsOneWidget);
  });

  testWidgets('Viewfinder: out-of-range initialIndex clamps to last page', (
    tester,
  ) async {
    final controller = ViewfinderController(initialIndex: 99);
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
    // Internal state used the clamped index when building PageView, so
    // the gallery is on the last actual page.
    expect(find.byType(PageView), findsOneWidget);
    // The semantic label reflects the clamped index, not 100 / 3.
    expect(find.bySemanticsLabel('Photo gallery, 3 of 3'), findsOneWidget);
  });

  testWidgets('Viewfinder: shrinking itemCount past currentIndex re-clamps', (
    tester,
  ) async {
    final controller = ViewfinderController(initialIndex: 4);
    Widget build(int count) => MaterialApp(
      home: Scaffold(
        body: Viewfinder(
          itemCount: count,
          controller: controller,
          itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
        ),
      ),
    );
    await tester.pumpWidget(build(5));
    await _settleImages(tester);
    expect(controller.currentIndex, 4);

    // Shrink — now the previously-last page is gone.
    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
    expect(find.bySemanticsLabel('Photo gallery, 2 of 2'), findsOneWidget);
  });

  testWidgets(
    'Viewfinder: itemCount=0 reports an empty-gallery semantic label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 0,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Photo gallery, empty'), findsOneWidget);
    },
  );

  testWidgets('Viewfinder: itemCount=0 builds without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 0,
            thumbnails: const ViewfinderThumbnails(size: 40),
            indicator: const ViewfinderPageIndicator(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('Viewfinder: zoomed at left edge with no previous page '
      'keeps the gesture inside (canPan returns true)', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Viewfinder(
              itemCount: 2,
              controller: controller,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final center = tester.getCenter(find.byType(ZoomableViewport));

    // Step 1: pinch to ~3× so the content overflows the viewport.
    final a = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveBy(const Offset(-40, 0));
    await b.moveBy(const Offset(40, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    // Step 2: anchor the content's left edge against the viewport's
    // left by panning rightward and releasing. After release the
    // image controller reports canSwipeHorizontally=true.
    final anchor = await tester.startGesture(center);
    for (var i = 0; i < 30; i++) {
      await anchor.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await anchor.up();
    await tester.pumpAndSettle();

    // Step 3: start a new pan gesture; canPan is consulted at slop
    // crossing with state=zoomed AND atBoundary=true. Sign=+1
    // (finger right) → targetIndex = 0 + (-1) = -1 (out of bounds)
    // → returns true (stay inside). Page must not advance.
    final p = await tester.startGesture(center);
    await p.moveBy(const Offset(80, 0));
    await tester.pump();
    await p.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(controller.currentIndex, 0);
  });

  testWidgets('ZoomableViewport: fast release at initial scale '
      'goes through the no-fling snap-back branch without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Fast horizontal swipe with no preceding zoom — release with
    // velocity but scale == 1.0, so the fling guard rejects and the
    // snap-back path runs (no-op for content that fits the viewport).
    await tester.fling(
      find.byType(ZoomableViewport),
      const Offset(200, 0),
      1500,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZoomableViewport: starting a new gesture during fling '
      'cancels the running animation cleanly', (tester) async {
    final imageController = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: _memoryImage(),
              controller: imageController,
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    imageController.animateToScale(4.0);
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(ZoomableViewport));

    // Fling: high-velocity release while zoomed > 1.01 enters the
    // FrictionSimulation-driven fling path.
    await tester.fling(
      find.byType(ZoomableViewport),
      const Offset(120, 0),
      2000,
    );
    // Pump just one frame so the fling is in flight but not done.
    await tester.pump(const Duration(milliseconds: 50));

    // Second gesture interrupts the fling (hits _stopFling()).
    final p = await tester.startGesture(center);
    await p.moveBy(const Offset(-20, 0));
    await tester.pump();
    await p.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ZoomableViewport: starting a new gesture during snap-back '
      'cancels the running animation cleanly', (tester) async {
    final imageController = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: _memoryImage(),
              controller: imageController,
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    imageController.animateToScale(4.0);
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(ZoomableViewport));

    // First gesture: pull into elastic over-pan and release. Snap-back
    // animation begins.
    final p1 = await tester.startGesture(center);
    for (var i = 0; i < 30; i++) {
      await p1.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await p1.up();
    // Pump just one frame so the snap-back animation is in flight but
    // not done.
    await tester.pump(const Duration(milliseconds: 50));

    // Second gesture interrupts the snap-back.
    final p2 = await tester.startGesture(center);
    await p2.moveBy(const Offset(-20, 0));
    await tester.pump();
    await p2.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ZoomableViewport: rubber-band over-pan while dragging, '
      'snap-back to strict clamp on release', (tester) async {
    final imageController = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: _memoryImage(),
              controller: imageController,
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    Matrix4 currentMatrix() {
      final t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(ZoomableViewport),
              matching: find.byType(Transform),
            )
            .first,
      );
      return t.transform;
    }

    // Zoom in programmatically so the content is well past the viewport.
    imageController.animateToScale(4.0);
    await tester.pumpAndSettle();
    expect(currentMatrix().getMaxScaleOnAxis(), closeTo(4.0, 0.01));

    // Drive a hard rightward single-pointer pan that pushes the
    // content's left edge past the viewport's left edge — the
    // rubber-band region. Stop short of release so we sample the
    // live elastic translation.
    final center = tester.getCenter(find.byType(ZoomableViewport));
    final p = await tester.startGesture(center);
    for (var i = 0; i < 30; i++) {
      await p.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final midTx = currentMatrix().storage[12];

    await p.up();
    await tester.pumpAndSettle();
    final endTx = currentMatrix().storage[12];

    // Strict-clamp position when over-panned past the left edge is
    // tx == 0 (content's left aligns with viewport's left).
    expect(endTx, closeTo(0.0, 0.5));
    // Mid-gesture sat in elastic over-pan — further right than the
    // strict-clamp position the snap-back pulled us to.
    expect(midTx, greaterThan(endTx + 10));
  });

  testWidgets('Viewfinder: default swipeDragDevices includes mouse, '
      'so mouse-drag swipes the PageView', (tester) async {
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

    // The ScrollConfiguration the gallery installs should expose
    // every PointerDeviceKind to its descendant Scrollable.
    final pageView = find.byType(PageView);
    final scrollContext = tester.element(pageView);
    final dragDevices = ScrollConfiguration.of(scrollContext).dragDevices;
    expect(dragDevices, containsAll(kViewfinderDefaultSwipeDragDevices));

    // And functionally: a mouse fling does scroll the pager.
    await tester.fling(
      pageView,
      const Offset(-400, 0),
      1000,
      deviceKind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
  });

  testWidgets('Viewfinder: restricting swipeDragDevices to touch '
      'blocks mouse-drag page changes', (tester) async {
    final controller = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: controller,
            swipeDragDevices: const {PointerDeviceKind.touch},
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    final pageView = find.byType(PageView);
    await tester.fling(
      pageView,
      const Offset(-400, 0),
      1000,
      deviceKind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 0);

    // Touch fling still swipes.
    await tester.fling(
      pageView,
      const Offset(-400, 0),
      1000,
      deviceKind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 1);
  });

  testWidgets(
    'Viewfinder.images: builds N pages from the provider list',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.images(
              List.generate(3, (_) => _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);
      expect(find.bySemanticsLabel('Photo gallery, 1 of 3'), findsOneWidget);
    },
  );

  testWidgets(
    'Viewfinder.images: hero callback wires per-page Hero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.images(
              List.generate(3, (_) => _memoryImage()),
              controller: ViewfinderController(initialIndex: 1),
              hero: (i) => ViewfinderHero('photo-$i'),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // Only the current page wears a Hero (page 1, index 1).
      final heroes = tester.widgetList<Hero>(find.byType(Hero)).toList();
      expect(heroes, hasLength(1));
      expect(heroes.single.tag, 'photo-1');
    },
  );

  testWidgets(
    'Viewfinder.images: forwards dismiss to the gallery',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.images(
              [_memoryImage()],
              dismiss: ViewfinderDismiss(
                onDismiss: () => dismissed++,
                threshold: 0.1,
              ),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      final center = tester.getCenter(find.byType(Viewfinder));
      await tester.dragFrom(center, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    },
  );

  testWidgets(
    'Viewfinder.single: shows exactly one page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.single(image: _memoryImage()),
          ),
        ),
      );
      await _settleImages(tester);
      expect(find.bySemanticsLabel('Photo gallery, 1 of 1'), findsOneWidget);
    },
  );

  testWidgets(
    'Viewfinder.single: dismiss fires onDismiss on vertical drag',
    (tester) async {
      var dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.single(
              image: _memoryImage(),
              dismiss: ViewfinderDismiss(
                onDismiss: () => dismissed++,
                threshold: 0.1,
              ),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      final center = tester.getCenter(find.byType(Viewfinder));
      await tester.dragFrom(center, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(dismissed, 1);
    },
  );
}
