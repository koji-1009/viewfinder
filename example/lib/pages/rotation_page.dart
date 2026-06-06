import 'package:flutter/material.dart';
import 'package:viewfinder/viewfinder.dart';

import '../shared.dart';

/// Scenario 5 — the rotation playground.
///
/// `rotateEnabled: true` turns on two-finger rotation. Flutter's
/// `ScaleGestureRecognizer` only reports rotation when explicitly asked,
/// which is why this is opt-in. A [ViewfinderImageController] drives a
/// reset button so the photo can snap back to upright after twisting.
class RotationPage extends StatefulWidget {
  const RotationPage({super.key});

  @override
  State<RotationPage> createState() => _RotationPageState();
}

class _RotationPageState extends State<RotationPage> {
  final _controller = ViewfinderImageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            onPressed: _controller.reset,
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoHint(
            icon: Icons.rotate_right_outlined,
            message:
                'rotateEnabled is on. Use two fingers (or a trackpad) to '
                'rotate while you pinch — boundary clamping follows the '
                "rotated photo's bounding box, so it never pans fully "
                'off-screen. Tap reset to snap back to upright.',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: InputHints(
              hints: [
                (icon: Icons.touch_app_outlined, label: 'Two-finger rotate'),
                (icon: Icons.gesture_outlined, label: 'Pinch to zoom'),
                (icon: Icons.restart_alt, label: 'Reset to upright'),
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
                  child: ViewfinderImage(
                    controller: _controller,
                    image: DemoPhotos.images[5],
                    rotateEnabled: true,
                    initialScale: const ViewfinderInitialScale.contain(0.9),
                    doubleTapScales: const [1, 2.5, 5],
                    maxScale: 8,
                    semanticLabel: 'Rotatable demo photo',
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
