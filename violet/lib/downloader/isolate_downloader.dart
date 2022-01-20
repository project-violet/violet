// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:violet/component/downloadable.dart';

part './isolate/core.dart';

enum DownloadTaskState {
  wait,
  append,
  downloading,
  complete,
  error,
  cancel,
}

class DownloadTaskStatus {
  final DownloadTaskState state;

  // downloading
  final int totalSize;
  final int countSize;

  // error
  final String errorContent;
  final String stackTraceContent;

  DownloadTaskStatus({
    this.state,
    this.totalSize,
    this.countSize,
    this.errorContent,
    this.stackTraceContent,
  });
}

class IsolateDownloader {
  final ReceivePort _receivePort = ReceivePort();
  SendPort _sendPort;
  Isolate _isolate;
  Map<int, DownloadTask> _tasks;
  int _taskTotalCount;
  Map<int, int> _taskTotalSizes;
  Map<int, int> _taskCountSizes;
  HashSet<int> _appendedTask;
  HashSet<int> _completedTask;
  HashSet<int> _erroredTask;
  HashSet<int> _canceledTask;
  Map<int, IsolateDownloaderErrorUnit> _errorContent;

  static IsolateDownloader _instance;
  static Future<IsolateDownloader> getInstance() async {
    if (_instance == null) {
      _instance = IsolateDownloader();
      await _instance.init();
    }

    return _instance;
  }

  Future<void> init() async {
    _receivePort.listen((dynamic message) => _listen(message));
    _isolate =
        await Isolate.spawn(_downloadIsolateRoutine, _receivePort.sendPort);
    _tasks = Map<int, DownloadTask>();
    _taskTotalSizes = Map<int, int>();
    _taskCountSizes = Map<int, int>();
    _appendedTask = HashSet<int>();
    _completedTask = HashSet<int>();
    _erroredTask = HashSet<int>();
    _canceledTask = HashSet<int>();
    _errorContent = Map<int, IsolateDownloaderErrorUnit>();
    _taskTotalCount = 0;
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
          // print('[append] ${message.data as int}');
          _appendedTask.add(message.data as int);
          break;
        case ReceivePortType.progresss:
          var unit = message.data as IsolateDownloaderProgressProtocolUnit;
          // print('[progress] ${unit.id} ${unit.countSize}/${unit.totalSize}');
          _progressTask(unit);
          break;
        case ReceivePortType.complete:
          // print('[complete] ${message.data as int}');
          _completeTask(message.data as int);
          break;
        case ReceivePortType.error:
          _errorTask(message.data as IsolateDownloaderErrorUnit);
          break;
      }
    }
  }

  void cancel(int taskId) {
    _sendPort.send(SendPortData(type: SendPortType.cancel, data: taskId));
    _canceledTask.add(taskId);
    _tasks.remove(taskId);
  }

  void close() {
    _sendPort.send(SendPortData(type: SendPortType.terminate));
    _isolate.kill(priority: Isolate.immediate);
  }

  void appendTask(DownloadTask task) {
    task.taskId = _taskTotalCount++;
    _tasks[task.taskId] = task;
    _sendPort.send(
      SendPortData(
        type: SendPortType.append,
        data: IsolateDownloaderTask.fromDownloadTask(task.taskId, task),
      ),
    );
  }

  void appendTasks(List<DownloadTask> tasks) {
    for (var task in tasks) {
      appendTask(task);
    }
  }

  DownloadTaskStatus getStatus(int taskId) {
    if (_appendedTask.contains(taskId)) {
      if (_canceledTask.contains(taskId)) {
        return DownloadTaskStatus(
          state: DownloadTaskState.cancel,
        );
      }

      if (_erroredTask.contains(taskId)) {
        return DownloadTaskStatus(
          state: DownloadTaskState.error,
          errorContent: _errorContent[taskId].error,
          stackTraceContent: _errorContent[taskId].stackTrace,
        );
      }

      if (_completedTask.contains(taskId)) {
        return DownloadTaskStatus(state: DownloadTaskState.complete);
      }

      if (_taskCountSizes.containsKey(taskId)) {
        return DownloadTaskStatus(
          state: DownloadTaskState.downloading,
          totalSize: _taskTotalSizes[taskId],
          countSize: _taskCountSizes[taskId],
        );
      }

      return DownloadTaskStatus(state: DownloadTaskState.append);
    }

    return DownloadTaskStatus(state: DownloadTaskState.wait);
  }

  void _progressTask(IsolateDownloaderProgressProtocolUnit unit) {
    if (!_tasks[unit.id].isSizeEnsued) {
      _tasks[unit.id].isSizeEnsued = true;
      if (_tasks[unit.id].sizeCallback != null)
        _tasks[unit.id].sizeCallback(unit.totalSize.toDouble());
    }
    if (_tasks[unit.id].downloadCallback != null)
      _tasks[unit.id].downloadCallback(
          (unit.countSize - _tasks[unit.id].accDownloadSize).toDouble());
    _taskTotalSizes[unit.id] = unit.totalSize;
    _taskCountSizes[unit.id] = unit.countSize;
    _tasks[unit.id].accDownloadSize = unit.countSize;
  }

  void _completeTask(int taskId) {
    if (_tasks[taskId].completeCallback != null)
      _tasks[taskId].completeCallback();
    _tasks.remove(taskId);
    _taskCountSizes.remove(taskId);
    _taskTotalSizes.remove(taskId);
    _completedTask.add(taskId);
  }

  void _errorTask(IsolateDownloaderErrorUnit unit) {
    if (_tasks[unit.id].errorCallback != null)
      _tasks[unit.id].errorCallback(unit.error);
    _tasks.remove(unit.id);
    _erroredTask.add(unit.id);
    _errorContent[unit.id] = unit;
  }
}
