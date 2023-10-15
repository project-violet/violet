import 'dart:io';

import 'package:flutter/services.dart';

class PlatformMiscMethods {
  const PlatformMiscMethods._();

  static const instance = PlatformMiscMethods._();

  final _methodChannel = const MethodChannel('xyz.project.violet/misc');

  Future<void> finishMainActivity() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android only');
    }

    await _methodChannel.invokeMethod('finishMainActivity');
  }

  Future<void> exportFile(
    String filePath, {
    required String mimeType,
    required String fileNameToSaveAs,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android only');
    }

    await _methodChannel.invokeMethod<String>(
      'exportFile',
      <String, dynamic>{
        'filePath': filePath,
        'mimeType': mimeType,
        'fileNameToSaveAs': fileNameToSaveAs,
      },
    );
  }
}
