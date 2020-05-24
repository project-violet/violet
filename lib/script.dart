import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:encrypt/encrypt.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

const String script_valid_pub = 
'''-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtPg+B+aZmkTR2l7p+I29
/iCsA0KfO09N6s9DWZN40zycKG0Fs3ir9sXVKCDVPF+zmuUi2vSEv+qG+65B5lMW
qoDW1HvbEu4fMigpX+xJ73cZl8dhSSmxqyaPFqtHSHOx1ODeRayVVSdXONlbKo3y
hJoiDHgQL49kbG8MdPZAu7Fomro1BhYnOimScNE3gfRCBdQPSomlSWRrlkOm1AfF
vdrbjVOeko1J4ere56wRMjArNb4GPZ6XwUkkRjkxrfOFkCJZfPKvIKJGcfiuccH7
v/IaqvbKIZHWxi05kZU915Dggm2S8b0tRqGxxwkOnFiq1Liyrxon476mmYdHp4Ns
pyvvdUZk1/qQghd8bAvAoVSb9sOeW5Qqr6WWJwAvi/VBzLga7W3bl1uf4HF9+R6G
a3FsblbsEfUwxBW/u/PWQLHmMkScHomvCgZBiQwfUVka0vze/jb+sLGi8QDMjwoT
iLHaWB/DpTrSFn5SRGh04hIBBMjIs+mL1cyejVVVJAZxcevXhZe2o9ZF3FSpvbyQ
SDefEuQ/hz03oshykKb9HTRq+ItGjlbVBHkbINhSPGwhjiuDLLx4CchsHgJV7BaZ
HGJ6Ttd1TgXBRfn2UuWrs6ybhMOORRCTg/rirt1ZZj3g2DsFmFX3G9NecMyJ7x/M
Mc3QJ2UNh6WpQlCXiRsknqECAwEAAQ==
-----END PUBLIC KEY-----''';

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

  static Future<bool> isValid(String inputB64, String sign) async {
    //final pubPem = await rootBundle.loadString('assets/script_valid_pub.pem');
    final pubPem = await rootBundle.loadString(script_valid_pub);
    final pubKey = RSAKeyParser().parse(pubPem) as RSAPublicKey;
    final signer = Signer(RSASigner(RSASignDigest.SHA256, publicKey: pubKey));

    return signer.verify64(inputB64, sign);
  }

  // Maybe, this method is called only once per App starting.
  static Future<String> safeDownload(String url) async {
    try {
      final res = await http.get(url);
      final par = json.decode(res.body).cast<Map<String, dynamic>>();
      final mmd = ScriptRawModel.fromJson(par);

      if (await isValid(mmd.script, mmd.sign) == true) return mmd.script;
    } catch (error) {}
    return "";
  }
}

class ScriptManager {}
