import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viewfinder/src/internal/zoomable_viewport.dart';

void main() {
  group('ZoomableViewport pinch-to-zoom via scale gestures', () {
    testWidgets('two-finger pinch scales around focal point', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final viewport = find.byType(ZoomableViewport);
      final center = tester.getCenter(viewport);

      // Two-finger pinch outward.
      final pointer1Start = center - const Offset(40, 0);
      final pointer2Start = center + const Offset(40, 0);
      final p1 = await tester.startGesture(pointer1Start, pointer: 1);
      final p2 = await tester.startGesture(pointer2Start, pointer: 2);
      await tester.pump();

      await p1.moveTo(center - const Offset(120, 0));
      await p2.moveTo(center + const Offset(120, 0));
      await tester.pump();

      await p1.up();
      await p2.up();
      await tester.pumpAndSettle();

      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.5));
    });

    testWidgets('release with velocity starts a fling that moves '
        'translation beyond the last drag point', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(3, 3, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: SizedBox.expand(child: Container(color: Colors.red)),
            ),
          ),
        ),
      );

      // fling() produces a proper velocity via VelocityTracker.
      // 1500 px/s well exceeds kMinFlingVelocity (50) so fling kicks in.
      await tester.fling(
        find.byType(ZoomableViewport),
        const Offset(-300, 0),
        1500,
      );
      // First pump registers the animation ticker (elapsed = 0).
      await tester.pump();
      final txAtFirstTick = controller.value.storage[12];
      // Second pump advances the simulation by 50ms.
      await tester.pump(const Duration(milliseconds: 50));
      final txMidFling = controller.value.storage[12];
      expect(
        txMidFling,
        lessThan(txAtFirstTick),
        reason: 'fling should continue the leftward motion after release',
      );
      await tester.pumpAndSettle();
    });

    testWidgets('pinch past maxScale clamps the matrix scale', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              minScale: 1,
              maxScale: 3,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      // Two fingers starting close together, spreading outward > 5x.
      final a = await tester.startGesture(
        center - const Offset(10, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(10, 0),
        pointer: 2,
      );
      await tester.pump();
      await a.moveBy(const Offset(-300, 0));
      await b.moveBy(const Offset(300, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      // Scale was clamped to maxScale (= 3), not left at ~30.
      expect(controller.value.getMaxScaleOnAxis(), closeTo(3.0, 0.01));
    });

    testWidgets('pinch shrink past minScale clamps the matrix scale', (
      tester,
    ) async {
      // Regression: the prior implementation clamped on
      // Matrix4.getMaxScaleOnAxis() which is dominated by the Z column
      // (always 1.0 in our 2D matrices) and so silently failed to
      // enforce the lower scale bound — pinch-shrink could drive
      // the X/Y scale below 1.
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      // Two fingers starting wide, pinching together — would shrink
      // X/Y to ~0.13 without the clamp.
      final a = await tester.startGesture(
        center - const Offset(150, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(150, 0),
        pointer: 2,
      );
      await tester.pump();
      await a.moveBy(const Offset(130, 0));
      await b.moveBy(const Offset(-130, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pumpAndSettle();

      // Read the actual X-column length so the assertion catches a
      // regression where Z=1 hides the X/Y shrink.
      final m = controller.value;
      final xColLen = math.sqrt(
        m.storage[0] * m.storage[0] +
            m.storage[1] * m.storage[1] +
            m.storage[2] * m.storage[2],
      );
      expect(xColLen, closeTo(1.0, 0.01));
    });

    testWidgets('new gesture mid-fling stops the fling cleanly', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(3, 3, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      await tester.fling(
        find.byType(ZoomableViewport),
        const Offset(-300, 0),
        1500,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // Interrupt with a new gesture mid-fling.
      final p = await tester.startGesture(
        tester.getCenter(find.byType(ZoomableViewport)),
      );
      await p.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('rotation is ignored when rotateEnabled is false', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.green),
            ),
          ),
        ),
      );

      // Simulate two pointers rotating. Because rotateEnabled is
      // false, the ScaleGestureRecognizer's rotation component is
      // discarded.
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p1 = await tester.startGesture(
        center + const Offset(0, -40),
        pointer: 1,
      );
      final p2 = await tester.startGesture(
        center + const Offset(0, 40),
        pointer: 2,
      );
      await tester.pump();
      await p1.moveBy(const Offset(40, 0));
      await p2.moveBy(const Offset(-40, 0));
      await tester.pump();
      await p1.up();
      await p2.up();
      await tester.pumpAndSettle();

      // Row 0 column 1 of rotation-free matrix should be 0.
      expect(controller.value.storage[1].abs(), lessThan(0.01));
    });

    testWidgets('rotation is applied when rotateEnabled is true', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              rotateEnabled: true,
              child: Container(color: Colors.green),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p1 = await tester.startGesture(
        center + const Offset(0, -40),
        pointer: 1,
      );
      final p2 = await tester.startGesture(
        center + const Offset(0, 40),
        pointer: 2,
      );
      await tester.pump();
      await p1.moveBy(const Offset(40, 0));
      await p2.moveBy(const Offset(-40, 0));
      await tester.pump();
      await p1.up();
      await p2.up();
      await tester.pumpAndSettle();

      // With rotation applied the off-diagonal should be non-zero.
      expect(controller.value.storage[1].abs(), greaterThan(0.05));
    });
  });

  group('ZoomableViewport mouse wheel', () {
    testWidgets('scroll wheel zooms around pointer', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      testPointer.hover(center);
      await tester.sendEventToBinding(
        testPointer.scroll(const Offset(0, -100)),
      );
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.1));
    });

    testWidgets('wheel event is ignored when scaleEnabled is false', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              scaleEnabled: false,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      testPointer.hover(center);
      await tester.sendEventToBinding(
        testPointer.scroll(const Offset(0, -100)),
      );
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
    });

    testWidgets('enableMouseWheelZoom=false leaves wheel alone', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              enableMouseWheelZoom: false,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final testPointer = TestPointer(1, PointerDeviceKind.mouse);
      testPointer.hover(center);
      await tester.sendEventToBinding(
        testPointer.scroll(const Offset(0, -100)),
      );
      await tester.pumpAndSettle();
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
    });
  });

  group('ZoomableViewport double-tap-drag', () {
    testWidgets('double-tap then upward drag zooms in (iOS Photos '
        'convention)', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              minScale: 0.5,
              maxScale: 10,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      // First tap.
      final first = await tester.startGesture(center);
      await first.up();
      await tester.pump(const Duration(milliseconds: 60));
      // Second tap then drag UP — Apple Photos convention: up = zoom in.
      final second = await tester.startGesture(center);
      await second.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 16));
      await second.up();
      await tester.pumpAndSettle();

      expect(controller.value.getMaxScaleOnAxis(), greaterThan(1.1));
    });

    testWidgets('second pointer arriving mid-drag yields to scale '
        'recognizer (pinch priority)', (tester) async {
      // After a double-tap puts DTD into dragging, if the user lands a
      // second finger to pinch, DTD should yield so ScaleGestureRecognizer
      // can claim both pointers and produce a proper pinch — not be
      // stuck in single-finger drag.
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              minScale: 0.5,
              maxScale: 10,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      // Two taps → mid-drag.
      final t1 = await tester.startGesture(center);
      await t1.up();
      await tester.pump(const Duration(milliseconds: 60));
      final dragFinger = await tester.startGesture(center, pointer: 10);
      await dragFinger.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
      final scaleAfterDrag = controller.value.getMaxScaleOnAxis();
      expect(scaleAfterDrag, greaterThan(1.0));

      // Second finger lands — DTD must yield.
      final secondFinger = await tester.startGesture(
        center + const Offset(60, 0),
        pointer: 11,
      );
      // Pinch outward.
      await dragFinger.moveBy(const Offset(-40, 0));
      await secondFinger.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await dragFinger.up();
      await secondFinger.up();
      await tester.pumpAndSettle();

      // No crash, controller still sane.
      expect(controller.value.getMaxScaleOnAxis(), isNonZero);
    });

    testWidgets('second tap released without drag still allows plain '
        'double-tap to reach an outer GestureDetector', (tester) async {
      // The critical case: the recognizer must yield arena cleanly so
      // GestureDetector.onDoubleTap wrapping the viewport still fires
      // when the user taps twice without moving.
      final controller = TransformationController();
      var doubleTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => doubleTaps++,
              child: ZoomableViewport(
                transformationController: controller,
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final first = await tester.startGesture(center);
      await first.up();
      await tester.pump(const Duration(milliseconds: 60));
      final second = await tester.startGesture(center);
      await second.up();
      await tester.pumpAndSettle();
      expect(doubleTaps, 1);
    });
  });

  group('ZoomableViewport arena-aware edge yield', () {
    testWidgets('canPan=false on Axis.vertical yields vertical drag', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final sawSigns = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              canPan: (axis, sign) {
                if (axis == Axis.vertical) sawSigns.add(sign);
                return false;
              },
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(0, 50));
      await p.up();
      await tester.pumpAndSettle();
      expect(sawSigns, contains(1));
      expect(controller.value.storage[13], 0.0);
    });

    testWidgets('canPanHorizontally=true pans the image (baseline)', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              canPan: (axis, sign) => true,
              doubleTapDragZoom: false, // isolate from DTD arena effects
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      // Drag over several frames so the scale recognizer exceeds its
      // kPanSlop acceptance threshold cleanly.
      for (var i = 0; i < 4; i++) {
        await p.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();

      // When pan is allowed, translation shifts.
      expect(controller.value.storage[12], lessThan(0));
    });

    testWidgets('vertical pan consults the gate on Axis.vertical', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final sawAxes = <Axis>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              canPan: (axis, sign) {
                sawAxes.add(axis);
                return true;
              },
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(0, -60));
      await p.up();
      await tester.pumpAndSettle();

      expect(sawAxes, contains(Axis.vertical));
    });

    testWidgets('canPanHorizontally=false yields the gesture — image '
        'does not pan, leaving the pointer available for an ancestor', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final sawSigns = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              canPan: (axis, sign) {
                if (axis == Axis.horizontal) sawSigns.add(sign);
                return false;
              },
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(-60, 0));
      await p.up();
      await tester.pumpAndSettle();

      // The gate was consulted with the right sign (finger moved left).
      expect(sawSigns, contains(-1));
      // Image did NOT pan — the gesture was yielded.
      expect(controller.value.storage[12], 0.0);
    });

    testWidgets('DTD: second tap beyond double-tap window starts a '
        'fresh tap1', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));

      // First tap at timeStamp 0.
      final t1 = await tester.createGesture();
      await t1.down(center);
      await t1.up(timeStamp: const Duration(milliseconds: 10));
      await tester.pump(const Duration(milliseconds: 500));

      // Second tap 500ms later — past the double-tap window. DTD should
      // treat this as a fresh tap1, not a second tap. Subsequent drift
      // then rejects DTD (drift > touchSlop in tap1), so the scale
      // recognizer claims the pan.
      final t2 = await tester.createGesture();
      await t2.down(center, timeStamp: const Duration(milliseconds: 510));
      await t2.moveBy(
        const Offset(0, -40),
        timeStamp: const Duration(milliseconds: 525),
      );
      await t2.up(timeStamp: const Duration(milliseconds: 540));
      await tester.pumpAndSettle();

      // No double-tap-drag zoom happened.
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    });

    testWidgets('DTD: tap1 drift beyond touchSlop rejects so scale '
        'recognizer can claim the pan', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      // Single-finger drag without double tap — DTD is in tap1Down, should
      // reject on drift so scale recognizer handles the pan.
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      for (var i = 1; i <= 4; i++) {
        await p.moveBy(const Offset(-25, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();
      expect(
        controller.value.storage[12],
        lessThan(0),
        reason: 'scale recognizer should have handled the pan',
      );
    });

    testWidgets('DTD: additional move events after drag starts call '
        'onDragUpdate repeatedly', (tester) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              minScale: 0.5,
              maxScale: 10,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final t1 = await tester.startGesture(center);
      await t1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(0, -30));
      final scaleAfterFirst = controller.value.getMaxScaleOnAxis();
      await p.moveBy(const Offset(0, -30));
      await tester.pump();
      final scaleAfterSecond = controller.value.getMaxScaleOnAxis();
      await p.up();
      await tester.pumpAndSettle();
      expect(scaleAfterSecond, greaterThan(scaleAfterFirst));
    });

    testWidgets('DTD: PointerCancel during continuous-zoom drag resets', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              minScale: 0.5,
              maxScale: 10,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final t1 = await tester.startGesture(center);
      await t1.up();
      await tester.pump(const Duration(milliseconds: 60));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 16));
      await p.cancel();
      await tester.pumpAndSettle();
      // No crash; controller state sensible.
      expect(tester.takeException(), isNull);
    });

    testWidgets('PointerCancel during pinch resets recognizer state', (
      tester,
    ) async {
      final controller = TransformationController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableViewport(
              transformationController: controller,
              child: Container(color: Colors.blue),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      await p.moveBy(const Offset(10, 10));
      await p.cancel();
      await tester.pumpAndSettle();
      // No crash; identity transform preserved.
      expect(controller.value.getMaxScaleOnAxis(), closeTo(1.0, 0.001));
    });
  });

  group('ZoomableViewport boundary clamp', () {
    testWidgets('aggressive pan upward clamps to bottom edge and '
        'fires onEdgeHit(Axis.vertical, +1)', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final edgeHits = <(Axis, int)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ZoomableViewport(
                transformationController: controller,
                onEdgeHit: (axis, sign) => edgeHits.add((axis, sign)),
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      for (var i = 0; i < 10; i++) {
        await p.moveBy(const Offset(0, -100));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();
      expect(edgeHits.any((e) => e == (Axis.vertical, 1)), isTrue);
    });

    testWidgets('aggressive pan left clamps and fires onEdgeHit'
        '(Axis.horizontal, +1)', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final edgeHits = <(Axis, int)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ZoomableViewport(
                transformationController: controller,
                onEdgeHit: (axis, sign) => edgeHits.add((axis, sign)),
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      for (var i = 0; i < 10; i++) {
        await p.moveBy(const Offset(-100, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();
      expect(edgeHits.any((e) => e == (Axis.horizontal, 1)), isTrue);
    });

    testWidgets('vertical pan of a zoomed image clamps to edge and '
        'fires onEdgeHit(Axis.vertical, …)', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final verticalEdgeHits = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ZoomableViewport(
                transformationController: controller,
                onEdgeHit: (axis, sign) {
                  if (axis == Axis.vertical) verticalEdgeHits.add(sign);
                },
                child: Container(color: Colors.green),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      for (var i = 0; i < 10; i++) {
        await p.moveBy(const Offset(0, 100));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();
      expect(verticalEdgeHits, isNotEmpty);
    });

    testWidgets('aggressive pan right of a zoomed image clamps to edge '
        'and fires onEdgeHit(Axis.horizontal, -1)', (tester) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      final edgeHits = <(Axis, int)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ZoomableViewport(
                transformationController: controller,
                onEdgeHit: (axis, sign) => edgeHits.add((axis, sign)),
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      // Drag content to the right aggressively.
      for (var i = 0; i < 10; i++) {
        await p.moveBy(const Offset(100, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await p.up();
      await tester.pumpAndSettle();
      expect(
        edgeHits.any((e) => e.$1 == Axis.horizontal),
        isTrue,
        reason: 'edge hit should have fired during clamp',
      );
    });

    testWidgets('zoomed content cannot be panned past left edge', (
      tester,
    ) async {
      final controller = TransformationController(
        Matrix4.identity()..scaleByDouble(2, 2, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ZoomableViewport(
                transformationController: controller,
                child: Container(color: Colors.blue),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(ZoomableViewport));
      final p = await tester.startGesture(center);
      // Drag the content aggressively to the right (should reveal left
      // part of the image). Clamp should prevent going past origin.
      await p.moveBy(const Offset(9999, 0));
      await p.up();
      await tester.pumpAndSettle();

      final tx = controller.value.storage[12];
      expect(
        tx,
        lessThanOrEqualTo(0.5),
        reason: 'translation.x cannot exceed right-edge bound',
      );
    });
  });
}
