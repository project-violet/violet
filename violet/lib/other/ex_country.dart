// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';

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
      'BR': 'pt',
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
      'BR': 'Português'
    };

    if (dict.containsKey(isoCode)) return dict[isoCode]!;

    if (isoCode == 'CN') {
      if (script == 'Hant') return '中文(繁體)';
      if (script == 'Hans') return '中文(简体)';
    }

    return 'English';
  }
}
