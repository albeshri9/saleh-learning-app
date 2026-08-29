import 'dart:math';

/// Picks exactly one cumulative-review question for every previous letter.
///
/// Half of the letters are tested by recognizing the glyph and the other half
/// by recognizing a word/image. A letter can therefore never appear in both
/// phases during the same review. Both the partition and the order inside each
/// phase change on every lesson run.
List<Map<String, dynamic>> reviewQuestionOrder(
    List<Map<String, dynamic>> questions, Random random) {
  final byLetter = <String, List<Map<String, dynamic>>>{};
  for (final question in questions) {
    final id = question['reviewLessonId'] as String?;
    if (id == null || id.isEmpty) continue;
    byLetter.putIfAbsent(id, () => []).add(question);
  }
  if (byLetter.isEmpty) return [...questions]..shuffle(random);

  final ids = byLetter.keys.toList()..shuffle(random);
  // Six previous letters become 3 glyph + 3 word questions. With an odd
  // count, the extra question alternates randomly between the two phases.
  final letterCount =
      ids.length ~/ 2 + (ids.length.isOdd && random.nextBool() ? 1 : 0);
  final letterIds = ids.take(letterCount).toSet();

  Map<String, dynamic> choose(String id, String preferredKind) {
    final candidates = byLetter[id]!;
    final preferred =
        candidates.where((q) => q['kind'] == preferredKind).toList();
    final pool = preferred.isEmpty ? candidates : preferred;
    return pool[random.nextInt(pool.length)];
  }

  final letters = <Map<String, dynamic>>[];
  final words = <Map<String, dynamic>>[];
  for (final id in ids) {
    if (letterIds.contains(id)) {
      letters.add(choose(id, 'letter'));
    } else {
      words.add(choose(id, 'word'));
    }
  }
  letters.shuffle(random);
  words.shuffle(random);

  return [...letters, ...words];
}
