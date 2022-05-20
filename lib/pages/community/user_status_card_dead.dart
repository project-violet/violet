// This source code is a part of Project Violet.
// Copyright (C) 2020-2022. violet-team. Licensed under the Apache-2.0 License.

import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:violet/other/dialogs.dart';
import 'package:violet/pages/community/signin_dialog.dart';
import 'package:violet/pages/community/signup_dialog.dart';
import 'package:violet/server/community/article.dart';
import 'package:violet/server/community/session.dart';
import 'package:violet/server/violet.dart';
import 'package:violet/settings/settings.dart';
import 'package:violet/widgets/toast.dart';

class UserStatusCard extends StatefulWidget {
  const UserStatusCard({Key key}) : super(key: key);

  @override
  State<UserStatusCard> createState() => _UserStatusCardState();
}

class _UserStatusCardState extends State<UserStatusCard>
    with AutomaticKeepAliveClientMixin<UserStatusCard> {
  @override
  bool get wantKeepAlive => true;

  VioletCommunitySession sess;
  String _userId = 'None';
  String _userAppId;
  String _userNickName = 'None';
  bool _logining = false;

  @override
  void initState() {
    super.initState();

    // load boards
    Future.delayed(const Duration(milliseconds: 100)).then((value) async {
      var id = (await SharedPreferences.getInstance())
          .getString('saved_community_id');
      var pw = (await SharedPreferences.getInstance())
          .getString('saved_community_pw');

      _userAppId =
          (await SharedPreferences.getInstance()).getString('fa_userid');
      setState(() {});

      if (id != null && pw != null) {
        setState(() {
          _logining = true;
        });
        sess = VioletCommunitySession.lastSession ??
            await VioletCommunitySession.signIn(id, pw);
        _userNickName =
            (await VioletCommunitySession.getUserInfo(id))['NickName'];
        setState(() {
          _logining = false;
        });
      }

      // [{Id: 1, ShortName: issue, Name: Issue, Description: Leave app issues or improvements here},
      //  {Id: 2, ShortName: general, Name: General, Description: Any Topic}]
      var boards = (await VioletCommunityArticle.getBoards(null))['result'];
      boards.removeWhere((element) => element['ShortName'] == '-- free --');
    });
  }

  Future<void> _trylogin() async {
    var id =
        (await SharedPreferences.getInstance()).getString('saved_community_id');
    var pw =
        (await SharedPreferences.getInstance()).getString('saved_community_pw');

    _userId = id ?? 'None';
    _userAppId = (await SharedPreferences.getInstance()).getString('fa_userid');
    setState(() {});

    if (id != null && pw != null) {
      sess = await VioletCommunitySession.signIn(id, pw);
    }
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

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
                  '$_userAppId\n\nThis user app id has a unique value on a per app session. If you have any problems using the app, please contact us with above user app id.',
                  'Your User App Id');
            },
          ),
        ),
        _buildDivider(),
        SizedBox(
          height: double.infinity,
          width: 88,
          child: _logining
              ? SizedBox(
                  height: 48,
                  width: 48,
                  child: Stack(
                      alignment: Alignment.center,
                      children: const <Widget>[
                        SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.grey),
                            ))
                      ]))
              : InkWell(
                  customBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10.0),
                        bottomRight: Radius.circular(10.0)),
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Badge(
                      showBadge: false,
                      badgeContent: const Text('N',
                          style:
                              TextStyle(color: Colors.white, fontSize: 12.0)),
                      // badgeColor: Settings.majorAccentColor,
                      child: Icon(
                          sess == null
                              ? MdiIcons.accountCancel
                              : MdiIcons.cloudUpload,
                          size: 30),
                    ),
                  ),
                  onTap: () async {
                    if (sess != null) {
                      setState(() {
                        _logining = true;
                      });

                      var resc = await VioletServer.uploadBookmark();
                      if (!mounted) return;

                      setState(() {
                        _logining = false;
                      });

                      if (resc) {
                        FlutterToast(context).showToast(
                          child: const ToastWrapper(
                            isCheck: true,
                            msg: 'Bookmark Backup Success!',
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: const Duration(seconds: 4),
                        );
                      } else {
                        FlutterToast(context).showToast(
                          child: const ToastWrapper(
                            isCheck: false,
                            isWarning: false,
                            msg: 'Bookmark Backup Fail!',
                          ),
                          gravity: ToastGravity.BOTTOM,
                          toastDuration: const Duration(seconds: 4),
                        );
                      }

                      return;
                    }

                    var ync = await showYesNoDialog(
                        context,
                        'You need to log in to use the community feature. '
                            'If you have an existing id, press "YES" to log in. '
                            'If you do not have an existing id, press "NO" to register for a new one.',
                        'Sign In/Up');

                    if (ync == null) return;

                    String id, pw;

                    if (ync == true) {
                      // signin
                      var r = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return const SignInDialog();
                          });
                      if (r == null) return;
                      id = r[0];
                      pw = r[1];
                    } else {
                      // signup
                      if (await VioletCommunitySession.checkUserAppId(
                              _userAppId) !=
                          'success') {
                        if (mounted) {
                          await showOkDialog(
                              context,
                              'You cannot continue, there is an account registered with your UserAppId. '
                              'If you have already registered as a member, please sign in with your existing id. '
                              'If you forgot your login information, please contact developer.');
                        }
                        return;
                      }
                      var r = await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return const SignUpDialog();
                          });

                      if (r == null) return;

                      print(await VioletCommunitySession.signUp(
                          r[0], r[1], _userAppId, r[2]));

                      if (await VioletCommunitySession.signUp(
                              r[0], r[1], _userAppId, r[2]) ==
                          'success') {
                        if (mounted) {
                          await showOkDialog(context, 'Sign up is complete!');
                        }
                        id = r[0];
                        pw = r[1];
                      } else {
                        if (mounted) {
                          await showOkDialog(
                              context, 'Registration has been declined!');
                        }
                        return;
                      }
                    }

                    await (await SharedPreferences.getInstance())
                        .setString('saved_community_id', id);
                    await (await SharedPreferences.getInstance())
                        .setString('saved_community_pw', pw);

                    await _trylogin();
                    setState(() {});
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
