import 'dart:math';

/// Shuffle within each phase, never mix word questions into letter practice.
List<Map<String, dynamic>> reviewQuestionOrder(
    List<Map<String, dynamic>> questions, Random random) {
  List<Map<String, dynamic>> phase(bool words) {
    final original =
        questions.where((q) => (q['kind'] == 'word') == words).toList();
    final result = [...original]..shuffle(random);
    if (result.length > 1 &&
        List.generate(result.length, (i) => identical(result[i], original[i]))
            .every((v) => v)) {
      result.add(result.removeAt(0));
    }
    return result;
  }

  return [...phase(false), ...phase(true)];
}
