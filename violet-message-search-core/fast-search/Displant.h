#ifndef _DISPLANT_9bf1541fdf7efd41b7b39543fd870ac4_
#define _DISPLANT_9bf1541fdf7efd41b7b39543fd870ac4_

#include <stdio.h>
#include <wchar.h>
#include <string.h>

namespace Utility {

#define TEXT(x) x

const char *index_letter_2[] = {
    TEXT("r"),  TEXT("R"),   TEXT("rt"),  TEXT("s"),  TEXT("sw"),  TEXT("sg"),
    TEXT("e"),  TEXT("E"),   TEXT("f"),   TEXT("fr"), TEXT("fa"),  TEXT("fq"),
    TEXT("ft"), TEXT("fe"),  TEXT("fv"),  TEXT("fg"), TEXT("a"),   TEXT("q"),
    TEXT("Q"),  TEXT("qt"),  TEXT("t"),   TEXT("T"),  TEXT("d"),   TEXT("w"),
    TEXT("W"),  TEXT(""),    TEXT("z"),   TEXT("e"),  TEXT("v"),   TEXT("g"),
    TEXT("k"),  TEXT("o"),   TEXT("i"),   TEXT("O"),  TEXT("j"),   TEXT("p"),
    TEXT("u"),  TEXT("P"),   TEXT("h"),   TEXT("hk"), TEXT("ho"),  TEXT("hl"),
    TEXT("y"),  TEXT("n"),   TEXT("nj"),  TEXT("np"), TEXT("nl"),  TEXT("b"),
    TEXT("m"),  TEXT("ml"),  TEXT("l"),   TEXT(" "),  TEXT("ss"),  TEXT("se"),
    TEXT("st"), TEXT(" "),   TEXT("frt"), TEXT("fe"), TEXT("fqt"), TEXT(" "),
    TEXT("fg"), TEXT("aq"),  TEXT("at"),  TEXT(" "),  TEXT(" "),   TEXT("qr"),
    TEXT("qe"), TEXT("qtr"), TEXT("qte"), TEXT("qw"), TEXT("qe"),  TEXT(" "),
    TEXT(" "),  TEXT("tr"),  TEXT("ts"),  TEXT("te"), TEXT("tq"),  TEXT("tw"),
    TEXT(" "),  TEXT("dd"),  TEXT("d"),   TEXT("dt"), TEXT(" "),   TEXT(" "),
    TEXT("gg"), TEXT(" "),   TEXT("yi"),  TEXT("yO"), TEXT("yl"),  TEXT("bu"),
    TEXT("bP"), TEXT("bl")};

const char *index_initial_2[] = {
    TEXT("r"), TEXT("R"), TEXT("s"), TEXT("e"), TEXT("E"), TEXT("f"), TEXT("a"),
    TEXT("q"), TEXT("Q"), TEXT("t"), TEXT("T"), TEXT("d"), TEXT("w"), TEXT("W"),
    TEXT("c"),  TEXT("z"), TEXT("x"), TEXT("v"), TEXT("g")};

const char *index_medial_2[] = {
    TEXT("k"), TEXT("o"),  TEXT("i"),  TEXT("O"),  TEXT("j"),  TEXT("p"),
    TEXT("u"), TEXT("P"),  TEXT("h"),  TEXT("hk"), TEXT("ho"), TEXT("hl"),
    TEXT("y"), TEXT("n"),  TEXT("nj"), TEXT("np"), TEXT("nl"), TEXT("b"),
    TEXT("m"), TEXT("ml"), TEXT("l")};

const char *index_final_2[] = {
    TEXT(""),   TEXT("r"),  TEXT("R"),  TEXT("rt"), TEXT("s"),  TEXT("sw"),
    TEXT("sg"), TEXT("e"),  TEXT("f"),  TEXT("fr"), TEXT("fa"), TEXT("fq"),
    TEXT("ft"), TEXT("fx"), TEXT("fv"), TEXT("fg"), TEXT("a"),  TEXT("q"),
    TEXT("qt"), TEXT("t"),  TEXT("T"),  TEXT("d"),  TEXT("w"),  TEXT(""),
    TEXT("z"),  TEXT("x"),  TEXT("v"),  TEXT("g")};

class HangulConverter {
  static const wchar_t magic = 0xAC00;

  class __HangulJamo {
  public:
    wchar_t initial;
    wchar_t medial;
    wchar_t final;
  };

public:
  static __HangulJamo distortion(const wchar_t ch) {
    __HangulJamo ret;
    wchar_t unis = (wchar_t)(ch)-magic;
    ret.initial = unis / (21 * 28);
    ret.medial = (unis % (21 * 28)) / 28;
    ret.final = (unis % (21 * 28)) % 28;
    return ret;
  }

  static bool check(const wchar_t ch) {
#ifdef _DISPLANT_SAFE_EXECUATIVE
    if ((wchar_t)0xac00 <= ch && ch <= (wchar_t)0xd7fb)
#else
    if (((wchar_t)0xac00 <= ch && ch <= (wchar_t)0xd7fb) ||
        ((wchar_t)0x3131 <= ch && ch <= (wchar_t)0x3163) ||
        ((wchar_t)0x1100 <= ch && ch <= (wchar_t)0x11ff))
#endif
      return true;
    return false;
  }

  static bool check_letter(const wchar_t ch) {
    if ((wchar_t)0xac00 <= ch && ch <= (wchar_t)0xd7fb)
      return true;
    return false;
  }

  static bool check_jamo31(const wchar_t ch) {
    if ((wchar_t)0x3131 <= ch && ch <= (wchar_t)0x3163)
      return true;
    return false;
  }

  static bool check_jamo11(const wchar_t ch) {
    if ((wchar_t)0x1100 <= ch && ch <= (wchar_t)0x11ff)
      return true;
    return false;
  }

  static const char *disassembly(wchar_t ch) {
    if (check_letter(ch)) {
      char buf[10];
      __HangulJamo jamo = distortion(ch);

      sprintf(buf, "%s%s%s", index_initial_2[jamo.initial],
               index_medial_2[jamo.medial], index_final_2[jamo.final]);

      return strdup(buf);
    } else if (check_jamo31(ch)) {
      return index_letter_2[ch - 0x3131];
    } else if (check_jamo11(ch)) {
      return index_letter_2[ch - 0x1100];
    }
    return 0;
  }

  static void total_disassembly(const wchar_t *what, char *buffer) {
    size_t len, index = 0, j;
    const char *ptr;
    for (; *what; what++) {
      ptr = disassembly(*what);
      if (ptr) {
        len = strlen(ptr);
        for (j = 0; j < len; j++) {
          *(buffer + index++) = ptr[j];
        }
      } else {
        //buffer[index++] = *what;
        // ignore except of hangul
      }
    }
    buffer[index] = 0;
  }
};

} // namespace Utility

#endif