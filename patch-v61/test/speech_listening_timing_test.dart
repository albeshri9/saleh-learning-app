import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saleh_app/services/speech/speech_service.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device callbacks stay under test control; widget tests supply a fake clock.
class _Recognizer extends Fake implements SpeechToText {
  SpeechStatusListener? _status;
  SpeechResultListener? _result;
  SpeechListenOptions? options;
  List<LocaleName> supportedLocales = [
    LocaleName('en_US', 'English'),
    LocaleName('ar_EG', 'Arabic Egypt'),
    LocaleName('ar-SA', 'Arabic Saudi Arabia'),
  ];
  Completer<void>? initializeGate;
  Completer<void>? stopGate;
  Object? stopError;
  void Function()? onListen;
  bool available = true;
  bool listening = false;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  bool get isListening => listening;

  @override
  bool get isNotListening => !listening;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    // Match the plugin: initialize retains its first callbacks.
    _status ??= onStatus;
    _status?.call(SpeechToText.notListeningStatus);
    if (initializeGate != null) await initializeGate!.future;
    return available;
  }

  @override
  Future<List<LocaleName>> locales() async => supportedLocales;

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
    options = listenOptions;
    _result = onResult;
    status(SpeechToText.listeningStatus);
    onListen?.call();
  }

  void result(String words,
      {bool finalResult = false, double confidence = .9}) {
    _result?.call(SpeechRecognitionResult.init(
      [SpeechRecognitionWords(words, null, confidence)],
      finalResult ? ResultType.finalResult : ResultType.partial,
    ));
  }

  void status(String value) {
    listening = value == SpeechToText.listeningStatus;
    _status?.call(value);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
    if (stopError != null) throw stopError!;
    if (stopGate != null) await stopGate!.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    listening = false;
  }
}

void main() {
  test('single letters, pairs and triples receive child-paced limits', () {
    final single = SpeechListeningTiming.forExpected('بَ');
    final pair = SpeechListeningTiming.forExpected('بَ حَ');
    final triple = SpeechListeningTiming.forExpected('فَ تَ حَ');
    expect(single.listenFor, const Duration(seconds: 10));
    expect(single.pauseFor, const Duration(seconds: 4));
    expect(pair.listenFor, const Duration(seconds: 30));
    expect(pair.pauseFor, const Duration(seconds: 10));
    expect(triple.listenFor, const Duration(seconds: 40));
    expect(triple.pauseFor, const Duration(seconds: 12));
    for (final timing in [single, pair, triple]) {
      expect(timing.watchdog, timing.listenFor + const Duration(seconds: 2));
      expect(timing.pauseFor, lessThanOrEqualTo(timing.listenFor));
    }
  });

  test('timing counts glyph groups, not Arabic marks or surrounding spaces',
      () {
    final pair = SpeechListeningTiming.forExpected('  بَ \n\t حَ  ');
    expect(pair.listenFor, const Duration(seconds: 30));
    expect(SpeechListeningTiming.forExpected(' با ').listenFor,
        const Duration(seconds: 10));
  });

  testWidgets('pair remains open past six seconds and accepts a late result',
      (tester) async {
    final recognizer = _Recognizer();
    final service = DeviceSpeechService(recognizer: recognizer);
    SpeechResult? completed;
    final pending =
        service.listenFor('بَ حَ').then((value) => completed = value);
    await tester.pump();
    expect(recognizer.options?.listenFor, const Duration(seconds: 30));
    expect(recognizer.options?.pauseFor, const Duration(seconds: 10));
    expect(recognizer.options?.listenMode, ListenMode.dictation);
    await tester.pump(const Duration(seconds: 7));
    expect(completed, isNull);
    expect(recognizer.stopCalls, 0);
    recognizer.result('بَ');
    await tester.pump(const Duration(seconds: 7));
    expect(completed, isNull);
    recognizer.result('بَ حَ', finalResult: true);
    await tester.pump();
    await pending;
    expect(completed?.recognizedWords, 'بَ حَ');
    await service.dispose();
  });

  testWidgets('fast synchronous final does not leave a watchdog behind',
      (tester) async {
    final recognizer = _Recognizer();
    recognizer.onListen = () => recognizer.result('با', finalResult: true);
    final service = DeviceSpeechService(recognizer: recognizer);
    final pending = service.listenFor('با');
    await tester.pump();
    expect((await pending).correct, isTrue);
    expect(recognizer.options?.listenMode, ListenMode.confirmation);
    // No dispose or large pump here: testWidgets detects any timer left alive
    // after a final result that arrived before recognizer.listen completed.
  });

  testWidgets('watchdog stops an unresponsive recognizer at its derived limit',
      (tester) async {
    final recognizer = _Recognizer();
    final service = DeviceSpeechService(recognizer: recognizer);
    SpeechResult? completed;
    final pending =
        service.listenFor('بَ حَ').then((value) => completed = value);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(completed, isNull);
    expect(recognizer.stopCalls, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await pending;
    expect(recognizer.stopCalls, 1);
    expect(completed?.correct, isFalse);
    await service.dispose();
  });

  testWidgets('notListening leaves room for a final after 350 milliseconds',
      (tester) async {
    final recognizer = _Recognizer();
    final service = DeviceSpeechService(recognizer: recognizer);
    SpeechResult? completed;
    final pending =
        service.listenFor('بَ حَ').then((value) => completed = value);
    await tester.pump();
    recognizer.result('بَ');
    recognizer.status(SpeechToText.notListeningStatus);
    await tester.pump(const Duration(milliseconds: 800));
    expect(completed, isNull);
    recognizer.result('بَ حَ', finalResult: true);
    await tester.pump();
    await pending;
    expect(completed?.recognizedWords, 'بَ حَ');
    await service.dispose();
  });

  for (final hangingStop in [false, true]) {
    testWidgets(
        'watchdog still settles when stop ${hangingStop ? 'hangs' : 'throws'}',
        (tester) async {
      final recognizer = _Recognizer();
      if (hangingStop) {
        recognizer.stopGate = Completer<void>();
      } else {
        recognizer.stopError = StateError('native stop failed');
      }
      final service = DeviceSpeechService(recognizer: recognizer);
      SpeechResult? completed;
      final pending =
          service.listenFor('با').then((value) => completed = value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      if (hangingStop) {
        expect(completed, isNull);
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump();
      await pending;
      expect(completed?.correct, isFalse);
      expect(recognizer.stopCalls, 1);
      recognizer.stopGate?.complete();
      await tester.pump();
      await service.dispose();
    });
  }

  testWidgets('dispose during initialization cannot later start the microphone',
      (tester) async {
    final recognizer = _Recognizer()..initializeGate = Completer<void>();
    final service = DeviceSpeechService(recognizer: recognizer);
    final pending = service.listenFor('بَ حَ');
    await tester.pump();
    await service.dispose();
    recognizer.initializeGate!.complete();
    await tester.pump();
    expect((await pending).correct, isFalse);
    expect(recognizer.listenCalls, 0);
    expect(recognizer.stopCalls, 0);
    expect(recognizer.cancelCalls, 1);
  });

  testWidgets('dispose settles listening and ignores a late stopped status',
      (tester) async {
    final recognizer = _Recognizer();
    final service = DeviceSpeechService(recognizer: recognizer);
    final pending = service.listenFor('بَ حَ');
    await tester.pump();
    await service.dispose();
    await tester.pump();
    expect((await pending).correct, isFalse);
    recognizer.status(SpeechToText.notListeningStatus);
    recognizer.result('بَ حَ', finalResult: true);
    await tester.pump();
    expect(recognizer.cancelCalls, 1);
    expect(recognizer.stopCalls, 0);
    // A stale status callback must not schedule a new finish timer.
  });

  testWidgets('a second attempt receives retained initialization callbacks',
      (tester) async {
    final recognizer = _Recognizer();
    final service = DeviceSpeechService(recognizer: recognizer);
    final first = service.listenFor('با');
    await tester.pump();
    recognizer.result('با', finalResult: true);
    await tester.pump();
    expect((await first).correct, isTrue);

    SpeechResult? completed;
    final second = service.listenFor('تا').then((value) => completed = value);
    await tester.pump();
    expect(completed, isNull,
        reason: 'Initialization notListening cannot close a new attempt');
    recognizer.status(SpeechToText.notListeningStatus);
    await tester.pump(const Duration(seconds: 3));
    await second;
    expect(completed?.correct, isFalse);
    await service.dispose();
  });

  for (final hasSaudiLocale in [true, false]) {
    testWidgets(
        'prefers ${hasSaudiLocale ? 'Saudi' : 'available'} Arabic locale',
        (tester) async {
      final recognizer = _Recognizer();
      if (!hasSaudiLocale) recognizer.supportedLocales.removeLast();
      recognizer.onListen = () => recognizer.result('با', finalResult: true);
      final service = DeviceSpeechService(recognizer: recognizer);
      final pending = service.listenFor('با');
      await tester.pump();
      await pending;
      expect(recognizer.options?.localeId, hasSaudiLocale ? 'ar-SA' : 'ar_EG');
      await service.dispose();
    });
  }
}
