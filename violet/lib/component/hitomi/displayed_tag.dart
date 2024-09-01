// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

import 'package:violet/component/hitomi/tag_translate.dart';

class DisplayedTag {
  // artist, group, tag, series, character, uploader, type, class, language, prefix, page, female, male
  String? group;
  // <tag>
  String? name;
  // <translated-tag>
  String? translated;

  // tag := <group>:<name>
  DisplayedTag({String? tag, this.group, this.name, this.translated}) {
    if (tag != null) {
      group = tag.split(':').first;
      name = tag.substring(tag.indexOf(':') + 1);
    }
  }

  String getTag() {
    if (group == 'page') return '$group$name';
    return '$group:$name';
  }

  String getTranslated() {
    return translated = (translated ?? TagTranslate.ofAny(name!))
        .split('|')
        .first
        .split(':')
        .last;
  }

  @override
  String toString() {
    return getTag();
  }
}
