/// Matches the *complete ASR transcript* of a two-/three-letter fatha reading.
///
/// [letters] contains individual glyphs in spoken order: `['بَ', 'حَ']` is
/// read baa then haa. Arabic UI direction does not reverse this list.
/// A transcript can contain bare glyphs (`بح`), phonetic ASR spellings
/// (`با حا`, `باحا`, `باء حاء`), or a mixture. Token boundaries may separate
/// complete syllables, but may not split one syllable into extra responses.
/// No substring, edit-distance, or unordered matching is performed.
///
/// This checks recognition text, NOT acoustic pronunciation or vowel quality.
/// ASR often omits vowels or writes a short fatha with an alif/hamza. Explicit
/// wrong vowel marks and distinct letter names are rejected; an unmarked
/// transcript cannot prove that the speaker used fatha. In ambiguous cases
/// involving a distinct letter name (for example `دال`), retry rather than
/// silently accepting a possible recitation of the name.
bool fathaReadingMatchesExpected(String recognized, List<String> letters) {
  if (letters.length < 2 || letters.length > 3) return false;

  final expected = <String>[];
  for (final letter in letters) {
    final glyph = _normalize(letter);
    if (glyph == null) return false;
    final canonical = glyph == 'ء' ? 'ا' : glyph;
    if (!_fathaSpellings.containsKey(canonical)) return false;
    expected.add(canonical);
  }

  final normalized = _normalize(recognized);
  if (normalized == null || normalized.isEmpty) return false;
  final tokens = normalized
      .split(_separators)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty || tokens.length > expected.length) return false;
  for (final token in tokens) {
    // Reject unrecognized characters instead of stripping them into a match.
    if (!_arabicLettersOnly.hasMatch(token) ||
        _distinctLetterNames.contains(token) ||
        (token.startsWith('ال') &&
            _distinctLetterNames.contains(token.substring(2)))) {
      return false;
    }
  }

  bool consume(int expectedIndex, int tokenIndex, int offset) {
    if (expectedIndex == expected.length) return tokenIndex == tokens.length;
    if (tokenIndex == tokens.length) return false;

    final token = tokens[tokenIndex];
    for (final spelling in _fathaSpellings[expected[expectedIndex]]!) {
      if (!token.startsWith(spelling, offset)) continue;
      final end = offset + spelling.length;
      final atBoundary = end == token.length;
      if (consume(
        expectedIndex + 1,
        atBoundary ? tokenIndex + 1 : tokenIndex,
        atBoundary ? 0 : end,
      )) {
        return true;
      }
    }
    return false;
  }

  return consume(0, 0, 0);
}

/// Matches one fatha letter's complete ASR transcript, optionally repeated
/// between one and four times as separate tokens.
///
/// [letterOrPhoneme] is a glyph (`سَ`) or its phonetic spelling (`سا`/`ساء`),
/// never a distinct alphabet name (`سين`). All accepted tokens must represent
/// that same syllable. Thus `سَ، سا، ساء` can pass, but `سا سين`, `ساسا`, an
/// extra word, or another letter cannot. Distinct letter names are rejected
/// even when ASR might have hallucinated them from a correct short syllable.
/// Names with the same written form as a supported syllable (such as `باء`)
/// cannot be distinguished from phonetic ASR spelling using text alone.
///
/// Like [fathaReadingMatchesExpected], this is transcript matching, not an
/// acoustic pronunciation test. In particular, it cannot establish the vowel
/// in an unmarked transcript or recover `سا` when ASR instead returned `سين`.
bool fathaLetterMatchesExpected(String recognized, String letterOrPhoneme) {
  final target = _normalize(letterOrPhoneme);
  if (target == null || target.isEmpty) return false;
  List<String>? spellings;
  for (final variants in _fathaSpellings.values) {
    if (variants.contains(target)) {
      spellings = variants;
      break;
    }
  }
  if (spellings == null) return false;

  final normalized = _normalize(recognized);
  if (normalized == null || normalized.isEmpty) return false;
  final tokens = normalized
      .split(_separators)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  return tokens.isNotEmpty &&
      tokens.length <= 4 &&
      tokens.every(spellings.contains);
}

// Short syllables can be returned as a glyph, an alif-ending syllable, or an
// alif + hamza spelling. These aliases do not include distinct letter names.
const _fathaSpellings = <String, List<String>>{
  'ا': ['ا', 'ء', 'اا', 'اء'],
  'ب': ['ب', 'با', 'باء'],
  'ت': ['ت', 'تا', 'تاء'],
  'ث': ['ث', 'ثا', 'ثاء'],
  'ج': ['ج', 'جا', 'جاء'],
  'ح': ['ح', 'حا', 'حاء'],
  'خ': ['خ', 'خا', 'خاء'],
  'د': ['د', 'دا', 'داء'],
  'ذ': ['ذ', 'ذا', 'ذاء'],
  'ر': ['ر', 'را', 'راء'],
  'ز': ['ز', 'زا', 'زاء'],
  'س': ['س', 'سا', 'ساء'],
  'ش': ['ش', 'شا', 'شاء'],
  'ص': ['ص', 'صا', 'صاء'],
  'ض': ['ض', 'ضا', 'ضاء'],
  'ط': ['ط', 'طا', 'طاء'],
  'ظ': ['ظ', 'ظا', 'ظاء'],
  'ع': ['ع', 'عا', 'عاء'],
  'غ': ['غ', 'غا', 'غاء'],
  'ف': ['ف', 'فا', 'فاء'],
  'ق': ['ق', 'قا', 'قاء'],
  'ك': ['ك', 'كا', 'كاء'],
  'ل': ['ل', 'لا', 'لاء'],
  'م': ['م', 'ما', 'ماء'],
  'ن': ['ن', 'نا', 'ناء'],
  'ه': ['ه', 'ها', 'هاء'],
  'و': ['و', 'وا', 'واء'],
  'ي': ['ي', 'يا', 'ياء'],
};

const _distinctLetterNames = <String>{
  'الف',
  'جيم',
  'دال',
  'ذال',
  'زاي',
  'زين',
  'سين',
  'شين',
  'صاد',
  'ضاد',
  'عين',
  'غين',
  'قاف',
  'كاف',
  'لام',
  'ميم',
  'نون',
  'واو',
};

final _separators = RegExp(r'[\s،,؛;.!?؟…]+');
final _arabicLettersOnly = RegExp(r'^[\u0621-\u063A\u0641-\u064A]+$');
// Only fatha is appropriate: also reject tanwin, shadda and sukun rather than
// deleting marks which may change the intended reading.
final _nonFathaMarks = RegExp(r'[\u064B-\u064D\u064F-\u0652\u0655\u0670]');
final _formatting =
    RegExp(r'[\u0640\u061C\u200C-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');

String? _normalize(String value) {
  if (_nonFathaMarks.hasMatch(value) || value.contains('إ')) return null;
  return value
      .replaceAll(_formatting, '')
      .replaceAll('\u064E', '')
      .replaceAll('ا\u0654', 'أ')
      .replaceAll('ا\u0653', 'آ')
      .replaceAll(RegExp('[أآٱ]'), 'ا')
      .trim();
}
