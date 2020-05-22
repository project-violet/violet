import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Translations {  
  Translations(this.locale);  
  
  final Locale locale;  
  
  static Translations of(BuildContext context) {  
    return Localizations.of<Translations>(context, Translations);  
  }  
  
  Map<String, String> _sentences;  
  
  Future<bool> load() async {
    String data = await rootBundle.loadString('assets/locale/${this.locale.languageCode}.json'); // 경로 유의
    Map<String, dynamic> _result = json.decode(data);

    this._sentences = new Map();
    _result.forEach((String key, dynamic value) {
      this._sentences[key] = value.toString();
    });

    return true;
  }
  
  String trans(String key) {  
    return this._sentences[key];  
  }  
}


class TranslationsDelegate extends LocalizationsDelegate<Translations> {  
  const TranslationsDelegate();  
  
  @override  
  bool isSupported(Locale locale) => ['ko', 'en'].contains(locale.languageCode);
  
  @override  
  Future<Translations> load(Locale locale) async {  
    Translations localizations = new Translations(locale);  
  await localizations.load();  
  
  print("Load ${locale.languageCode}");  
  
  return localizations;  
  }  
  
  @override  
  bool shouldReload(TranslationsDelegate old) => false;  
}