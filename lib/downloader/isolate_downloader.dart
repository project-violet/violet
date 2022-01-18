// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:dio_http_cache/dio_http_cache.dart';
import 'package:violet/component/downloadable.dart';

enum SendPortType {
  init,
  append,
  test,
}

class SendPortData {
  final dynamic data;
  final SendPortType type;

  const SendPortData({this.type, this.data});
}

enum ReceivePortType {
  append,
  progresss,
  complete,
}

class ReceivePortData {
  final dynamic data;
  final ReceivePortType type;

  const ReceivePortData({this.type, this.data});
}

class IsolateDownloaderTask {
  final int id;
  final String url;
  final String fullpath;
  final CancelToken cancelToken;
  final Map<String, dynamic> header;

  IsolateDownloaderTask({
    this.id,
    this.url,
    this.fullpath,
    this.header,
    this.cancelToken,
  });

  static IsolateDownloaderTask fromDownloadTask(
      int taskId, DownloadTask task, CancelToken cancelToken) {
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
      cancelToken: cancelToken,
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

class IsolateDownloaderOption {
  final int threadCount;

  IsolateDownloaderOption({this.threadCount});
}

class IsolateDownloaderProgressProtocolUnit {
  final int id;
  final int countSize;
  final int totalSize;

  IsolateDownloaderProgressProtocolUnit({
    this.id,
    this.countSize,
    this.totalSize,
  });
}

int _taskTotalCount = 0;
int _taskCurrentCount = 0;
int _maxTaskCount = 0;
SendPort _sendPort;
Queue<IsolateDownloaderTask> _dqueue;
Map<int, IsolateDownloaderTask> _workingMap;

Future<void> _processTask(IsolateDownloaderTask task) async {
  _sendPort.send(ReceivePortData(type: ReceivePortType.append, data: task.id));

  var options = BaseOptions(
    contentType: Headers.formUrlEncodedContentType,
  );
  var dio = Dio(options);

  for (var kv in task.header.entries) {
    dio.options.headers[kv.key] = kv.value;
  }

  // dio.interceptors.add(DioCacheManager(
  //   CacheConfig(
  //     skipDiskCache: true,
  //     maxMemoryCacheCount: 1000,
  //   ),
  // ).interceptor as Interceptor);

  await dio.download(
    task.url,
    task.fullpath,
    cancelToken: task.cancelToken,
    onReceiveProgress: (count, total) {
      _sendPort.send(
        ReceivePortData(
          type: ReceivePortType.progresss,
          data: IsolateDownloaderProgressProtocolUnit(
            id: task.id,
            countSize: count,
            totalSize: total,
          ),
        ),
      );
    },
  );

  _sendPort
      .send(ReceivePortData(type: ReceivePortType.complete, data: task.id));
  _taskCurrentCount -= 1;
  _workingMap.remove(task.id);
  _resolveQueue();
}

void _resolveQueue() {
  if (_dqueue.isEmpty) return;
  if (_taskCurrentCount < _maxTaskCount) {
    _taskCurrentCount += 1;
    final _itask = _dqueue.removeFirst();
    _workingMap[_itask.id] = _itask;
    _processTask(_itask);
  }
}

void _appendTask(DownloadTask task) {
  var token = CancelToken();
  var itask =
      IsolateDownloaderTask.fromDownloadTask(_taskTotalCount++, task, token);
  _dqueue.add(itask);
  _resolveQueue();
}

void _initIsolateDownloader(IsolateDownloaderOption option) {
  _dqueue = Queue<IsolateDownloaderTask>();
  _workingMap = Map<int, IsolateDownloaderTask>();
  _maxTaskCount = option.threadCount;
}

void _downloadIsolateRoutine(SendPort sendPort) {
  final ReceivePort _receivePort = ReceivePort();
  sendPort.send(_receivePort.sendPort);
  _sendPort = sendPort;

  _receivePort.listen((dynamic message) async {
    if (message is SendPortData) {
      switch (message.type) {
        case SendPortType.init:
          _initIsolateDownloader(message.data as IsolateDownloaderOption);
          break;
        case SendPortType.append:
          _appendTask(message.data as DownloadTask);
          break;
        case SendPortType.test:
          var ttask = message.data as List<String>;
          break;
      }
    }
  });
}

class IsolateDownloader {
  final ReceivePort _receivePort = ReceivePort();
  SendPort _sendPort;
  Isolate _isolate;

  Future<void> init() async {
    _receivePort.listen((dynamic message) => _listen(message));
    _isolate =
        await Isolate.spawn(_downloadIsolateRoutine, _receivePort.sendPort);
  }

  bool isReady() => _sendPort != null;

  Future<void> _listen(dynamic message) async {
    if (message is SendPort) {
      print('[listen] SendPort received!');
      _sendPort = message;
      _sendPort.send(
        SendPortData(
          type: SendPortType.init,
          data: IsolateDownloaderOption(threadCount: 4),
        ),
      );
    } else if (message is ReceivePortData) {
      switch (message.type) {
        case ReceivePortType.append:
          print('[append] ${message.data as int}');
          break;
        case ReceivePortType.progresss:
          var unit = message.data as IsolateDownloaderProgressProtocolUnit;
          print('[progress] ${unit.id} ${unit.countSize}/${unit.totalSize}');
          break;
        case ReceivePortType.complete:
          print('[complete] ${message.data as int}');
          break;
      }
    }
  }

  void close() {
    _isolate.kill(priority: Isolate.immediate);
  }

  void appendTask(DownloadTask task) {
    _sendPort.send(SendPortData(type: SendPortType.append, data: task));
  }
}
