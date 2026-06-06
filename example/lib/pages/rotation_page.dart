import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 5 — the rotation playground.
///
/// `rotateEnabled: true` turns on two-finger rotation, which needs a
/// real touchscreen — mouse and web-trackpad input has no rotate
/// gesture. The slider covers those devices by driving the same
/// transform through [ViewfinderImageController.jumpToTransform], and a
/// reset button snaps the photo back to upright.
class RotationPage extends StatefulWidget {
  const RotationPage({super.key});

  @override
  State<RotationPage> createState() => _RotationPageState();
}

class _RotationPageState extends State<RotationPage> {
  static const _initialScale = ViewfinderInitialScale.contain(0.9);

  final _controller = ViewfinderImageController();
  double _degrees = 0;
  Size _viewport = Size.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyRotation(double degrees) {
    setState(() => _degrees = degrees);
    if (_viewport.isEmpty) return;
    final theta = degrees * math.pi / 180;
    // jumpToTransform is absolute; controller.scale is relative to the
    // initial baseline.
    final scale = _controller.scale * _initialScale.baseScale;
    final center = _viewport.center(Offset.zero);
    _controller.jumpToTransform(
      Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..rotateZ(theta)
        ..scaleByDouble(scale, scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1),
    );
  }

  void _reset() {
    setState(() => _degrees = 0);
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rotation playground'),
        actions: [
          IconButton(
            tooltip: 'Reset transform',
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.rotate_right_outlined,
            message:
                'rotateEnabled is on. Two-finger rotation needs a '
                'touchscreen — mouse and web trackpads have no rotate '
                'gesture — so the slider drives the same transform through '
                "ViewfinderImageController. Boundary clamping follows the "
                "rotated photo's bounding box, so it never pans fully "
                'off-screen.',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InputHints(
              hints: [
                (
                  icon: Icons.touch_app_outlined,
                  label: 'Two-finger rotate (touch)',
                ),
                (icon: Icons.tune, label: 'Slider on any device'),
                (icon: Icons.restart_alt, label: 'Reset to upright'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.rotate_90_degrees_ccw_outlined, size: 20),
                Expanded(
                  child: Slider(
                    value: _degrees,
                    min: -180,
                    max: 180,
                    divisions: 72,
                    label: '${_degrees.round()}°',
                    onChanged: _applyRotation,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text('${_degrees.round()}°', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return ViewfinderImage(
                        controller: _controller,
                        image: DemoPhotos.images[5],
                        rotateEnabled: true,
                        initialScale: _initialScale,
                        doubleTapScales: const [1, 2.5, 5],
                        maxScale: 8,
                        semanticLabel: 'Rotatable demo photo',
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
