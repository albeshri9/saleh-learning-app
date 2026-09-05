import 'audio_service.dart';
import 'fatha_model_clips.dart';

String _baseLetter(String letter) {
  final base = letter.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640\s]'), '');
  return base == 'ا' ? 'أ' : base;
}

AudioClip? fathaModelClipFor(String letter) =>
    fathaModelClips[_baseLetter(letter)];

/// Full three-repeat recordings used by the existing single-letter practice.
/// These are deliberately distinct from excerpt sources, which may include a
/// following word/question outside their checked clip boundaries.
const fathaTapRepeatAssets = <String, String>{
  'أ': 'assets/audio/alif/tap_repeat_3_v59.mp3',
  'ب': 'assets/audio/baa/tap_repeat_3_v59.mp3',
  'ت': 'assets/audio/taa/tap_repeat_3_v59.mp3',
  'ث': 'assets/audio/thaa/tap_repeat_3_v59.mp3',
  'ج': 'assets/audio/jeem_v44/tap_repeat_3_v59.mp3',
  'ح': 'assets/audio/haa/tap_repeat_3_v59.mp3',
  'خ': 'assets/audio/khaa/tap_repeat_3_v59.mp3',
  'د': 'assets/audio/dal/tap_repeat_3_v59.mp3',
  'ذ': 'assets/audio/dhal/tap_repeat_3_v59.mp3',
  'ر': 'assets/audio/raa/tap_repeat_3_v59.mp3',
  'ز': 'assets/audio/zay/tap_repeat_3_v59.mp3',
  'س': 'assets/audio/seen/tap_repeat_3_v59.mp3',
  'ش': 'assets/audio/sheen/tap_repeat_3_v60.mp3',
  'ص': 'assets/audio/saad/tap_repeat_3_v60.mp3',
  'ض': 'assets/audio/daad/tap_repeat_3_v60.mp3',
  'ط': 'assets/audio/tah/tap_repeat_3_v60.mp3',
  'ظ': 'assets/audio/zah/tap_repeat_3_v60.mp3',
  'ع': 'assets/audio/ayn/tap_repeat_3_v60.mp3',
  'غ': 'assets/audio/ghayn/tap_repeat_3_v60.mp3',
  'ف': 'assets/audio/faa/tap_repeat_3_v60.mp3',
  'ق': 'assets/audio/qaaf/tap_repeat_3_v60.mp3',
  'ك': 'assets/audio/kaaf/tap_repeat_3_v60.mp3',
  'ل': 'assets/audio/laam/tap_repeat_3_v60.mp3',
  'م': 'assets/audio/meem/tap_repeat_3_v60.mp3',
  'ن': 'assets/audio/noon/tap_repeat_3_v60.mp3',
  'ه': 'assets/audio/heh/tap_repeat_3_v60.mp3',
  'و': 'assets/audio/waw/tap_repeat_3_v60.mp3',
  'ي': 'assets/audio/yaa/tap_repeat_3_v60.mp3',
};

String? fathaTapRepeatAssetFor(String letter) =>
    fathaTapRepeatAssets[_baseLetter(letter)];

/// Plays exactly one existing phoneme for each displayed glyph, in reading
/// order. Cancellation is synchronous, including between two clip futures.
class FathaReadingDemonstration {
  FathaReadingDemonstration(this.audio);

  final AudioService audio;
  int _generation = 0;

  void cancel() => _generation++;

  Future<void> play(List<String> letters) async {
    final generation = ++_generation;
    final clips = letters.map(fathaModelClipFor).toList();
    if (audio is! AudioClipService || clips.any((clip) => clip == null)) return;
    await audio.stop();
    for (final clip in clips) {
      if (generation != _generation) return;
      await (audio as AudioClipService).playClip(clip!);
    }
  }
}
