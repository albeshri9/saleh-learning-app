import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/services/speech/fatha_reading_matcher.dart';
import 'package:saleh_app/services/speech/speech_service.dart';

void main() {
  group('runtime speech service boundary for the sixteen new letters', () {
    const newLetters = 'شصضطظعغفقكلمنهوي';

    test('recognizes every glyph, phonetic spelling and 1–4 repeats', () {
      for (final letter in newLetters.split('')) {
        final phoneme = '$letterا';
        for (final expected in [letter, '$letterَ', phoneme, '$letterَا']) {
          for (final heard in [letter, '$letterَ', phoneme, '$letterاء']) {
            for (var repetitions = 1; repetitions <= 4; repetitions++) {
              final transcript = List.filled(repetitions, heard).join('، ');
              expect(speechMatchesExpected(transcript, expected), isTrue,
                  reason: 'Expected $expected; ASR $transcript');
            }
          }
        }
      }
    });

    test('does not let legacy equality erase a wrong vowel or accept a name',
        () {
      for (final letter in newLetters.split('')) {
        for (final mark in ['ِ', 'ُ', 'ْ', 'ّ', 'ً', 'ٌ', 'ٍ']) {
          expect(speechMatchesExpected('$letter$mark', '$letterَ'), isFalse,
              reason: 'Wrong mark $mark on $letter');
          expect(speechMatchesExpected('$letter$mark', '$letter$mark'), isFalse,
              reason: 'Invalid expected mark must not pass via equality');
        }
      }
      const names = {
        'شين': 'شا',
        'صاد': 'صا',
        'ضاد': 'ضا',
        'عين': 'عا',
        'غين': 'غا',
        'قاف': 'قا',
        'كاف': 'كا',
        'لام': 'لا',
        'ميم': 'ما',
        'نون': 'نا',
        'واو': 'وا',
      };
      for (final entry in names.entries) {
        expect(speechMatchesExpected(entry.key, entry.value), isFalse,
            reason: entry.key);
        expect(speechMatchesExpected('ال${entry.key}', entry.value), isFalse);
        expect(speechMatchesExpected(entry.key, entry.key), isFalse,
            reason: 'A distinct alphabet name is not a fatha target');
      }
    });

    test('rejects other letters, extra words and five reads', () {
      for (final letter in newLetters.split('')) {
        final expected = '$letterا';
        for (final other in 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'.split('')) {
          if (other == letter) continue;
          expect(speechMatchesExpected('$otherا', expected), isFalse,
              reason: 'Expected $letter, got $other');
        }
        for (final heard in [
          '$expected أحسنتم',
          'هذا $expected',
          List.filled(5, expected).join(' '),
          '${letter}1',
        ]) {
          expect(speechMatchesExpected(heard, expected), isFalse,
              reason: heard);
        }
      }
    });

    test('all runtime letters use fatha spellings rather than alphabet names',
        () {
      const legacy = <String, List<String>>{
        'آ': ['أَ', 'آ', 'اا', 'اء'],
        'با': ['ب', 'با', 'باء', 'الباء'],
        'تا': ['ت', 'تا', 'تاء', 'التاء'],
        'ثا': ['ث', 'ثا', 'ثاء', 'الثاء'],
        'جا': ['ج', 'جا', 'جاء', 'الجا', 'الجاء', 'جا جا'],
        'حا': ['ح', 'حا', 'حاء', 'الحاء'],
        'خا': ['خ', 'خا', 'خاء', 'الخاء', 'خا خا'],
        'دا': ['د', 'دا', 'داء', 'الدا', 'الداء'],
        'ذا': ['ذ', 'ذا', 'ذاء', 'الذا', 'الذاء'],
        'را': ['ر', 'را', 'راء', 'الراء'],
        'زا': ['ز', 'زا', 'زاء', 'الزا', 'الزاء'],
        'سا': ['س', 'سا', 'ساء', 'السا', 'الساء'],
      };
      for (final entry in legacy.entries) {
        for (final heard in entry.value) {
          expect(speechMatchesExpected(heard, entry.key), isTrue,
              reason: 'Preserve ${entry.key}: $heard');
        }
      }
      expect(speechMatchesExpected('باء', 'آ'), isFalse);
      expect(speechMatchesExpected('بطة', 'با'), isFalse);
      expect(speechMatchesExpected('جمل', 'جا'), isFalse);
      expect(speechMatchesExpected('ساعة', 'سا'), isFalse);
      for (final entry in {
        'ألف': 'آ',
        'ها': 'آ',
        'آه': 'آ',
        'الجيم': 'جا',
        'الدال': 'دا',
        'الذال': 'ذا',
        'الزاي': 'زا',
        'سين': 'سا',
      }.entries) {
        expect(speechMatchesExpected(entry.key, entry.value), isFalse,
            reason: '${entry.key} is not the requested ${entry.value}');
      }
    });
  });

  group('single fatha letter', () {
    test(
        'all 28 letters accept article, lengthening, pauses and joined repeats',
        () {
      for (final glyph in 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'.split('')) {
        final syllable = glyph == 'ا' ? 'آ' : '$glyphا';
        final longSyllable = glyph == 'ا' ? 'آاا' : '$glyphااا';
        for (final heard in [
          'ال$syllable',
          longSyllable,
          '$longSyllableء',
          'ال$longSyllableء',
          '$syllable$syllable',
          '$syllable … $syllable',
          '$syllable، $longSyllableء، ال$syllable',
        ]) {
          expect(fathaLetterMatchesExpected(heard, '$glyphَ'), isTrue,
              reason: '$glyph: $heard');
          expect(speechMatchesExpected(heard, '$glyphَ'), isTrue,
              reason: 'Device service must use the same matcher: $heard');
        }
      }
    });

    test('accepts all 28 glyphs and their phonetic ASR spellings', () {
      const alphabet = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي';
      for (final letter in alphabet.split('')) {
        final phoneme = '$letterا';
        final hamzaSpelling = letter == 'ا' ? 'اء' : '$letterاء';
        for (final expected in [letter, '$letterَ', phoneme, hamzaSpelling]) {
          for (final heard in [letter, '$letterَ', phoneme, hamzaSpelling]) {
            expect(fathaLetterMatchesExpected(heard, expected), isTrue,
                reason: 'Expected $expected; heard $heard');
          }
        }
      }
    });

    test('accepts one through four connected or separated repetitions', () {
      for (final heard in [
        'سا',
        'سا سا',
        'سَ سا ساء',
        'سا، سَ! ساء؟ سا',
        'ساسا',
        'سا ساسا',
        'سا-سا',
        'سااا',
        'السا',
        'الساااء',
      ]) {
        expect(fathaLetterMatchesExpected(heard, 'سَا'), isTrue, reason: heard);
      }
      for (final heard in [
        'سا سا سا سا سا',
        'سا شا',
        'سا سين',
        'سا سِ',
        'س ا',
      ]) {
        expect(fathaLetterMatchesExpected(heard, 'سا'), isFalse, reason: heard);
      }
    });

    test('rejects distinct names as responses and as expected phonemes', () {
      const names = <String, String>{
        'ألف': 'أَ',
        'جيم': 'جَا',
        'دال': 'دَا',
        'ذال': 'ذَا',
        'زاي': 'زَا',
        'زين': 'زَا',
        'سين': 'سَا',
        'شين': 'شَا',
        'صاد': 'صَا',
        'ضاد': 'ضَا',
        'عين': 'عَا',
        'غين': 'غَا',
        'قاف': 'قَا',
        'كاف': 'كَا',
        'لام': 'لَا',
        'ميم': 'مَا',
        'نون': 'نَا',
        'واو': 'وَا',
      };
      for (final entry in names.entries) {
        expect(fathaLetterMatchesExpected(entry.key, entry.value), isFalse,
            reason: 'Do not accept the name ${entry.key}');
        expect(
            fathaLetterMatchesExpected('ال${entry.key}', entry.value), isFalse,
            reason: 'Do not accept the definite name ${entry.key}');
        expect(fathaLetterMatchesExpected(entry.value, entry.key), isFalse,
            reason: 'Content must request the phoneme, not ${entry.key}');
      }
    });

    test('accepts the reported saa sound but never substitutes seen for saa',
        () {
      for (final heard in ['سا', 'سَا', 'س', 'سَ', 'ساء', 'السا', 'الساااء']) {
        expect(fathaLetterMatchesExpected(heard, 'سَا'), isTrue, reason: heard);
      }
      for (final heard in ['سين', 'السين', 'ساعة', 'سالم', 'سؤال']) {
        expect(fathaLetterMatchesExpected(heard, 'سَا'), isFalse,
            reason: heard);
      }
    });

    test('handles alif and hamza without allowing an extra haa or a name', () {
      for (final heard in ['أ', 'أَ', 'آ', 'ا', 'ء', 'اا', 'اء', 'اَ\u0654']) {
        expect(fathaLetterMatchesExpected(heard, 'أَ'), isTrue, reason: heard);
      }
      for (final heard in ['إ', 'إِ', 'ا\u0655', 'آه', 'ها', 'اه', 'ألف']) {
        expect(fathaLetterMatchesExpected(heard, 'أَ'), isFalse, reason: heard);
      }
    });

    test('rejects explicit wrong vowels, extra words, symbols and partials',
        () {
      for (final heard in [
        '',
        '   ',
        'سِ',
        'سُ',
        'سْ',
        'سً',
        'سَّ',
        'سٍ',
        'سٌ',
        'سي',
        'سو',
        'أقول سا',
        'سا أحسنتم',
        'saa',
        'سا1',
        'لا سا',
        'سام',
        'اسا',
      ]) {
        expect(fathaLetterMatchesExpected(heard, 'سا'), isFalse, reason: heard);
      }
      expect(fathaLetterMatchesExpected('سَـا\u200f،', 'سَا'), isTrue);
      for (final expected in ['', 'سِ', 'سُ', 'سَ ذَ', 'seen', 'ة']) {
        expect(fathaLetterMatchesExpected('سا', expected), isFalse,
            reason: 'Invalid expected value: $expected');
      }
    });
  });

  group('two-/three-letter fatha reading', () {
    test('interim qa-sha succeeds immediately after both sounds are present',
        () {
      for (final heard in ['قاء شاء', 'قاشا', 'قشاء', 'القا الشا', 'قا… شا']) {
        expect(fathaReadingCanAcceptInterim(heard, ['قَ', 'شَ']), isTrue,
            reason: heard);
      }
      for (final heard in ['قا', 'قاء', 'قااا', 'شا', 'قا سا', 'قاف شين']) {
        expect(fathaReadingCanAcceptInterim(heard, ['قَ', 'شَ']), isFalse,
            reason: heard);
      }
    });

    test('interim alif after another sound needs a separate syllable boundary',
        () {
      for (final heard in ['را', 'رَا', 'راء', 'رااا', 'رأ']) {
        expect(fathaReadingMatchesExpected(heard, ['رَ', 'أَ']), isTrue,
            reason: 'Preserve final-result compatibility: $heard');
        expect(fathaReadingCanAcceptInterim(heard, ['رَ', 'أَ']), isFalse,
            reason: 'This may only be the first sound: $heard');
      }
      for (final heard in [
        'رَ أَ',
        'را آ',
        'راء، آ',
        'رَأَ',
        'رَءَ',
        'راآ',
        'راءآ',
        'را الأَ',
        'را آ را آ',
        'رَأَ رَأَ',
      ]) {
        expect(fathaReadingCanAcceptInterim(heard, ['رَ', 'أَ']), isTrue,
            reason: heard);
      }
      for (final heard in ['تا آ تا', 'را آ را', 'را آ راء']) {
        final first = heard.startsWith('ت') ? 'تَ' : 'رَ';
        expect(fathaReadingMatchesExpected(heard, [first, 'أَ']), isFalse,
            reason: 'A repeated first syllable cannot replace the next alif');
      }
    });

    test('initial alif is clear but an ambiguous middle alif waits for final',
        () {
      for (final heard in ['أكل', 'اكل', 'أَكَلَ', 'آ كا لا']) {
        expect(fathaReadingCanAcceptInterim(heard, ['أَ', 'كَ', 'لَ']), isTrue,
            reason: heard);
      }
      for (final heard in ['رأس', 'راس', 'را سا', 'راسا']) {
        expect(fathaReadingMatchesExpected(heard, ['رَ', 'أَ', 'سَ']), isTrue,
            reason: 'Preserve final-result compatibility: $heard');
        expect(fathaReadingCanAcceptInterim(heard, ['رَ', 'أَ', 'سَ']), isFalse,
            reason: 'Do not split ra into two sounds before final: $heard');
      }
      for (final heard in ['رَأَسَ', 'را آ سا', 'راآسا', 'را أَسا']) {
        expect(fathaReadingCanAcceptInterim(heard, ['رَ', 'أَ', 'سَ']), isTrue,
            reason: heard);
      }
      expect(fathaReadingCanAcceptInterim('را آ', ['رَ', 'أَ', 'سَ']), isFalse);
      expect(
          fathaReadingCanAcceptInterim('را اللا', ['رَ', 'أَ', 'لَ']), isFalse);
    });

    test('reported qa-sha case accepts pace, lengthening and spelling practice',
        () {
      for (final heard in [
        'قاء شاء',
        'قا شا',
        'قاشا',
        'قشاء',
        'قشا',
        'قَ شَ',
        'القاء شاء',
        'القا الشا',
        'قاااا شاااا',
        'قاء… شاء',
        'قا — شا',
        'قا قا شا',
        'قاء شاء قاشا',
        'قاء شاء قاء شاء',
        'قا شا شا',
      ]) {
        expect(fathaReadingMatchesExpected(heard, ['قَ', 'شَ']), isTrue,
            reason: heard);
      }
      for (final heard in [
        'قا',
        'قاء',
        'شا',
        'شاء قا',
        'كا شا',
        'قا سا',
        'قا شا فا',
        'قا شا قا',
        'قا ثم شا',
        'قا و شا',
        'قاف شين',
        'القاف الشين',
        'قاااف شا',
        'قا شين',
        'قِ شَ',
        'قَ شُ',
        'قا شا صحيح',
        'ق ا شا',
      ]) {
        expect(fathaReadingMatchesExpected(heard, ['قَ', 'شَ']), isFalse,
            reason: heard);
      }
    });

    test(
        'all 64 shipped cards accept all supported styles without wrong letters',
        () {
      final cards = <List<String>>[];
      for (var group = 2; group <= 5; group++) {
        final content = jsonDecode(
            File('assets/content/lesson_reading_group_$group.json')
                .readAsStringSync()) as Map<String, dynamic>;
        for (final scene in content['scenes'] as List<dynamic>) {
          if (scene['type'] != 'reading') continue;
          for (final item in scene['data']['items'] as List<dynamic>) {
            cards.add(List<String>.from(item as List<dynamic>));
          }
        }
      }
      expect(cards, hasLength(64));
      for (final letters in cards) {
        final syllables = letters.map((letter) {
          final glyph = letter.replaceAll('َ', '');
          return glyph == 'أ' ? 'آ' : '$glyphا';
        }).toList();
        final longSyllables = syllables.map((sound) => '$soundااء').toList();
        final styles = [
          letters.join(),
          syllables.join(' '),
          syllables.join(),
          syllables.map((sound) => '$soundء').join(' '),
          longSyllables.join(' … '),
          longSyllables.map((sound) => 'ال$sound').join('، '),
          syllables.map((sound) => '$sound $sound').join(' '),
          '${syllables.join(' ')} ${syllables.join()}',
        ];
        for (final heard in styles) {
          expect(fathaReadingMatchesExpected(heard, letters), isTrue,
              reason: 'Card ${letters.join(' ')}; ASR $heard');
          expect(fathaReadingCanAcceptInterim(heard, letters), isTrue,
              reason:
                  'Complete unambiguous interim ${letters.join(' ')}: $heard');
        }
        final wrongLast = letters.last.startsWith('ب') ? 'تا' : 'با';
        for (final heard in [
          letters.take(letters.length - 1).join(' '),
          syllables.reversed.join(' '),
          [...syllables.take(syllables.length - 1), wrongLast].join(' '),
          '${syllables.join(' ')} ممتاز',
          '${syllables.join(' ')} ${syllables.first}',
          letters.join(' ').replaceFirst('َ', 'ِ'),
        ]) {
          expect(fathaReadingMatchesExpected(heard, letters), isFalse,
              reason: 'Must reject ${letters.join(' ')} from $heard');
        }
      }
    });

    test('accepts the reference cards in logical RTL reading order', () {
      const referenceReadings = <String>[
        // First card, rows from right to left.
        'بح', 'دخ', 'زس', 'تأ', 'جث', 'ذر',
        'جز', 'رأ', 'ثح', 'سذ', 'خت', 'دب',
        // Second card.
        'شح', 'طخ', 'ظس', 'صأ', 'عث', 'ضر',
        'جط', 'رض', 'ثش', 'سع', 'خظ', 'دص',
        'جد', 'ذس', 'تز', 'سش', 'ظع', 'بد',
        // Third card.
        'غص', 'فظ', 'قش', 'لط', 'مث', 'كض',
        'سل', 'بم', 'زغ', 'شف', 'خك', 'ذق',
        // Fourth card: first pairs, then three-letter readings.
        'نص', 'وظ', 'هو', 'يه', 'من', 'يط', 'كي',
        'أكل', 'رأس', 'صبر', 'نظر', 'حرث',
        'خدم', 'صدق', 'ضرع', 'غزل', 'طرأ',
        'فتح', 'وقف', 'وجد', 'خذل', 'نشر',
      ];
      for (final reading in referenceReadings) {
        final letters = reading.split('');
        final withFatha = letters.map((letter) => '$letterَ').toList();
        expect(fathaReadingMatchesExpected(reading, letters), isTrue,
            reason: reading);
        expect(
            fathaReadingMatchesExpected(withFatha.join(' '), withFatha), isTrue,
            reason: 'Spaced fatha: $reading');
        expect(fathaReadingMatchesExpected(withFatha.join(), withFatha), isTrue,
            reason: 'Connected fatha: $reading');
        expect(fathaReadingMatchesExpected(letters.reversed.join(), letters),
            isFalse,
            reason: 'Reversed order: $reading');
      }
    });

    test('covers all 28 letters with alif/hamza ASR syllable spellings', () {
      const alphabet = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي';
      for (final letter in alphabet.split('')) {
        final expected = [letter, 'ح'];
        expect(fathaReadingMatchesExpected('$letterَ حَ', expected), isTrue,
            reason: 'Glyph: $letter');
        expect(fathaReadingMatchesExpected('$letterا حا', expected), isTrue,
            reason: 'Alif spelling: $letter');
        final hamzaSpelling = letter == 'ا' ? 'اء' : '$letterاء';
        expect(
            fathaReadingMatchesExpected('$hamzaSpelling حاء', expected), isTrue,
            reason: 'Hamza spelling: $letter');
      }
    });

    test('accepts complete connected, separated and mixed syllables', () {
      for (final heard in ['سا ذا', 'ساذا', 'ساء ذاء', 'سَ ذا', 'سا ذَ']) {
        expect(fathaReadingMatchesExpected(heard, ['سَ', 'ذَ']), isTrue,
            reason: heard);
      }
      expect(fathaReadingMatchesExpected('فا تا حا', ['ف', 'ت', 'ح']), isTrue);
      expect(fathaReadingMatchesExpected('فاتاحا', ['ف', 'ت', 'ح']), isTrue);
      expect(fathaReadingMatchesExpected('فا تحا', ['ف', 'ت', 'ح']), isTrue);
    });

    test('accepts only the expected alif/hamza variants', () {
      for (final heard in ['رأ', 'را', 'رَ أَ', 'را آ', 'ر ء', 'را اا']) {
        expect(fathaReadingMatchesExpected(heard, ['ر', 'أ']), isTrue,
            reason: heard);
      }
      expect(fathaReadingMatchesExpected('رَ ا\u0654َ', ['ر', 'أ']), isTrue);
      expect(fathaReadingMatchesExpected('رَ اَ\u0654', ['ر', 'أ']), isTrue);
      expect(fathaReadingMatchesExpected('را ء', ['ر', 'ء']), isTrue);
      expect(fathaReadingMatchesExpected('را آه', ['ر', 'أ']), isFalse);
      expect(fathaReadingMatchesExpected('را ألف', ['ر', 'أ']), isFalse);
      expect(fathaReadingMatchesExpected('رَ إِ', ['ر', 'أ']), isFalse);
    });

    test('preserves token boundaries and consumes exactly the whole response',
        () {
      for (final heard in [
        '',
        'سا',
        'سا ذا سا',
        'ذا سا',
        'شا ذا',
        'أقول سا ذا',
        'سا ذا أحسنتم',
        'اساذا',
        'ساذاب',
        'سا و ذا',
        'س ا ذا',
        'سا ذ ا',
        'سا1ذا',
        'sin ذا',
        'سين ذا',
        'السين ذا',
      ]) {
        expect(fathaReadingMatchesExpected(heard, ['س', 'ذ']), isFalse,
            reason: heard);
      }
      expect(fathaReadingMatchesExpected('سا ذ', ['س', 'ذ']), isTrue);
      expect(fathaReadingMatchesExpected('سا سا ذا', ['س', 'ذ']), isTrue);
      expect(fathaReadingMatchesExpected('سا-ذا', ['س', 'ذ']), isTrue);
      expect(fathaReadingMatchesExpected('السا ذا', ['س', 'ذ']), isTrue);
      expect(fathaReadingMatchesExpected('سَا، ذَا!', ['س', 'ذ']), isTrue);
      expect(
          fathaReadingMatchesExpected('سَـا\u200f، ذَا', ['س', 'ذ']), isTrue);
    });

    test('does not accept a word merely containing expected letters', () {
      expect(fathaReadingMatchesExpected('سلام', ['س', 'م']), isFalse);
      expect(fathaReadingMatchesExpected('جمل', ['ج', 'م']), isFalse);
      expect(fathaReadingMatchesExpected('حرف السين', ['س', 'ن']), isFalse);
      expect(fathaReadingMatchesExpected('الساعة', ['س', 'ع']), isFalse);
    });

    test('rejects distinct letter names even if syllables could segment them',
        () {
      const cases = <String, List<String>>{
        'دال': ['د', 'ل'],
        'ذال': ['ذ', 'ل'],
        'صاد': ['ص', 'د'],
        'ضاد': ['ض', 'د'],
        'قاف': ['ق', 'ف'],
        'كاف': ['ك', 'ف'],
        'لام': ['ل', 'م'],
        'واو': ['و', 'و'],
        'جيم حا': ['ج', 'ح'],
        'عين حا': ['ع', 'ح'],
        'غين حا': ['غ', 'ح'],
        'سين حا': ['س', 'ح'],
        'شين حا': ['ش', 'ح'],
        'ميم حا': ['م', 'ح'],
        'نون حا': ['ن', 'ح'],
        'زاي حا': ['ز', 'ح'],
        'الدال': ['د', 'ل'],
      };
      for (final entry in cases.entries) {
        expect(fathaReadingMatchesExpected(entry.key, entry.value), isFalse,
            reason: entry.key);
      }
      // Separated phonemes are not the ambiguous whole-token letter name.
      expect(fathaReadingMatchesExpected('دا لَ', ['د', 'ل']), isTrue);
      expect(fathaReadingMatchesExpected('دَ لَ', ['د', 'ل']), isTrue);
    });

    test('rejects explicit non-fatha vowels instead of stripping them', () {
      for (final heard in [
        'سِ ذَ',
        'سُ ذَ',
        'سْ ذَ',
        'سٍ ذَ',
        'سٌ ذَ',
        'سً ذَ',
        'سَّ ذَ',
        'سَا ذِي',
        'سَا ذُو',
      ]) {
        expect(fathaReadingMatchesExpected(heard, ['س', 'ذ']), isFalse,
            reason: heard);
      }
      expect(fathaReadingMatchesExpected('سَذَ', ['سَ', 'ذَ']), isTrue);
      expect(fathaReadingMatchesExpected('سذ', ['سِ', 'ذَ']), isFalse);
    });

    test('validates expected shape and requires exactly two or three glyphs',
        () {
      expect(fathaReadingMatchesExpected('سا', ['س']), isFalse);
      expect(fathaReadingMatchesExpected('سذ', []), isFalse);
      expect(
          fathaReadingMatchesExpected('سذرح', ['س', 'ذ', 'ر', 'ح']), isFalse);
      expect(fathaReadingMatchesExpected('سذ', ['سا', 'ذ']), isFalse);
      expect(fathaReadingMatchesExpected('سذ', ['seen', 'dhal']), isFalse);
      expect(fathaReadingMatchesExpected('سذ', ['سين', 'ذ']), isFalse);
      expect(fathaReadingMatchesExpected('سذ', ['س', 'ة']), isFalse);
      expect(fathaReadingMatchesExpected('فت', ['ف', 'ت', 'ح']), isFalse);
      expect(fathaReadingMatchesExpected('فتحخ', ['ف', 'ت', 'ح']), isFalse);
    });
  });
}
