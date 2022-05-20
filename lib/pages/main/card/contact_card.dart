// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:division/division.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/locale/locale.dart';

class ContactCard extends StatefulWidget {
  const ContactCard({Key key}) : super(key: key);

  @override
  State<ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<ContactCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return SizedBox(
      width: width - 64 + 8,
      height: 65,
      child: Parent(
        style: settingsItemStyle(pressed),
        gesture: Gestures()
          ..isTap((isTapped) {
            setState(() => pressed = isTapped);
          })
          ..onTapUp((detail) async {
            const url =
                'mailto:violet.dev.master@gmail.com?subject=[App Issue] &body=';
            if (await canLaunch(url)) {
              await launch(url);
            }
          }),
        child: Container(
          width: width - 16,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Card(
            color: Colors.redAccent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  MdiIcons.gmail,
                  color: Colors.white,
                ),
                Padding(
                  padding: Translations.of(context).dbLanguageCode == 'en'
                      ? const EdgeInsets.only(top: 4)
                      : const EdgeInsets.only(top: 4),
                  child: Text(
                    '  ${Translations.of(context).trans('maincontact')}',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontFamily: 'Calibre-Semibold',
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ParentStyle settingsItemStyle(bool pressed) => ParentStyle()
    ..elevation(pressed ? 0 : 10000, color: Colors.transparent)
    ..scale(pressed ? 0.95 : 1.0)
    ..alignmentContent.center()
    ..ripple(true)
    ..animate(150, Curves.easeOut);
}
