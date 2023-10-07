// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
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

  static const libraryAbis = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86',
    'x86_64',
  ];

  Future<String?> _checkSharedLibrary() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final devicePlugin = DeviceInfoPlugin();
    final deviceInfo = await devicePlugin.androidInfo;

    final targetAbi = deviceInfo.supportedAbis.firstWhere(
      (abi) => libraryAbis.contains(abi),
    );
    final sharedLibraryPath = 'assets/p7zip/$targetAbi/lib7zr.so';
    final sharedLibraryContent = await rootBundle.load(sharedLibraryPath);

    final tempDir = await getTemporaryDirectory();
    final libraryFile = File('${tempDir.path}/lib7zr.so');
    final createdFile = await libraryFile.create();
    final openFile = await createdFile.open(mode: FileMode.write);
    final writtenFile =
        await openFile.writeFrom(Uint8List.view(sharedLibraryContent.buffer));
    await writtenFile.close();

    return libraryFile.path;
  }
}
