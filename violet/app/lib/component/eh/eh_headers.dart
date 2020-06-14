// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT Licence.

import 'package:http/http.dart' as http;

class EHSession {
  // ??
  static List<String> cookies = [
    "igneous=30e0c0a66;ipb_member_id=2742770;ipb_pass_hash=6042be35e994fed920ee7dd11180b65f;sl=dm_2",
    "igneous=5676ef9eb21f775ab55895d02b30e2805d616aaed60eb5f9e7e5bddeb018be5596a971e6ad5947c4c1f2cb02ef069779db694b2649da1b0bfb5a7b2a23767fa4;ipb_member_id=2263496;ipb_pass_hash=6d94181101e10c5e8497c22bcfdf49e5;sl=dm_2",
    "ipb_member_id=1885095;ipb_pass_hash=c09d537c4eb19c406aca61fedc525eef",
    "ipb_member_id=1804967;ipb_pass_hash=1f3cf1b418ad112a234aea89d04ab7a8",
    "ipb_member_id=2195218;ipb_pass_hash=55e08b8e81a8c93f41c14bafb38e4d0a",
    "ipb_member_id=1654282;ipb_pass_hash=bb2d2fa99b7004fda582bcc38836c39e",
    "ipb_member_id=1715959;ipb_pass_hash=67e57ed90cfc3b391c8a32e920a31cf0",
  ];

  String cookie;

  static EHSession tryLogin(String id, String pass) {
    return null;
  }

  static Future<String> requestString(String url) async {
    return (await http.get(url, headers: {"cookie": cookies[0]})).body;
  }
}
