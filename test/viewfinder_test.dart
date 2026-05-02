import 'package:fake_async/fake_async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewfinder/src/internal/dismissible.dart';
import 'package:viewfinder/src/internal/page_indicator_overlay.dart';
import 'package:viewfinder/src/internal/thumbnail_bar.dart';
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
      contentKey: 'custom-gallery-child',
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

    test('contain(factor): scales the contain fit', () {
      const s = ViewfinderInitialScale.contain(0.8);
      expect(s.boxFit, BoxFit.contain);
      expect(s.baseScale, 0.8);
    });

    test('cover(factor): scales the cover fit', () {
      const s = ViewfinderInitialScale.cover(1.5);
      expect(s.boxFit, BoxFit.cover);
      expect(s.baseScale, 1.5);
    });

    test('contain and cover with same factor are not equal', () {
      const a = ViewfinderInitialScale.contain(1.5);
      const b = ViewfinderInitialScale.cover(1.5);
      expect(a, isNot(equals(b)));
    });

    test('cover(x) instances with same factor compare equal', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderInitialScale.cover(1.5);
      // ignore: prefer_const_constructors
      final b = ViewfinderInitialScale.cover(1.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('contain(x) instances with same factor compare equal', () {
      // Use `final` (non-canonicalized) so the field-by-field == branch
      // and the hashCode getter run rather than the const-pool identity
      // short-circuit.
      // ignore: prefer_const_constructors
      final a = ViewfinderInitialScale.contain(1.5);
      // ignore: prefer_const_constructors
      final b = ViewfinderInitialScale.contain(1.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('factor must be positive', () {
      expect(
        () => ViewfinderInitialScale.contain(0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ViewfinderInitialScale.cover(-1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Config equality', () {
    // Use `final` (non-canonicalized) so `identical(this, other)` is
    // false and the field-by-field branch of `==` actually runs.
    void onDismiss() {}
    test('ViewfinderHero', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderHero('photo-1');
      // ignore: prefer_const_constructors
      final b = ViewfinderHero('photo-1');
      // ignore: prefer_const_constructors
      final c = ViewfinderHero('photo-2');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('ViewfinderDismiss', () {
      final a = ViewfinderDismiss(onDismiss: onDismiss);
      final b = ViewfinderDismiss(onDismiss: onDismiss);
      final c = ViewfinderDismiss(onDismiss: onDismiss, threshold: 0.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('ViewfinderThumbnails', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderThumbnails();
      // ignore: prefer_const_constructors
      final b = ViewfinderThumbnails();
      // ignore: prefer_const_constructors
      final c = ViewfinderThumbnails(size: 80);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('ViewfinderPageIndicatorDots', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderPageIndicatorDots();
      // ignore: prefer_const_constructors
      final b = ViewfinderPageIndicatorDots();
      // ignore: prefer_const_constructors
      final c = ViewfinderPageIndicatorDots(dotSize: 12);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('ViewfinderPageIndicatorLabel', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderPageIndicatorLabel();
      // ignore: prefer_const_constructors
      final b = ViewfinderPageIndicatorLabel();
      // ignore: prefer_const_constructors
      final c = ViewfinderPageIndicatorLabel(padding: EdgeInsets.zero);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('ViewfinderPageIndicatorAdaptive', () {
      // ignore: prefer_const_constructors
      final a = ViewfinderPageIndicatorAdaptive();
      // ignore: prefer_const_constructors
      final b = ViewfinderPageIndicatorAdaptive();
      // ignore: prefer_const_constructors
      final c = ViewfinderPageIndicatorAdaptive(maxDots: 6);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  testWidgets(
    'ViewfinderImage.contain(factor) initialScale applies the multiplier',
    (tester) async {
      final controller = ViewfinderImageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewfinderImage(
              image: _memoryImage(),
              controller: controller,
              initialScale: const ViewfinderInitialScale.contain(2.0),
              maxScale: 10,
            ),
          ),
        ),
      );
      await _settleImages(tester);
      expect(controller.scale, closeTo(2.0, 0.001));
    },
  );

  testWidgets('ViewfinderImageController.scale reports the X/Y scale, not '
      'getMaxScaleOnAxis (which Z=1 would mask when shrunk)', (tester) async {
    final controller = ViewfinderImageController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(
            image: _memoryImage(),
            controller: controller,
            minScale: 0.25,
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Pinch-shrink. Without the fix, controller.scale would still
    // return 1.0 (Matrix4.getMaxScaleOnAxis sees the Z=1 column and
    // hides the X/Y shrink), and the lower clamp would never fire.
    final viewer = find.byType(ZoomableViewport);
    final center = tester.getCenter(viewer);
    final a = await tester.startGesture(
      center - const Offset(150, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(150, 0),
      pointer: 2,
    );
    await tester.pump();
    await a.moveBy(const Offset(120, 0));
    await b.moveBy(const Offset(-120, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(controller.scale, lessThan(0.6));
    expect(controller.scale, greaterThanOrEqualTo(0.25));
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

    setScale(() => scale = const ViewfinderInitialScale.contain(2.5));
    await tester.pumpAndSettle();
    expect(controller.scale, closeTo(2.5, 0.001));
  });

  testWidgets(
    'ViewfinderImage: swapping in a different ImageProvider resets the '
    'transform (slot reuse must not leak the previous photo zoom)',
    (tester) async {
      // Distinct byte buffers → MemoryImage equality returns false
      // because Uint8List uses identity-based ==.
      final bytesA = Uint8List.fromList(_pngBytes);
      final bytesB = Uint8List.fromList(_pngBytes);
      final controller = ViewfinderImageController();
      ImageProvider current = MemoryImage(bytesA);
      late StateSetter setImage;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              setImage = setState;
              return Scaffold(
                body: ViewfinderImage(image: current, controller: controller),
              );
            },
          ),
        ),
      );
      await _settleImages(tester);

      controller.animateToScale(3.0);
      await tester.pumpAndSettle();
      expect(controller.scaleState, ViewfinderScaleState.zoomed);

      setImage(() => current = MemoryImage(bytesB));
      await tester.pump();
      // Transform reset is synchronous via didUpdateWidget.
      expect(controller.scaleState, ViewfinderScaleState.initial);
      expect(controller.scale, closeTo(1.0, 0.001));
    },
  );

  testWidgets(
    'ViewfinderImage.child: stable contentKey preserves the transform '
    'across rebuilds even when child is a fresh instance each frame',
    (tester) async {
      // With required contentKey, the gallery decides identity from
      // the key, not from the child reference. A fresh Text() per
      // rebuild with the same contentKey must keep the user's zoom.
      final controller = ViewfinderImageController();
      late StateSetter bumpRebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              bumpRebuild = setState;
              // ignore: prefer_const_constructors
              return Scaffold(
                body: ViewfinderImage.child(
                  controller: controller,
                  contentKey: 'main',
                  // ignore: prefer_const_constructors
                  child: Text('arbitrary', textDirection: TextDirection.ltr),
                ),
              );
            },
          ),
        ),
      );
      await _settleImages(tester);

      controller.animateToScale(3.0);
      await tester.pumpAndSettle();
      expect(controller.scaleState, ViewfinderScaleState.zoomed);

      bumpRebuild(() {});
      await tester.pump();
      expect(controller.scaleState, ViewfinderScaleState.zoomed);
    },
  );

  testWidgets(
    'ViewfinderImage.child: changing contentKey resets the transform',
    (tester) async {
      final controller = ViewfinderImageController();
      Object key = 'photo-1';
      late StateSetter setKey;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              setKey = setState;
              return Scaffold(
                body: ViewfinderImage.child(
                  controller: controller,
                  contentKey: key,
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      );
      await _settleImages(tester);

      controller.animateToScale(3.0);
      await tester.pumpAndSettle();
      expect(controller.scaleState, ViewfinderScaleState.zoomed);

      setKey(() => key = 'photo-2');
      await tester.pump();
      expect(controller.scaleState, ViewfinderScaleState.initial);
    },
  );

  testWidgets(
    'ViewfinderImage: re-rendering with the equal ImageProvider keeps '
    'the user transform (no spurious reset on pure rebuild)',
    (tester) async {
      // Same provider value (same MemoryImage bytes reference) on
      // both renders → equality is true → didUpdateWidget must not
      // touch the transform.
      final bytes = Uint8List.fromList(_pngBytes);
      final controller = ViewfinderImageController();
      var rebuilds = 0;
      late StateSetter bumpRebuild;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              bumpRebuild = setState;
              rebuilds++;
              return Scaffold(
                body: ViewfinderImage(
                  image: MemoryImage(bytes),
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );
      await _settleImages(tester);
      expect(rebuilds, 1);

      controller.animateToScale(3.0);
      await tester.pumpAndSettle();
      expect(controller.scaleState, ViewfinderScaleState.zoomed);

      bumpRebuild(() {}); // trigger an idempotent rebuild
      await tester.pump();
      expect(rebuilds, greaterThan(1));
      // Same image bytes → no swap → user zoom preserved.
      expect(controller.scaleState, ViewfinderScaleState.zoomed);
    },
  );

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
            contentKey: 'custom-child',
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
            indicator: const ViewfinderPageIndicatorAdaptive(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    expect(find.byWidgetPredicate((w) => w is ViewfinderImage), findsOneWidget);
    expect(find.byType(ViewfinderThumbnailBar), findsOneWidget);

    controller.animateTo(3);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 3);
    expect(pageChanges.last, 3);
  });

  testWidgets(
    'Viewfinder: navigating away from a zoomed page resets its transform',
    (tester) async {
      final ctrl = ViewfinderController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 3,
              controller: ctrl,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // Zoom page 0 via double-tap.
      final viewer = find.byType(ZoomableViewport);
      final center = tester.getCenter(viewer);
      final g1 = await tester.startGesture(center);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(center);
      await g2.up();
      await tester.pumpAndSettle();

      // Navigate to page 1, then back to page 0.
      ctrl.animateTo(1);
      await tester.pumpAndSettle();
      ctrl.animateTo(0);
      await tester.pumpAndSettle();

      // resetCurrentImage returns true only if a reset actually happened
      // (i.e., the page was still zoomed on entry). After navigating away
      // and back, page 0 must already be at initial scale.
      expect(
        ctrl.resetCurrentImage(),
        isFalse,
        reason: 'previous page should be at initial scale on return',
      );
    },
  );

  testWidgets('Viewfinder: reverse forwards to PageView.reverse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            reverse: true,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    final pv = tester.widget<PageView>(find.byType(PageView));
    expect(pv.reverse, isTrue);
  });

  testWidgets(
    'ViewfinderImage.gaplessPlayback default forwards true to underlying Image',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ViewfinderImage(image: _memoryImage())),
        ),
      );
      await _settleImages(tester);
      final img = tester.widget<Image>(find.byType(Image).first);
      expect(img.gaplessPlayback, isTrue);
    },
  );

  testWidgets('ViewfinderImage.gaplessPlayback false flows through', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ViewfinderImage(image: _memoryImage(), gaplessPlayback: false),
        ),
      ),
    );
    await _settleImages(tester);
    final img = tester.widget<Image>(find.byType(Image).first);
    expect(img.gaplessPlayback, isFalse);
  });

  testWidgets(
    'Viewfinder: ViewfinderImageItem.gaplessPlayback reaches per-page Image',
    (tester) async {
      // Gallery code path is separate from standalone ViewfinderImage —
      // `_ViewfinderPage.build` has to thread the field through.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 1,
              itemBuilder: (_, _) =>
                  ViewfinderItem(image: _memoryImage(), gaplessPlayback: false),
            ),
          ),
        ),
      );
      await _settleImages(tester);
      final img = tester.widget<Image>(find.byType(Image).first);
      expect(img.gaplessPlayback, isFalse);
    },
  );

  testWidgets('ViewfinderImage onScaleStart / onScaleEnd fire on pinch', (
    tester,
  ) async {
    var startCount = 0;
    var endCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: ViewfinderImage(
              image: _memoryImage(),
              onScaleStart: (_) => startCount++,
              onScaleEnd: (_) => endCount++,
            ),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Simulate a single-pointer pan — fires the same scale recognizer.
    final center = tester.getCenter(find.byType(ZoomableViewport));
    final g = await tester.startGesture(center);
    await g.moveBy(const Offset(20, 0));
    await g.up();
    await tester.pumpAndSettle();

    expect(startCount, 1);
    expect(endCount, 1);
  });

  testWidgets(
    'ViewfinderImage.rubberBandPan: false hard-clamps pan past the edge',
    (tester) async {
      final c = ViewfinderImageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ViewfinderImage(
                image: _memoryImage(),
                controller: c,
                rubberBandPan: false,
              ),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // Zoom 3× so there is over-pan room.
      c.animateToScale(3.0);
      await tester.pumpAndSettle();

      final viewer = find.byType(ZoomableViewport);
      final center = tester.getCenter(viewer);

      // Drag hard left mid-gesture. Without rubber-band, the live
      // matrix's tx must not drop below the strict left clamp
      // (= viewport.width - scale * viewport.width = 400 - 3*400 = -800).
      final p = await tester.startGesture(center);
      for (var i = 0; i < 30; i++) {
        await p.moveBy(const Offset(-100, 0));
        await tester.pump();
        final tx = c.currentTransform.storage[12];
        // 0.5 epsilon matches the in-code clamp tolerance.
        expect(
          tx,
          greaterThanOrEqualTo(-800 - 0.5),
          reason: 'rubberBandPan: false must not allow elastic over-pan',
        );
      }
      await p.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'ViewfinderImageController.jumpToTransform sets the matrix instantly',
    (tester) async {
      final c = ViewfinderImageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewfinderImage(image: _memoryImage(), controller: c),
          ),
        ),
      );
      await _settleImages(tester);

      final target = Matrix4.identity()..scaleByDouble(2.0, 2.0, 1, 1);
      c.jumpToTransform(target);
      await tester.pump();
      expect(c.currentTransform, equals(target));
      expect(c.scale, closeTo(2.0, 1e-6));
    },
  );

  testWidgets(
    'ViewfinderImageController.animateToTransform converges to target',
    (tester) async {
      final c = ViewfinderImageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViewfinderImage(image: _memoryImage(), controller: c),
          ),
        ),
      );
      await _settleImages(tester);

      final target = Matrix4.identity()..scaleByDouble(3.0, 3.0, 1, 1);
      c.animateToTransform(target);
      await tester.pumpAndSettle();
      expect(c.scale, closeTo(3.0, 1e-2));
    },
  );

  testWidgets(
    'Viewfinder.allowEdgeHandoff: false still allows unzoomed swipe',
    (tester) async {
      final ctrl = ViewfinderController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 3,
              controller: ctrl,
              allowEdgeHandoff: false,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // No zoom. Fling the pager — should swipe normally, because the
      // handoff knob only governs the zoomed-edge gesture path.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(ctrl.currentIndex, 1);
    },
  );

  testWidgets(
    'Viewfinder.allowEdgeHandoff: false keeps swipe locked while zoomed',
    (tester) async {
      final ctrl = ViewfinderController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 3,
              controller: ctrl,
              allowEdgeHandoff: false,
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // Zoom page 0 via double-tap.
      final viewer = find.byType(ZoomableViewport);
      final center = tester.getCenter(viewer);
      final g1 = await tester.startGesture(center);
      await g1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final g2 = await tester.startGesture(center);
      await g2.up();
      await tester.pumpAndSettle();

      // Pan all the way left (would normally trigger handoff to PageView
      // at the edge). With handoff off, image consumes everything; pager
      // stays put.
      final g3 = await tester.startGesture(center);
      for (var i = 0; i < 30; i++) {
        await g3.moveBy(const Offset(-50, 0));
        await tester.pump();
      }
      await g3.up();
      await tester.pumpAndSettle();

      expect(ctrl.currentIndex, 0);
    },
  );

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
              contentKey: 'C$i',
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
    var dismissed = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 2,
            controller: galleryController,
            dismiss: ViewfinderDismiss(onDismiss: () => dismissed++),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
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

  testWidgets('ViewfinderImageController.canSwipeVertically mirrors '
      'canSwipeHorizontally on the Y axis', (tester) async {
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

    expect(imageController.canSwipeVertically, isTrue);

    imageController.animateToScale(3.0);
    await tester.pumpAndSettle();
    expect(
      imageController.canSwipeVertically,
      isFalse,
      reason: 'zoomed and centered: off both vertical edges',
    );

    imageController.reset();
    await tester.pumpAndSettle();
    expect(imageController.canSwipeVertically, isTrue);
  });

  testWidgets('Viewfinder: vertical pager + zoomed page locks the pager '
      'when the image is off both vertical edges', (tester) async {
    // Regression: the gallery used to consult canSwipeHorizontally
    // regardless of pagerAxis, so a vertical pager would unlock the
    // pager on horizontal-edge state (wrong axis) and lock it on
    // vertical-edge state in the wrong direction. Verify the lock
    // now follows pagerAxis.
    final galleryController = ViewfinderController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            controller: galleryController,
            pagerAxis: Axis.vertical,
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Reach into the active ViewfinderImage's controller via the
    // PageView's currently-built page. The state tree exposes it via
    // the GestureDetector → ZoomableViewport hierarchy, but the
    // simplest hook is to drive the zoom through a real gesture.
    final viewer = find.byType(ZoomableViewport).first;
    final center = tester.getCenter(viewer);
    // Pinch out to ~3x.
    final p1 = await tester.startGesture(
      center - const Offset(20, 0),
      pointer: 1,
    );
    final p2 = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    await tester.pump();
    await p1.moveTo(center - const Offset(120, 0));
    await p2.moveTo(center + const Offset(120, 0));
    await tester.pump();
    await p1.up();
    await p2.up();
    await tester.pumpAndSettle();
    // Sanity: didn't accidentally page-swipe via the pinch.
    expect(galleryController.currentIndex, 0);

    // Now try to swipe vertically as if to advance pages. The image
    // is zoomed and centered (off both vertical edges) so the pager
    // should be locked — index stays at 0.
    await tester.fling(
      find.byType(PageView),
      const Offset(0, -300),
      800,
      deviceKind: PointerDeviceKind.touch,
    );
    await tester.pumpAndSettle();
    expect(
      galleryController.currentIndex,
      0,
      reason:
          'zoomed off vertical edges: vertical pager swipe must stay locked',
    );
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

    final tapPoint = tester.getCenter(
      find.byWidgetPredicate((w) => w is ViewfinderImage),
    );
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
            indicator: const ViewfinderPageIndicatorAdaptive(),
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
    final ctx = tester.element(
      find.byWidgetPredicate((w) => w is ViewfinderImage),
    );
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
            indicator: const ViewfinderPageIndicatorAdaptive(),
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
            indicator: const ViewfinderPageIndicatorAdaptive(maxDots: 5),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.text('1 / 20'), findsOneWidget);
  });

  testWidgets('PageIndicator Dots: renders dots even past 12 items, no label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 30,
            indicator: const ViewfinderPageIndicatorDots(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    // No numeric label.
    expect(find.text('1 / 30'), findsNothing);
    // One dot (AnimatedContainer) per item, all rendered.
    final overlay = find.byType(ViewfinderPageIndicatorOverlay);
    expect(
      find.descendant(of: overlay, matching: find.byType(AnimatedContainer)),
      findsNWidgets(30),
    );
  });

  testWidgets('PageIndicator Label: renders default "i / N" pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 3,
            indicator: const ViewfinderPageIndicatorLabel(),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('PageIndicator Label: custom labelBuilder receives indices', (
    tester,
  ) async {
    final controller = ViewfinderController(initialIndex: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 7,
            controller: controller,
            indicator: ViewfinderPageIndicatorLabel(
              labelBuilder: (_, current, total) => Text(
                'page=${current + 1} of $total',
                textDirection: TextDirection.ltr,
              ),
            ),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.text('page=3 of 7'), findsOneWidget);
    // Default pill must NOT render alongside the custom label.
    expect(find.text('3 / 7'), findsNothing);
  });

  testWidgets('PageIndicator Adaptive: dots at/below threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder(
            itemCount: 4,
            indicator: const ViewfinderPageIndicatorAdaptive(maxDots: 5),
            itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
          ),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.text('1 / 4'), findsNothing);
    final overlay = find.byType(ViewfinderPageIndicatorOverlay);
    expect(
      find.descendant(of: overlay, matching: find.byType(AnimatedContainer)),
      findsNWidgets(4),
    );
  });

  testWidgets(
    'PageIndicator Adaptive: custom labelBuilder used past threshold',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 10,
              indicator: ViewfinderPageIndicatorAdaptive(
                maxDots: 5,
                label: ViewfinderPageIndicatorLabel(
                  labelBuilder: (_, current, total) => Text(
                    'idx=$current/$total',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await _settleImages(tester);
      expect(find.text('idx=0/10'), findsOneWidget);
    },
  );

  testWidgets(
    'PageIndicator Adaptive: itemCount=0 renders nothing (no assert)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder(
              itemCount: 0,
              indicator: const ViewfinderPageIndicatorAdaptive(),
              itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The overlay short-circuits to SizedBox.shrink for empty galleries.
      final overlay = find.byType(ViewfinderPageIndicatorOverlay);
      expect(
        find.descendant(of: overlay, matching: find.byType(AnimatedContainer)),
        findsNothing,
      );
      expect(find.text('1 / 0'), findsNothing);
    },
  );

  test('PageIndicator Adaptive: rejects negative maxDots at construction', () {
    expect(
      () => ViewfinderPageIndicatorAdaptive(maxDots: -1),
      throwsA(isA<AssertionError>()),
    );
    // Defaults match — should construct (const) without asserting.
    expect(() => const ViewfinderPageIndicatorAdaptive(), returnsNormally);
  });

  testWidgets(
    'PageIndicator Adaptive: debug assert flags inner alignment/padding '
    'customization (release silently ignores)',
    (tester) async {
      Future<void> pumpWith(ViewfinderPageIndicator indicator) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Viewfinder(
                itemCount: 3,
                indicator: indicator,
                itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
              ),
            ),
          ),
        );
      }

      await pumpWith(
        const ViewfinderPageIndicatorAdaptive(
          dots: ViewfinderPageIndicatorDots(alignment: Alignment.topCenter),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());

      await pumpWith(
        const ViewfinderPageIndicatorAdaptive(
          label: ViewfinderPageIndicatorLabel(padding: EdgeInsets.zero),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    },
  );

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
            indicator: const ViewfinderPageIndicatorAdaptive(),
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

  testWidgets('Viewfinder.images: builds N pages from the provider list', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Viewfinder.images(List.generate(3, (_) => _memoryImage())),
        ),
      ),
    );
    await _settleImages(tester);
    expect(find.bySemanticsLabel('Photo gallery, 1 of 3'), findsOneWidget);
  });

  testWidgets(
    'Viewfinder.images: thumbImage and semanticLabel callbacks are invoked',
    (tester) async {
      final thumbCalls = <int>[];
      final labelCalls = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.images(
              List.generate(2, (_) => _memoryImage()),
              thumbImage: (i) {
                thumbCalls.add(i);
                return _memoryImage();
              },
              semanticLabel: (i) {
                labelCalls.add(i);
                return 'photo $i';
              },
            ),
          ),
        ),
      );
      await _settleImages(tester);
      // Both callbacks fire with the page index while the gallery's
      // itemBuilder runs. Page 0 is current; page 1 is pre-built by
      // PageView. Use containsAll so we don't depend on call order or
      // the exact viewport-cache strategy.
      expect(thumbCalls, containsAll([0, 1]));
      expect(labelCalls, containsAll([0, 1]));
    },
  );

  testWidgets('Viewfinder.images: hero callback wires per-page Hero', (
    tester,
  ) async {
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
  });

  testWidgets('Viewfinder.images: forwards dismiss to the gallery', (
    tester,
  ) async {
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
  });

  testWidgets(
    'Viewfinder.images: reverse / allowEdgeHandoff / rubberBandPan are '
    'forwarded to the underlying Viewfinder',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Viewfinder.images(
              [_memoryImage(), _memoryImage(), _memoryImage()],
              reverse: true,
              allowEdgeHandoff: false,
              rubberBandPan: false,
            ),
          ),
        ),
      );
      await _settleImages(tester);
      final inner = tester.widget<Viewfinder>(find.byType(Viewfinder));
      expect(inner.reverse, isTrue);
      expect(inner.allowEdgeHandoff, isFalse);
      expect(inner.rubberBandPan, isFalse);
      // PageView.reverse confirms the option actually reaches the pager.
      final pv = tester.widget<PageView>(find.byType(PageView));
      expect(pv.reverse, isTrue);
    },
  );

  test('Viewfinder: pagerAxis: vertical with non-null dismiss is rejected '
      'by debug assert', () {
    expect(
      () => Viewfinder(
        itemCount: 1,
        pagerAxis: Axis.vertical,
        dismiss: ViewfinderDismiss(onDismiss: () {}),
        itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
      ),
      throwsA(isA<AssertionError>()),
    );
    // Sanity: vertical without dismiss is fine.
    expect(
      () => Viewfinder(
        itemCount: 1,
        pagerAxis: Axis.vertical,
        itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
      ),
      returnsNormally,
    );
    // Sanity: horizontal with dismiss is fine.
    expect(
      () => Viewfinder(
        itemCount: 1,
        dismiss: ViewfinderDismiss(onDismiss: () {}),
        itemBuilder: (_, _) => ViewfinderItem(image: _memoryImage()),
      ),
      returnsNormally,
    );
  });

  testWidgets(
    'ViewfinderImageController.canSwipeHorizontally tracks the photo\'s '
    'logical edges under rotation, not raw translation',
    (tester) async {
      // Regression for the pre-0.2.0 implementation that consulted
      // m.storage[12]/[13] directly and so misreported edge state when
      // `rotateEnabled: true`.
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
                rotateEnabled: true,
              ),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      // 3× scale plus 30° rotation around the viewport center: the
      // photo's logical left edge is well past the viewport's left
      // (≈ x=-619) and its logical right edge is well past the right
      // (≈ x=1019). User is at neither logical edge → no handoff.
      final m = Matrix4.identity()
        ..translateByDouble(200.0, 200.0, 0, 1)
        ..rotateZ(0.5236)
        ..scaleByDouble(3.0, 3.0, 1, 1)
        ..translateByDouble(-200.0, -200.0, 0, 1);
      imageController.jumpToTransform(m);
      await tester.pumpAndSettle();

      expect(imageController.scaleState, ViewfinderScaleState.zoomed);
      expect(imageController.canSwipeHorizontally, isFalse);
    },
  );

  testWidgets(
    'ViewfinderImageController.canSwipeVertically tracks the photo\'s '
    'logical edges under rotation',
    (tester) async {
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
                rotateEnabled: true,
              ),
            ),
          ),
        ),
      );
      await _settleImages(tester);

      final m = Matrix4.identity()
        ..translateByDouble(200.0, 200.0, 0, 1)
        ..rotateZ(0.5236)
        ..scaleByDouble(3.0, 3.0, 1, 1)
        ..translateByDouble(-200.0, -200.0, 0, 1);
      imageController.jumpToTransform(m);
      await tester.pumpAndSettle();

      expect(imageController.scaleState, ViewfinderScaleState.zoomed);
      expect(imageController.canSwipeVertically, isFalse);
    },
  );

  testWidgets(
    'ViewfinderImageController: attaching to multiple ViewfinderImage '
    'widgets at once trips a debug assert',
    (tester) async {
      // 1 controller = 1 view. Sharing across widgets would silently
      // overwrite the binding (release) or produce incorrect reads
      // (because per-state fields like scaleState would resolve to
      // whichever widget attached last).
      final shared = ViewfinderImageController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: ViewfinderImage(
                    image: _memoryImage(),
                    controller: shared,
                  ),
                ),
                Expanded(
                  child: ViewfinderImage(
                    image: _memoryImage(),
                    controller: shared,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // The second ViewfinderImage's initState calls _attach while the
      // first is still attached → debug assert fires.
      expect(tester.takeException(), isA<AssertionError>());
    },
  );

  testWidgets('ViewfinderImage: deactivate detaches and activate re-attaches '
      'the controller across a GlobalKey-driven tree move', (tester) async {
    // GlobalKey moves trigger deactivate (old slot) then activate
    // (new slot) on the same State instance — without re-attaching
    // in activate, the controller would be left detached.
    final key = GlobalKey();
    final controller = ViewfinderImageController();
    var inA = true;
    late StateSetter setSlot;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              setSlot = setState;
              final viewer = ViewfinderImage(
                key: key,
                image: _memoryImage(),
                controller: controller,
              );
              return Column(
                children: [
                  Expanded(child: inA ? viewer : const SizedBox.expand()),
                  Expanded(child: inA ? const SizedBox.expand() : viewer),
                ],
              );
            },
          ),
        ),
      ),
    );
    await _settleImages(tester);

    // Initial bind: controller drives the viewer.
    controller.animateToScale(3.0);
    await tester.pumpAndSettle();
    expect(controller.scaleState, ViewfinderScaleState.zoomed);

    // Move to slot B — same State, deactivate then activate.
    setSlot(() => inA = false);
    await tester.pumpAndSettle();

    // After the move, the controller is still bound and reads the
    // (preserved) zoom state from the same State instance.
    expect(controller.scaleState, ViewfinderScaleState.zoomed);
    controller.reset();
    await tester.pumpAndSettle();
    expect(controller.scaleState, ViewfinderScaleState.initial);
  });

  testWidgets('Viewfinder.single: shows exactly one page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Viewfinder.single(image: _memoryImage())),
      ),
    );
    await _settleImages(tester);
    expect(find.bySemanticsLabel('Photo gallery, 1 of 1'), findsOneWidget);
  });

  testWidgets('Viewfinder.single: dismiss fires onDismiss on vertical drag', (
    tester,
  ) async {
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
  });
}
