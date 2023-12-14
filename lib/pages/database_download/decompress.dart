// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/path.dart';

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
      final binPath = await _checkBinary();
      if(binPath == null){
        return null;
      }
      final filesStr = files.join(' ');
      await ((()async{
        Process process = await Process.start(
          "chmod",
            [
              "+x",
              "${(await DefaultPathProvider.getBaseDirectory())}/7zr",
            ],
        );
        await process.stdout
            .transform(utf8.decoder)
            .forEach(print);
      })());
      await ((()async{
        Process process = await Process.start(
            "${(await DefaultPathProvider.getBaseDirectory())}/7zr",
            [
                "e","$filesStr",
                "-o$path"
            ],
        );
        await process.stdout
            .transform(utf8.decoder)
            .forEach(print);
      })());
      // return null;
      return path;
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
    if(await libraryFile.exists()){
      await libraryFile.delete();
    }
    final createdFile = await libraryFile.create();
    final openFile = await createdFile.open(mode: FileMode.write);
    final writtenFile =
        await openFile.writeFrom(Uint8List.view(sharedLibraryContent.buffer));
    await writtenFile.close();

    return libraryFile.path;
  }
  Future<String?> _checkBinary() async {
    if(!Platform.isLinux){
      return null;
    }

    var _arch = await ((()async{
      var _a = '';
      // https://stackoverflow.com/questions/70247458/flutter-dart-print-output-of-all-child-processes-to-stdout
      Process process = await Process.start(
          "uname",
          [
              "-m"
          ],
      );

      await process.stdout
          .transform(utf8.decoder)
          .forEach((value){
            if(_a.isEmpty){
              _a = value.replaceAll('\r', '').replaceAll('\n', '');
            }
          });
      if((_a.contains('arm') || _a.contains('aarch')) && (_a.contains('32') || _a.contains('v7'))) return 'armv7';
      if((_a.contains('arm') || _a.contains('aarch')) && (_a.contains('64') || _a.contains('v8'))) return 'armv8';
      if(_a == 'x86_64' || _a == 'amd64') return 'x86_64';
      if((_a.contains('i') || _a.contains('x')) && _a.contains('86') && !_a.contains('64')) return 'x86';
    })());
    final binaryPath = 'assets/p7zip/linux/$_arch/7zr';
    final binaryContent = await rootBundle.load(binaryPath);
    final tempDir = await DefaultPathProvider.getBaseDirectory();
    final binaryFile = File('${tempDir}/7zr');
    if(await binaryFile.exists()){
      await binaryFile.delete();
    }
    if(await Directory('${tempDir}/').exists()){
      Logger.info('${tempDir}/ exists');
    }
    final createdFile = await binaryFile.create();
    final openFile = await createdFile.open(mode: FileMode.write);
    final writtenFile =
        await openFile.writeFrom(Uint8List.view(binaryContent.buffer));
    await writtenFile.close();

    return binaryFile.path;
  }
}
