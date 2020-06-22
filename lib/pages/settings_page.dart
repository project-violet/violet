// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:violet/locale.dart';
import 'package:violet/pages/test_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/settings.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin<SettingsPage> {
  FlareControls _flareController = FlareControls();
  bool _themeSwitch = false;

  @override
  void initState() {
    super.initState();
    _themeSwitch = Settings.themeWhat;
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: <Widget>[
                _buildGroup(Translations.of(context).trans('theme')),
                _buildItems([
                  ListTile(
                    leading: ShaderMask(
                      shaderCallback: (bounds) => RadialGradient(
                        center: Alignment.topLeft,
                        radius: 1.0,
                        colors: [Colors.black, Colors.white],
                        tileMode: TileMode.clamp,
                      ).createShader(bounds),
                      child: Icon(MdiIcons.themeLightDark, color: Colors.white),
                    ),
                    title: Text(Translations.of(context).trans('darkmode')),
                    trailing: SizedBox(
                      width: 50,
                      height: 50,
                      child: FlareActor(
                        'assets/flare/switch_daytime.flr',
                        animation: _themeSwitch ? "night_idle" : "day_idle",
                        controller: _flareController,
                        snapToEnd: true,
                      ),
                    ),
                    onTap: () async {
                      if (!_themeSwitch)
                        _flareController.play('switch_night');
                      else
                        _flareController.play('switch_day');
                      _themeSwitch = !_themeSwitch;
                      Settings.setThemeWhat(_themeSwitch);
                      DynamicTheme.of(context).setBrightness(
                          Theme.of(context).brightness == Brightness.dark
                              ? Brightness.light
                              : Brightness.dark);
                      setState(() {});
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: ShaderMask(
                      shaderCallback: (bounds) => RadialGradient(
                        center: Alignment.bottomLeft,
                        radius: 1.2,
                        colors: [Colors.orange, Colors.pink],
                        tileMode: TileMode.clamp,
                      ).createShader(bounds),
                      child:
                          Icon(MdiIcons.formatColorFill, color: Colors.white),
                    ),
                    title: Text(Translations.of(context).trans('colorsetting')),
                    trailing: Icon(
                        // Icons.message,
                        Icons.keyboard_arrow_right),
                    onTap: () {
                      // showDialog(
                      //   context: context,
                      //   builder: (BuildContext context) {
                      //     return AlertDialog(
                      //       titlePadding: const EdgeInsets.all(0.0),
                      //       contentPadding: const EdgeInsets.all(0.0),
                      //       content: SingleChildScrollView(
                      //         child: ColorPicker(
                      //           pickerColor: Settings.majorColor,
                      //           onColorChanged: (color) async {
                      //             await Settings.setMajorColor(color);
                      //             setState(() {});
                      //           },
                      //           colorPickerWidth: 300.0,
                      //           pickerAreaHeightPercent: 0.7,
                      //           enableAlpha: true,
                      //           displayThumbColor: true,
                      //           showLabel: true,
                      //           paletteType: PaletteType.hsv,
                      //           pickerAreaBorderRadius: const BorderRadius.only(
                      //             topLeft: const Radius.circular(2.0),
                      //             topRight: const Radius.circular(2.0),
                      //           ),
                      //         ),
                      //       ),
                      //     );
                      //   },
                      // );
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                                Translations.of(context).trans('selectcolor')),
                            content: SingleChildScrollView(
                              child: BlockPicker(
                                pickerColor: Settings.majorColor,
                                onColorChanged: (color) async {
                                  await Settings.setMajorColor(color);
                                  setState(() {});
                                },
                              ),
                            ),
                          );
                        },
                      );
                      // showDialog(
                      //   context: context,
                      //   builder: (BuildContext context) {
                      //     return AlertDialog(
                      //       titlePadding: const EdgeInsets.all(0.0),
                      //       contentPadding: const EdgeInsets.all(0.0),
                      //       content: SingleChildScrollView(
                      //         child: MaterialPicker(
                      //           pickerColor: Settings.majorColor,
                      //           onColorChanged: (color) async {
                      //             await Settings.setMajorColor(color);
                      //             setState(() {});
                      //           },
                      //           enableLabel: true,
                      //         ),
                      //       ),
                      //     );
                      //   },
                      // );
                    },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('search')),
                _buildItems([
                  ListTile(
                    leading: Icon(
                      MdiIcons.tagHeartOutline,
                      color: Settings.majorColor,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Translations.of(context).trans('defaulttag')),
                        Text(Translations.of(context).trans('currenttag')),
                      ],
                    ),
                    trailing: Icon(
                        // Icons.message,
                        Icons.keyboard_arrow_right),
                    onTap: () {},
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.tagOff,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('excludetag')),
                    trailing: Icon(
                        // Icons.message,
                        Icons.keyboard_arrow_right),
                    onTap: () {},
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.blur,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('blurredtag')),
                    trailing: Icon(
                        // Icons.message,
                        Icons.keyboard_arrow_right),
                    onTap: () {},
                  ),
                  // _buildDivider(),
                  // ListTile(
                  //   leading: Icon(
                  //     MdiIcons.imageMultipleOutline,
                  //     color: Settings.majorColor,
                  //   ),
                  //   title: Text(Translations.of(context).trans('howtoshowsearchresult')),
                  //   trailing: Icon(
                  //       // Icons.message,
                  //       Icons.keyboard_arrow_right),
                  //   onTap: () {},
                  // ),
                ]),
                _buildGroup(Translations.of(context).trans('system')),
                _buildItems([
                  // ListTile(
                  //   leading: Icon(Icons.folder_open, color: Settings.majorColor),
                  //   title: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Text(Translations.of(context).trans('savedir')),
                  //       Text(Translations.of(context).trans('curdir') + ": /android/Pictures"),
                  //     ],
                  //   ),
                  //   trailing: Icon(Icons.keyboard_arrow_right),
                  //   onTap: () {},
                  // ),
                  // _buildDivider(),
                  ListTile(
                    leading: Icon(Icons.receipt, color: Settings.majorColor),
                    title: Text(Translations.of(context).trans('logrecord')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () {},
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(Icons.language, color: Settings.majorColor),
                    title: Text(Translations.of(context).trans('language')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Theme(
                            data: Theme.of(context)
                                .copyWith(primaryColor: Colors.pink),
                            child: CountryPickerDialog(
                                titlePadding: EdgeInsets.all(8.0),
                                // searchCursorColor: Colors.pinkAccent,
                                // searchInputDecoration:
                                //     InputDecoration(hintText: 'Search...'),
                                // isSearchable: true,
                                title: Text('Select Language'),
                                onValuePicked: (Country country) async {
                                  final dict = {
                                    'KR': 'ko',
                                    'US': 'en',
                                    'JP': 'ja',
                                    'CN': 'zh',
                                    'RU': 'ru'
                                  };
                                  await Translations.of(context)
                                      .load(dict[country.isoCode]);
                                  await Settings.setLanguage(
                                      dict[country.isoCode]);
                                  setState(() {});
                                },
                                itemFilter: (c) => [].contains(c.isoCode),
                                priorityList: [
                                  CountryPickerUtils.getCountryByIsoCode('US'),
                                  CountryPickerUtils.getCountryByIsoCode('KR'),
                                  CountryPickerUtils.getCountryByIsoCode('JP'),
                                  // CountryPickerUtils.getCountryByIsoCode('CN'),
                                  // CountryPickerUtils.getCountryByIsoCode('RU'),
                                ],
                                itemBuilder: (Country country) {
                                  final dict = {
                                    'KR': '한국어',
                                    'US': 'English',
                                    'JP': '日本語',
                                    'CN': '中文',
                                    'RU': 'Русский'
                                  };
                                  return Container(
                                    child: Row(
                                      children: <Widget>[
                                        CountryPickerUtils.getDefaultFlagImage(
                                            country),
                                        SizedBox(
                                          width: 8.0,
                                          height: 20,
                                        ),
                                        Text("${dict[country.isoCode]}"),
                                      ],
                                    ),
                                  );
                                })),
                      );
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading:
                        Icon(Icons.info_outline, color: Settings.majorColor),
                    title: Text(Translations.of(context).trans('info')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (_, __, ___) {
                            return VersionViewPage();
                          },
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            var begin = Offset(0.0, 1.0);
                            var end = Offset.zero;
                            var curve = Curves.ease;

                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));

                            return SlideTransition(
                              position: animation.drive(tween),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(Icons.developer_mode, color: Colors.orange),
                    title: Text(Translations.of(context).trans('devtool')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => TestPage(),
                        ),
                      );
                    },
                  ),
                ]),
                // _buildGroup(Translations.of(context).trans('viewer')),
                // _buildItems([
                //   ListTile(
                //     leading: Icon(Icons.view_array, color: Settings.majorColor),
                //     title: Column(
                //       crossAxisAlignment: CrossAxisAlignment.start,
                //       children: [
                //         Text(Translations.of(context).trans('viewertype')),
                //         Text(Translations.of(context).trans('currenttype') + ": " + Translations.of(context).trans('scrollview')),
                //       ],
                //     ),
                //     trailing: Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                //   _buildDivider(),
                //   ListTile(
                //     leading: Icon(
                //       Icons.blur_linear,
                //       color: Settings.majorColor,
                //     ),
                //     title: Text(Translations.of(context).trans('imgquality')),
                //     trailing: Icon(
                //         // Icons.message,
                //         Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                // ]),
                // _buildGroup(Translations.of(context).trans('downloader')),
                // _buildItems([
                //   ListTile(
                //     leading: ShaderMask(
                //       shaderCallback: (bounds) => RadialGradient(
                //         center: Alignment.bottomLeft,
                //         radius: 1.3,
                //         colors: [Colors.yellow, Colors.red, Colors.purple],
                //         tileMode: TileMode.clamp,
                //       ).createShader(bounds),
                //       child: Icon(MdiIcons.instagram, color: Colors.white),
                //     ),
                //     title: Text(Translations.of(context).trans('instagram')),
                //     trailing: Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                //   _buildDivider(),
                //   ListTile(
                //     leading: Icon(MdiIcons.twitter, color: Colors.blue),
                //     title: Text(Translations.of(context).trans('twitter')),
                //     trailing: Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                //   _buildDivider(),
                //   ListTile(
                //     leading: Image.asset('assets/icons/pixiv.ico', width: 25),
                //     title: Text(Translations.of(context).trans('pixiv')),
                //     trailing: Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                // ]),
                // _buildGroup(Translations.of(context).trans('cache')),
                // _buildItems([
                //   ListTile(
                //     leading: Icon(Icons.lock_outline, color: Settings.majorColor),
                //     title: Text("Enable Locking"),
                //     trailing: AbsorbPointer(
                //       child: Switch(
                //         value: true,
                //         onChanged: (value) {
                //           //setState(() {
                //           //  isSwitched = value;
                //           //  print(isSwitched);
                //           //});
                //         },
                //         activeTrackColor: Settings.majorColor,
                //         activeColor: Settings.majorAccentColor,
                //       ),
                //     ),
                //     //Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                // ]),
                // _buildGroup('잠금'),
                // _buildItems([
                //   ListTile(
                //     leading: Icon(Icons.lock_outline, color: Settings.majorColor),
                //     title: Text("잠금 기능 켜기"),
                //     trailing: AbsorbPointer(
                //       child: Switch(
                //         value: true,
                //         onChanged: (value) {
                //           //setState(() {
                //           //  isSwitched = value;
                //           //  print(isSwitched);
                //           //});
                //         },
                //         activeTrackColor: Settings.majorColor,
                //         activeColor: Settings.majorAccentColor,
                //       ),
                //     ),
                //     //Icon(Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                //   _buildDivider(),
                //   ListTile(
                //     leading: Icon(
                //       Icons.security,
                //       color: Settings.majorColor,
                //     ),
                //     title: Text("보호 설정"), // blurring
                //     trailing: Icon(
                //         // Icons.message,
                //         Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                // ]),
                // _buildGroup('네트워크'),
                // _buildItems([
                //   ListTile(
                //     leading: Icon(
                //       Icons.router,
                //       color: Settings.majorColor,
                //     ),
                //     title: Text("라우팅 규칙"),
                //     trailing: Icon(
                //         // Icons.message,
                //         Icons.keyboard_arrow_right),
                //     onTap: () {},
                //   ),
                // ]),
                _buildGroup(Translations.of(context).trans('update')),
                _buildItems([
                  ListTile(
                    leading: Icon(
                      Icons.update,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('checkupdate')),
                    trailing: Icon(
                        // Icons.message,
                        Icons.keyboard_arrow_right),
                    onTap: () {},
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('etc')),
                _buildItems([
                  ListTile(
                    leading: Icon(
                      MdiIcons.discord,
                      color: Color(0xFF7189da),
                    ),
                    title: Text(Translations.of(context).trans('discord')),
                    trailing: Icon(Icons.open_in_new),
                    onTap: () async {
                      const url = 'https://discord.gg/K8qny6E';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.github,
                      color: Colors.black,
                    ),
                    title: Text(
                        "Github " + Translations.of(context).trans('project')),
                    trailing: Icon(Icons.open_in_new),
                    onTap: () async {
                      const url = 'https://github.com/project-violet/';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.gmail,
                      color: Colors.redAccent,
                    ),
                    title: Text(Translations.of(context).trans('contact')),
                    trailing: Icon(
                        // Icons.email,
                        Icons.keyboard_arrow_right),
                    onTap: () async {
                      const url =
                          'mailto:violet.dev.master@gmail.com?subject=[App Issue] &body=';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.heart,
                      color: Colors.orange,
                    ),
                    title: Text(Translations.of(context).trans('donate')),
                    trailing: Icon(
                        // Icons.email,
                        Icons.open_in_new),
                    onTap: () async {
                      const url = 'https://www.patreon.com/projectviolet';
                      if (await canLaunch(url)) {
                        await launch(url);
                      }
                    },
                  ),
                  // _buildDivider(),
                  // ListTile(
                  //   leading: Icon(
                  //     Icons.open_in_new,
                  //     color: Settings.majorColor,
                  //   ),
                  //   title: Text(Translations.of(context).trans('externallink')),
                  //   trailing: Icon(
                  //       // Icons.email,
                  //       Icons.keyboard_arrow_right),
                  //   onTap: () {},
                  // ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.library,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('license')),
                    trailing: Icon(
                        // Icons.email,
                        Icons.keyboard_arrow_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => LicensePage(
                            applicationName: 'Project Violet\n',
                            applicationIcon: Image.asset(
                              'assets/images/logo.png',
                              width: 100,
                              height: 100,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ]),
                Container(
                  margin: EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        // Card(
                        //   elevation: 5,
                        //   shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.circular(10.0),
                        //   ),
                        //   child:
                        InkWell(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 100,
                            height: 100,
                          ),
                          //onTap: () {},
                        ),
                        // ),
                        Padding(
                          padding: EdgeInsets.only(top: 12),
                        ),
                        Text(
                          'Project Violet',
                          style: TextStyle(
                            color: Settings.themeWhat
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 16.0,
                            fontFamily: "Calibre-Semibold",
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'Copyright (C) 2020 by dc-koromo',
                          style: TextStyle(
                            color: Settings.themeWhat
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 12.0,
                            fontFamily: "Calibre-Semibold",
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
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

  Padding _buildGroup(String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(name,
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 24.0,
                fontFamily: "Calibre-Semibold",
                letterSpacing: 1.0,
              )),
        ],
      ),
    );
  }

  Container _buildItems(List<Widget> items) {
    return Container(
      transform: Matrix4.translationValues(0, -2, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: Card(
          elevation: 4.0,
          margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Column(children: items),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class SettingsGroup extends StatelessWidget {
  final String name;
  //final List<SettingsItem> items;

  SettingsGroup({this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(name,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 24.0,
                      fontFamily: "Calibre-Semibold",
                      letterSpacing: 1.0,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatefulWidget {
  @override
  _SettingsItemState createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class VersionViewPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Card(
            color: Settings.themeWhat
                ? Colors.black.withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            elevation: 10,
            child: SizedBox(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  children: <Widget>[
                    Text(''),
                    Text(
                      'Violet',
                      style: TextStyle(fontSize: 30),
                    ),
                    Text(
                      '0.1.0',
                      style: TextStyle(fontSize: 20),
                    ),
                    Text(''),
                    Text('Project-Violet Android App'),
                  ],
                ),
                width: 250,
                height: 130,
              ),
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
    );
  }
}

class ColorSettingsPage extends StatefulWidget {
  @override
  _ColorSettingsPageState createState() => _ColorSettingsPageState();
}

class _ColorSettingsPageState extends State<ColorSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
