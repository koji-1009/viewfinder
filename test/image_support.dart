import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// `dart:ui`'s real image codec is not wired up in `flutter test`, so
// any `MemoryImage` (or other byte-decoding provider) raises "Codec
// failed to produce an image" — both on the display path and on
// `precacheImage`. We sidestep the codec entirely by handing the
// framework a pre-baked `ui.Image` (created via `createTestImage`)
// through a synchronous `ImageProvider`.
late ui.Image _testImage;

/// Call from `setUpAll` before any [memoryImage] resolves.
Future<void> prepareTestImage() async {
  _testImage = await createTestImage(width: 1, height: 1);
}

@immutable
class _SyncImageProvider extends ImageProvider<_SyncImageProvider> {
  const _SyncImageProvider(this._tag);
  final Object _tag;

  @override
  Future<_SyncImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SyncImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: _testImage.clone())),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _SyncImageProvider && other._tag == _tag;

  @override
  int get hashCode => _tag.hashCode;
}

/// Codec-free provider; equal tags compare equal (provider identity).
ImageProvider memoryImage([Object tag = 'default']) => _SyncImageProvider(tag);

/// Codec-free provider whose stream stays pending until [resolveNow] is
/// called — lets a test observe the pre-resolution build (e.g. a Hero
/// shuttle's fallback fit before the intrinsic size is known).
class DeferredImageProvider extends ImageProvider<DeferredImageProvider> {
  final _completer = Completer<ImageInfo>();

  /// Completes the pending stream with the shared 1×1 test image.
  void resolveNow() =>
      _completer.complete(ImageInfo(image: _testImage.clone()));

  @override
  Future<DeferredImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    DeferredImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_completer.future);
}

Future<void> settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
}
