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
        (0xAC00..=0xD7FB).contains(&ch)
    }

    fn check_jamo31(ch: u32) -> bool {
        (0x3131..=0x3163).contains(&ch)
    }

    fn check_jamo11(ch: u32) -> bool {
        (0x1100..=0x11FF).contains(&ch)
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
            Some(INDEX_LETTER_2[(ch - 0x3131) as usize].to_string())
        } else if HangulConverter::check_jamo11(ch) {
            Some(INDEX_LETTER_2[(ch - 0x1100) as usize].to_string())
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
}
