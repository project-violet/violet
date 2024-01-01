// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

class CallOnce {
  final Function _function;
  bool _isCalled = false;

  CallOnce(this._function);

  void call() {
    if (!_isCalled) {
      _function.call();
      _isCalled = true;
    }
  }
}
