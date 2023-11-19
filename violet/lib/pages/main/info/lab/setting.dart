// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/pages/segment/card_panel.dart';
import 'package:violet/settings/settings.dart';

class LabSetting extends StatefulWidget {
  const LabSetting({super.key});

  @override
  State<LabSetting> createState() => _LabSettingState();
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
              title: const Text('Simple item widget loading icon'),
              subtitle: const Text('using circular bar instead of flare'),
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
              title: const Text('Artist article list tap option'),
              subtitle: const Text(
                  'show new viewer when artist article list item tapped'),
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
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('Enable viewer function backdrop filter'),
              subtitle: const Text(
                  'apply ios style blur effect to viewer functions. this blur effect may decrease performance.'),
              trailing: Switch(
                value: Settings.enableViewerFunctionBackdropFilter,
                onChanged: (newValue) async {
                  await Settings.setEnableViewerFunctionBackdropFilter(
                      newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setEnableViewerFunctionBackdropFilter(
                  !Settings.enableViewerFunctionBackdropFilter);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('Using PushReplacement On Article Read'),
              subtitle: const Text(
                  'when tap Read button in the article-info, the article-info closes.'),
              trailing: Switch(
                value: Settings.usingPushReplacementOnArticleRead,
                onChanged: (newValue) async {
                  await Settings.setUsingPushReplacementOnArticleRead(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setUsingPushReplacementOnArticleRead(
                  !Settings.usingPushReplacementOnArticleRead);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('Download E(x)hentai Raw Image'),
              subtitle: const Text(
                  'download the original image. many network errors (connection reset ... etc) can occur during this operation.'),
              trailing: Switch(
                value: Settings.downloadEhRawImage,
                onChanged: (newValue) async {
                  await Settings.setDownloadEhRawImage(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setDownloadEhRawImage(
                  !Settings.downloadEhRawImage);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('Bookmark Scrollbar Position To Left'),
              subtitle: const Text('Reposition Bookmark Scrollber'),
              trailing: Switch(
                value: Settings.bookmarkScrollbarPositionToLeft,
                onChanged: (newValue) async {
                  await Settings.setBookmarkScrollbarPositionToLeft(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setBookmarkScrollbarPositionToLeft(
                  !Settings.bookmarkScrollbarPositionToLeft);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('Vertical Webview Viewer'),
              subtitle: const Text(
                  'It replaces the vertical viewer to webview viewer.'),
              trailing: Switch(
                value: Settings.useVerticalWebviewViewer,
                onChanged: (newValue) async {
                  await Settings.setUseVerticalWebviewViewer(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setUseVerticalWebviewViewer(
                  !Settings.useVerticalWebviewViewer);
              setState(() {});
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(MdiIcons.flask, color: Settings.majorColor),
              title: const Text('In Viewer Message Search'),
              subtitle: const Text(
                  'Support message search on viewer mode.'),
              trailing: Switch(
                value: Settings.inViewerMessageSearch,
                onChanged: (newValue) async {
                  await Settings.setInViewerMessageSearch(newValue);
                  setState(() {});
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setInViewerMessageSearch(
                  !Settings.inViewerMessageSearch);
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
