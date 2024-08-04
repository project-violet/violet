// This source code is a part of Project Violet.
// Copyright (C) 2020-2024. violet-team. Licensed under the Apache-2.0 License.

class KoreanShielderFilter {
  static List<String> tags = [
    'female:loli',
    'female:low_lolicon',
    'female:oppai_loli',
    'female:gothic_lolita',
    'male:shota',
    'male:yaoi',
    'male:tomgirl',
    'male:furry',
    'male:low_shotacon',
    'female:schoolgirl_uniform',
    'male:schoolboy_uniform',
    'female:school_swimsuit',
    'female:schoolgirl',
    'female:schoolboy',
    'female:school_uniform',
    'male:schoolgirl',
    'male:schoolgirl_uniform',
    'male:schoolboy',
    'male:school_swimsuit',
    'female:schoolboy_uniform',
    'female:toddlercon',
    'male:toddlercon',
    'female:kindergarten_uniform',
    'male:kindergarten_uniform',
    'female:randoseru',
    'male:randoseru',
  ];
}

// Filter to filter out shocking works that are unacceptable by common sense.
// Things that are only allowed in comics and should not happen in reality
class MinorShielderFilter {
  static List<String> tags = [
    'female:rape',
    'male:rape',
    'female:loli',
    'male:shota',
    'female:ryona',
    'male:ryona',
    'female:scat',
    'male:scat',
    'female:snuff',
    'male:snuff',
    'female:insect',
    'female:insect_girl',
    'male:insect',
    'male:insect_boy',
    'female:gore',
    'male:gore',
    'female:gag',
    'male:gag',
    'female:bondage',
    'male:bondage',
    'female:enema',
    'male:enema',
    'female:bdsm',
    'male:bdsm',
    'female:monster',
    'male:monster',
    'female:netorare',
    'male:netorare',
  ];
}

class MaleShielderFilter {
  static List<String> tags = [
    'male:yaoi',
    'male:male_only',
  ];
}

class FemaleShielderFilter {}

class ClothShielderFilter {
  static List<String> tags = [
    'female:glasses',
    'female:collar',
    'female:swimsuit',
    'female:schoolgirl_uniform',
    'female:garter_belt',
  ];
}
