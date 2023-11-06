// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/settings/settings.dart';

class SignUpDialog extends StatefulWidget {
  const SignUpDialog({super.key});

  @override
  State<SignUpDialog> createState() => _SignUpDialogState();
}

class _SignUpDialogState extends State<SignUpDialog> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwaController = TextEditingController();
  final TextEditingController _nnController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Widget yesButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: const Text('Sign Up'),
      onPressed: () async {
        var id = _idController.text.trim();
        var pw = _pwController.text.trim();
        var pwa = _pwaController.text.trim();
        var nn = _nnController.text.trim();

        if (pw != pwa || pw.length < 8) {
          await showOkDialog(context,
              'Please check your password. Pw and Pw Again must be the same, and must be at least 8 characters long.');
          return;
        }

        if (await VioletCommunitySession.checkId(id) != 'success') {
          await showOkDialog(
              context, 'Id already exists. Please use a different ID.');
          return;
        }

        if (await VioletCommunitySession.checkNickName(nn) != 'success') {
          await showOkDialog(context,
              'NickName already exists. Please use a different NickName.');
          return;
        }

        Navigator.pop(context,
            [_idController.text, _pwController.text, _nnController.text]);
      },
    );
    Widget noButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: const Text('Cancel'),
      onPressed: () {
        Navigator.pop(context, null);
      },
    );

    return AlertDialog(
      title: const Text('Sign Up'),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      actions: [
        yesButton,
        noButton,
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(children: [
            const Text('Id: '),
            Expanded(
              child: TextField(
                controller: _idController,
              ),
            ),
          ]),
          Row(
            children: [
              const Text('Pw: '),
              Expanded(
                child: TextField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: _pwController,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Pw Again: '),
              Expanded(
                child: TextField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: _pwaController,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Text('NickName: '),
              Expanded(
                child: TextField(
                  controller: _nnController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
