// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/lock/lock_screen.dart';
import 'package:violet/settings/settings.dart';

class LockSettingPage extends StatefulWidget {
  const LockSettingPage({super.key});

  @override
  State<LockSettingPage> createState() => _LockSettingPageState();
}

class _LockSettingPageState extends State<LockSettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red,
        title: const Text('LOCK SETTING'),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.numbers),
            title: Text(Translations.instance!.trans('pinsetting')),
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const LockScreen(
                    isRegisterMode: true,
                  ),
                ),
              );
            },
            trailing: FutureBuilder(
                future: SharedPreferences.getInstance(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('');

                  if ((snapshot.data as SharedPreferences)
                          .getString('pinPass') !=
                      null) {
                    return Text(Translations.instance!.trans('setted'));
                  }
                  return Text(Translations.instance!.trans('notsetted'));
                }),
          ),
          Container(
            width: double.infinity,
            height: 0.5,
            color: Settings.themeWhat
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.fingerprint),
            title: Text(Translations.instance!.trans('fingersetting')),
            onTap: () {},
            trailing: Text(Translations.instance!.trans('notsetted')),
          ),
          Container(
            width: double.infinity,
            height: 0.5,
            color: Settings.themeWhat
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          ListTile(
            enabled: false,
            leading: const Icon(MdiIcons.humanMaleBoard),
            title: Text(Translations.instance!.trans('etchumansetting')),
            onTap: () {},
            trailing: Text(Translations.instance!.trans('notsetted')),
          ),
          Container(
            width: double.infinity,
            height: 0.5,
            color: Settings.themeWhat
                ? Colors.grey.shade600
                : Colors.grey.shade400,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(Translations.instance!.trans('useapplocksetting')),
            onTap: () async {
              _toggleAppLock();
            },
            trailing: Switch(
              activeTrackColor: Colors.red,
              activeColor: Colors.redAccent,
              value: Settings.useLockScreen,
              onChanged: (value) async {
                _toggleAppLock();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('pinPass') == null) {
      if (!mounted) return;
      showOkDialog(
          context, Translations.instance!.trans('registerfinbeforeuseapplock'));
      return;
    }

    await Settings.setUseLockScreen(!Settings.useLockScreen);
    setState(() {});
  }
}
