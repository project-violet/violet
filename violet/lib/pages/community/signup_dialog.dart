// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/settings/settings.dart';

class SignUpDialog extends StatelessWidget {
  TextEditingController idController = TextEditingController();
  TextEditingController pwController = TextEditingController();
  TextEditingController pwaController = TextEditingController();
  TextEditingController nnController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    Widget yesButton = FlatButton(
      child: Text('Sign Up', style: TextStyle(color: Settings.majorColor)),
      focusColor: Settings.majorColor,
      splashColor: Settings.majorColor.withOpacity(0.3),
      onPressed: () async {
        var id = idController.text.trim();
        var pw = pwController.text.trim();
        var pwa = pwaController.text.trim();
        var nn = nnController.text.trim();

        if (pw != pwa || pw.length < 8) {
          await Dialogs.okDialog(context,
              'Please check your password. Pw and Pw Again must be the same, and must be at least 8 characters long.');
          return;
        }

        if (await VioletCommunitySession.checkId(id) != 'success') {
          await Dialogs.okDialog(
              context, 'Id already exists. Please use a different ID.');
          return;
        }

        if (await VioletCommunitySession.checkNickName(nn) != 'success') {
          await Dialogs.okDialog(context,
              'NickName already exists. Please use a different NickName.');
          return;
        }

        Navigator.pop(
            context, [idController.text, pwController.text, nnController.text]);
      },
    );
    Widget noButton = FlatButton(
      child: Text('Cancel', style: TextStyle(color: Settings.majorColor)),
      focusColor: Settings.majorColor,
      splashColor: Settings.majorColor.withOpacity(0.3),
      onPressed: () {
        Navigator.pop(context, null);
      },
    );

    return AlertDialog(
      title: Text('Sign Up'),
      contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      actions: [
        yesButton,
        noButton,
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(children: [
            Text('Id: '),
            Expanded(
              child: TextField(
                controller: idController,
              ),
            ),
          ]),
          Row(
            children: [
              Text('Pw: '),
              Expanded(
                child: TextField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: pwController,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('Pw Again: '),
              Expanded(
                child: TextField(
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  controller: pwaController,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text('NickName: '),
              Expanded(
                child: TextField(
                  controller: nnController,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
