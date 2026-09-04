/// Temporary switches used while the lessons are being reviewed on devices.
///
/// The official release must set both values to false so the curriculum
/// returns to sequential unlocking and only pedagogically approved skips.
abstract final class ExperimentalRelease {
  static const openEveryLessonAndCheckpoint = true;
  static const skipEveryLessonSection = true;
}
