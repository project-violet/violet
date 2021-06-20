// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';

class ViewerSettingPanel extends StatefulWidget {
  final VoidCallback viewerStyleChangeEvent;
  final VoidCallback setStateCallback;

  ViewerSettingPanel({this.viewerStyleChangeEvent, this.setStateCallback});

  @override
  _ViewerSettingPanelState createState() => _ViewerSettingPanelState();
}

class _ViewerSettingPanelState extends State<ViewerSettingPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // color: Colors.black,
      padding: EdgeInsets.only(bottom: Variables.bottomBarHeight),
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: [
          ListTile(
            dense: true,
            title: Row(
              children: [
                Text(Translations.instance.trans('timersetting') +
                    ' (' +
                    Settings.timerTick.toStringAsFixed(1) +
                    Translations.instance.trans('second') +
                    ')'),
                Expanded(
                  child: Align(
                    child: SliderTheme(
                      data: SliderThemeData(
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
            title: Translations.of(context).trans('toggleviewerstyle'),
            onChanged: (value) {
              Settings.setIsHorizontal(!Settings.isHorizontal);
              widget.viewerStyleChangeEvent.call();
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('togglescrollvertical'),
            value: Settings.scrollVertical,
            enabled: Settings.isHorizontal,
            onChanged: (value) {
              Settings.setScrollVertical(!Settings.scrollVertical);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('togglerighttoleft'),
            value: Settings.rightToLeft,
            onChanged: (value) {
              Settings.setRightToLeft(!Settings.rightToLeft);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('toggleanimatin'),
            value: Settings.animation,
            onChanged: (value) {
              Settings.setAnimation(!Settings.animation);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('togglepadding'),
            value: Settings.padding,
            onChanged: (value) {
              Settings.setPadding(!Settings.padding);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('disableoverlaybuttons'),
            value: !Settings.disableOverlayButton,
            onChanged: (value) {
              Settings.setDisableOverlayButton(!Settings.disableOverlayButton);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            value: Settings.moveToAppBarToBottom,
            title: Translations.of(context).trans('movetoappbartobottom'),
            onChanged: (value) {
              Settings.setMoveToAppBarToBottom(!Settings.moveToAppBarToBottom);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            value: Settings.showSlider,
            title: Translations.of(context).trans('showslider'),
            enabled: Settings.moveToAppBarToBottom,
            onChanged: (value) {
              Settings.setShowSlider(!Settings.showSlider);
              widget.setStateCallback.call();
              setState(() {});
            },
          ),
          _checkBox(
            title: Translations.of(context).trans('disablefullscreen'),
            value: !Settings.disableFullScreen,
            onChanged: (value) {
              Settings.setDisableFullScreen(!Settings.disableFullScreen);
              widget.setStateCallback.call();
              if (Settings.disableFullScreen) {
                SystemChrome.setEnabledSystemUIOverlays(
                    [SystemUiOverlay.bottom, SystemUiOverlay.top]);
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  _checkBox({
    bool value,
    String title,
    ValueChanged<bool> onChanged,
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
      title: Text(title),
      onTap: () => onChanged(value),
    );
  }
}
