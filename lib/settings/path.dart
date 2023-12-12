// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/log/log.dart';

class DefaultPathProvider {
  static Future<String> getHomeDirectory() async{
    var home = '';
    if(Platform.isLinux){
      Platform.environment.forEach((key, value) {
        if(key == 'HOME'){
          home = value;
        }
      });
      return home;
    }
    Logger.error('[getHomeDirectory] unsupported os');
    throw Error();
  }
  static Future<String> getBaseDirectory() async {
    if(Platform.isAndroid){
      return '${(await getApplicationDocumentsDirectory()).path}';
    } else if(Platform.isIOS){
      return '${(await getDatabasesPath())}';
    } else if(Platform.isLinux){
      return '${(await getHomeDirectory())}/.violet';
    }
    Logger.error('[getBaseDirectory] unsupported os');
    throw Error();
  }
  static Future<String> getDocumentsDirectory() async {
    if(Platform.isAndroid || Platform.isIOS){
      return '${(await getApplicationDocumentsDirectory()).path}';
    } else if(Platform.isLinux){
      return '${(await getHomeDirectory())}/.violet';
    }
    Logger.error('[getDocumentsDirectory] unsupported os');
    throw Error();
  }
  static Future<String> getSupportDirectory() async {
    if(Platform.isAndroid){
      return '${(await getApplicationDocumentsDirectory()).path}';
    } else if(Platform.isIOS){
      return '${(await getApplicationSupportDirectory()).path}';
    } else if(Platform.isLinux){
      return '${(await getHomeDirectory())}/.violet';
    }
    Logger.error('[getSupportDirectory] unsupported os');
    throw Error();
  }
  static Future<String> getExportDirectory() async {
    if(Platform.isAndroid){
      return '${(await getExternalStorageDirectory())}';
    } else if(Platform.isIOS){
      return '${(await getApplicationSupportDirectory()).path}';
    } else if(Platform.isLinux){
      return '${(await getHomeDirectory())}/.violet';
    }
    Logger.error('[getExportDirectory] unsupported os');
    throw Error();
  }
}