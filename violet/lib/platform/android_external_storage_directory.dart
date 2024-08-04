import 'dart:io';

import 'package:flutter/services.dart';

class AndroidExternalStorageDirectory {
  const AndroidExternalStorageDirectory._();

  static const instance = AndroidExternalStorageDirectory._();

  final _methodChannel =
      const MethodChannel('xyz.project.violet/externalStorageDirectory');

  Future<String> getExternalStorageDirectory() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android only');
    }

    final path = await _methodChannel
        .invokeMethod<String>('getExternalStorageDirectory');

    return path!;
  }

  Future<String> getExternalStorageDownloadsDirectory() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Android only');
    }

    final path = await _methodChannel
        .invokeMethod<String>('getExternalStorageDownloadsDirectory');

    return path!;
  }
}
