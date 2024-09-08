// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/settings/settings.dart';

class GroupModifyPage extends StatefulWidget {
  final String name;
  final String desc;

  const GroupModifyPage({
    super.key,
    required this.name,
    required this.desc,
  });

  @override
  State<GroupModifyPage> createState() => _GroupModifyPageState();
}

class _GroupModifyPageState extends State<GroupModifyPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.name);
    _descController = TextEditingController(text: widget.desc);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(Translations.instance!.trans('modifygroupinfo')),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(children: [
            Text('${Translations.instance!.trans('name')}: '),
            Expanded(
              child: TextField(
                controller: _nameController,
              ),
            ),
          ]),
          Row(children: [
            Text('${Translations.instance!.trans('desc')}: '),
            Expanded(
              child: TextField(
                controller: _descController,
              ),
            ),
          ]),
          Container(
            height: 16,
          ),
          Row(
            children: <Widget>[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(Translations.instance!.trans('delete')),
                onPressed: () async {
                  if (await showYesNoDialog(
                      context,
                      Translations.instance!.trans('deletegroupmsg'),
                      Translations.instance!.trans('bookmark'))) {
                    if (!context.mounted) return;
                    Navigator.pop(context, [2]);
                  }
                },
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Settings.majorColor,
                ),
                child: Text(Translations.instance!.trans('ok')),
                onPressed: () {
                  Navigator.pop(context, [
                    1,
                    _nameController.text,
                    _descController.text,
                  ]);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Settings.majorColor,
                ),
                child: Text(Translations.instance!.trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, [0]);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
