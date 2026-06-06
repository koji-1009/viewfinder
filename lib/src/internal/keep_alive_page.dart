import 'package:flutter/widgets.dart';

/// Keeps a gallery page's element alive when it scrolls out of the
/// [PageView]'s cache extent. Internal — wrapped around pages when
/// `Viewfinder.keepAlivePages` is enabled, so a `.child` page's state
/// (video position, scroll offset, …) survives swiping away.
class KeepAlivePage extends StatefulWidget {
  const KeepAlivePage({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
