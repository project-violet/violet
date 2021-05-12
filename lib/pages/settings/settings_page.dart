// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:io';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controls.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/eh/eh_bookmark.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/pages/community/user_status_card.dart';
import 'package:violet/pages/settings/import_from_eh.dart';
import 'package:violet/pages/settings/license_page.dart';
import 'package:violet/pages/settings/login/ehentai_login.dart';
import 'package:violet/pages/settings/log_page.dart';
import 'package:violet/pages/settings/route.dart';
import 'package:violet/pages/settings/tag_selector.dart';
import 'package:violet/pages/settings/test_page.dart';
import 'package:violet/pages/settings/version_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/widgets/toast.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/database.dart';

class ExCountry extends Country {
  String language;
  String script;
  String region;
  String variant;

  ExCountry(String name, String iso) : super(name: name, isoCode: iso) {}

  static ExCountry create(String iso,
      {String language, String script, String region, String variant}) {
    var c = CountryPickerUtils.getCountryByIsoCode(iso);
    var country = ExCountry(c.name, c.isoCode);
    country.language = language;
    country.script = script;
    country.region = region;
    country.variant = variant;
    return country;
  }

  String toString() {
    final dict = {
      'KR': 'ko',
      'US': 'en',
      'JP': 'ja',
      // 'CN': 'zh',
      'RU': 'ru',
      'IT': 'it',
      'ES': 'eo',
    };

    if (dict.containsKey(isoCode)) return dict[isoCode];

    if (isoCode == 'CN') {
      if (script == 'Hant') return 'zh_Hant';
      if (script == 'Hans') return 'zh_Hans';
    }

    return 'en';
  }

  String getDisplayLanguage() {
    final dict = {
      'KR': '한국어',
      'US': 'English',
      'JP': '日本語',
      // 'CN': '中文(简体)',
      // 'CN': '中文(繁體)',
      'RU': 'Русский',
      'IT': 'Italiano',
      'ES': 'Español',
    };

    if (dict.containsKey(isoCode)) return dict[isoCode];

    if (isoCode == 'CN') {
      if (script == 'Hant') return '中文(繁體)';
      if (script == 'Hans') return '中文(简体)';
    }

    return 'English';
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin<SettingsPage> {
  FlareControls _flareController = FlareControls();
  bool _themeSwitch = false;
  FlutterToast flutterToast;

  @override
  void initState() {
    super.initState();
    _themeSwitch = Settings.themeWhat;
    flutterToast = FlutterToast(context);
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
              duration: const Duration(milliseconds: 0),
              childAnimationBuilder: (widget) => SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: <Widget>[
                _buildGroup(Translations.of(context).trans('theme')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: ShaderMask(
                        shaderCallback: (bounds) => RadialGradient(
                          center: Alignment.topLeft,
                          radius: 1.0,
                          colors: [Colors.black, Colors.white],
                          tileMode: TileMode.clamp,
                        ).createShader(bounds),
                        child:
                            Icon(MdiIcons.themeLightDark, color: Colors.white),
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
                    },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(MdiIcons.cellphoneText,
                          color: Settings.majorColor),
                      title: Text('Drawer 사용'),
                      trailing: Switch(
                        value: Settings.useDrawer,
                        onChanged: (value) async {},
                        activeTrackColor: Settings.majorColor,
                        activeColor: Settings.majorAccentColor,
                      ),
                    ),
                    onTap: () async {
                      await Settings.setUseDrawer(!Settings.useDrawer);
                      setState(() {});
                    },
                  ),
                ]),
                UserStatusCard(),
                _buildGroup(Translations.of(context).trans('search')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.tagHeartOutline,
                        color: Settings.majorColor,
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Translations.of(context).trans('defaulttag')),
                          Text(
                            Translations.of(context).trans('currenttag') +
                                Settings.includeTags,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () async {
                      final vv = await showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            TagSelectorDialog(what: 'include'),
                      );

                      if (vv != null && vv.item1 == 1) {
                        Settings.setIncludeTags(vv.item2);
                        setState(() {});
                      }
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.tagOff,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('excludetag')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () async {
                      final vv = await showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            TagSelectorDialog(what: 'exclude'),
                      );

                      if (vv.item1 == 1) {
                        Settings.setExcludeTags(vv.item2);
                        setState(() {});
                      }
                    },
                  ),
                  // _buildDivider(),
                  // InkWell(
                  //   child: ListTile(
                  //     leading: Icon(
                  //       MdiIcons.blur,
                  //       color: Settings.majorColor,
                  //     ),
                  //     title: Text(Translations.of(context).trans('blurredtag')),
                  //     trailing: Icon(Icons.keyboard_arrow_right),
                  //   ),
                  //   onTap: () async {
                  //     final vv = await showDialog(
                  //       context: context,
                  //       child: TagSelectorDialog(what: 'blurred'),
                  //     );

                  //     if (vv.item1 == 1) {
                  //       Settings.setBlurredTags(vv.item2);
                  //       setState(() {});
                  //     }
                  //   },
                  // ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.tooltipEdit,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('tagrebuild')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () async {
                      if (await Dialogs.yesnoDialog(
                          context,
                          Translations.of(context).trans('tagrebuildmsg'),
                          Translations.of(context).trans('tagrebuild'))) {
                        await Dialogs.okDialog(context, 'TODO: Implementation');
                      }
                    },
                  ),

                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.searchWeb,
                        color: Settings.majorColor,
                      ),
                      title:
                          Text(Translations.of(context).trans('usewebsearch')),
                      trailing: Switch(
                        value: Settings.searchNetwork,
                        onChanged: (value) async {},
                        activeTrackColor: Settings.majorColor,
                        activeColor: Settings.majorAccentColor,
                      ),
                    ),
                    onTap: () async {
                      await Settings.setSearchOnWeb(!Settings.searchNetwork);
                      setState(() {});
                    },
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
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(Icons.receipt, color: Settings.majorColor),
                      title: Text(Translations.of(context).trans('logrecord')),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () {
                      if (!Platform.isIOS) {
                        Navigator.of(context).push(PageRouteBuilder(
                          transitionDuration: Duration(milliseconds: 500),
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
                          pageBuilder: (_, __, ___) => LogPage(),
                        ));
                      } else {
                        Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => LogPage()));
                      }
                    },
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
                                titlePadding:
                                    EdgeInsets.symmetric(vertical: 16),
                                // searchCursorColor: Colors.pinkAccent,
                                // searchInputDecoration:
                                //     InputDecoration(hintText: 'Search...'),
                                // isSearchable: true,
                                title: Text('Select Language'),
                                onValuePicked: (Country country) async {
                                  var exc = country as ExCountry;
                                  await Translations.of(context)
                                      .load(exc.toString());
                                  await Settings.setLanguage(exc.toString());
                                  setState(() {});
                                },
                                itemFilter: (c) => [].contains(c.isoCode),
                                priorityList: [
                                  ExCountry.create('US'),
                                  ExCountry.create('KR'),
                                  ExCountry.create('JP'),
                                  ExCountry.create('CN', script: 'Hant'),
                                  ExCountry.create('CN', script: 'Hans'),
                                  ExCountry.create('IT'),
                                  ExCountry.create('ES'),
                                  // CountryPickerUtils.getCountryByIsoCode('RU'),
                                ],
                                itemBuilder: (Country country) {
                                  return Container(
                                    child: Row(
                                      children: <Widget>[
                                        CountryPickerUtils.getDefaultFlagImage(
                                            country),
                                        SizedBox(
                                          width: 8.0,
                                          height: 30,
                                        ),
                                        Text(
                                            "${(country as ExCountry).getDisplayLanguage()}"),
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
                      if (!Platform.isIOS) {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            opaque: false,
                            pageBuilder: (_, __, ___) {
                              return VersionViewPage();
                            },
                            transitionsBuilder: (context, animation,
                                secondaryAnimation, child) {
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
                      }
                    },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(Icons.developer_mode, color: Colors.orange),
                      title: Text(Translations.of(context).trans('devtool')),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () async {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => TestPage(),
                        ),
                      );
                    },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('database')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(MdiIcons.swapHorizontal,
                          color: Settings.majorColor),
                      title: Text(Translations.of(context).trans('switching')),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: Variables.databaseDecompressed
                        ? null
                        : () async {
                            Navigator.of(context)
                                .pushReplacement(MaterialPageRoute(
                                    builder: (context) => SplashPage(
                                          switching: true,
                                        )));
                          },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(MdiIcons.databaseSync,
                          color: Settings.majorColor),
                      title: Text(Translations.of(context).trans('syncmanual')),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: Variables.databaseDecompressed
                        ? null
                        : () async {
                            var latestDB =
                                SyncManager.getLatestDB().getDateTime();
                            var lastDB = (await SharedPreferences.getInstance())
                                .getString('databasesync');

                            if (lastDB != null &&
                                latestDB
                                        .difference(DateTime.parse(lastDB))
                                        .inHours <
                                    1) {
                              flutterToast.showToast(
                                child: ToastWrapper(
                                  isCheck: true,
                                  msg: Translations.of(context)
                                      .trans('thisislatestbookmark'),
                                ),
                                gravity: ToastGravity.BOTTOM,
                                toastDuration: Duration(seconds: 4),
                              );
                              return;
                            }

                            var dir = await getApplicationDocumentsDirectory();
                            try {
                              await ((await openDatabase(
                                      '${dir.path}/data/data.db'))
                                  .close());
                              await deleteDatabase('${dir.path}/data/data.db');
                              await Directory('${dir.path}/data')
                                  .delete(recursive: true);
                            } catch (e) {}

                            Navigator.of(context)
                                .push(MaterialPageRoute(
                                    builder: (context) => DataBaseDownloadPage(
                                          dbType: Settings.databaseType,
                                          isExistsDataBase: false,
                                          isSync: true,
                                        )))
                                .then((value) async {
                              HitomiIndexs.init();
                              final directory =
                                  await getApplicationDocumentsDirectory();
                              final path =
                                  File('${directory.path}/data/index.json');
                              final text = path.readAsStringSync();
                              HitomiManager.tagmap = jsonDecode(text);
                              await DataBaseManager.reloadInstance();

                              flutterToast.showToast(
                                child: ToastWrapper(
                                  isCheck: true,
                                  msg: Translations.of(context)
                                      .trans('synccomplete'),
                                ),
                                gravity: ToastGravity.BOTTOM,
                                toastDuration: Duration(seconds: 4),
                              );
                            });
                          },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('network')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(MdiIcons.vpn, color: Settings.majorColor),
                      title: Text('VPN'),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () {},
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      Icons.router,
                      color: Settings.majorColor,
                    ),
                    title: Text(Translations.of(context).trans('routing_rule')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) => RouteDialog(),
                      );
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      Icons.router,
                      color: Settings.majorColor,
                    ),
                    title: Text('Image ' +
                        Translations.of(context).trans('routing_rule')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) => ImageRouteDialog(),
                      );
                    },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Image.asset(
                        'assets/images/logo.png',
                        width: 25,
                        height: 25,
                      ),
                      title: Text(
                          Translations.of(context).trans('usevioletserver')),
                      trailing: Switch(
                        value: Settings.useVioletServer,
                        onChanged: (value) async {},
                        activeTrackColor: Settings.majorColor,
                        activeColor: Settings.majorAccentColor,
                      ),
                    ),
                    onTap: () async {
                      await Settings.setUseVioletServer(
                          !Settings.useVioletServer);
                      setState(() {});
                    },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('download')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.downloadLock,
                        color: Settings.majorColor,
                      ),
                      title: Text(
                          Translations.of(context).trans('useinnerstorage')),
                      trailing: Switch(
                        value: Settings.useInnerStorage,
                        onChanged: (value) async {},
                        activeTrackColor: Settings.majorColor,
                        activeColor: Settings.majorAccentColor,
                      ),
                    ),
                    onTap: Platform.isIOS
                        ? null
                        : () async {
                            await Settings.setUserInnerStorage(
                                !Settings.useInnerStorage);
                            setState(() {});
                          },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    //   customBorder: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.all(
                    //       Radius.circular(10.0),
                    //     ),
                    //   ),
                    child: ListTile(
                      leading: Icon(MdiIcons.folderDownload,
                          color: Settings.majorColor),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Translations.of(context).trans('downloadpath')),
                          Text(
                            Translations.of(context).trans('curdownloadpath') +
                                ': ' +
                                Settings.downloadBasePath,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: Settings.useInnerStorage
                        ? null
                        : () async {
                            Widget yesButton = FlatButton(
                              child: Text(Translations.of(context).trans('ok'),
                                  style: TextStyle(color: Settings.majorColor)),
                              focusColor: Settings.majorColor,
                              splashColor: Settings.majorColor.withOpacity(0.3),
                              onPressed: () {
                                Navigator.pop(context, true);
                              },
                            );
                            Widget noButton = FlatButton(
                              child: Text(
                                  Translations.of(context).trans('cancel'),
                                  style: TextStyle(color: Settings.majorColor)),
                              focusColor: Settings.majorColor,
                              splashColor: Settings.majorColor.withOpacity(0.3),
                              onPressed: () {
                                Navigator.pop(context, false);
                              },
                            );
                            TextEditingController text = TextEditingController(
                                text: Settings.downloadBasePath);
                            var dialog = await showDialog(
                              useRootNavigator: false,
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                contentPadding:
                                    EdgeInsets.fromLTRB(12, 0, 12, 0),
                                title: Text(Translations.of(context)
                                    .trans('downloadpath')),
                                content: TextField(
                                  controller: text,
                                  autofocus: true,
                                  maxLines: 3,
                                ),
                                actions: [yesButton, noButton],
                              ),
                            );
                            if (dialog != null && dialog == true) {
                              try {
                                if (await Permission.storage.isGranted) {
                                  var prevDir =
                                      Directory(Settings.downloadBasePath);
                                  if (await prevDir.exists()) {
                                    await prevDir.rename(text.text);
                                  }
                                }
                              } catch (e) {}

                              await Settings.setBaseDownloadPath(text.text);
                            }
                          },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('bookmark')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading:
                          Icon(MdiIcons.import, color: Settings.majorColor),
                      title: Text(
                          Translations.of(context).trans('importingbookmark')),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () async {
                      if (!await Permission.storage.isGranted) {
                        if (await Permission.storage.request() ==
                            PermissionStatus.denied) {
                          flutterToast.showToast(
                            child: ToastWrapper(
                              isCheck: false,
                              msg: Translations.of(context).trans('noauth'),
                            ),
                            gravity: ToastGravity.BOTTOM,
                            toastDuration: Duration(seconds: 4),
                          );
                          return;
                        }
                      }

                      File file;
                      file = await FilePicker.getFile(
                        type: FileType.any,
                      );

                      if (file == null) {
                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: false,
                            msg: Translations.of(context).trans('noselectedb'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );

                        return;
                      }

                      var db = await getApplicationDocumentsDirectory();
                      var extfile = File(file.path);
                      await extfile.copy('${db.path}/user.db');

                      await Bookmark.getInstance();

                      flutterToast.showToast(
                        child: ToastWrapper(
                          isCheck: true,
                          msg: Translations.of(context).trans('importbookmark'),
                        ),
                        gravity: ToastGravity.BOTTOM,
                        toastDuration: Duration(seconds: 4),
                      );
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.export,
                      color: Settings.majorColor,
                    ),
                    title: Text(
                        Translations.of(context).trans('exportingbookmark')),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    onTap: () async {
                      if (!await Permission.storage.isGranted) {
                        if (await Permission.storage.request() ==
                            PermissionStatus.denied) {
                          flutterToast.showToast(
                            child: ToastWrapper(
                              isCheck: false,
                              msg: Translations.of(context).trans('noauth'),
                            ),
                            gravity: ToastGravity.BOTTOM,
                            toastDuration: Duration(seconds: 4),
                          );

                          return;
                        }
                      }

                      var db = await getApplicationDocumentsDirectory();
                      var dbfile = File('${db.path}/user.db');
                      var ext = await getExternalStorageDirectory();
                      var extpath = '${ext.path}/bookmark.db';
                      var extfile = await dbfile.copy(extpath);

                      flutterToast.showToast(
                        child: ToastWrapper(
                          isCheck: true,
                          msg: Translations.of(context).trans('exportbookmark'),
                        ),
                        gravity: ToastGravity.BOTTOM,
                        toastDuration: Duration(seconds: 4),
                      );
                    },
                  ),
                  _buildDivider(),
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(10.0),
                          bottomRight: Radius.circular(10.0)),
                    ),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.cloudSearchOutline,
                        color: Settings.majorColor,
                      ),
                      title: Text('Import From E/Ex-Hentai'),
                      trailing: Icon(Icons.keyboard_arrow_right),
                    ),
                    onTap: () async {
                      var ehc = (await SharedPreferences.getInstance())
                          .getString('eh_cookies');

                      if (ehc == null || ehc == '') {
                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: false,
                            msg: 'Set Cookie First!',
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                        return;
                      }

                      await showDialog(
                        context: context,
                        builder: (BuildContext context) => ImportFromEHPage(),
                      );

                      if (EHBookmark.bookmarkInfo == null) {
                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: false,
                            isWarning: true,
                            msg: 'Bookmark is empty!',
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                        return;
                      }

                      int count = 0;
                      EHBookmark.bookmarkInfo.forEach((element) {
                        count += element.length;
                      });

                      var qqq = await Dialogs.yesnoDialog(context,
                          '$count개 항목을 북마크에 추가할까요? (각 Favorite별로 그룹이 생성됩니다.)');
                      if (qqq != null && qqq == true) {
                        var bookmark = await Bookmark.getInstance();
                        for (int i = 0;
                            i < EHBookmark.bookmarkInfo.length;
                            i++) {
                          if (EHBookmark.bookmarkInfo[i].isEmpty) continue;
                          await bookmark.createGroup(
                              'Favorite $i', '', Colors.black);
                          var group = (await bookmark.getGroup())
                              .where(
                                  (element) => element.name() == 'Favorite $i')
                              .first
                              .id();
                          for (int j = 0;
                              j < EHBookmark.bookmarkInfo[i].length;
                              j++) {
                            await bookmark.insertArticle(
                                EHBookmark.bookmarkInfo[i]
                                    .elementAt(j)
                                    .toString(),
                                DateTime.now(),
                                group);
                          }
                        }

                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            isWarning: false,
                            msg: '북마크 정보를 모두 불러왔습니다!',
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                      }
                    },
                  ),
                ]),
                // _buildGroup(Translations.of(context).trans('viewer')),
                // _buildItems([
                //   InkWell(
                //     customBorder: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(10.0),
                //     ),
                //     child: ListTile(
                //       leading: Icon(MdiIcons.signDirection,
                //           color: Settings.majorColor),
                //       title: Text(Translations.of(context).trans('right2left')),
                //       trailing: AbsorbPointer(
                //         child: Switch(
                //           value: Settings.rightToLeft,
                //           onChanged: (value) async {},
                //           activeTrackColor: Settings.majorColor,
                //           activeColor: Settings.majorAccentColor,
                //         ),
                //       ),
                //     ),
                //     onTap: () async {
                //       await Settings.setRightToLeft(!Settings.rightToLeft);
                //       setState(() {});
                //     },
                //   ),
                //   // ListTile(
                //   //   leading: Icon(Icons.view_array, color: Settings.majorColor),
                //   //   title: Column(
                //   //     crossAxisAlignment: CrossAxisAlignment.start,
                //   //     children: [
                //   //       Text(Translations.of(context).trans('viewertype')),
                //   //       Text(Translations.of(context).trans('currenttype') +
                //   //           ": " +
                //   //           Translations.of(context).trans('scrollview')),
                //   //     ],
                //   //   ),
                //   //   trailing: Icon(Icons.keyboard_arrow_right),
                //   //   onTap: () {},
                //   // ),
                //   // _buildDivider(),
                //   // ListTile(
                //   //   leading: Icon(
                //   //     Icons.blur_linear,
                //   //     color: Settings.majorColor,
                //   //   ),
                //   //   title: Text(Translations.of(context).trans('imgquality')),
                //   //   trailing: Icon(
                //   //       // Icons.message,
                //   //       Icons.keyboard_arrow_right),
                //   //   onTap: () {},
                //   // ),
                // ]),
                _buildGroup(Translations.of(context).trans('component')),
                _buildItems(
                  [
                    InkWell(
                      customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0)),
                      ),
                      child: ListTile(
                        leading: CachedNetworkImage(
                          imageUrl: 'https://e-hentai.org/favicon.ico',
                          width: 25,
                        ),
                        title: Text('E-Hentai/ExHentai'),
                        trailing: Icon(Icons.keyboard_arrow_right),
                      ),
                      onTap: () async {
                        var dialog = await showDialog(
                          context: context,
                          builder: (BuildContext context) => AlertDialog(
                            title: Text('E-Hentai Login'),
                            contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                RaisedButton(
                                  child: Text('Login From WebPage'),
                                  onPressed: () => Navigator.pop(context, 1),
                                  color: Settings.majorColor,
                                ),
                                RaisedButton(
                                  child: Text('Enter Cookie Information'),
                                  onPressed: () => Navigator.pop(context, 2),
                                  color: Settings.majorColor,
                                ),
                              ],
                            ),
                          ),
                        );

                        if (dialog == null) return;

                        if (dialog == 1) {
                          var result = await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => LoginScreen()));

                          await (await SharedPreferences.getInstance())
                              .setString('eh_cookies', result);

                          if (result != null) {
                            flutterToast.showToast(
                              child: ToastWrapper(
                                isCheck: true,
                                msg: 'Login Success!',
                              ),
                              gravity: ToastGravity.BOTTOM,
                              toastDuration: Duration(seconds: 4),
                            );
                          }
                        } else if (dialog == 2) {
                          var cookie = (await SharedPreferences.getInstance())
                              .getString('eh_cookies');

                          var iController = TextEditingController(
                              text: cookie != null
                                  ? parseCookies(cookie)['igneous']
                                  : '');
                          var imiController = TextEditingController(
                              text: cookie != null
                                  ? parseCookies(cookie)['ipb_member_id']
                                  : '');
                          var iphController = TextEditingController(
                              text: cookie != null
                                  ? parseCookies(cookie)['ipb_pass_hash']
                                  : '');
                          Widget yesButton = FlatButton(
                            child: Text(Translations.of(context).trans('ok'),
                                style: TextStyle(color: Settings.majorColor)),
                            focusColor: Settings.majorColor,
                            splashColor: Settings.majorColor.withOpacity(0.3),
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                          );
                          Widget noButton = FlatButton(
                            child: Text(
                                Translations.of(context).trans('cancel'),
                                style: TextStyle(color: Settings.majorColor)),
                            focusColor: Settings.majorColor,
                            splashColor: Settings.majorColor.withOpacity(0.3),
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                          );
                          var dialog = await showDialog(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              actions: [yesButton, noButton],
                              title: Text('E-Hentai Login'),
                              contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Row(children: [
                                    Text('igneous: '),
                                    Expanded(
                                      child: TextField(
                                        controller: iController,
                                      ),
                                    ),
                                  ]),
                                  Row(children: [
                                    Text('ipb_member_id: '),
                                    Expanded(
                                      child: TextField(
                                        controller: imiController,
                                      ),
                                    ),
                                  ]),
                                  Row(children: [
                                    Text('ipb_pass_hash: '),
                                    Expanded(
                                      child: TextField(
                                        controller: iphController,
                                      ),
                                    ),
                                  ]),
                                ],
                              ),
                            ),
                          );

                          if (dialog != null && dialog == true) {
                            var ck =
                                'igneous=${iController.text};ipb_member_id=${imiController.text};ipb_pass_hash=${iphController.text};';
                            await (await SharedPreferences.getInstance())
                                .setString('eh_cookies', ck);
                          }
                        }

                        Settings.searchRule =
                            'ExHentai|EHentai|Hitomi|Hiyobi|NHentai'.split('|');
                        await (await SharedPreferences.getInstance()).setString(
                            'searchrule',
                            'ExHentai|EHentai|Hitomi|Hiyobi|NHentai');
                      },
                    ),
                    // ListTile(
                    //   leading: ShaderMask(
                    //     shaderCallback: (bounds) => RadialGradient(
                    //       center: Alignment.bottomLeft,
                    //       radius: 1.3,
                    //       colors: [Colors.yellow, Colors.red, Colors.purple],
                    //       tileMode: TileMode.clamp,
                    //     ).createShader(bounds),
                    //     child: Icon(MdiIcons.instagram, color: Colors.white),
                    //   ),
                    //   title: Text(Translations.of(context).trans('instagram')),
                    //   trailing: Icon(Icons.keyboard_arrow_right),
                    //   // onTap: () {},
                    // ),
                    // _buildDivider(),
                    // ListTile(
                    //   leading: Icon(MdiIcons.twitter, color: Colors.blue),
                    //   title: Text(Translations.of(context).trans('twitter')),
                    //   trailing: Icon(Icons.keyboard_arrow_right),
                    //   // onTap: () {},
                    // ),
                    // _buildDivider(),
                    // InkWell(
                    //   customBorder: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.only(
                    //           bottomLeft: Radius.circular(10.0),
                    //           bottomRight: Radius.circular(10.0))),
                    //   child: ListTile(
                    //     leading:
                    //         Image.asset('assets/icons/pixiv.ico', width: 25),
                    //     title: Text(Translations.of(context).trans('pixiv')),
                    //     trailing: Icon(Icons.keyboard_arrow_right),
                    //   ),
                    //   onTap: () async {
                    //     var nameController = TextEditingController(
                    //         text: (await SharedPreferences.getInstance())
                    //             .getString('pixiv_id'));
                    //     var descController = TextEditingController(
                    //         text: (await SharedPreferences.getInstance())
                    //             .getString('pixiv_pwd'));
                    //     Widget yesButton = FlatButton(
                    //       child: Text(Translations.of(context).trans('ok'),
                    //           style: TextStyle(color: Settings.majorColor)),
                    //       focusColor: Settings.majorColor,
                    //       splashColor: Settings.majorColor.withOpacity(0.3),
                    //       onPressed: () {
                    //         Navigator.pop(context, true);
                    //       },
                    //     );
                    //     Widget noButton = FlatButton(
                    //       child: Text(Translations.of(context).trans('cancel'),
                    //           style: TextStyle(color: Settings.majorColor)),
                    //       focusColor: Settings.majorColor,
                    //       splashColor: Settings.majorColor.withOpacity(0.3),
                    //       onPressed: () {
                    //         Navigator.pop(context, false);
                    //       },
                    //     );
                    //     var dialog = await showDialog(
                    //       context: context,
                    //       builder: (BuildContext context) => AlertDialog(
                    //         actions: [yesButton, noButton],
                    //         title: Text('Pixiv Login'),
                    //         contentPadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    //         content: Column(
                    //           mainAxisSize: MainAxisSize.min,
                    //           children: <Widget>[
                    //             Row(children: [
                    //               Text('Id: '),
                    //               Expanded(
                    //                 child: TextField(
                    //                   controller: nameController,
                    //                 ),
                    //               ),
                    //             ]),
                    //             Row(children: [
                    //               Text('Pwd: '),
                    //               Expanded(
                    //                 child: TextField(
                    //                   controller: descController,
                    //                 ),
                    //               ),
                    //             ]),
                    //           ],
                    //         ),
                    //       ),
                    //     );
                    //     if (dialog) {
                    //       var id = nameController.text.trim();
                    //       var pwd = descController.text.trim();
                    //       print(id);
                    //       print(pwd);
                    //       await (await SharedPreferences.getInstance())
                    //           .setString('pixiv_id', id);
                    //       await (await SharedPreferences.getInstance())
                    //           .setString('pixiv_pwd', pwd);
                    //       var accessToken =
                    //           await PixivAPI.getAccessToken(id, pwd);
                    //       if (accessToken == null || accessToken == '') {
                    //         flutterToast.showToast(
                    //           child: ToastWrapper(
                    //             isCheck: false,
                    //             msg: 'Login Fail. Try Again!',
                    //           ),
                    //           gravity: ToastGravity.BOTTOM,
                    //           toastDuration: Duration(seconds: 4),
                    //         );
                    //       } else {
                    //         flutterToast.showToast(
                    //           child: ToastWrapper(
                    //             isCheck: true,
                    //             msg: 'Login Success!',
                    //           ),
                    //           gravity: ToastGravity.BOTTOM,
                    //           toastDuration: Duration(seconds: 4),
                    //         );
                    //       }
                    //     }
                    //   },
                    // ),
                  ],
                ),
                _buildGroup(Translations.of(context).trans('view')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.progressClock,
                        color: Settings.majorColor,
                      ),
                      title: Text(Translations.of(context)
                          .trans('showarticleprogress')),
                      trailing: Switch(
                        value: Settings.showArticleProgress,
                        onChanged: (value) async {},
                        activeTrackColor: Settings.majorColor,
                        activeColor: Settings.majorAccentColor,
                      ),
                    ),
                    onTap: Platform.isIOS
                        ? null
                        : () async {
                            await Settings.setShowArticleProgress(
                                !Settings.showArticleProgress);
                            setState(() {});
                          },
                  ),
                ]),
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

                // _buildGroup(Translations.of(context).trans('network')),
                // _buildItems([
                //   InkWell(
                //     customBorder: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(10.0),
                //     ),
                //     child: ListTile(
                //       // borderRadius: BorderRadius.circular(10.0),
                //       leading: Icon(
                //         Icons.router,
                //         color: Settings.majorColor,
                //       ),
                //       title:
                //           Text(Translations.of(context).trans('routing_rule')),
                //       trailing: Icon(
                //           // Icons.message,
                //           Icons.keyboard_arrow_right),
                //     ),
                //     onTap: () {},
                //   ),
                // ]),
                _buildGroup(Translations.of(context).trans('update')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: ListTile(
                      // borderRadius: BorderRadius.circular(10.0),
                      leading: Icon(
                        Icons.update,
                        color: Settings.majorColor,
                      ),
                      title:
                          Text(Translations.of(context).trans('checkupdate')),
                      trailing: Icon(
                          // Icons.message,
                          Icons.keyboard_arrow_right),
                    ),
                    onTap: () async {
                      await UpdateSyncManager.checkUpdateSync();

                      if (UpdateSyncManager.updateRequire) {
                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            msg: Translations.of(context).trans('newupdate'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                      } else {
                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            msg: Translations.of(context).trans('latestver'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: Duration(seconds: 4),
                        );
                      }
                    },
                  ),
                ]),
                _buildGroup(Translations.of(context).trans('etc')),
                _buildItems([
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10.0),
                            topRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.discord,
                        color: Color(0xFF7189da),
                      ),
                      title: Text(Translations.of(context).trans('discord')),
                      trailing: Icon(Icons.open_in_new),
                    ),
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
                      // const url = 'https://www.patreon.com/projectviolet';
                      // if (await canLaunch(url)) {
                      //   await launch(url);
                      // }
                    },
                  ),
                  _buildDivider(),
                  ListTile(
                    leading: Icon(
                      MdiIcons.humanHandsup,
                      color: Settings.majorColor,
                    ),
                    title: Text('Developers'),
                    trailing: Icon(
                        // Icons.email,
                        Icons.keyboard_arrow_right),
                    onTap: () async {
                      // const url = 'https://www.patreon.com/projectviolet';
                      // if (await canLaunch(url)) {
                      //   await launch(url);
                      // }
                    },
                  ),
                  // _buildDivider(),
                  // ListTile(
                  //   leading: Icon(
                  //     MdiIcons.script,
                  //     color: Settings.majorColor,
                  //   ),
                  //   title: Text(Translations.of(context).trans('termsofuse')),
                  //   trailing: Icon(
                  //       // Icons.email,
                  //       Icons.keyboard_arrow_right),
                  //   onTap: () async {

                  //   },
                  // ),
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
                  InkWell(
                    customBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0))),
                    child: ListTile(
                      leading: Icon(
                        MdiIcons.library,
                        color: Settings.majorColor,
                      ),
                      title: Text(Translations.of(context).trans('license')),
                      trailing: Icon(
                          // Icons.email,
                          Icons.keyboard_arrow_right),
                    ),
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   CupertinoPageRoute(
                      //     builder: (context) => LicensePage(
                      //       applicationName: 'Project Violet\n',
                      //       applicationIcon: Image.asset(
                      //         'assets/images/logo.png',
                      //         width: 100,
                      //         height: 100,
                      //       ),
                      //     ),
                      //   ),
                      // );
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => VioletLicensePage(),
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
                          'Copyright (C) 2020-2021 by project-violet',
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, 2),
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
