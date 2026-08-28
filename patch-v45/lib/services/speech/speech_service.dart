import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

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

/// تحقق حقيقي باستخدام خدمة التعرف على الكلام في الجهاز.
/// الجلسة قصيرة ومهيأة للعربية لأنها مخصصة لحرف واحد لا للإملاء الطويل.
class DeviceSpeechService implements SpeechService {
  final soundLevel = ValueNotifier<double>(0);
  final SpeechToText _speech = SpeechToText();
  VoidCallback? _sessionError;
  void Function(String)? _sessionStatus;

  @override
  Future<SpeechResult> listenFor(String expected) async {
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
        if (!listeningStarted) return;
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          // نمنح النتيجة النهائية فرصة قصيرة للوصول قبل إغلاق المحاولة.
          statusFinishDelay?.cancel();
          statusFinishDelay = Timer(const Duration(milliseconds: 350), finish);
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
      if (!available) return const SpeechResult(correct: false);

      final locales = await _speech.locales();
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
      await _speech.listen(
        onSoundLevelChange: (level) =>
            soundLevel.value = ((level + 2) / 12).clamp(0.0, 1.0),
        onResult: (result) {
          recognizedWords = result.recognizedWords;
          confidence = result.confidence;
          if (result.finalResult) finish();
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: false,
          onDevice: false,
        ),
      );
      timeout = Timer(const Duration(seconds: 6), () async {
        await _speech.stop();
        finish();
      });
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
    return const {'اه', 'اا', 'ااه', 'الف'}.contains(heard);
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
