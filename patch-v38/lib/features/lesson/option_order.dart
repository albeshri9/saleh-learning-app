import 'dart:math';

/// Stable for the whole attempt. A retry moves every option, including the
/// answer, while keeping labels/images and original correctness tied together.
List<int> shuffledOptions(int length, Random random, [List<int>? previous]) {
  if (previous != null && length > 1) {
    final shift = 1 + random.nextInt(length - 1);
    return [...previous.skip(shift), ...previous.take(shift)];
  }
  return List<int>.generate(length, (i) => i)..shuffle(random);
}
