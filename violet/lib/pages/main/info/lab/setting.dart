// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/query.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/model/article_list_item.dart';
import 'package:violet/pages/artist_info/artist_info_page.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/server/community/anon.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/article_item/article_list_item_widget.dart';

class LabSetting extends StatefulWidget {
  @override
  _LabSettingState createState() => _LabSettingState();
}

class _LabSettingState extends State<LabSetting> {
  @override
  Widget build(BuildContext context) {
    return CardPanel.build(
      context,
      enableBackgroundColor: true,
      child: Column(
        children: [
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: Text('Simple item widget loading icon'),
              subtitle: Text('using circular bar instead of flare'),
              trailing: Switch(
                value: Settings.simpleItemWidgetLoadingIcon,
                onChanged: (newValue) async {
                  await Settings.setSimpleItemWidgetLoadingIcon(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setSimpleItemWidgetLoadingIcon(
                  !Settings.simpleItemWidgetLoadingIcon);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: Text('Artist article list tap option'),
              subtitle:
                  Text('show new viewer when artist article list item tapped'),
              trailing: Switch(
                value: Settings.showNewViewerWhenArtistArticleListItemTap,
                onChanged: (newValue) async {
                  await Settings.setShowNewViewerWhenArtistArticleListItemTap(
                      newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setShowNewViewerWhenArtistArticleListItemTap(
                  !Settings.showNewViewerWhenArtistArticleListItemTap);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 8.0,
      ),
      width: double.infinity,
      height: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }
}
