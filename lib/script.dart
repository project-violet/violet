import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class ScriptRawModel {
  final String sign;
  final String script;

  ScriptRawModel({this.script, this.sign});

  factory ScriptRawModel.fromJson(Map<String, dynamic> json) {
    return ScriptRawModel(
      script: json['script'] as String,
      sign: json['sign'] as String,
    );
  }
}

class Validator {

  static Future<bool> IsValid(String input_b64, String sign) async {
    final pubPem = await rootBundle.loadString('assets/script_valid_pub.pem');
    final pubKey = RSAKeyParser().parse(pubPem) as RSAPublicKey;
    final signer = Signer(RSASigner(RSASignDigest.SHA256, publicKey: pubKey));

    return signer.verify64(input_b64, sign);
  }

  // Maybe, this method is called only once per App starting.
  static Future<String> SafeDownload(String url) async {
    try {
      final res = await http.get(url);
      final par = json.decode(res.body).cast<Map<String, dynamic>>();
      final mmd = ScriptRawModel.fromJson(par);

      if (IsValid(mmd.script, mmd.sign) == true) return mmd.script;
    } catch (error) {}
    return "";
  }
}

class ScriptManager {}
