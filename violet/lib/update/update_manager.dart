// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_downloader/flutter_downloader.dart'; // @dependent: android
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/platform/android_external_storage_directory.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/version/update_sync.dart';

class UpdateManager {
  static Future<void> updateCheck(BuildContext context) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) return;

    await UpdateSyncManager.checkUpdateSync();

    // Update is only available for Android.
    if (Platform.isAndroid) {
      if (!context.mounted) return;
      updateCheckAndDownload(context); // @dependent: android
    }
  }

  // @dependent: android [
  static final ReceivePort _port = ReceivePort();

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  static void updateCheckAndDownload(BuildContext context) {
    bool updateContinued = false;
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      if (UpdateSyncManager.updateRequire) {
        var bb = await showYesNoDialog(context,
            '${Translations.instance!.trans('newupdate')} ${UpdateSyncManager.updateMessage} ${Translations.instance!.trans('wouldyouupdate')}');
        if (bb == false) return;
      } else {
        return;
      }

      if (!await Permission.manageExternalStorage.isGranted) {
        if (await Permission.manageExternalStorage.request() ==
            PermissionStatus.denied) {
          if (!context.mounted) return;
          await showOkDialog(context,
              'If you do not allow file permissions, you cannot continue :(');
          return;
        }
      }
      updateContinued = true;

      final ext = await AndroidExternalStorageDirectory.instance
          .getExternalStorageDownloadsDirectory();

      bool once = false;
      IsolateNameServer.registerPortWithName(
          _port.sendPort, 'downloader_send_port');
      _port.listen((dynamic data) {
        int progress = data[2];
        if (progress == 100 && !once) {
          OpenFile.open('$ext/${UpdateSyncManager.updateUrl.split('/').last}');
          once = true;
        }
      });

      if (await File('$ext/${UpdateSyncManager.updateUrl.split('/').last}')
          .exists()) {
        await File('$ext/${UpdateSyncManager.updateUrl.split('/').last}')
            .delete();
      }

      FlutterDownloader.registerCallback(downloadCallback);
      await FlutterDownloader.enqueue(
        url: UpdateSyncManager.updateUrl,
        savedDir: ext,
        fileName: UpdateSyncManager.updateUrl.split('/').last,
        showNotification: true,
        openFileFromNotification: true,
      );
    }).then((value) async {
      if (updateContinued) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('usevioletserver_check') != null) return;

      if (!context.mounted) return;
      final bb = await showYesNoDialog(
          context, Translations.instance!.trans('violetservermsg'));
      if (bb == false) {
        await prefs.setBool('usevioletserver_check', false);
        return;
      }

      await Settings.setUseVioletServer(true);
      await prefs.setBool('usevioletserver_check', false);
    });
  }

  // @dependent: android ]
}
