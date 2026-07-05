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

    pub fn total_disassembly(what: &str) -> String {
        let mut buffer = String::new();
        for ch in what.chars() {
            if let Some(ptr) = HangulConverter::disassembly(ch as u32) {
                buffer.push_str(&ptr);
            } else {
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
