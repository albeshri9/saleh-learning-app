import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/features/games/game_catalog.dart';

void main() {
  test('approved examples retain initial fatha in lesson choices', () {
    for (final id in ['alif', 'baa', 'taa']) {
      final data =
          jsonDecode(File('assets/content/lesson_$id.json').readAsStringSync());
      final scenes = data['scenes'] as List;
      final example =
          scenes.firstWhere((s) => s['type'] == 'explanation')['data']
              ['example']['word'] as String;
      expect(example[1], 'َ');
      final questions =
          scenes.firstWhere((s) => s['type'] == 'multipleChoice')['data']
              ['questions'] as List;
      for (final word in questions.last['options'] as List) {
        expect((word as String)[1], 'َ');
      }
    }
  });
  test('initial diacritics stay attached to game letter tiles', () {
    expect(objectWords[0], 'أَسد');
    expect(objectWords[2], 'بَطة');
    expect(objectWords[3], 'ثَعْلَب');
    final train = gameCatalog.firstWhere((g) => g.id == 'word_train');
    final basket = gameCatalog.firstWhere((g) => g.id == 'picture_word');
    expect(roundFor(basket, 0).items.first.text, 'أَسد');
    for (var i = 0; i < 3; i++) {
      final r = roundFor(train, i);
      expect(r.items.last.text, isNot('َ'));
    }
  });
  test('new lesson configuration uses the requested rope example', () {
    final lessons =
        jsonDecode(File('tool/v43_narration.json').readAsStringSync()) as List;
    expect(lessons.map((l) => l['word']), ['ثَعْلَب', 'جَمَل', 'حَبْل']);
    expect(lessons.last['image'], 'rope_v43.png');
    expect(jsonEncode(lessons), isNot(contains('حَمامة')));
  });
}
