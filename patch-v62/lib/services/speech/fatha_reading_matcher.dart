/// Matches the complete recognized text of a two-/three-letter fatha reading.
///
/// [letters] contains individual glyphs in spoken order: `['بَ', 'حَ']` is
/// read baa then haa. Arabic UI direction does not reverse this list.
/// Accepts connected/separated syllables, alif lengthening, ASR hamza, and
/// the definite article: `قا شا`, `قاء شاء`, `قاشا`, `قشاء`, `القاء شا`.
/// A child can rehearse a syllable or repeat the complete reading. Every
/// syllable must still appear in order, and the last reading must be complete.
/// Token boundaries may separate syllables, but cannot split one syllable.
/// There is no substring, edit-distance, or unordered matching.
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

  return _matchesSyllables(recognized, expected, maxReadings: 4);
}

/// Whether a matching interim result is clear enough to end listening now.
///
/// An alif after another letter needs its own syllable boundary. For example,
/// `را`/`راء` can be ASR for the first sound alone in `رَ أَ`. They retain their
/// final-result compatibility, but cannot end listening prematurely. `را آ`,
/// `رَأَ`, and `راآ` establish the second sound. An initial alif (`أكل`) is not
/// ambiguous in this way. The rule also applies to an alif inside a triple.
bool fathaReadingCanAcceptInterim(String recognized, List<String> letters) {
  if (!fathaReadingMatchesExpected(recognized, letters)) return false;
  final expected = letters.map((letter) {
    final glyph = _normalize(letter)!;
    return glyph == 'ء' ? 'ا' : glyph;
  }).toList(growable: false);
  return _matchesSyllables(recognized, expected,
      maxReadings: 4, requireIndependentAlif: true);
}

/// Matches one fatha syllable, optionally repeated one to four times.
///
/// [letterOrPhoneme] is a glyph (`سَ`) or its phonetic spelling (`سا`/`ساء`),
/// never a distinct alphabet name (`سين`). All syllables must represent that
/// same sound, whether ASR joins them (`ساسا`), separates them (`سا سا`),
/// lengthens the alif (`سااا`), or adds the article (`السا`). An extra word or
/// another letter cannot pass. Distinct letter names are rejected
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
  for (final entry in _fathaSpellings.entries) {
    if (entry.value.contains(target)) {
      return _matchesSyllables(recognized, [entry.key], maxReadings: 1);
    }
  }
  return false;
}

bool _matchesSyllables(String recognized, List<String> expected,
    {required int maxReadings, bool requireIndependentAlif = false}) {
  final normalized = _normalize(recognized);
  if (normalized == null || normalized.isEmpty || normalized.length > 512) {
    return false;
  }
  final tokens = normalized
      .split(_separators)
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  // Preserve explicit vowel/hamza boundaries before normalization removes
  // them. These are used only to disambiguate a non-initial alif.
  final alifBoundaries = recognized
      .replaceAll(_formatting, '')
      .split(_separators)
      .where((token) => token.isNotEmpty)
      .map(_explicitAlifBoundaries)
      .toList(growable: false);
  if (tokens.isEmpty ||
      tokens.length > expected.length * _maxSyllableRepetitions * maxReadings) {
    return false;
  }
  for (final token in tokens) {
    // Do not delete unrelated text into a match. Extending the alif in a
    // distinct alphabet name does not turn that name into a fatha syllable.
    final unlengthened = token.replaceAll(_repeatedAlif, 'ا');
    final withoutArticle = unlengthened.startsWith('ال')
        ? unlengthened.substring(2)
        : unlengthened;
    if (!_arabicLettersOnly.hasMatch(token) ||
        _distinctLetterNames.contains(unlengthened) ||
        _distinctLetterNames.contains(withoutArticle)) {
      return false;
    }
  }

  final failedStates = <String>{};
  bool consume(int expectedIndex, int tokenIndex, int offset, int repetitions,
      int reading) {
    if (tokenIndex == tokens.length) return false;
    final state = '$expectedIndex:$tokenIndex:$offset:$repetitions:$reading';
    if (failedStates.contains(state)) return false;
    final token = tokens[tokenIndex];
    for (final end in _syllableEnds(token, offset, expected[expectedIndex])) {
      if (expectedIndex > 0 &&
          expected[expectedIndex] == 'ا' &&
          (requireIndependentAlif || reading > 0) &&
          !_hasIndependentAlif(
              token, offset, end, alifBoundaries[tokenIndex])) {
        continue;
      }
      final atBoundary = end == token.length;
      final nextToken = atBoundary ? tokenIndex + 1 : tokenIndex;
      final nextOffset = atBoundary ? 0 : end;
      final isLast = expectedIndex == expected.length - 1;
      if (isLast && nextToken == tokens.length) return true;

      // Advance only to the next required syllable; a pause has no effect on
      // this order. A short rehearsal (قا قا شا) is accepted as well.
      if (!isLast &&
          consume(expectedIndex + 1, nextToken, nextOffset, 0, reading)) {
        return true;
      }
      if (repetitions + 1 < _maxSyllableRepetitions &&
          consume(
              expectedIndex, nextToken, nextOffset, repetitions + 1, reading)) {
        return true;
      }
      // A second complete reading is fine (قا شا قاشا); a trailing partial
      // reading (قا شا قا) is not accepted by this whole-transcript matcher.
      if (isLast &&
          reading + 1 < maxReadings &&
          consume(0, nextToken, nextOffset, 0, reading + 1)) {
        return true;
      }
    }
    failedStates.add(state);
    return false;
  }

  return consume(0, 0, 0, 0, 0);
}

bool _hasIndependentAlif(
    String token, int offset, int end, Set<int> explicitBoundaries) {
  if (token.startsWith('ال', offset)) {
    // The article must be followed by the actual alif syllable; its own alif
    // cannot stand in for the requested letter before a lam.
    return end > offset + 2;
  }
  return offset == 0 || explicitBoundaries.contains(offset);
}

Set<int> _explicitAlifBoundaries(String token) {
  final result = <int>{};
  for (var index = 0; index < token.length; index++) {
    final letter = token[index];
    if (!'اأآء'.contains(letter)) continue;
    final explicitlyVowelled = index > 0 &&
        token[index - 1] == 'َ' &&
        _fathaAfterAlif.hasMatch(token.substring(index + 1));
    final separateHamzaAfterVowel = index > 0 &&
        (letter == 'أ' || letter == 'آ') &&
        (token[index - 1] == 'ا' || token[index - 1] == 'ء');
    if (explicitlyVowelled || separateHamzaAfterVowel) {
      result.add(_normalize(token.substring(0, index))!.length);
    }
  }
  return result;
}

Iterable<int> _syllableEnds(String token, int offset, String glyph) sync* {
  final starts = <int>[offset];
  if (token.startsWith('ال', offset)) starts.add(offset + 2);
  for (final start in starts) {
    if (start >= token.length) continue;
    if (glyph == 'ا' && token[start] == 'ء') {
      yield start + 1;
      continue;
    }
    if (token[start] != glyph) continue;
    var end = start + 1;
    yield end;
    if (glyph == 'ا' && end < token.length && token[end] == 'ء') {
      yield end + 1;
    }
    while (end < token.length && token[end] == 'ا') {
      end++;
      yield end;
      if (end < token.length && token[end] == 'ء') yield end + 1;
    }
  }
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

const _maxSyllableRepetitions = 4;
final _separators = RegExp(r'[\s،,؛;.!?؟…:\-–—]+');
final _repeatedAlif = RegExp('ا{2,}');
final _fathaAfterAlif = RegExp(r'^[\u0653\u0654]*\u064E');
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
