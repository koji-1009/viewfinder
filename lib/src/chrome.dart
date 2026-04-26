import 'dart:async';

import 'package:flutter/foundation.dart';

/// Controls visibility of the gallery's chrome — thumbnails, page
/// indicator, and any `chromeOverlays` widgets the caller plugs in.
///
/// The controller implements the common photo-viewer UX pattern:
/// - Tap anywhere on the photo area toggles chrome.
/// - Chrome fades out after [autoHideAfter] of inactivity (if non-null).
/// - Chrome hides while any page is zoomed in (if [autoHideWhileZoomed]).
/// - Any user interaction bumps the auto-hide timer.
///
/// Extends [ChangeNotifier] so widgets can rebuild on visibility change
/// via `AnimatedBuilder`.
class ViewfinderChromeController extends ChangeNotifier {
  ViewfinderChromeController({
    bool initialVisible = true,
    this.autoHideAfter = const Duration(seconds: 3),
    this.autoHideWhileZoomed = true,
  }) : _visible = initialVisible {
    if (_visible) _restartTimer();
  }

  /// Time of inactivity after which chrome fades out. `null` disables
  /// auto-hide entirely — chrome stays up until explicitly toggled.
  final Duration? autoHideAfter;

  /// When true, the gallery auto-hides chrome while any page is
  /// zoomed past its initial scale. Calling [show] overrides this
  /// until the next zoom transition.
  final bool autoHideWhileZoomed;

  bool _visible;
  bool _disposed = false;
  Timer? _timer;

  /// Whether chrome is currently visible.
  bool get visible => _visible;

  /// Make chrome visible, (re)starting the auto-hide timer.
  void show() {
    if (_disposed) return;
    _restartTimer();
    if (_visible) return;
    _visible = true;
    notifyListeners();
  }

  /// Hide chrome immediately and cancel any pending auto-hide timer.
  void hide() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = null;
    if (!_visible) return;
    _visible = false;
    notifyListeners();
  }

  /// Toggle visibility. When showing, auto-hide timer is restarted.
  void toggle() {
    if (_visible) {
      hide();
    } else {
      show();
    }
  }

  /// Restart the auto-hide timer without changing visibility. Call on
  /// any user interaction (page change, finger move) to keep chrome up
  /// while the user is engaged.
  void bumpAutoHide() {
    if (_disposed) return;
    if (!_visible) return;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    final delay = autoHideAfter;
    if (delay == null) return;
    _timer = Timer(delay, () {
      if (_disposed) return;
      if (!_visible) return;
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
