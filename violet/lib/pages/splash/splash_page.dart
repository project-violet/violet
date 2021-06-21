// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:io';

import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:violet/component/hitomi/indexs.dart';
import 'package:violet/component/hitomi/tag_translate.dart';
import 'package:violet/database/user/bookmark.dart';
import 'package:violet/database/user/record.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/log/log.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/other/named_color.dart';
import 'package:violet/pages/after_loading/afterloading_page.dart';
import 'package:violet/pages/database_download/database_download_page.dart';
import 'package:violet/pages/settings/settings_page.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/variables.dart';
import 'package:violet/version/sync.dart';

class RadioTile<T> extends StatefulWidget {
  RadioTile({
    Key key,
    this.value,
    this.groupValue,
    this.setGroupValue,
    this.title,
    this.subtitle,
    this.onLongPress,
  }) : super(key: key);

  final T value;
  final T groupValue;
  final void Function(T) setGroupValue;
  final Widget title;
  final Widget subtitle;
  final void Function() onLongPress;

  @override
  _RadioTileState<T> createState() => _RadioTileState<T>();
}

class _RadioTileState<T> extends State<RadioTile<T>> {
  bool _longPressing = false;

  @override
  Widget build(BuildContext context) {
    bool selected = widget.value == widget.groupValue;

    return AnimatedContainer(
      transform: Matrix4.identity()
        ..translate(300 / 2, 50 / 2)
        ..scale(_longPressing ? 0.95 : (selected ? 1.03 : 1.0))
        ..translate(-300 / 2, -50 / 2),
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 4,
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3.0))),
          child: ListTile(
            leading: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
                maxWidth: 44,
                maxHeight: 44,
              ),
              child: Radio(
                value: widget.value,
                groupValue: widget.groupValue,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onChanged: (selected) {
                  setState(() {
                    _longPressing = false;
                    widget.setGroupValue(selected);
                  });
                },
              ),
            ),
            title: widget.title,
            subtitle: widget.subtitle,
            dense: true,
          ),
          onTapDown: (details) {
            setState(() {
              _longPressing = true;
            });
          },
          onTap: () {
            setState(() {
              _longPressing = false;
              widget.setGroupValue(widget.value);
            });
          },
          onLongPress: () {
            setState(() {
              _longPressing = false;
              widget.onLongPress();
            });
          },
        ),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  final bool switching;

  SplashPage({this.switching = false});

  @override
  _SplashPageState createState() => _SplashPageState();
}

enum Database { userLanguage, all }

class _SplashPageState extends State<SplashPage> {
  bool showFirst = false;
  bool animateBox = false;
  bool languageBox = false;
  bool showIndicator = false;
  int chunkDownloadMax = 0;
  int chunkDownloadProgress = 0;

  final imgSize = {
    'global': '320MB',
    'ko': '76MB',
    'en': '100MB',
    'jp': '165MB',
    'zh': '85MB',
  };

  final dbSuppors = {'global', 'ko', 'en', 'jp', 'zh'};

  final imgZipSize = {
    'global': '32MB',
    'ko': '9MB',
    'en': '10MB',
    'jp': '18MB',
    'zh': '9MB',
  };

  Future<void> checkAuth() async {
    if ((await SharedPreferences.getInstance()).getBool('checkauthalready') ==
        null) {
      await (await SharedPreferences.getInstance())
          .setBool('checkauthalready', true);
      if (await Permission.storage.request() == PermissionStatus.denied) {
        await showOkDialog(context, "파일 권한을 허용하지 않으면 다운로드 기능을 이용할 수 없습니다.");
      }
    }
  }

  startTime() async {
    var _duration = Duration(milliseconds: 100);
    return Timer(_duration, navigationPage);
  }

  Future<void> navigationPage() async {
    await Settings.init();
    await Bookmark.getInstance();
    await User.getInstance();
    await Variables.init();
    await HitomiIndexs.init();
    await Logger.init();
    await TagTranslate.init();

    if ((await SharedPreferences.getInstance()).getInt('db_exists') == 1 &&
        !widget.switching) {
      try {
        await SyncManager.checkSync();
        if (!SyncManager.firstSync && SyncManager.chunkRequire) {
          setState(() {
            showIndicator = true;
          });
          await SyncManager.doChunkSync((_, len) async {
            setState(() {
              chunkDownloadMax = len;
              chunkDownloadProgress++;
            });
          });
        }
      } catch (e, st) {
        // If an error occurs, stops synchronization immediately.
        FirebaseCrashlytics.instance.recordError(e, st);
        Logger.error(
            '[Splash-Navigation] E: ' + e.toString() + '\n' + st.toString());
      }

      // We must show main page to user anyway
      Navigator.of(context).pushReplacementNamed('/AfterLoading');
    } else {
      if (!widget.switching) await Future.delayed(Duration(milliseconds: 1400));
      setState(() {
        showFirst = true;
      });
      await Future.delayed(Duration(milliseconds: 400));
      setState(() {
        animateBox = true;
      });
      await Future.delayed(Duration(milliseconds: 200));
      setState(() {
        languageBox = true;
      });
      await Future.delayed(Duration(milliseconds: 500));
      setState(() {
        _database = Database.userLanguage;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    startTime();
  }

  Route _createRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          AfterLoadingPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        var begin = Offset(0.0, 1.0);
        var end = Offset.zero;
        var curve = Curves.ease;
        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  Database _database;

  void _setDatabase(Database database) {
    setState(() {
      _database = database;
    });
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.ease,
              top: showFirst ? 130 : height / 2 - 50,
              left: width / 2 - 50,
              child: Image.asset(
                'assets/images/logo-' +
                    Settings.majorColor.name +
                    '.png',
                width: 100,
                height: 100,
              ),
            ),
            _chunkDownload(),
            _firstPage(),
            _dbSelector(),
            _languageSelector(),
          ],
        ),
      ),
      backgroundColor: showFirst && !widget.switching
          ? Color(0x7FB200ED)
          : Settings.majorColor.withAlpha(200),
    );
  }

  _chunkDownload() {
    return Visibility(
      visible: showIndicator,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('<< AutoSync >>', style: TextStyle(color: Colors.white)),
              Text(
                  chunkDownloadProgress != chunkDownloadMax ||
                          chunkDownloadMax == 0
                      ? 'Chunk downloading...[$chunkDownloadProgress/${SyncManager.getSyncRequiredChunkCount()}]'
                      : 'Extracting...',
                  style: TextStyle(color: Colors.white)),
              Container(
                height: 16,
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _firstPage() {
    final translations = Translations.of(context);

    return Visibility(
      visible: showFirst,
      child: Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(top: 140),
          child: Card(
            elevation: 100,
            color: widget.switching
                ? Settings.majorColor.withAlpha(150)
                : Colors.purple.shade50,
            child: AnimatedOpacity(
              opacity: animateBox ? 1.0 : 0,
              duration: Duration(milliseconds: 500),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 500),
                curve: Curves.ease,
                width: animateBox ? 300 : 300,
                height: animateBox ? 300 : 0,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 900),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      horizontalOffset: 50.0,
                      child: FadeInAnimation(
                        child: widget,
                      ),
                    ),
                    children: <Widget>[
                      _welcomeMessage(),
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 4.0),
                      ),
                      RadioTile(
                        value: Database.userLanguage,
                        groupValue: _database,
                        setGroupValue: _setDatabase,
                        title: Text(
                          translations.trans('dbuser'),
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${imgZipSize['ko']}${translations.trans('dbdownloadsize')}',
                          style: TextStyle(fontSize: 12),
                        ),
                        onLongPress: () {
                          showOkDialog(
                              context,
                              translations.trans('dbusermsg').replaceFirst(
                                  '%s', imgSize[translations.dbLanguageCode]));
                        },
                      ),
                      RadioTile(
                        value: Database.all,
                        groupValue: _database,
                        setGroupValue: _setDatabase,
                        title: Text(
                          translations.trans('dballname'),
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${imgZipSize['global']}${translations.trans('dbdownloadsize')}',
                          style: TextStyle(fontSize: 12),
                        ),
                        onLongPress: () {
                          showOkDialog(
                              context,
                              translations
                                  .trans('dballmsg')
                                  .replaceFirst('%s', imgSize['global']));
                        },
                      ),
                      _downloadButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _welcomeMessage() {
    return Row(
      children: <Widget>[
        Icon(
          MdiIcons.database,
          size: 50,
          color: widget.switching
              ? Settings.majorAccentColor.withOpacity(0.8)
              : Colors.grey,
        ),
        Container(
          padding: EdgeInsets.all(4),
        ),
        Expanded(
          child: Text(
            widget.switching
                ? '${Translations.of(context).trans('database')} ${Translations.of(context).trans('switching')}'
                : Translations.of(context).trans('welcome'),
            maxLines: 4,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  _downloadButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 16, 0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: widget.switching
                ? Settings.majorColor.withAlpha(200)
                : Colors.purple.shade400,
          ),
          child: SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(Translations.of(context).trans('download')),
                Icon(Icons.keyboard_arrow_right),
              ],
            ),
          ),
          onPressed: _onDownloadButtonPressed,
        ),
      ),
    );
  }

  Future<void> _onDownloadButtonPressed() async {
    if (_database == Database.all) {
      if (!await showYesNoDialog(
          context,
          Translations.of(context).trans('dbwarn'),
          Translations.of(context).trans('warning'))) {
        return;
      }
    }
    if (widget.switching) {
      var dir = await getApplicationDocumentsDirectory();
      try {
        await ((await openDatabase('${dir.path}/data/data.db')).close());
        await deleteDatabase('${dir.path}/data/data.db');
        await Directory('${dir.path}/data').delete(recursive: true);
      } catch (e) {}
    }
    print(Translations.of(context).dbLanguageCode);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => DataBaseDownloadPage(
              dbType: _database == Database.all
                  ? 'global'
                  : Translations.of(context).dbLanguageCode,
              isExistsDataBase: false,
            )));
  }

  _dbSelector() {
    return AnimatedOpacity(
      opacity: languageBox ? 1.0 : 0.0,
      duration: Duration(milliseconds: 700),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 100),
          child: GestureDetector(
            child: SizedBox(
              child: Text(Translations.of(context).trans('dbalready'),
                  style: TextStyle(
                      color: widget.switching
                          ? Settings.majorAccentColor
                          : Colors.purpleAccent.shade100,
                      fontSize: 12.0)),
            ),
            onTap: () async {
              var path = await getFile();

              if (path == '') return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => DataBaseDownloadPage(
                        dbType: _database == Database.all
                            ? 'global'
                            : Translations.of(context).locale.languageCode,
                        isExistsDataBase: true,
                        dbPath: path,
                      )));
            },
          ),
        ),
      ),
    );
  }

  _languageSelector() {
    return AnimatedOpacity(
      opacity: languageBox ? 1.0 : 0.0,
      duration: Duration(milliseconds: 700),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 40),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8.0))),
            child: SizedBox(
              width: 150,
              height: 50,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.language,
                    size: 35,
                    color: Colors.white70,
                  ),
                  Text('  Language',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))
                ],
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Theme(
                  data: Theme.of(context).copyWith(primaryColor: Colors.pink),
                  child: CountryPickerDialog(
                    titlePadding: EdgeInsets.symmetric(vertical: 16),
                    // searchCursorColor: Colors.pinkAccent,
                    // searchInputDecoration:
                    //     InputDecoration(hintText: 'Search...'),
                    // isSearchable: true,
                    title: Text('Select Language'),
                    onValuePicked: (Country country) async {
                      var exc = country as ExCountry;
                      await Translations.of(context).load(exc.toString());
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
                      // ExCountry.create('IT'),
                      // ExCountry.create('ES'),
                      // CountryPickerUtils.getCountryByIsoCode('RU'),
                    ],
                    itemBuilder: (Country country) {
                      return Container(
                        child: Row(
                          children: <Widget>[
                            CountryPickerUtils.getDefaultFlagImage(country),
                            SizedBox(
                              width: 8.0,
                              height: 30,
                            ),
                            Text(
                                "${(country as ExCountry).getDisplayLanguage()}"),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<String> getFile() async {
    File file;
    file = await FilePicker.getFile(
      type: FileType.any,
    );

    if (file == null) {
      await showOkDialog(
          context, Translations.of(context).trans('dbalreadyerr'));
      return '';
    }

    return file.path;
  }
}
