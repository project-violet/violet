// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/toast.dart';

class LockScreen extends StatefulWidget {
  final bool isRegisterMode;
  final bool isSecureMode;

  const LockScreen(
      {super.key, this.isRegisterMode = false, this.isSecureMode = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  List<int?> _pin = List.filled(4, null);
  bool _isFirstPINInserted = false;
  String? _firstPIN;
  String? _message;
  late final FToast fToast;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);

    _controller = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this)
      ..addListener(() => setState(() {}));

    _animation = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.elasticIn));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _message ??= widget.isRegisterMode
        ? Translations.of(context).trans('insertpinforregister')
        : Translations.of(context).trans('insertpinforcheck');
  }

  @override
  Widget build(BuildContext context) {
    final header = Text(
      Translations.of(context).trans('pinauth'),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20.0,
      ),
    );

    final pinNumber = SizedBox(
      width: 200.0,
      height: 30.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(child: _pinIcon(0), width: 12.0),
          SizedBox(child: _pinIcon(1), width: 12.0),
          SizedBox(child: _pinIcon(2), width: 12.0),
          SizedBox(child: _pinIcon(3), width: 12.0),
        ],
      ),
    );

    final passwordMissing = SizedBox(
      height: 64.0,
      child: Center(
        child: GestureDetector(
          onTap: _passwordMissing,
          child: Text.rich(TextSpan(
              text: Translations.of(context).trans('missingpass'),
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ))),
        ),
      ),
    );

    final numPad = SizedBox(
      height: 300.0,
      child: Column(
        children: [
          _numberRow([
            _button(1, '1'),
            _button(2, '2'),
            _button(3, '3'),
          ]),
          _numberRow([
            _button(4, '4'),
            _button(5, '5'),
            _button(6, '6'),
          ]),
          _numberRow([
            _button(7, '7'),
            _button(8, '8'),
            _button(9, '9'),
          ]),
          _numberRow([
            _button(-2, ''),
            _button(0, '0'),
            _button(-1, ''),
          ]),
        ],
      ),
    );

    final contents = Column(
      children: [
        header,
        Container(height: 8.0),
        Text(_message!),
        Container(height: 36),
        const Icon(Icons.lock),
        const Spacer(),
        pinNumber,
        const Spacer(),
        passwordMissing,
        numPad
      ],
    );

    final page = Material(
      color: Settings.themeBlack && Settings.themeWhat ? Colors.black : null,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          child: Transform.translate(
            offset: Offset(_animation.value * 12.0, 0.0),
            child: contents,
          ),
        ),
      ),
    );

    return WillPopScope(
      onWillPop: () async {
        return widget.isRegisterMode;
      },
      child: page,
    );
  }

  _pinIcon(index) {
    if (_pin[index] == null) {
      return const SizedBox(
        width: 10.0,
        height: 10.0,
        child: Material(
          color: Color.fromARGB(255, 207, 207, 207),
          type: MaterialType.circle,
        ),
      );
    }

    return Text(
      _pin[index].toString(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20.0,
      ),
    );
  }

  _numberRow(List<Widget> items) {
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: Row(children: items),
          )
        ],
      ),
    );
  }

  _button(index, text) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          child: Ink(
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: InkWell(
              customBorder: const CircleBorder(),
              child: Center(
                child: index == -1
                    ? const Icon(Icons.backspace)
                    // : index == -2
                    //     ? Icon(Icons.fingerprint)
                    : Text(text,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20.0)),
              ),
              onTap: () async {
                var pos = _pin.indexOf(null);

                SystemSound.play(SystemSoundType.click);
                HapticFeedback.lightImpact();

                if (index == -1) {
                  if (pos == -1) pos = 4;
                  if (pos != 0) setState(() => _pin[pos - 1] = null);
                } else if (index >= 0) {
                  if (pos == -1) pos = 0;
                  setState(() => _pin[pos] = index);

                  if (pos == 3) {
                    _checkPasswordIsCorret();
                  }
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _passwordMissing() async {
    final Widget yesButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: Text(Translations.of(context).trans('ok')),
      onPressed: () {
        Navigator.pop(context, true);
      },
    );

    final Widget noButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: Text(Translations.of(context).trans('cancel')),
      onPressed: () {
        Navigator.pop(context, false);
      },
    );

    final TextEditingController text = TextEditingController();

    final dialog = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (BuildContext context) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        title: Text(Translations.of(context).trans('entersecondpass')),
        content: TextField(
          controller: text,
          autofocus: true,
        ),
        actions: [yesButton, noButton],
      ),
    );

    if (dialog != null && dialog) {
      if (text.text == 'violet.jjang') {
        await showOkDialog(context, Translations.of(context).trans('resetpin'),
            Translations.of(context).trans('authmanager'));

        Navigator.pushReplacementNamed(context, '/SplashPage');
      } else {
        _controller.forward();
        Future.delayed(const Duration(milliseconds: 300)).then((value) {
          _controller.reverse();
          setState(() {});
        });
        await showOkDialog(
            context,
            Translations.of(context).trans('notcorrectsecondpass'),
            Translations.of(context).trans('authmanager'));
      }
    }
  }

  Future<void> _checkPasswordIsCorret() async {
    final prefs = await SharedPreferences.getInstance();
    final pinPass = prefs.getString('pinPass');

    if (!widget.isRegisterMode && _pin.join() == pinPass) {
      if (widget.isSecureMode) {
        Navigator.of(context).pop();
      } else {
        Navigator.pushReplacementNamed(context, '/SplashPage');
      }
      return;
    }

    final passwordIncorrect =
        (!widget.isRegisterMode && _pin.join() != pinPass) ||
            (widget.isRegisterMode &&
                _isFirstPINInserted &&
                _pin.join() != _firstPIN);

    if (passwordIncorrect) {
      passwordIncorrectInteraction();
    } else {
      if (_isFirstPINInserted) {
        await passwordRegisterInteraction(prefs);
      } else {
        passwordAgainInteraction();
      }
    }
  }

  void passwordIncorrectInteraction() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 300)).then((value) {
      _controller.reverse();
      _pin = List.filled(4, null);
      setState(() {
        _message = Translations.of(context).trans('pinisnotcorrect');
      });
    });
  }

  Future<void> passwordRegisterInteraction(SharedPreferences prefs) async {
    await prefs.setString('pinPass', _pin.join());
    Future.delayed(const Duration(milliseconds: 300)).then((value) {
      fToast.showToast(
        child: ToastWrapper(
          isCheck: true,
          isWarning: false,
          msg: Translations.of(context).trans('pinisregistered'),
        ),
        ignorePointer: true,
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 4),
      );
      Navigator.pop(context);
    });
  }

  void passwordAgainInteraction() {
    _isFirstPINInserted = true;
    _firstPIN = _pin.join();
    _pin = List.filled(4, null);
    _message = Translations.of(context).trans('retrypin');
    Future.delayed(const Duration(milliseconds: 300)).then((value) {
      setState(() {});
    });
  }
}
