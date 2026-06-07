import 'package:flutter/widgets.dart';

/// Tells the viewers inside a gallery page which axis the surrounding
/// pager scrolls on, so they can yield pager-axis gestures:
///
/// - the double-tap-drag recognizer rejects pager-axis-dominant drags
///   (a tap followed by a swipe should page, not zoom);
/// - with [wheelPaging], pager-axis-dominant scroll events pass
///   through to the pager and zoom reads the cross-axis component.
///
/// A standalone viewer (no scope) yields nothing — there is no pager
/// to hand anything to.
class PagerScope extends InheritedWidget {
  const PagerScope({
    super.key,
    required this.axis,
    required this.wheelPaging,
    required super.child,
  });

  final Axis axis;
  final bool wheelPaging;

  static PagerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PagerScope>();

  @override
  bool updateShouldNotify(PagerScope oldWidget) =>
      axis != oldWidget.axis || wheelPaging != oldWidget.wheelPaging;
}
