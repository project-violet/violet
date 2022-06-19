// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';
import 'dart:io';

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
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mdi/mdi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:violet/component/eh/eh_bookmark.dart';
import 'package:violet/component/hitomi/hitomi.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/database/database.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/downloader/isolate_downloader.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/community/user_status_card.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/segment/platform_navigator.dart';
import 'package:violet/pages/settings/bookmark_version_select.dart';
import 'package:violet/pages/settings/db_rebuild_page.dart';
import 'package:violet/pages/settings/import_from_eh.dart';
import 'package:violet/pages/settings/license_page.dart';
import 'package:violet/pages/settings/lock_setting_page.dart';
import 'package:violet/pages/settings/log_page.dart';
import 'package:violet/pages/settings/login/ehentai_login.dart';
import 'package:violet/pages/settings/restore_bookmark.dart';
import 'package:violet/pages/settings/route.dart';
import 'package:violet/pages/settings/tag_rebuild_page.dart';
import 'package:violet/pages/settings/tag_selector.dart';
import 'package:violet/pages/settings/version_page.dart';
import 'package:violet/pages/splash/splash_page.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';
import 'package:violet/version/update_sync.dart';
import 'package:violet/widgets/toast.dart';

class ExCountry extends Country {
  String? language;
  String? script;
  String? region;
  String? variant;

  ExCountry(
    String name,
    String isoCode,
    String iso3Code,
    String phoneCode,
  ) : super(
          name: name,
          isoCode: isoCode,
          iso3Code: iso3Code,
          phoneCode: phoneCode,
        );

  static ExCountry create(String iso,
      {String? language, String? script, String? region, String? variant}) {
    var c = CountryPickerUtils.getCountryByIsoCode(iso);
    var country = ExCountry(c.name, c.isoCode, c.iso3Code, c.phoneCode);
    country.language = language;
    country.script = script;
    country.region = region;
    country.variant = variant;
    return country;
  }

  @override
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

    if (dict.containsKey(isoCode)) return dict[isoCode]!;

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

    if (dict.containsKey(isoCode)) return dict[isoCode]!;

    if (isoCode == 'CN') {
      if (script == 'Hant') return '中文(繁體)';
      if (script == 'Hans') return '中文(简体)';
    }

    return 'English';
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with AutomaticKeepAliveClientMixin<SettingsPage> {
  final FlareControls _flareController = FlareControls();
  bool _themeSwitch = false;
  late final FToast flutterToast;

  @override
  void initState() {
    super.initState();
    _themeSwitch = Settings.themeWhat;
    flutterToast = FToast();
    flutterToast.init(context);
  }

  List<Widget>? _cachedGroups;
  bool _shouldReload = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    if (_cachedGroups == null || _shouldReload) {
      _shouldReload = false;
      _cachedGroups = _themeGroup()
        ..add(const UserStatusCard())
        ..addAll(_searchGroup())
        ..addAll(_systemGroup())
        ..addAll(_securityGroup())
        ..addAll(_databaseGroup())
        ..addAll(_networkingGroup())
        ..addAll(_downloadGroup())
        ..addAll(_bookmarkGroup())
        ..addAll(_componetGroup())
        ..addAll(_viewGroup())
        ..addAll(_updateGroup())
        ..addAll(_etcGroup())
        ..add(_bottomInfo());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: statusBarHeight),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _cachedGroups!,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(name,
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 24.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              )),
        ],
      ),
    );
  }

  Container _buildItems(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      width: double.infinity,
      decoration: !Settings.themeFlat
          ? BoxDecoration(
              color: Settings.themeWhat ? Colors.black26 : Colors.white,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8)),
              boxShadow: [
                BoxShadow(
                  color: Settings.themeWhat
                      ? Colors.black26
                      : Colors.grey.withOpacity(0.1),
                  spreadRadius: Settings.themeWhat ? 0 : 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3), // changes position of shadow
                ),
              ],
            )
          : null,
      color: !Settings.themeFlat
          ? null
          : Settings.themeWhat
              ? Colors.black26
              : Colors.white,
      child: !Settings.themeFlat
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Material(
                color: Settings.themeWhat
                    ? Settings.themeBlack
                        ? const Color(0xFF141414)
                        : Colors.black38
                    : Colors.white,
                child: Column(children: items),
              ))
          : Column(children: items),
    );
  }

  @override
  bool get wantKeepAlive => true;

  List<Widget> _themeGroup() {
    return [
      _buildGroup(Translations.of(context).trans('theme')),
      _buildItems([
        InkWell(
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0))),
          child: ListTile(
            leading: ShaderMask(
              shaderCallback: (bounds) => const RadialGradient(
                center: Alignment.topLeft,
                radius: 1.0,
                colors: [Colors.black, Colors.white],
                tileMode: TileMode.clamp,
              ).createShader(bounds),
              child: const Icon(MdiIcons.themeLightDark, color: Colors.white),
            ),
            title: Text(Translations.of(context).trans('darkmode')),
            trailing: SizedBox(
              width: 50,
              height: 50,
              child: FlareActor(
                'assets/flare/switch_daytime.flr',
                animation: _themeSwitch ? 'night_idle' : 'day_idle',
                controller: _flareController,
                snapToEnd: true,
              ),
            ),
          ),
          onTap: () async {
            if (!_themeSwitch) {
              _flareController.play('switch_night');
            } else {
              _flareController.play('switch_day');
            }
            _themeSwitch = !_themeSwitch;
            await Settings.setThemeWhat(_themeSwitch);
            DynamicTheme.of(context)!.setBrightness(
                !_themeSwitch ? Brightness.light : Brightness.dark);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        _buildDivider(),
        ListTile(
          leading: ShaderMask(
            shaderCallback: (bounds) => const RadialGradient(
              center: Alignment.bottomLeft,
              radius: 1.2,
              colors: [Colors.orange, Colors.pink],
              tileMode: TileMode.clamp,
            ).createShader(bounds),
            child: const Icon(MdiIcons.formatColorFill, color: Colors.white),
          ),
          title: Text(Translations.of(context).trans('colorsetting')),
          trailing: const Icon(
              // Icons.message,
              Icons.keyboard_arrow_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(Translations.of(context).trans('selectcolor')),
                  content: SingleChildScrollView(
                    child: BlockPicker(
                      pickerColor: Settings.majorColor,
                      onColorChanged: (color) async {
                        await Settings.setMajorColor(color);
                        setState(() {
                          _shouldReload = true;
                        });
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
          onTap: _themeSwitch
              ? () async {
                  await Settings.setThemeBlack(!Settings.themeBlack);
                  DynamicTheme.of(context)!.setThemeData(
                    ThemeData(
                      accentColor: Settings.majorColor,
                      brightness: Theme.of(context).brightness,
                      bottomSheetTheme: BottomSheetThemeData(
                          backgroundColor: Colors.black.withOpacity(0)),
                      scaffoldBackgroundColor:
                          Settings.themeBlack && Settings.themeWhat
                              ? Colors.black
                              : null,
                      dialogBackgroundColor:
                          Settings.themeBlack && Settings.themeWhat
                              ? const Color(0xFF141414)
                              : null,
                      cardColor: Settings.themeBlack && Settings.themeWhat
                          ? const Color(0xFF141414)
                          : null,
                    ),
                  );
                  setState(() {
                    _shouldReload = true;
                  });
                }
              : null,
          child: ListTile(
            leading: Icon(MdiIcons.brightness3, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('blackmode')),
            trailing: Switch(
              value: Settings.themeBlack,
              onChanged: _themeSwitch
                  ? (newValue) async {
                      await Settings.setThemeFlat(newValue);
                      DynamicTheme.of(context)!.setThemeData(
                        ThemeData(
                          accentColor: Settings.majorColor,
                          brightness: Theme.of(context).brightness,
                          bottomSheetTheme: BottomSheetThemeData(
                              backgroundColor: Colors.black.withOpacity(0)),
                          scaffoldBackgroundColor:
                              Settings.themeBlack && Settings.themeWhat
                                  ? Colors.black
                                  : null,
                          dialogBackgroundColor:
                              Settings.themeBlack && Settings.themeWhat
                                  ? const Color(0xFF141414)
                                  : null,
                          cardColor: Settings.themeBlack && Settings.themeWhat
                              ? const Color(0xFF141414)
                              : null,
                        ),
                      );
                      setState(() {
                        _shouldReload = true;
                      });
                    }
                  : null,
              activeTrackColor: Settings.majorColor,
              activeColor: Settings.majorAccentColor,
            ),
          ),
        ),
        _buildDivider(),
        InkWell(
          child: ListTile(
            leading: Icon(Mdi.buffer, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('useflattheme')),
            trailing: Switch(
              value: Settings.themeFlat,
              onChanged: (newValue) async {
                await Settings.setThemeFlat(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor,
              activeColor: Settings.majorAccentColor,
            ),
          ),
          onTap: () async {
            await Settings.setThemeFlat(!Settings.themeFlat);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        _buildDivider(),
        InkWell(
          child: ListTile(
            leading: Icon(MdiIcons.tabletDashboard, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('usetabletmode')),
            trailing: Switch(
              value: Settings.useTabletMode,
              onChanged: (newValue) async {
                await Settings.setUseTabletMode(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor,
              activeColor: Settings.majorAccentColor,
            ),
          ),
          onTap: () async {
            await Settings.setUseTabletMode(!Settings.useTabletMode);
            setState(() {
              _shouldReload = true;
            });
          },
        ),
        _buildDivider(),
        InkWell(
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8.0),
                  bottomRight: Radius.circular(8.0))),
          child: ListTile(
            leading: Icon(MdiIcons.cellphoneText, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('userdrawer')),
            trailing: Switch(
              value: Settings.useDrawer,
              onChanged: (newValue) async {
                await Settings.setUseDrawer(newValue);
                setState(() {
                  _shouldReload = true;
                });

                final afterLoadingPageState =
                    context.findAncestorStateOfType<AfterLoadingPageState>();
                afterLoadingPageState!.setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor,
              activeColor: Settings.majorAccentColor,
            ),
          ),
          onTap: () async {
            await Settings.setUseDrawer(!Settings.useDrawer);
            setState(() {
              _shouldReload = true;
            });

            final afterLoadingPageState =
                context.findAncestorStateOfType<AfterLoadingPageState>();
            afterLoadingPageState!.setState(() {
              _shouldReload = true;
            });
          },
        ),
      ])
    ];
  }

  List<Widget> _searchGroup() {
    return [
      _buildGroup(Translations.of(context).trans('search')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
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
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              final vv = await showDialog(
                context: context,
                builder: (BuildContext context) =>
                    const TagSelectorDialog(what: 'include'),
              );

              if (vv != null && vv.item1 == 1) {
                Settings.setIncludeTags(vv.item2);
                setState(() {
                  _shouldReload = true;
                });
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
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              final vv = await showDialog(
                context: context,
                builder: (BuildContext context) =>
                    const TagSelectorDialog(what: 'exclude'),
              );

              if (vv.item1 == 1) {
                Settings.setExcludeTags(vv.item2);
                setState(() {
                  _shouldReload = true;
                });
              }
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              MdiIcons.tooltipEdit,
              color: Settings.majorColor,
            ),
            title: Text(Translations.of(context).trans('tagrebuild')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              if (await showYesNoDialog(
                  context,
                  Translations.of(context).trans('tagrebuildmsg'),
                  Translations.of(context).trans('tagrebuild'))) {
                await showDialog(
                  context: context,
                  builder: (BuildContext context) => const TagRebuildPage(),
                );

                await HitomiIndexs.init();
                HitomiManager.reloadIndex();

                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: true,
                    msg:
                        '${Translations.of(context).trans('tagrebuild')} ${Translations.of(context).trans('complete')}',
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
              }
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(Mdi.compassOutline, color: Settings.majorColor),
              title: const Text('Pure Search'),
              trailing: Switch(
                value: Settings.searchPure,
                onChanged: (newValue) async {
                  await Settings.setSearchPure(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setSearchPure(!Settings.searchPure);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(
                MdiIcons.searchWeb,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('usewebsearch')),
              trailing: Switch(
                value: Settings.searchNetwork,
                onChanged: (newValue) async {
                  await Settings.setSearchOnWeb(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setSearchOnWeb(!Settings.searchNetwork);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _systemGroup() {
    return [
      _buildGroup(Translations.of(context).trans('system')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(Icons.receipt, color: Settings.majorColor),
              title: Text(Translations.of(context).trans('logrecord')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () {
              PlatformNavigator.navigateSlide(context, const LogPage());
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(Icons.language, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('language')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Theme(
                    data: Theme.of(context).copyWith(primaryColor: Colors.pink),
                    child: CountryPickerDialog(
                        titlePadding: const EdgeInsets.symmetric(vertical: 16),
                        // searchCursorColor: Colors.pinkAccent,
                        // searchInputDecoration:
                        //     InputDecoration(hintText: 'Search...'),
                        // isSearchable: true,
                        title: const Text('Select Language'),
                        onValuePicked: (Country country) async {
                          var exc = country as ExCountry;
                          await Translations.of(context).load(exc.toString());
                          await Settings.setLanguage(exc.toString());
                          setState(() {
                            _shouldReload = true;
                          });
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
                          return Row(
                            children: <Widget>[
                              CountryPickerUtils.getDefaultFlagImage(country),
                              const SizedBox(
                                width: 8.0,
                                height: 30,
                              ),
                              Text((country as ExCountry).getDisplayLanguage()),
                            ],
                          );
                        })),
              );
            },
          ),
          if (Settings.language == 'ko') _buildDivider(),
          if (Settings.language == 'ko')
            ListTile(
              leading: Icon(Icons.translate, color: Settings.majorColor),
              title:
                  Text(Translations.of(context).trans('translatetagtokorean')),
              trailing: Switch(
                value: Settings.translateTags,
                onChanged: (newValue) async {
                  await Settings.setTranslateTags(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
              onTap: () async {
                await Settings.setTranslateTags(!Settings.translateTags);
                setState(() {
                  _shouldReload = true;
                });
              },
            ),
          _buildDivider(),
          ListTile(
            leading:
                Icon(MdiIcons.imageSizeSelectLarge, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('lowresmode')),
            trailing: Switch(
              value: Settings.useLowPerf,
              onChanged: (newValue) async {
                await Settings.setUseLowPerf(newValue);
                setState(() {
                  _shouldReload = true;
                });
              },
              activeTrackColor: Settings.majorColor,
              activeColor: Settings.majorAccentColor,
            ),
            onTap: () async {
              await Settings.setUseLowPerf(!Settings.useLowPerf);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(Mdi.tableArrowRight, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('exportlog')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await Logger.exportLog();

              flutterToast.showToast(
                child: ToastWrapper(
                  isCheck: true,
                  msg: Translations.of(context).trans('complete'),
                ),
                gravity: ToastGravity.BOTTOM,
                toastDuration: const Duration(seconds: 4),
              );
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(Icons.info_outline, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('info')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const VersionViewPage();
                },
              );
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            child: ListTile(
              leading: const Icon(Icons.developer_mode, color: Colors.orange),
              title: Text(Translations.of(context).trans('devtool')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              if (kDebugMode) {
                // Navigator.push(
                //   context,
                //   CupertinoPageRoute(
                //     builder: (context) => TestPage(),
                //   ),
                // );
              } else {
                await showOkDialog(
                    context, 'Developer tools can only be run in debug mode.');
              }
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _securityGroup() {
    return [
      _buildGroup(Translations.of(context).trans('security')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            child: ListTile(
              // borderRadius: BorderRadius.circular(8.0),
              leading: Icon(
                Icons.lock_outline,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('lockapp')),
              trailing: const Icon(
                  // Icons.message,
                  Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const LockSettingPage(),
                ),
              );
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(
                MdiIcons.shieldLockOutline,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('securemode')),
              trailing: Switch(
                value: Settings.useSecureMode,
                onChanged: (newValue) async {
                  await Settings.setUseSecureMode(newValue);
                  await _setSecureMode();
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setUseSecureMode(!Settings.useSecureMode);
              await _setSecureMode();
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        ],
      ),
    ];
  }

  Future<void> _setSecureMode() async {
    if (Platform.isAndroid) {
      if (Settings.useSecureMode) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    }
  }

  List<Widget> _databaseGroup() {
    return [
      _buildGroup(Translations.of(context).trans('database')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            onTap: Variables.databaseDecompressed
                ? null
                : () async {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const SplashPage(
                              switching: true,
                            )));
                  },
            child: ListTile(
              leading:
                  Icon(MdiIcons.swapHorizontal, color: Settings.majorColor),
              title: Text(Translations.of(context).trans('switching')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(
                MdiIcons.databaseEdit,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('dbrebuild')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              if (await showYesNoDialog(
                  context,
                  Translations.of(context).trans('dbrebuildmsg'),
                  Translations.of(context).trans('dbrebuild'))) {
                await showDialog(
                  context: context,
                  builder: (BuildContext context) => const DBRebuildPage(),
                );

                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: true,
                    msg:
                        '${Translations.of(context).trans('dbrebuild')} ${Translations.of(context).trans('complete')}',
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
              }
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(
                MdiIcons.vectorIntersection,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('dbopt')),
              trailing: Switch(
                value: Settings.useOptimizeDatabase,
                onChanged: (newValue) async {
                  await Settings.setUseOptimizeDatabase(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setUseOptimizeDatabase(
                  !Settings.useOptimizeDatabase);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            onTap: Variables.databaseDecompressed
                ? null
                : () async {
                    final prefs = await SharedPreferences.getInstance();
                    var latestDB = SyncManager.getLatestDB().getDateTime();
                    var lastDB = prefs.getString('databasesync');

                    if (lastDB != null &&
                        latestDB.difference(DateTime.parse(lastDB)).inHours <
                            1) {
                      flutterToast.showToast(
                        child: ToastWrapper(
                          isCheck: true,
                          msg: Translations.of(context)
                              .trans('thisislatestbookmark'),
                        ),
                        gravity: ToastGravity.BOTTOM,
                        toastDuration: const Duration(seconds: 4),
                      );
                      return;
                    }

                    var dir = await getApplicationDocumentsDirectory();
                    try {
                      await ((await openDatabase('${dir.path}/data/data.db'))
                          .close());
                      await deleteDatabase('${dir.path}/data/data.db');
                      await Directory('${dir.path}/data')
                          .delete(recursive: true);
                    } catch (_) {}

                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (context) => DataBaseDownloadPage(
                                  dbType: Settings.databaseType,
                                  isSync: true,
                                )))
                        .then(
                      (value) async {
                        HitomiIndexs.init();
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final path = File('${directory.path}/data/index.json');
                        final text = path.readAsStringSync();
                        HitomiManager.tagmap = jsonDecode(text);
                        await DataBaseManager.reloadInstance();

                        flutterToast.showToast(
                          child: ToastWrapper(
                            isCheck: true,
                            msg: Translations.of(context).trans('synccomplete'),
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: const Duration(seconds: 4),
                        );
                      },
                    );
                  },
            child: ListTile(
              leading: Icon(MdiIcons.databaseSync, color: Settings.majorColor),
              title: Text(Translations.of(context).trans('syncmanual')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _networkingGroup() {
    return [
      _buildGroup(Translations.of(context).trans('network')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(MdiIcons.vpn, color: Settings.majorColor),
              title: const Text('VPN'),
              trailing: const Icon(Icons.keyboard_arrow_right),
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
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (BuildContext context) => const RouteDialog(),
              );
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              Icons.router,
              color: Settings.majorColor,
            ),
            title:
                Text('Image ${Translations.of(context).trans('routing_rule')}'),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (BuildContext context) => const ImageRouteDialog(),
              );
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              MdiIcons.commentSearch,
              color: Settings.majorColor,
            ),
            title: Text(Translations.of(context).trans('messagesearchapi')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              TextEditingController text =
                  TextEditingController(text: Settings.searchMessageAPI);
              Widget okButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('ok')),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              );
              Widget defaultButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('default')),
                onPressed: () {
                  _shouldReload = true;
                  setState(
                      () => text.text = 'https://koromo.xyz/api/search/msg');
                },
              );
              var dialog = await showDialog(
                useRootNavigator: false,
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  title: const Text('대사 검색기 API'),
                  content: TextField(
                    controller: text,
                    autofocus: true,
                    maxLines: 3,
                  ),
                  actions: [defaultButton, okButton, cancelButton],
                ),
              );
              if (dialog != null && dialog == true) {
                await Settings.setSearchMessageAPI(text.text);
              }
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Image.asset(
                'assets/images/logo.png',
                width: 25,
                height: 25,
              ),
              title: Text(Translations.of(context).trans('usevioletserver')),
              trailing: Switch(
                value: Settings.useVioletServer,
                onChanged: (newValue) async {
                  await Settings.setUseVioletServer(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setUseVioletServer(!Settings.useVioletServer);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _downloadGroup() {
    return [
      _buildGroup(Translations.of(context).trans('download')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            onTap: Platform.isIOS
                ? null
                : () async {
                    await Settings.setUserInnerStorage(
                        !Settings.useInnerStorage);
                    setState(() {
                      _shouldReload = true;
                    });
                  },
            child: ListTile(
              leading: Icon(
                MdiIcons.downloadLock,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('useinnerstorage')),
              trailing: Switch(
                value: Settings.useInnerStorage,
                onChanged: Platform.isIOS
                    ? null
                    : (newValue) async {
                        await Settings.setUserInnerStorage(newValue);
                        setState(() {
                          _shouldReload = true;
                        });
                      },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              MdiIcons.lan,
              color: Settings.majorColor,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Translations.of(context).trans('threadcount'),
                ),
                FutureBuilder(
                  builder:
                      (context, AsyncSnapshot<SharedPreferences> snapshot) {
                    if (!snapshot.hasData) {
                      return Text(
                        '${Translations.of(context).trans('curthread')}: ',
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    return Text(
                      '${Translations.of(context).trans('curthread')}: ${snapshot.data!.getInt('thread_count')}',
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                  future: SharedPreferences.getInstance(),
                )
              ],
            ),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              // 32개 => 50mb/s
              var tc = prefs.getInt('thread_count');

              TextEditingController text =
                  TextEditingController(text: tc.toString());
              Widget yesButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                onPressed: () async {
                  if (int.tryParse(text.text) == null) {
                    await showOkDialog(
                        context, Translations.of(context).trans('putonlynum'));
                    return;
                  }
                  if (int.parse(text.text) > 128) {
                    await showOkDialog(
                        context, Translations.of(context).trans('toomuch'));
                    return;
                  }
                  if (int.parse(text.text) == 0) {
                    await showOkDialog(
                        context, Translations.of(context).trans('threadzero'));
                    return;
                  }

                  Navigator.pop(context, true);
                },
                child: Text(Translations.of(context).trans('change'),
                    style: TextStyle(color: Settings.majorColor)),
              );
              Widget noButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: Text(Translations.of(context).trans('cancel'),
                    style: TextStyle(color: Settings.majorColor)),
              );
              var dialog = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  title: Text(Translations.of(context).trans('setthread')),
                  content: TextField(
                    controller: text,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                  actions: [yesButton, noButton],
                ),
              );
              if (dialog == true) {
                (await IsolateDownloader.getInstance())
                    .changeThreadCount(int.parse(text.text));

                await prefs.setInt('thread_count', int.parse(text.text));

                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: true,
                    msg: Translations.of(context).trans('changedthread'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );

                setState(() {});
              }
            },
          ),
          _buildDivider(),
          InkWell(
            // customBorder: RoundedRectangleBorder(
            //   borderRadius: BorderRadius.all(
            //     Radius.circular(8.0),
            //   ),
            child: ListTile(
              leading:
                  Icon(MdiIcons.folderDownload, color: Settings.majorColor),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Translations.of(context).trans('downloadpath')),
                  Text(
                    '${Translations.of(context).trans('curdownloadpath')}: ${Settings.downloadBasePath}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: Settings.useInnerStorage
                ? null
                : () async {
                    TextEditingController text =
                        TextEditingController(text: Settings.downloadBasePath);
                    Widget yesButton = TextButton(
                      style: TextButton.styleFrom(primary: Settings.majorColor),
                      child: Text(Translations.of(context).trans('ok')),
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                    );
                    Widget noButton = TextButton(
                      style: TextButton.styleFrom(primary: Settings.majorColor),
                      child: Text(Translations.of(context).trans('cancel')),
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                    );
                    Widget defaultButton = TextButton(
                      style: TextButton.styleFrom(primary: Settings.majorColor),
                      child: Text(Translations.of(context).trans('default')),
                      onPressed: () {
                        _shouldReload = true;
                        Settings.getDefaultDownloadPath()
                            .then((value) => setState(() => text.text = value));
                      },
                    );
                    var dialog = await showDialog(
                      useRootNavigator: false,
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                        title: Text(
                            Translations.of(context).trans('downloadpath')),
                        content: TextField(
                          controller: text,
                          autofocus: true,
                          maxLines: 3,
                        ),
                        actions: [defaultButton, yesButton, noButton],
                      ),
                    );
                    if (dialog != null && dialog == true) {
                      try {
                        if (await Permission.storage.isGranted) {
                          var prevDir = Directory(Settings.downloadBasePath);
                          if (await prevDir.exists()) {
                            await prevDir.rename(text.text);
                          }
                        }
                      } catch (_) {}

                      await Settings.setBaseDownloadPath(text.text);
                    }
                  },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            //   customBorder: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.all(
            //       Radius.circular(8.0),
            //     ),
            //   ),
            child: ListTile(
              leading: Icon(MdiIcons.folderTable, color: Settings.majorColor),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Translations.of(context).trans('downloadrule')),
                  Text(
                    '${Translations.of(context).trans('curdownloadrule')}: ${Settings.downloadRule}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              TextEditingController text =
                  TextEditingController(text: Settings.downloadRule);
              Widget okButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('ok')),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              );
              Widget defaultButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('default')),
                onPressed: () {
                  _shouldReload = true;
                  setState(() =>
                      text.text = '%(extractor)s/%(id)s/%(file)s.%(ext)s');
                },
              );
              var dialog = await showDialog(
                useRootNavigator: false,
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  title: Text(Translations.of(context).trans('downloadrule')),
                  content: TextField(
                    controller: text,
                    autofocus: true,
                    maxLines: 3,
                  ),
                  actions: [defaultButton, okButton, cancelButton],
                ),
              );
              if (dialog != null && dialog == true) {
                await Settings.setDownloadRule(text.text);
              }
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _bookmarkGroup() {
    return [
      _buildGroup(Translations.of(context).trans('bookmark')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            onTap: true
                ? null
                : () async {
                    await Settings.setAutoBackupBookmark(
                        !Settings.autobackupBookmark);
                    setState(() {
                      _shouldReload = true;
                    });
                  },
            child: ListTile(
              leading: Icon(
                MdiIcons.bookArrowUpOutline,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('autobackupbookmark')),
              trailing: Switch(
                value: Settings.autobackupBookmark,
                onChanged: true
                    ? null
                    : (newValue) async {
                        await Settings.setAutoBackupBookmark(newValue);
                        setState(() {
                          _shouldReload = true;
                        });
                      },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              MdiIcons.bookArrowDownOutline,
              color: Settings.majorColor,
            ),
            title: Text(Translations.of(context).trans('restoringbookmark')),
            trailing: const Icon(Icons.keyboard_arrow_right),
            onTap: () async {
              await showOkDialog(
                  context,
                  Translations.of(context).trans('restorebookmarkmsg'),
                  Translations.of(context).trans('warning'));

              final prefs = await SharedPreferences.getInstance();
              var myappid = prefs.getString('fa_userid');

              // 1. 북마크 유저 아이디 선택
              TextEditingController text = TextEditingController(text: myappid);
              Widget okButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('ok')),
                onPressed: () {
                  Navigator.pop(context, true);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: Text(Translations.of(context).trans('cancel')),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              );
              var dialog = await showDialog(
                useRootNavigator: false,
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  contentPadding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  title: const Text('Enter User App Id'),
                  content: TextField(
                    controller: text,
                    autofocus: true,
                    maxLines: 3,
                  ),
                  actions: [okButton, cancelButton],
                ),
              );
              if (dialog == null || dialog == false) {
                // await Settings.setDownloadRule(text.text);
                return;
              }

              try {
                // 2. 유효한 유저 아이디 인지 확인(서버 요청 및 다운로드)
                var result = await VioletServer.resotreBookmark(text.text);
                if (result == null) {
                  await showOkDialog(
                      context,
                      "Invalid User-App-Id! If you're still getting this error, contact the developer.",
                      Translations.of(context).trans('restoringbookmark'));
                  return;
                }

                // 3. 북마크 버전 가져오기
                var versions = await VioletServer.versionsBookmark(text.text);
                if (versions == null) {
                  await showOkDialog(
                      context,
                      '북마크 버전 정보를 가져오는데 오류가 발생했습니다. UserAppId와 함께 개발자에게 문의하시기 바랍니다.',
                      Translations.of(context).trans('restoringbookmark'));
                  return;
                }

                // 4. 버전 선택 및 북마크 확인 (이 북마크를 복원할까요?)
                var version = await PlatformNavigator.navigateSlide(
                  context,
                  BookmarkVersionSelectPage(
                    userAppId: text.text,
                    versions: versions,
                  ),
                );

                if (version == null) {
                  return;
                }

                // 5. 열람기록도 같이 복원할까요?
                var restoreWithRecord =
                    await showYesNoDialog(context, '열람기록도 같이 복원할까요?');

                // 6. 북마크 다운로드
                var bookmark = await VioletServer.resotreBookmarkWithVersion(
                    text.text, version);

                // 7. 덮어쓰기 한다.
                var rr = await showDialog(
                  context: context,
                  builder: (BuildContext context) => RestoreBookmarkPage(
                    source: bookmark,
                    restoreWithRecord: restoreWithRecord,
                  ),
                );

                if (rr != null && rr == false) {
                  return;
                }
              } catch (e, st) {
                Logger.error('[Restore Bookmark] $e\n'
                    '$st');
                flutterToast.showToast(
                  child: const ToastWrapper(
                    isCheck: false,
                    msg: 'Bookmark Restoring Error!',
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
                return;
              }

              await Bookmark.getInstance();

              flutterToast.showToast(
                child: ToastWrapper(
                  isCheck: true,
                  msg: Translations.of(context).trans('importbookmark'),
                ),
                gravity: ToastGravity.BOTTOM,
                toastDuration: const Duration(seconds: 4),
              );
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(MdiIcons.import, color: Settings.majorColor),
            title: Text(Translations.of(context).trans('importingbookmark')),
            trailing: const Icon(Icons.keyboard_arrow_right),
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
                    toastDuration: const Duration(seconds: 4),
                  );
                  return;
                }
              }

              File file;
              file = File((await FilePicker.platform.pickFiles(
                type: FileType.any,
              ))!
                  .files
                  .single
                  .path!);

              if (file == null) {
                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: false,
                    msg: Translations.of(context).trans('noselectedb'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
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
                toastDuration: const Duration(seconds: 4),
              );
            },
          ),
          _buildDivider(),
          ListTile(
            leading: Icon(
              MdiIcons.export,
              color: Settings.majorColor,
            ),
            title: Text(Translations.of(context).trans('exportingbookmark')),
            trailing: const Icon(Icons.keyboard_arrow_right),
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
                    toastDuration: const Duration(seconds: 4),
                  );

                  return;
                }
              }

              var db = await getApplicationDocumentsDirectory();
              var dbfile = File('${db.path}/user.db');
              var ext = await getExternalStorageDirectory();
              var extpath = '${ext!.path}/bookmark.db';
              await dbfile.copy(extpath);

              flutterToast.showToast(
                child: ToastWrapper(
                  isCheck: true,
                  msg: Translations.of(context).trans('exportbookmark'),
                ),
                gravity: ToastGravity.BOTTOM,
                toastDuration: const Duration(seconds: 4),
              );
            },
          ),
          _buildDivider(),
          InkWell(
            child: ListTile(
              leading: Icon(
                MdiIcons.cloudSearchOutline,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('importfromeh')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              var ehc = prefs.getString('eh_cookies');

              if (ehc == null || ehc == '') {
                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: false,
                    msg: Translations.of(context).trans('setcookiefirst'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
                return;
              }

              await showDialog(
                context: context,
                builder: (BuildContext context) => const ImportFromEHPage(),
              );

              if (EHBookmark.bookmarkInfo == null) {
                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: false,
                    isWarning: true,
                    msg: Translations.of(context).trans('bookmarkisempty'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
                return;
              }

              int count = 0;
              for (var element in EHBookmark.bookmarkInfo!) {
                count += element.length;
              }

              var qqq = await showYesNoDialog(
                  context,
                  Translations.of(context)
                      .trans('ensurecreatebookmark')
                      .replaceAll('\$1', count.toString()));
              if (qqq) {
                var bookmark = await Bookmark.getInstance();
                for (int i = 0; i < EHBookmark.bookmarkInfo!.length; i++) {
                  if (EHBookmark.bookmarkInfo![i].isEmpty) continue;
                  await bookmark.createGroup('Favorite $i', '', Colors.black);
                  var group = (await bookmark.getGroup())
                      .where((element) => element.name() == 'Favorite $i')
                      .first
                      .id();
                  for (int j = 0; j < EHBookmark.bookmarkInfo![i].length; j++) {
                    await bookmark.insertArticle(
                        EHBookmark.bookmarkInfo![i].elementAt(j).toString(),
                        DateTime.now(),
                        group);
                  }
                }

                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: true,
                    isWarning: false,
                    msg: Translations.of(context)
                        .trans('completeimportbookmark'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
              }
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(8.0),
                  bottomRight: Radius.circular(8.0)),
            ),
            child: ListTile(
              leading: Icon(
                MdiIcons.cloudSearchOutline,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('importfromjson')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              TextEditingController textController = TextEditingController();

              Widget importButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: const Text('Import'),
                onPressed: () async {
                  Navigator.pop(context, textController.text);
                },
              );
              Widget cancelButton = TextButton(
                style: TextButton.styleFrom(primary: Settings.majorColor),
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.pop(context, null);
                },
              );

              final text = await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title:
                        Text(Translations.of(context).trans('importfromjson')),
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    actions: [
                      importButton,
                      cancelButton,
                    ],
                    content: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      reverse: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(Translations.of(context)
                              .trans('pasteyourbookmarktext')),
                          Row(
                            children: [
                              const Text('JSON: '),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText:
                                          'ex: ["1207894", "artist:michiking", ...]'),
                                  controller: textController,
                                  keyboardType: TextInputType.multiline,
                                  minLines: null,
                                  maxLines: null,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );

              if (text == null) return;

              try {
                var json = jsonDecode(text) as List<dynamic>;

                var bookmark = await Bookmark.getInstance();
                await bookmark.createGroup('Hiyobi', '', Colors.black);
                var group = (await bookmark.getGroup())
                    .where((element) => element.name() == 'Hiyobi')
                    .first
                    .id();
                for (int j = 0; j < json.length; j++) {
                  var tar = json.elementAt(j).toString();
                  if (int.tryParse(tar) != null) {
                    await bookmark.insertArticle(tar, DateTime.now(), group);
                  } else if (tar.contains(':') &&
                      ['artist', 'group'].contains(tar.split(':')[0])) {
                    await bookmark.bookmarkArtist(tar.split(':')[1],
                        tar.split(':')[0] == 'artist' ? 0 : 1, group);
                  }
                }

                await showOkDialog(context, 'Success!');
              } catch (e, st) {
                Logger.error('[Import from hiyobi] $e\n'
                    '$st');

                await showOkDialog(context,
                    'Bookmark format is not correct. Please refer to Log Record for details.');
              }
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _componetGroup() {
    return [
      _buildGroup(Translations.of(context).trans('component')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            child: ListTile(
              leading: CachedNetworkImage(
                imageUrl: 'https://e-hentai.org/favicon.ico',
                width: 25,
              ),
              title: const Text('E-Hentai/ExHentai'),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () async {
              var dialog = await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('E-Hentai Login'),
                  contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Settings.majorColor,
                        ),
                        child: const Text('Login From WebPage'),
                        onPressed: () => Navigator.pop(context, 1),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          primary: Settings.majorColor,
                        ),
                        child: const Text('Enter Cookie Information'),
                        onPressed: () => Navigator.pop(context, 2),
                      ),
                    ],
                  ),
                ),
              );

              if (dialog == null) return;

              final prefs = await SharedPreferences.getInstance();
              if (dialog == 1) {
                var result = await Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => const LoginScreen()));

                await prefs.setString('eh_cookies', result);

                if (result != null) {
                  flutterToast.showToast(
                    child: const ToastWrapper(
                      isCheck: true,
                      msg: 'Login Success!',
                    ),
                    gravity: ToastGravity.BOTTOM,
                    toastDuration: const Duration(seconds: 4),
                  );
                }
              } else if (dialog == 2) {
                var cookie = prefs.getString('eh_cookies');

                var iController = TextEditingController(
                    text:
                        cookie != null ? parseCookies(cookie)['igneous'] : '');
                var imiController = TextEditingController(
                    text: cookie != null
                        ? parseCookies(cookie)['ipb_member_id']
                        : '');
                var iphController = TextEditingController(
                    text: cookie != null
                        ? parseCookies(cookie)['ipb_pass_hash']
                        : '');
                Widget okButton = TextButton(
                  style: TextButton.styleFrom(primary: Settings.majorColor),
                  child: Text(Translations.of(context).trans('ok')),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                );
                Widget cancelButton = TextButton(
                  style: TextButton.styleFrom(primary: Settings.majorColor),
                  child: Text(Translations.of(context).trans('cancel')),
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                );
                var dialog = await showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    actions: [okButton, cancelButton],
                    title: const Text('E-Hentai Login'),
                    contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(children: [
                          const Text('igneous: '),
                          Expanded(
                            child: TextField(
                              controller: iController,
                            ),
                          ),
                        ]),
                        Row(children: [
                          const Text('ipb_member_id: '),
                          Expanded(
                            child: TextField(
                              controller: imiController,
                            ),
                          ),
                        ]),
                        Row(children: [
                          const Text('ipb_pass_hash: '),
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
                  await prefs.setString('eh_cookies', ck);
                }
              }

              Settings.searchRule =
                  'ExHentai|EHentai|Hitomi|NHentai|Hisoki'.split('|');
              await prefs.setString(
                  'searchrule', 'ExHentai|EHentai|Hitomi|NHentai|Hisoki');
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _viewGroup() {
    return [
      _buildGroup(Translations.of(context).trans('view')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(
                MdiIcons.progressClock,
                color: Settings.majorColor,
              ),
              title:
                  Text(Translations.of(context).trans('showarticleprogress')),
              trailing: Switch(
                value: Settings.showArticleProgress,
                onChanged: (newValue) async {
                  await Settings.setShowArticleProgress(newValue);
                  setState(() {
                    _shouldReload = true;
                  });
                },
                activeTrackColor: Settings.majorColor,
                activeColor: Settings.majorAccentColor,
              ),
            ),
            onTap: () async {
              await Settings.setShowArticleProgress(
                  !Settings.showArticleProgress);
              setState(() {
                _shouldReload = true;
              });
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _updateGroup() {
    return [
      _buildGroup(Translations.of(context).trans('update')),
      _buildItems(
        [
          InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListTile(
              // borderRadius: BorderRadius.circular(8.0),
              leading: Icon(
                Icons.update,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('checkupdate')),
              trailing: const Icon(
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
                  toastDuration: const Duration(seconds: 4),
                );
              } else {
                flutterToast.showToast(
                  child: ToastWrapper(
                    isCheck: true,
                    msg: Translations.of(context).trans('latestver'),
                  ),
                  gravity: ToastGravity.BOTTOM,
                  toastDuration: const Duration(seconds: 4),
                );
              }
            },
          ),
        ],
      ),
    ];
  }

  List<Widget> _etcGroup() {
    return [
      _buildGroup(Translations.of(context).trans('etc')),
      _buildItems(
        [
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    topRight: Radius.circular(8.0))),
            child: ListTile(
              leading: const Icon(
                MdiIcons.discord,
                color: Color(0xFF7189da),
              ),
              title: Text(Translations.of(context).trans('discord')),
              trailing: const Icon(Icons.open_in_new),
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
            leading: const Icon(
              MdiIcons.github,
              color: Colors.black,
            ),
            title: Text('GitHub ${Translations.of(context).trans('project')}'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              const url = 'https://github.com/project-violet/';
              if (await canLaunch(url)) {
                await launch(url);
              }
            },
          ),
          _buildDivider(),
          ListTile(
            leading: const Icon(
              MdiIcons.gmail,
              color: Colors.redAccent,
            ),
            title: Text(Translations.of(context).trans('contact')),
            trailing: const Icon(Icons.keyboard_arrow_right),
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
            leading: const Icon(
              MdiIcons.heart,
              color: Colors.orange,
            ),
            title: Text(Translations.of(context).trans('donate')),
            trailing: const Icon(
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
            title: const Text('Developers'),
            trailing: const Icon(
                // Icons.email,
                Icons.keyboard_arrow_right),
            onTap: () async {
              // const url = 'https://www.patreon.com/projectviolet';
              // if (await canLaunch(url)) {
              //   await launch(url);
              // }
            },
          ),
          _buildDivider(),
          InkWell(
            customBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0))),
            child: ListTile(
              leading: Icon(
                MdiIcons.library,
                color: Settings.majorColor,
              ),
              title: Text(Translations.of(context).trans('license')),
              trailing: const Icon(Icons.keyboard_arrow_right),
            ),
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => const VioletLicensePage(),
                ),
              );
            },
          ),
        ],
      ),
    ];
  }

  _bottomInfo() {
    return Container(
      margin: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: <Widget>[
            // Card(
            //   elevation: 5,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(8.0),
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
            const Padding(
              padding: EdgeInsets.only(top: 12),
            ),
            Text(
              'Project Violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 16.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'Copyright (C) 2020-2022 by project-violet',
              style: TextStyle(
                color: Settings.themeWhat ? Colors.white : Colors.black87,
                fontSize: 12.0,
                fontFamily: 'Calibre-Semibold',
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
