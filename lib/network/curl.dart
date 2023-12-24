// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:violet/log/log.dart';
import 'package:violet/settings/path.dart';

typedef _NativeP7zipShell = NativeFunction<Int32 Function(Pointer<Int8>)>;
typedef _DartP7zipShell = int Function(Pointer<Int8>);

Pointer<Int8> intListToArray(String list) {
  final ptr = malloc.allocate<Int8>(list.length + 1);
  for (var i = 0; i < list.length; i++) {
    ptr.elementAt(i).value = list.codeUnitAt(i);
  }
  ptr.elementAt(list.length).value = 0;
  return ptr;
}

class StaticCurl {
  static Future<http.Response> getHttp3Request(String url,Map<String, String>? headers,[bool? followRedirects = true]) async {
      final binPath = await _checkBinary();
      if(binPath == null){
        throw Error();
      }
      var result = '';
      var log = '';
      await ((()async{
        var options = [];
        headers?.forEach((key, value) {
          options.add('-H');
          options.add('${key}: ${value}');
        });
        Logger.info('[Http3 Request] GET: $url');
        Process process = await Process.start(
            "${(await DefaultPathProvider.getBaseDirectory())}/curl",
            [
                (((followRedirects == null || followRedirects == true) && followRedirects != false) ? "-LsSf" : ''),
                "--http3-only",...(options.length == 0 ? [''] : options),
                // "-H","Pragma: no-cache",
                // "-H","Cache-Control: no-cache",
                "${url}","-vvv"
            ],
        );
        await process.stdout
            .transform(utf8.decoder)
            .forEach((e){
              result += e;
            });
        await process.stderr
            .transform(utf8.decoder)
            .forEach((e){
              log += e;
            });
      })());
      Map<String,String> requestHeaders = Map<String,String>();
      log.split('\r\n').where((element) => element.startsWith('> ')).forEach((element) {
        if(element.contains(':')){
          final _raw = element.substring(2);
          final key = _raw.substring(0,_raw.indexOf(':'));
          final value = _raw.substring(_raw.indexOf(':') + 1,_raw.length);
          requestHeaders[key] = value;
        }
      });
      Map<String,String> responseHeaders = Map<String,String>();
      log.split('\r\n').where((element) => element.startsWith('< ')).forEach((element) {
        if(element.contains(':')){
          final _raw = element.substring(2);
          final key = _raw.substring(0,_raw.indexOf(':')).trim();
          final value = _raw.substring(_raw.indexOf(':') + 1,_raw.length).trim();
          responseHeaders[key] = value;
        }
      });
      var statusCodeString;
      var a = log.split('\r\n').where((element) => element.startsWith('< HTTP/'));
      if(a != null && a.isNotEmpty){
        try{
          statusCodeString = a?.first?.split(' ')?.lastWhere((element) => element.isNotEmpty);
        } catch(e,st){
          if(result.length > 0){
            statusCodeString = '200';
          }
        }
      } else {
        if(result.length > 0){
          statusCodeString = '200';
        }
      }
      var isRedirect = false;
      responseHeaders.forEach((key, value) {
        if(key == 'location'){
          isRedirect = true;
        }
      });
      final statusCode = int.parse(statusCodeString);
      final response = http.Response(result, statusCode,isRedirect: isRedirect,headers: responseHeaders);
      
      return response;
  }

  static const libraryAbis = [
    'arm64-v8a',
    'armeabi-v7a',
    'x86',
    'x86_64',
  ];

  static Future<String?> _checkBinary() async {
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

      await process.stderr
          .transform(utf8.decoder)
          .forEach((value){
            if(_a.isEmpty){
              _a = value.replaceAll('\r', '').replaceAll('\n', '');
            }
          });
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
    final binaryPath = 'assets/static-curl/linux/$_arch/curl';
    final binaryContent = await rootBundle.load(binaryPath);
    final tempDir = await DefaultPathProvider.getBaseDirectory();
    final binaryFile = File('${tempDir}/curl');
    if(await binaryFile.exists()){
      // await binaryFile.delete();
      return binaryFile.path;
    }
    if(await Directory('${tempDir}/').exists()){
      Logger.info('${tempDir}/ exists');
    }
    final createdFile = await binaryFile.create();
    final openFile = await createdFile.open(mode: FileMode.write);
    final writtenFile =
        await openFile.writeFrom(Uint8List.view(binaryContent.buffer));
    await writtenFile.close();
      await ((()async{
        Process process = await Process.start(
          "chmod",
            [
              "+x",
              "${(await DefaultPathProvider.getBaseDirectory())}/curl",
            ],
        );
        await process.stdout
            .transform(utf8.decoder)
            .forEach(print);
      })());

    return binaryFile.path;
  }
}
