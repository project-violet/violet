// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:violet/locale/locale.dart' as locale;
import 'package:violet/pages/viewer/viewer_controller.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ViewerSettingPanel extends StatefulWidget {
  final String getxId;
  final VoidCallback viewerStyleChangeEvent;
  final VoidCallback thumbSizeChangeEvent;

  const ViewerSettingPanel({
    super.key,
    required this.viewerStyleChangeEvent,
    required this.thumbSizeChangeEvent,
    required this.getxId,
  });

  @override
  State<ViewerSettingPanel> createState() => _ViewerSettingPanelState();
}

class _ViewerSettingPanelState extends State<ViewerSettingPanel> {
  late final ViewerController c;
  int imgqualityOption = Settings.imageQuality;

  @override
  void initState() {
    super.initState();
    c = Get.find(tag: widget.getxId);
  }

  @override
  Widget build(BuildContext context) {
    var listview = ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        ListTile(
          dense: true,
          title: Row(
            children: [
              Text(
                  '${locale.Translations.instance!.trans('timersetting')} '
                  '(${Settings.timerTick.toStringAsFixed(1)}${locale.Translations.instance!.trans('second')})',
                  style: const TextStyle(color: Colors.white)),
              Expanded(
                child: Align(
                  child: SliderTheme(
                    data: const SliderThemeData(
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Color(0xffd0d2d3),
                      trackHeight: 3,
                      thumbShape:
                          RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    ),
                    child: Slider(
                      value: Settings.timerTick,
                      max: 20,
                      min: 1,
                      divisions: (20 - 1) * 2,
                      inactiveColor: Settings.majorColor.withOpacity(0.7),
                      activeColor: Settings.majorColor,
                      onChangeEnd: (value) async {
                        await Settings.setTimerTick(value);
                      },
                      onChanged: (value) {
                        setState(() {
                          Settings.timerTick = value;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _checkBox(
          value: Settings.isHorizontal,
          title: locale.Translations.of(context).trans('toggleviewerstyle'),
          onChanged: (value) async {
            await Settings.setIsHorizontal(!Settings.isHorizontal);

            widget.viewerStyleChangeEvent.call();

            c.viewType.value =
                Settings.isHorizontal ? ViewType.horizontal : ViewType.vertical;
            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.of(context).trans('togglescrollvertical'),
          value: Settings.scrollVertical,
          enabled: Settings.isHorizontal,
          onChanged: (value) async {
            await Settings.setScrollVertical(!Settings.scrollVertical);

            c.viewScrollType.value = Settings.scrollVertical
                ? ViewType.vertical
                : ViewType.horizontal;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.of(context).trans('togglerighttoleft'),
          value: Settings.rightToLeft,
          onChanged: (value) async {
            await Settings.setRightToLeft(!Settings.rightToLeft);

            c.rightToLeft.value = Settings.rightToLeft;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.of(context).trans('toggleanimatin'),
          value: Settings.animation,
          onChanged: (value) async {
            await Settings.setAnimation(!Settings.animation);

            c.animation.value = Settings.animation;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.of(context).trans('togglepadding'),
          value: Settings.padding,
          onChanged: (value) async {
            await Settings.setPadding(!Settings.padding);

            c.padding.value = Settings.padding;

            setState(() {});
          },
        ),
        _checkBox(
          title: locale.Translations.of(context).trans('disableoverlaybuttons'),
          value: !Settings.disableOverlayButton,
          onChanged: (value) async {
            await Settings.setDisableOverlayButton(
                !Settings.disableOverlayButton);

            c.overlayButton.value = !Settings.disableOverlayButton;

            setState(() {});
          },
        ),
        if (!Platform.isIOS)
          _checkBox(
            value: Settings.moveToAppBarToBottom,
            title:
                locale.Translations.of(context).trans('movetoappbartobottom'),
            onChanged: (value) async {
              await Settings.setMoveToAppBarToBottom(
                  !Settings.moveToAppBarToBottom);

              c.appBarToBottom.value = Settings.moveToAppBarToBottom;

              setState(() {});
            },
          ),
        _checkBox(
          value: Settings.showSlider,
          title: locale.Translations.of(context).trans('showslider'),
          enabled: Settings.moveToAppBarToBottom,
          onChanged: (value) async {
            await Settings.setShowSlider(!Settings.showSlider);

            c.showSlider.value = Settings.showSlider;

            setState(() {});
          },
        ),
        _checkBox(
          value: Settings.showPageNumberIndicator,
          title:
              locale.Translations.of(context).trans('showpagenumberindicator'),
          onChanged: (value) async {
            await Settings.setShowPageNumberIndicator(
                !Settings.showPageNumberIndicator);

            c.indicator.value = Settings.showPageNumberIndicator;

            setState(() {});
          },
        ),
        if (!Platform.isIOS)
          _checkBox(
            title: locale.Translations.of(context).trans('disablefullscreen'),
            value: !Settings.disableFullScreen,
            onChanged: (value) async {
              await Settings.setDisableFullScreen(!Settings.disableFullScreen);

              c.fullscreen.value = Settings.disableFullScreen;

              if (Settings.disableFullScreen) {
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
                );
              }
              setState(() {});
            },
          ),
        PopupMenuButton<int>(
          onSelected: (int value) async {
            await Settings.setImageQuality(value);

            c.imgQuality.value = value;

            setState(() {
              imgqualityOption = value;
            });
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            const PopupMenuItem<int>(
              value: 0,
              child: Text('None'),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Text(locale.Translations.of(context).trans('high')),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Text(locale.Translations.of(context).trans('middle')),
            ),
            PopupMenuItem<int>(
              value: 3,
              child: Text(locale.Translations.of(context).trans('low')),
            ),
          ],
          child: ListTile(
            dense: true,
            title: Text(
              locale.Translations.of(context).trans('imgquality'),
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              [
                'None',
                locale.Translations.of(context).trans('high'),
                locale.Translations.of(context).trans('middle'),
                locale.Translations.of(context).trans('low')
              ][imgqualityOption],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        PopupMenuButton<int>(
          onSelected: (int value) {
            Settings.setThumbSize(value);

            c.thumbSize.value = value;

            widget.thumbSizeChangeEvent.call();
            setState(() {});
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: Text(locale.Translations.of(context).trans('large')),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: Text(locale.Translations.of(context).trans('middle')),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: Text(locale.Translations.of(context).trans('small')),
            ),
          ],
          child: ListTile(
            dense: true,
            title: Text(
              locale.Translations.of(context).trans('thumbnailslidersize'),
              style: const TextStyle(color: Colors.white),
            ),
            trailing: Text(
              [
                locale.Translations.of(context).trans('large'),
                locale.Translations.of(context).trans('middle'),
                locale.Translations.of(context).trans('small')
              ][Settings.thumbSize],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        _checkBox(
          value: Settings.showRecordJumpMessage,
          title: locale.Translations.of(context).trans('showrecordjumpmessage'),
          onChanged: (value) {
            Settings.setShowRecordJumpMessage(!Settings.showRecordJumpMessage);
            setState(() {});
          },
        ),
        if (Platform.isIOS) Container(height: 24),
      ],
    );

    if (Settings.enableViewerFunctionBackdropFilter) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6)),
            padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
            child: listview,
          ),
        ),
      );
    } else {
      return Container(
        color: Colors.black.withOpacity(0.8),
        padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
        child: listview,
      );
    }
  }

  _checkBox({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return ListTile(
      dense: true,
      enabled: enabled,
      trailing: Switch(
        onChanged: enabled ? onChanged : null,
        value: value,
        activeColor: Settings.majorColor,
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => onChanged(value),
    );
  }
}
