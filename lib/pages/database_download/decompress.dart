// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

typedef _NativeP7zipShell = NativeFunction<Int32 Function(Pointer<Int8>)>;
typedef _DartP7zipShell = int Function(Pointer<Int8>);

void _shell(List argv) {
  // TODO: Using the LZMA SDK directly may be better.
  final SendPort sendPort = argv[0];
  final String soPath = argv[1];
  final String cmd = argv[2];
  final p7zip = DynamicLibrary.open(soPath);
  final p7zipShell = p7zip.lookup<_NativeP7zipShell>('p7zipShell');
  if (p7zipShell.address == 0) {
    sendPort.send(-1);
    return;
  }
  final _DartP7zipShell p7zipShellFn = p7zipShell.asFunction();
  final cstr = intListToArray(cmd);
  final result = p7zipShellFn.call(cstr);
  sendPort.send(result);
  // final DynamicLibrary dlLib = DynamicLibrary.process();
  // final int Function(Pointer<Void>) dlcloseFun = dlLib
  //     .lookup<NativeFunction<Int32 Function(Pointer<Void>)>>("dlclose")
  //     .asFunction();
  // dlcloseFun(p7zip.handle);
}

Pointer<Int8> intListToArray(String list) {
  final ptr = malloc.allocate<Int8>(list.length + 1);
  for (var i = 0; i < list.length; i++) {
    ptr.elementAt(i).value = list.codeUnitAt(i);
  }
  ptr.elementAt(list.length).value = 0;
  return ptr;
}

class P7zip {
  Future<String?> decompress(List<String> files, {required String path}) async {
    final soPath = await _checkSharedLibrary();
    print(soPath);
    if (soPath == null) {
      return null;
    }

    final filesStr = files.join(' ');

    final receivePort = ReceivePort();
    await Isolate.spawn(
        _shell, [receivePort.sendPort, soPath, '7zr e $filesStr -o$path']);
    final result = await receivePort.first;
    print('[p7zip] compress: after first result = $result');
    receivePort.close();
    return result == 0 ? path : null;
  }

  Future<String?> _checkSharedLibrary() async {
    final dir = await getTemporaryDirectory();
    final libFile = File('${dir.path}/lib7zr.so');
    if (Platform.isAndroid) {
      final devicePlugin = DeviceInfoPlugin();
      final deviceInfo = await devicePlugin.androidInfo;
      String soResource = 'assets/p7zip/armeabi-v7a/lib7zr.so';
      if (kDebugMode) soResource = 'assets/p7zip/x86/lib7zr.so';
      final support64 = deviceInfo.supported64BitAbis;
      if (support64.isNotEmpty) {
        if (kDebugMode) {
          soResource = 'assets/p7zip/x86_64/lib7zr.so';
        } else {
          soResource = 'assets/p7zip/arm64-v8a/lib7zr.so';
        }
      }
      final data = await rootBundle.load(soResource);
      final createFile = await libFile.create();
      final writeFile = await createFile.open(mode: FileMode.write);
      await writeFile.writeFrom(Uint8List.view(data.buffer));
      return libFile.path;
    }
    return null;
  }
}
