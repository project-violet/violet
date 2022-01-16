// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:violet/component/downloadable.dart';

class CancellationToken {
  final Completer _completer = Completer();

  bool isCancelled = false;

  void cancel() {
    isCancelled = true;
    _completer.complete();
  }
}

class IsolateDownloaderTask {
  final int id;
  final String url;
  final String fullpath;
  final CancellationToken cancellationToken;
  final Map<String, dynamic> header;

  IsolateDownloaderTask({
    this.id,
    this.url,
    this.fullpath,
    this.header,
    this.cancellationToken,
  });

  static IsolateDownloaderTask fromDownloadTask(
      int taskId, DownloadTask task, CancellationToken cancellationToken) {
    var header = Map<String, String>();
    if (task.referer != null) header['referer'] = task.referer;
    if (task.accept != null) header['accept'] = task.accept;
    if (task.userAgent != null) header['user-agent'] = task.userAgent;
    if (task.headers != null) {
      task.headers.entries.forEach((element) {
        header[element.key.toLowerCase()] = element.value;
      });
    }
    return IsolateDownloaderTask(
      id: taskId,
      url: task.url,
      fullpath: task.downloadPath,
      header: header,
      cancellationToken: cancellationToken,
    );
  }

  String toString() {
    return jsonEncode({
      "id": id,
      "url": url,
      "fullpath": fullpath,
      "header": header,
    });
  }
}

void _downloadIsolateRoutine(SendPort sendPort) {
  final ReceivePort _receivePort = ReceivePort();
  sendPort.send(_receivePort.sendPort);

  _receivePort.listen((dynamic message) async {});
}

void _donwnloadImage() {}

enum SendPortType {
  init,
  append,
}

class SendPortData {
  final dynamic data;
  final SendPortType type;

  const SendPortData({this.type, this.data});
}

class IsolateDownloader {
  final ReceivePort _receivePort = ReceivePort();
  SendPort _sendPort;
  Isolate _isolate;

  Future<void> init() async {
    _isolate =
        await Isolate.spawn(_downloadIsolateRoutine, _receivePort.sendPort);

    _receivePort.listen((dynamic message) => _listen(
          message,
        ));
  }

  Future<void> _listen(dynamic message) async {
    if (message is SendPort) {
      _sendPort = message;
      _sendPort.send(
        SendPortData(type: SendPortType.init, data: "init"),
      );
    }
  }

  Future<void> appendTask(DownloadTask task) async {}
}
