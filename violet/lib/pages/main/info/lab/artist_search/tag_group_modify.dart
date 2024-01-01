// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/main/info/lab/artist_search/tag_group_modify_controller.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/pages/settings/tag_selector.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/locale/locale.dart' as trans;

class TagGroupModify extends StatefulWidget {
  final Map<String, int> tagGroup;

  const TagGroupModify({super.key, required this.tagGroup});

  @override
  State<TagGroupModify> createState() => _TagGroupModifyState();
}

class _TagGroupModifyState extends State<TagGroupModify> {
  late final TagGroupModifyController c;
  late final String getxId;

  @override
  void initState() {
    super.initState();
    getxId = const Uuid().v4();
    c = Get.put(TagGroupModifyController(widget.tagGroup), tag: getxId);
  }

  @override
  void dispose() {
    super.dispose();
    Get.delete<TagGroupModifyController>(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: CardPanel.build(
        context,
        enableBackgroundColor: true,
        child: Column(
          children: [
            Expanded(
              child: Obx(
                () => ListView.builder(
                  itemCount: c.items.length,
                  itemBuilder: (context, index) {
                    return _TagGroupItem(
                      getxId: getxId,
                      index: index,
                    );
                  },
                ),
              ),
            ),
            buttonArea(),
          ],
        ),
      ),
    );
  }

  buttonArea() {
    return Row(
      children: [
        Container(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Settings.majorColor,
            ),
            child: const Text('Add'),
            onPressed: () => showAddTagDialog(context),
          ),
        ),
        Container(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Settings.majorColor,
            ),
            child: const Text('Remove All'),
            onPressed: () => c.removeAll(),
          ),
        ),
        Container(width: 8),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Settings.majorColor,
            ),
            child: const Text('Apply'),
            onPressed: () => apply(context),
          ),
        ),
        Container(width: 8),
      ],
    );
  }

  apply(BuildContext context) async {
    if (c.items.isEmpty) {
      await showOkDialog(context, 'There must be at least one item.');
      return;
    }

    Navigator.pop(context, Map.fromEntries(c.items.entries));
  }

  showAddTagDialog(BuildContext context) async {
    final vv = await showDialog(
      context: context,
      builder: (BuildContext context) => const TagSelectorDialog(
        what: 'addtag',
        onlyFMT: true,
      ),
    );

    if (vv != null && vv.item1 == 1) {
      c.addItems((vv.item2 as String)
          .split(' ')
          .where((element) => element.trim().isNotEmpty)
          .toList());
    }
  }
}

class _TagGroupItem extends StatelessWidget {
  final int index;
  late final TagGroupModifyController c;

  _TagGroupItem({required String getxId, required this.index}) {
    c = Get.find(tag: getxId);
  }

  @override
  Widget build(BuildContext context) {
    final item = c.getItem(index);
    return ListTile(
      title: Text(item.key),
      subtitle: Text('count: ${item.value.toString()}'),
      dense: true,
      trailing: IconButton(
        icon: const Icon(Icons.dangerous),
        onPressed: () {
          c.removeItem(item.key);
        },
      ),
      onTap: () => showCountModifyDialog(context, item),
    );
  }

  showCountModifyDialog(
      BuildContext context, MapEntry<String, int> item) async {
    final countController = TextEditingController(text: item.value.toString());

    Widget okButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: Text(trans.Translations.of(context).trans('ok')),
      onPressed: () {
        Navigator.pop(context, true);
      },
    );

    Widget cancelButton = TextButton(
      style: TextButton.styleFrom(foregroundColor: Settings.majorColor),
      child: Text(trans.Translations.of(context).trans('cancel')),
      onPressed: () {
        Navigator.pop(context, false);
      },
    );

    final dialog = await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        actions: [okButton, cancelButton],
        title: Text(item.key),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: [
                const Text('Count: '),
                Expanded(
                  child: TextField(
                    controller: countController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ], // Only numbers can be entered
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (dialog != null && dialog == true) {
      c.modifyItem(item.key, int.parse(countController.text));
    }
  }
}
