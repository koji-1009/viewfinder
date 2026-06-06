import 'package:flutter/widgets.dart';

/// Stable [Key]s the gallery attaches to its parts, so consumer widget
/// tests can target them with `find.byKey` instead of fishing through
/// internal types.
///
/// ```dart
/// await tester.tap(find.byKey(ViewfinderKeys.thumbnail(3)));
/// expect(find.byKey(ViewfinderKeys.page(3)), findsOneWidget);
/// ```
abstract final class ViewfinderKeys {
  /// Key of the page showing item [index].
  ///
  /// Attached to bounded (non-looping) galleries only — a looping
  /// pager can mount the same logical page in two slots at once, so
  /// its page keys stay internal.
  static Key page(int index) => ValueKey<String>('viewfinder-page-$index');

  /// Key of the thumbnail-strip tile for item [index].
  static Key thumbnail(int index) =>
      ValueKey<String>('viewfinder-thumbnail-$index');
}
