// This source code is a part of Project Violet.
// Copyright (C) 2020-2023. violet-team. Licensed under the Apache-2.0 License.

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/locale/locale.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/theme_switchable_state.dart';
import 'package:violet/widgets/toast.dart';

class UserStatusCard extends StatefulWidget {
  const UserStatusCard({super.key});

  @override
  State<UserStatusCard> createState() => _UserStatusCardState();
}

class _UserStatusCardState extends ThemeSwitchableState<UserStatusCard>
    with AutomaticKeepAliveClientMixin<UserStatusCard> {
  @override
  bool get wantKeepAlive => true;

  @override
  VoidCallback? get shouldReloadCallback => null;

  late VioletCommunitySession sess;
  final String _userId = 'None';
  String _userAppId = '';
  final String _userNickName = 'None';
  bool _logining = false;
  DateTime _latestBackup = DateTime.now();
  late final FToast fToast;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);

    // load boards
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      final prefs = await SharedPreferences.getInstance();
      _userAppId = prefs.getString('fa_userid')!;
      setState(() {});

      // if (id != null && pw != null) {
      //   setState(() {
      //     _logining = true;
      //   });
      //   sess = VioletCommunitySession.lastSession != null
      //       ? VioletCommunitySession.lastSession
      //       : await VioletCommunitySession.signIn(id, pw);
      //   _userNickName =
      //       (await VioletCommunitySession.getUserInfo(id))['NickName'];
      //   setState(() {
      //     _logining = false;
      //   });
      // }

      // [{Id: 1, ShortName: issue, Name: Issue, Description: Leave app issues or improvements here},
      //  {Id: 2, ShortName: general, Name: General, Description: Any Topic}]
      // var boards = (await VioletCommunityArticle.getBoards(null))['result'];
      // boards.removeWhere((element) => element['ShortName'] == '-- free --');
    });
  }

  // Future<void> _trylogin() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   var id = prefs.getString('saved_community_id');
  //   var pw = prefs.getString('saved_community_pw');

  //   _userId = id != null ? id : 'None';
  //   _userAppId = prefs.getString('fa_userid');
  //   setState(() {});

  //   if (id != null && pw != null) {
  //     sess = await VioletCommunitySession.signIn(id, pw);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          alignment: Alignment.centerLeft,
          height: 80,
          decoration: !Settings.themeFlat
              ? BoxDecoration(
                  // color: Colors.white,
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
          // decoration:
          child: Ink(
            child: !Settings.themeFlat
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Material(
                      color: Settings.themeWhat ? Colors.black38 : Colors.white,
                      child: _statusCardContent(),
                    ))
                : _statusCardContent(),
          ),
        ),
      ],
    );
  }

  _statusCardContent() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10.0),
                  bottomLeft: Radius.circular(10.0)),
            ),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'User:  ',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Expanded(
                        child: Text(
                          '$_userNickName ($_userId)',
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text(
                        'User App Id:  ',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Expanded(
                        child: Text(
                          _userAppId,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            onTap: () async {
              await showOkDialog(
                  context,
                  '$_userAppId\n\n${Translations.of(context).trans('userappmsg')}',
                  Translations.of(context).trans('uruserappid'));
            },
          ),
        ),
        _buildDivider(),
        SizedBox(
          height: double.infinity,
          width: 88,
          child: _logining
              ? const SizedBox(
                  height: 48,
                  width: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.grey),
                        ),
                      ),
                    ],
                  ),
                )
              : InkWell(
                  customBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10.0),
                        bottomRight: Radius.circular(10.0)),
                  ),
                  child: const Align(
                    alignment: Alignment.center,
                    child: badges.Badge(
                      showBadge: false,
                      badgeContent: Text(
                        'N',
                        style: TextStyle(color: Colors.white, fontSize: 12.0),
                      ),
                      // badgeColor: Settings.majorAccentColor,
                      child: Icon(MdiIcons.cloudUpload, size: 30),
                    ),
                  ),
                  onTap: () async {
                    // if (Settings.autobackupBookmark) {
                    //   await showOkDialog(
                    //       context,
                    //       'Bookmark Auto-Backup function is enabled. Each time you restart the app, ' +
                    //           'your bookmarks are automatically backed up to Violet Server. If you want ' +
                    //           'to back up manually, turn off automatic backup option.',
                    //       'Bookmark Backup');
                    //   return;
                    // }

                    if (DateTime.now()
                            .difference(_latestBackup)
                            .abs()
                            .inMinutes >
                        3) {
                      await showOkDialog(
                          context,
                          'Please try again in a few minutes!',
                          'Bookmark Backup');
                      return;
                    }
                    _latestBackup = DateTime.now();

                    setState(() {
                      _logining = true;
                    });

                    var resc = await VioletServer.uploadBookmark();

                    setState(() {
                      _logining = false;
                    });

                    if (resc) {
                      fToast.showToast(
                        child: const ToastWrapper(
                          isCheck: true,
                          msg: 'Bookmark Backup Success!',
                        ),
                        ignorePointer: true,
                        gravity: ToastGravity.BOTTOM,
                        toastDuration: const Duration(seconds: 4),
                      );
                    } else {
                      fToast.showToast(
                        child: const ToastWrapper(
                          isCheck: false,
                          isWarning: false,
                          msg: 'Bookmark Backup Fail!',
                        ),
                        ignorePointer: true,
                        gravity: ToastGravity.BOTTOM,
                        toastDuration: const Duration(seconds: 4),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Container _buildDivider() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      height: double.infinity,
      width: 1.0,
      color: Settings.themeWhat ? Colors.grey.shade600 : Colors.grey.shade400,
    );
  }
}
