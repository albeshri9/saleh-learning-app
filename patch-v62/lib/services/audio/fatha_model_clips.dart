import 'audio_service.dart';

/// Single fatha syllables drawn from the existing lesson narration.
/// Boundaries were inspected against decoded energy/silence, not obtained by
/// dividing three-repeat recordings into thirds. The source audio is unchanged.
/// These technical boundaries do not constitute new auditory approval.
const fathaModelClips = <String, AudioClip>{
  'أ': AudioClip(
      assetPath: 'assets/audio/alif/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 450)),
  'ب': AudioClip(
      assetPath: 'assets/audio/baa/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 350)),
  'ت': AudioClip(
      assetPath: 'assets/audio/taa/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 500)),
  'ث': AudioClip(
      assetPath: 'assets/audio/thaa/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 560)),
  'ج': AudioClip(
      assetPath: 'assets/audio/jeem/explain_3.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 580)),
  'ح': AudioClip(
      assetPath: 'assets/audio/haa/explain_3.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 570)),
  'خ': AudioClip(
      assetPath: 'assets/audio/khaa/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 520)),
  'د': AudioClip(
      assetPath: 'assets/audio/dal/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 540)),
  'ذ': AudioClip(
      assetPath: 'assets/audio/dhal/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 560)),
  'ر': AudioClip(
      assetPath: 'assets/audio/raa/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 520)),
  'ز': AudioClip(
      assetPath: 'assets/audio/zay/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 670)),
  'س': AudioClip(
      assetPath: 'assets/audio/seen/tap_repeat_3_v59.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 570)),
  'ش': AudioClip(
      assetPath: 'assets/audio/sheen/explain_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 620)),
  'ص': AudioClip(
      assetPath: 'assets/audio/saad/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 570)),
  'ض': AudioClip(
      assetPath: 'assets/audio/daad/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 520)),
  'ط': AudioClip(
      assetPath: 'assets/audio/tah/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 470)),
  'ظ': AudioClip(
      assetPath: 'assets/audio/zah/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 540)),
  'ع': AudioClip(
      assetPath: 'assets/audio/ayn/explain_2_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 640)),
  'غ': AudioClip(
      assetPath: 'assets/audio/ghayn/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 470)),
  'ف': AudioClip(
      assetPath: 'assets/audio/faa/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 580)),
  'ق': AudioClip(
      assetPath: 'assets/audio/qaaf/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 540)),
  'ك': AudioClip(
      assetPath: 'assets/audio/kaaf/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 540)),
  'ل': AudioClip(
      assetPath: 'assets/audio/laam/explain_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 700)),
  'م': AudioClip(
      assetPath: 'assets/audio/meem/tap_repeat_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 600)),
  'ن': AudioClip(
      assetPath: 'assets/audio/noon/explain_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 580)),
  // Connected /ha/ repeats: boundary at the inter-syllable energy trough.
  // The saved ASR audit transcribed this source as three /ha/ syllables.
  'ه': AudioClip(
      assetPath: 'assets/audio/heh/explain_2_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 470)),
  'و': AudioClip(
      assetPath: 'assets/audio/waw/explain_3_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 620)),
  'ي': AudioClip(
      assetPath: 'assets/audio/yaa/explain_2_v60.mp3',
      start: Duration.zero,
      end: Duration(milliseconds: 540)),
};
