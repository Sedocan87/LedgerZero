import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ledger_zero/app/theme.dart';

/// Loads Inter (the app's font, bundled under assets/fonts/Inter) into the
/// test engine, so text is laid out with real metrics instead of the square
/// test font. Call it from `setUpAll`.
Future<void> loadInter() async {
  Future<ByteData> font(String name) async {
    final bytes = await File('assets/fonts/Inter/$name').readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  final loader = FontLoader(AppTextStyles.fontFamily)
    ..addFont(font('Inter-Regular.ttf'))
    ..addFont(font('Inter-Medium.ttf'))
    ..addFont(font('Inter-SemiBold.ttf'))
    ..addFont(font('Inter-Bold.ttf'));
  await loader.load();
}
