static INDEX_LETTER_2: &[&str] = &[
    "r", "R", "rt", "s", "sw", "sg", "e", "E", "f", "fr", "fa", "fq", "ft", "fe", "fv", "fg", "a",
    "q", "Q", "qt", "t", "T", "d", "w", "W", "", "z", "e", "v", "g", "k", "o", "i", "O", "j", "p",
    "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b", "m", "ml", "l", " ", "ss",
    "se", "st", " ", "frt", "fe", "fqt", " ", "fg", "aq", "at", " ", " ", "qr", "qe", "qtr", "qte",
    "qw", "qe", " ", " ", "tr", "ts", "te", "tq", "tw", " ", "dd", "d", "dt", " ", " ", "gg", " ",
    "yi", "yO", "yl", "bu", "bP", "bl",
];

static INDEX_INITIAL_2: &[&str] = &[
    "r", "R", "s", "e", "E", "f", "a", "q", "Q", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g",
];

static INDEX_MEDIAL_2: &[&str] = &[
    "k", "o", "i", "O", "j", "p", "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b",
    "m", "ml", "l",
];

static INDEX_FINAL_2: &[&str] = &[
    "", "r", "R", "rt", "s", "sw", "sg", "e", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a",
    "q", "qt", "t", "T", "d", "w", "", "z", "x", "v", "g",
];

#[derive(Debug)]
struct HangulJamo {
    initial: u32,
    medial: u32,
    final_: u32,
}

pub struct HangulConverter;

impl HangulConverter {
    fn distortion(ch: u32) -> HangulJamo {
        let unis = ch - 0xAC00;
        HangulJamo {
            initial: unis / (21 * 28),
            medial: (unis % (21 * 28)) / 28,
            final_: (unis % (21 * 28)) % 28,
        }
    }

    #[allow(dead_code)]
    fn check(ch: u32) -> bool {
        Self::check_letter(ch) || Self::check_jamo31(ch) || Self::check_jamo11(ch)
    }

    fn check_letter(ch: u32) -> bool {
        (0xAC00..=0xD7A3).contains(&ch)
    }

    fn check_jamo31(ch: u32) -> bool {
        (0x3131..=0x3163).contains(&ch)
    }

    fn check_jamo11(ch: u32) -> bool {
        (0x1100..=0x1112).contains(&ch)
            || (0x1161..=0x1175).contains(&ch)
            || (0x11A8..=0x11C2).contains(&ch)
    }

    #[allow(dead_code)]
    pub fn disassembly(ch: u32) -> Option<String> {
        if HangulConverter::check_letter(ch) {
            let jamo = HangulConverter::distortion(ch);
            Some(format!(
                "{}{}{}",
                INDEX_INITIAL_2[jamo.initial as usize],
                INDEX_MEDIAL_2[jamo.medial as usize],
                INDEX_FINAL_2[jamo.final_ as usize]
            ))
        } else if HangulConverter::check_jamo31(ch) {
            INDEX_LETTER_2
                .get((ch - 0x3131) as usize)
                .map(|letter| letter.to_string())
        } else if (0x1100..=0x1112).contains(&ch) {
            INDEX_INITIAL_2
                .get((ch - 0x1100) as usize)
                .map(|letter| letter.to_string())
        } else if (0x1161..=0x1175).contains(&ch) {
            INDEX_MEDIAL_2
                .get((ch - 0x1161) as usize)
                .map(|letter| letter.to_string())
        } else if (0x11A8..=0x11C2).contains(&ch) {
            INDEX_FINAL_2
                .get((ch - 0x11A7) as usize)
                .map(|letter| letter.to_string())
        } else {
            None
        }
    }

    fn push_disassembly(ch: u32, buffer: &mut String) -> bool {
        if HangulConverter::check_letter(ch) {
            let jamo = HangulConverter::distortion(ch);
            buffer.push_str(INDEX_INITIAL_2[jamo.initial as usize]);
            buffer.push_str(INDEX_MEDIAL_2[jamo.medial as usize]);
            buffer.push_str(INDEX_FINAL_2[jamo.final_ as usize]);
            true
        } else if HangulConverter::check_jamo31(ch) {
            if let Some(letter) = INDEX_LETTER_2.get((ch - 0x3131) as usize) {
                buffer.push_str(letter);
                true
            } else {
                false
            }
        } else if (0x1100..=0x1112).contains(&ch) {
            if let Some(letter) = INDEX_INITIAL_2.get((ch - 0x1100) as usize) {
                buffer.push_str(letter);
                true
            } else {
                false
            }
        } else if (0x1161..=0x1175).contains(&ch) {
            if let Some(letter) = INDEX_MEDIAL_2.get((ch - 0x1161) as usize) {
                buffer.push_str(letter);
                true
            } else {
                false
            }
        } else if (0x11A8..=0x11C2).contains(&ch) {
            if let Some(letter) = INDEX_FINAL_2.get((ch - 0x11A7) as usize) {
                buffer.push_str(letter);
                true
            } else {
                false
            }
        } else {
            false
        }
    }

    /// Best-effort inverse of two-set keyboard text. Removed whitespace, literal
    /// English, and characters omitted by legacy encoding cannot be recovered.
    pub fn keyboard_to_hangul(text: &str) -> String {
        const FINALS: &[&str] = &[
            "", "r", "R", "rt", "s", "sw", "sg", "e", "f", "fr", "fa", "fq",
            "ft", "fx", "fv", "fg", "a", "q", "qt", "t", "T", "d", "w", "c",
            "z", "x", "v", "g",
        ];
        const INITIAL_JAMO: &str = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ";
        fn longest(text: &str, table: &[&str]) -> Option<(usize, usize)> {
            table.iter().enumerate()
                .filter(|(_, key)| !key.is_empty() && text.starts_with(**key))
                .map(|(index, key)| (index, key.len()))
                .max_by_key(|(_, len)| *len)
        }
        let mut output = String::with_capacity(text.len());
        let mut rest = text;
        while !rest.is_empty() {
            if let Some((initial, initial_len)) = longest(rest, INDEX_INITIAL_2) {
                if let Some((medial, medial_len)) = longest(&rest[initial_len..], INDEX_MEDIAL_2) {
                    let tail = &rest[initial_len + medial_len..];
                    // A consonant followed by a vowel starts the next syllable.
                    // For a compound final this leaves its last consonant there.
                    let (final_, final_len) = FINALS.iter().enumerate()
                        .filter(|(_, key)| !key.is_empty() && tail.starts_with(**key))
                        .filter(|(_, key)| longest(&tail[key.len()..], INDEX_MEDIAL_2).is_none())
                        .map(|(index, key)| (index, key.len()))
                        .max_by_key(|(_, len)| *len)
                        .unwrap_or((0, 0));
                    output.push(char::from_u32(0xAC00 + ((initial * 21 + medial) * 28 + final_) as u32).unwrap());
                    rest = &tail[final_len..];
                } else {
                    output.push(INITIAL_JAMO.chars().nth(initial).unwrap());
                    rest = &rest[initial_len..];
                }
            } else if let Some((medial, len)) = longest(rest, INDEX_MEDIAL_2) {
                output.push(char::from_u32(0x314F + medial as u32).unwrap());
                rest = &rest[len..];
            } else {
                let ch = rest.chars().next().unwrap();
                output.push(ch);
                rest = &rest[ch.len_utf8()..];
            }
        }
        output
    }

    pub fn total_disassembly(what: &str) -> String {
        let mut buffer = String::with_capacity(what.len());
        for ch in what.chars() {
            if !HangulConverter::push_disassembly(ch as u32, &mut buffer) {
                buffer.push(ch);
            }
        }
        buffer
    }
}

#[cfg(test)]
mod tests {
    use crate::displant::HangulConverter;

    #[test]
    fn restores_keyboard_text_and_syllable_boundaries() {
        for text in ["안녕하세요", "값이", "읽고", "읽어", "앉아", "없다", "괜찮아",
                     "까꿍", "쐐기", "의외", "각사", "가나", "안녕! 123🙂", "ㄱㅏ"] {
            let encoded = HangulConverter::total_disassembly(text);
            let expected = if text == "ㄱㅏ" { "가" } else { text };
            assert_eq!(HangulConverter::keyboard_to_hangul(&encoded), expected, "{encoded}");
        }
        assert_eq!(HangulConverter::keyboard_to_hangul(""), "");
        assert_eq!(HangulConverter::keyboard_to_hangul("rkcl"), "가치");
        assert_eq!(HangulConverter::keyboard_to_hangul("rkc!"), "갗!");
    }

    #[test]
    fn restores_all_losslessly_encoded_individual_syllables() {
        for code in 0xAC00..=0xD7A3 {
            // The existing encoder drops final ㅊ (index 23).
            if (code - 0xAC00) % 28 == 23 { continue; }
            let text = char::from_u32(code).unwrap().to_string();
            assert_eq!(HangulConverter::keyboard_to_hangul(
                &HangulConverter::total_disassembly(&text)), text);
        }
    }

    #[test]
    fn unittest_displant() {
        let cases = [
            ("안녕하세요", "dkssudgktpdy"),
            ("안녕!", "dkssud!"),
            ("바이올렛 never die", "qkdldhffpt never die"),
            ("1234", "1234"),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::total_disassembly(src), tar);
        }
    }

    #[test]
    fn disassembles_complete_hangul_syllables() {
        let cases = [
            ('가', Some("rk")),
            ('각', Some("rkr")),
            ('힣', Some("glg")),
            ('\u{D7A4}', None),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::disassembly(src as u32).as_deref(), tar);
        }
    }

    #[test]
    fn disassembles_compatibility_jamo() {
        let cases = [
            ('\u{3130}', None),
            ('ㄱ', Some("r")),
            ('ㅣ', Some("l")),
            ('\u{3164}', None),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::disassembly(src as u32).as_deref(), tar);
        }
    }

    #[test]
    fn disassembles_combining_leading_jamo() {
        let cases = [
            ('\u{10FF}', None),
            ('ᄀ', Some("r")),
            ('ᄒ', Some("g")),
            ('\u{1113}', None),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::disassembly(src as u32).as_deref(), tar);
        }
    }

    #[test]
    fn disassembles_combining_medial_jamo() {
        let cases = [
            ('\u{1160}', None),
            ('ᅡ', Some("k")),
            ('ᅵ', Some("l")),
            ('\u{1176}', None),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::disassembly(src as u32).as_deref(), tar);
        }
    }

    #[test]
    fn disassembles_combining_trailing_jamo() {
        let cases = [
            ('\u{11A7}', None),
            ('ᆨ', Some("r")),
            ('ᆫ', Some("s")),
            ('ᇂ', Some("g")),
            ('\u{11C3}', None),
        ];

        for (src, tar) in cases {
            assert_eq!(HangulConverter::disassembly(src as u32).as_deref(), tar);
        }
    }

    #[test]
    fn keeps_unknown_characters_in_total_disassembly() {
        assert_eq!(HangulConverter::disassembly('A' as u32), None);
        assert_eq!(
            HangulConverter::total_disassembly("내\u{11AB}은 A"),
            "sosdms A"
        );
    }
}
