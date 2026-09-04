import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'fatha_reading_matcher.dart';

/// نتيجة تقييم نطق الطفل.
class SpeechResult {
  const SpeechResult({
    required this.correct,
    this.confidence = 0,
    this.recognizedWords = '',
  });

  final bool correct;
  final double confidence;
  final String recognizedWords;
}

/// خدمة التعرف على الصوت — تُستخدم في مشاهد التدريب فقط.
abstract interface class SpeechService {
  /// يستمع ثم يقيّم هل نطق الطفل [expected].
  Future<SpeechResult> listenFor(String expected);

  Future<void> dispose();
}

/// Time budgets for a child sounding out a letter or combining syllables.
/// Device recognizers can still end earlier; these are requested maximums.
class SpeechListeningTiming {
  const SpeechListeningTiming({
    required this.listenFor,
    required this.pauseFor,
    required this.listenMode,
  });

  factory SpeechListeningTiming.forExpected(String expected) {
    final syllables = expected
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .length;
    if (syllables >= 3) {
      return const SpeechListeningTiming(
        listenFor: Duration(seconds: 40),
        pauseFor: Duration(seconds: 12),
        listenMode: ListenMode.dictation,
      );
    }
    if (syllables == 2) {
      return const SpeechListeningTiming(
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 10),
        listenMode: ListenMode.dictation,
      );
    }
    return const SpeechListeningTiming(
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 4),
      listenMode: ListenMode.confirmation,
    );
  }

  final Duration listenFor;
  final Duration pauseFor;
  final ListenMode listenMode;
  Duration get watchdog => listenFor + const Duration(seconds: 2);
}

/// تحقق حقيقي باستخدام خدمة التعرف على الكلام في الجهاز.
/// المهلة تتسع لتهجئة الطفل والوقفة بين الحرفين أو الحروف الثلاثة.
class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({SpeechToText? recognizer})
      : _speech = recognizer ?? SpeechToText();

  final soundLevel = ValueNotifier<double>(0);
  final SpeechToText _speech;
  VoidCallback? _sessionError;
  void Function(String)? _sessionStatus;

  @override
  Future<SpeechResult> listenFor(String expected) async {
    final timing = SpeechListeningTiming.forExpected(expected);
    var recognizedWords = '';
    var confidence = 0.0;
    var finished = false;
    var listeningStarted = false;
    Timer? timeout;
    Timer? statusFinishDelay;
    final completer = Completer<SpeechResult>();

    void finish() {
      if (finished) return;
      finished = true;
      timeout?.cancel();
      statusFinishDelay?.cancel();
      soundLevel.value = 0;
      if (!completer.isCompleted) {
        completer.complete(
          SpeechResult(
            correct: speechMatchesExpected(recognizedWords, expected),
            confidence: confidence < 0 ? 0 : confidence,
            recognizedWords: recognizedWords,
          ),
        );
      }
    }

    try {
      _sessionError = finish;
      _sessionStatus = (status) {
        // initialize() قد يرسل notListening قبل بدء الجلسة الفعلية.
        // تجاهله يمنع إنهاء المحاولة قبل أن يسمع الجهاز الطفل.
        if (!listeningStarted || finished) return;
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          // notListening can precede the final transcript. Match the plugin's
          // final-result grace instead of cutting that transcript off at 350ms.
          statusFinishDelay?.cancel();
          statusFinishDelay = Timer(
            status == SpeechToText.notListeningStatus
                ? SpeechToText.defaultFinalTimeout
                : const Duration(milliseconds: 350),
            finish,
          );
        }
      };
      // The plugin keeps initialize callbacks from its first initialization.
      // Dispatch to the current attempt instead of its stale first closure.
      final available = await _speech.initialize(
        onError: (error) {
          debugPrint('[speech] ${error.errorMsg}');
          _sessionError?.call();
        },
        onStatus: (status) => _sessionStatus?.call(status),
      );
      if (!available || finished) {
        finish();
        return await completer.future;
      }

      final locales = await _speech.locales();
      if (finished) return await completer.future;
      final arabicLocales = locales.where(
        (locale) => locale.localeId.toLowerCase().startsWith('ar'),
      );
      final localeId = arabicLocales
              .where((locale) {
                final id = locale.localeId.toLowerCase().replaceAll('-', '_');
                return id == 'ar_sa';
              })
              .map((locale) => locale.localeId)
              .firstOrNull ??
          arabicLocales.map((locale) => locale.localeId).firstOrNull;

      listeningStarted = true;
      // Arm before listen(): some native implementations return a final result
      // synchronously. finish() must be able to cancel this timer in that case.
      timeout = Timer(timing.watchdog, () async {
        try {
          await _speech.stop().timeout(const Duration(seconds: 1));
        } catch (error) {
          debugPrint('[speech] stop at time limit: $error');
        } finally {
          finish();
        }
      });
      await _speech.listen(
        onSoundLevelChange: (level) {
          if (!finished) {
            soundLevel.value = ((level + 2) / 12).clamp(0.0, 1.0);
          }
        },
        onResult: (result) {
          if (finished) return;
          recognizedWords = result.recognizedWords;
          confidence = result.confidence;
          if (result.finalResult) finish();
        },
        listenOptions: SpeechListenOptions(
          listenFor: timing.listenFor,
          pauseFor: timing.pauseFor,
          localeId: localeId,
          listenMode: timing.listenMode,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: false,
          onDevice: false,
        ),
      );
      return await completer.future;
    } catch (error) {
      debugPrint('[speech] initialization/listening failed: $error');
      finish();
      return completer.future;
    }
  }

  @override
  Future<void> dispose() async {
    _sessionError?.call();
    _sessionError = null;
    _sessionStatus = null;
    soundLevel.value = 0;
    await _speech.cancel();
  }
}

@visibleForTesting
bool speechMatchesExpected(String recognized, String expected) {
  // The newly added letters use the full-transcript fatha matcher before any
  // legacy normalization can erase an incorrect vowel or short-circuit an
  // exact letter-name match. This remains ASR text matching, not an acoustic
  // diagnosis. The first twelve letters keep their established device aliases
  // until their separate migration is verified.
  final requested = expected.trim();
  if (requested.isNotEmpty && 'شصضطظعغفقكلمنهوي'.contains(requested[0])) {
    return fathaLetterMatchesExpected(recognized, expected);
  }

  String normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll(RegExp(r'[^\u0621-\u064A]'), '');

  final heard = normalize(recognized);
  final target = normalize(expected);
  if (heard.isEmpty || target.isEmpty) return false;
  if (heard == target) return true;

  // عند نطق صوت «آ» وحده قد يعيده محرّك iOS كنص «آه» أو «ألف»؛
  // هذه اختلافات تفريغ آلي للصوت نفسه وليست مطالبة للطفل بنطق اسم الحرف.
  if (target == 'ا') {
    // محركات iOS وAndroid قد تفرّغ صوت «آ» القصير بأحد هذه الأشكال.
    // نقبل اختلاف التفريغ فقط، ولا نغيّر الصوت المطلوب من الطفل.
    return const {'ا', 'اه', 'اا', 'ااه', 'ها', 'الف', 'الالف'}.contains(heard);
  }

  if (target == 'با') return const {'ب', 'باء', 'الباء'}.contains(heard);
  if (target == 'تا') return const {'ت', 'تاء', 'التاء'}.contains(heard);
  if (target == 'ثا') return const {'ث', 'ثاء', 'الثاء'}.contains(heard);
  if (target == 'جا') {
    // Arabic ASR often spells the isolated sound as the word جاء, including
    // when a child repeats it. Do not accept unrelated words such as جمل.
    const variants = {'جا', 'جاء', 'ج', 'جيم', 'الجيم', 'الجا', 'الجاء'};
    if (variants.contains(heard)) return true;
    final tokens = recognized
        .trim()
        .split(RegExp(r'[\s،,!.؟]+'))
        .where((s) => s.isNotEmpty)
        .map(normalize)
        .toList();
    return tokens.length >= 2 &&
        tokens.length <= 4 &&
        tokens.every(variants.contains);
  }
  if (target == 'حا') return const {'ح', 'حاء', 'الحاء'}.contains(heard);
  if (target == 'خا') {
    const variants = {'خا', 'خاء', 'خ', 'الخا', 'الخاء'};
    if (variants.contains(heard)) return true;
    final tokens = recognized
        .trim()
        .split(RegExp(r'[\s،,!.؟]+'))
        .where((value) => value.isNotEmpty)
        .map(normalize)
        .toList();
    return tokens.length >= 2 &&
        tokens.length <= 4 &&
        tokens.every(variants.contains);
  }
  if (target == 'دا') {
    return const {'د', 'دال', 'الدال', 'دا', 'داء'}.contains(heard);
  }
  if (target == 'ذا') {
    return const {'ذ', 'ذال', 'الذال', 'ذا', 'ذاء'}.contains(heard);
  }
  if (target == 'را') {
    return const {'ر', 'راء', 'الراء', 'را'}.contains(heard);
  }
  if (target == 'زا') {
    return const {'ز', 'زاي', 'الزاي', 'زا', 'زاء'}.contains(heard);
  }
  if (target == 'سا') {
    return const {'س', 'سين', 'السين', 'سا', 'ساء'}.contains(heard);
  }
  return false;
}

class MockSpeechService implements SpeechService {
  const MockSpeechService({this.result = const SpeechResult(correct: true)});

  final SpeechResult result;

  @override
  Future<SpeechResult> listenFor(String expected) async => result;

  @override
  Future<void> dispose() async {}
}
