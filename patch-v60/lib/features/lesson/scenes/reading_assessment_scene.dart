import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/experimental_release.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/letter_glyph.dart';
import '../../../core/design/widgets/touch_feedback.dart';
import '../../../domain/models/lesson.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/audio/interaction_audio.dart';
import '../../../services/speech/speech_service.dart';
import '../../../services/speech/fatha_reading_matcher.dart';
import '../scene_registry.dart';

/// Keep the reference's reading direction inside each item. Only the order of
/// complete items is randomized; pairs always precede triples.
List<List<String>> readingAssessmentItems(Map<String, dynamic> data,
    {math.Random? random}) {
  final items = ((data['items'] as List?) ?? const [])
      .map((item) => (item as List).cast<String>())
      .where((letters) => letters.length == 2 || letters.length == 3)
      .toList();
  final rng = random ?? math.Random();
  return [
    for (final length in [2, 3])
      ...(items.where((item) => item.length == length).toList()..shuffle(rng)),
  ];
}

class ReadingAssessmentScene extends ConsumerStatefulWidget {
  const ReadingAssessmentScene(
      {super.key, required this.scene, required this.api});
  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<ReadingAssessmentScene> createState() =>
      _ReadingAssessmentState();
}

class _ReadingAssessmentState extends ConsumerState<ReadingAssessmentScene> {
  late final AudioService _audio;
  late final SpeechService _speech;
  late final List<List<String>> _items;
  final List<List<String>> _retry = [];
  int _index = 0;
  int _request = 0;
  int _attempts = 0;
  int _correctCount = 0;
  bool _listening = false;
  bool _correct = false;
  bool _result = false;
  bool _remediation = false;
  bool _hadSkippedItem = false;
  String _feedback = 'اضغطوا على الميكروفون ثم اقرؤوا من اليمين إلى اليسار';

  List<String> get _current => _items[_index];

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    _speech = ref.read(speechServiceProvider);
    _items = readingAssessmentItems(widget.scene.data);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _items.isNotEmpty) unawaited(_prompt());
    });
  }

  Future<void> _prompt() async {
    widget.api.channel.interruptScript();
    final key = _current.length == 2 ? 'pairPromptAudio' : 'triplePromptAudio';
    final asset = widget.scene.data[key] as String?;
    if (asset != null) await _audio.play(asset);
  }

  Future<void> _listen() async {
    if (_listening || _result) return;
    final request = ++_request;
    widget.api.channel.interruptScript();
    InteractionAudio.stopCelebration();
    setState(() {
      _listening = true;
      _correct = false;
      _feedback = 'أسمعكم الآن…';
    });
    await _audio.stop();
    if (!mounted || request != _request) return;
    widget.api.recordAttempt();
    try {
      final result = await _speech.listenFor(_current.join(' '));
      if (!mounted || request != _request) return;
      // Score the entire transcript and its order, never a substring or the
      // single-letter service's boolean. This is ASR, not a phonetic diagnosis.
      final correct =
          fathaReadingMatchesExpected(result.recognizedWords, _current);
      widget.api.recordAnswer(correct: correct);
      setState(() {
        _attempts++;
        _listening = false;
        _correct = correct;
        _feedback = correct ? 'أحسنتم يا أبطال.' : 'حاولوا مرة أخرى';
      });
      widget.api.triggerSaleh(correct ? 'happyOnce' : 'idle');
      if (correct) {
        _correctCount++;
        unawaited(InteractionAudio.celebrate());
      }
      final asset =
          widget.scene.data[correct ? 'successAudio' : 'retryAudio'] as String?;
      if (asset != null) unawaited(_audio.play(asset));
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _listening = false;
        _feedback = 'تعذر سماعكم الآن، اضغطوا للمحاولة مرة أخرى';
      });
    }
  }

  void _advance({bool skipped = false}) {
    if (_result || (!skipped && !_correct)) return;
    _request++;
    unawaited(_audio.stop());
    unawaited(_speech.dispose());
    InteractionAudio.stopCelebration();
    if (skipped) {
      _hadSkippedItem = true;
      _retry.add(List.of(_current));
    }
    setState(() {
      _listening = false;
      _correct = false;
      _attempts = 0;
      if (_index + 1 < _items.length) {
        _index++;
      } else {
        _result = true;
      }
      _feedback = 'اضغطوا على الميكروفون ثم اقرؤوا من اليمين إلى اليسار';
    });
    if (!_result) unawaited(_prompt());
  }

  void _retrySkipped() {
    if (_retry.isEmpty) return;
    setState(() {
      _items
        ..clear()
        ..addAll(_retry);
      _retry.clear();
      _index = 0;
      _correctCount = 0;
      _attempts = 0;
      _result = false;
      _remediation = true;
      _hadSkippedItem = false;
    });
    unawaited(_prompt());
  }

  @override
  void dispose() {
    _request++;
    unawaited(_audio.stop());
    unawaited(_speech.dispose());
    InteractionAudio.stopCelebration();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(child: Text('لا توجد تدريبات قراءة في هذه الحزمة'));
    }
    return LayoutBuilder(builder: (context, size) {
      final compact = size.maxHeight < 280;
      final canSkip =
          ExperimentalRelease.skipEveryLessonSection || _attempts >= 2;
      return Column(children: [
        SizedBox(
          height: compact ? 24 : 30,
          child: Center(
              child: Text(
            _result
                ? 'نتيجة القراءة'
                : '${_remediation ? 'لنتدرب معًا • ' : ''}${_index + 1} من ${_items.length}  •  ${_current.length == 2 ? 'اقرأ الحرفين معًا' : 'اقرأ ثلاثة أحرف معًا'}',
            maxLines: 1,
            style: TextStyle(
                fontSize: compact ? 14 : 18,
                color: const Color(0xFF594574),
                fontWeight: FontWeight.w800),
          )),
        ),
        LinearProgressIndicator(
          value: _result ? 1 : _index / _items.length,
          color: const Color(0xFF4BA595),
          backgroundColor: const Color(0xFFE8DFF2),
          minHeight: 4,
          borderRadius: BorderRadius.circular(4),
        ),
        Expanded(
            child: Center(
                child: _result
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _hadSkippedItem
                              ? 'قرأتم $_correctCount من ${_items.length}\nبقيت تدريبات يمكن العودة إليها'
                              : 'أحسنتم يا أبطال!\nأكملتم قراءة ${_items.length} تدريبًا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: compact ? 20 : 26,
                              color: const Color(0xFF388575),
                              fontWeight: FontWeight.w800),
                        ))
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: Row(
                          key: ValueKey('reading-item-$_index-$_remediation'),
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _current.length; i++)
                              Flexible(
                                  child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 8),
                                child: AspectRatio(
                                  aspectRatio: .9,
                                  child: Container(
                                    key: ValueKey('reading-glyph-$i'),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xF7FFFCF7),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                          color: _correct
                                              ? const Color(0xFF56A46F)
                                              : const Color(0xFFD3C2E9),
                                          width: 2),
                                    ),
                                    child: LetterGlyph(_current[i]),
                                  ),
                                ),
                              )),
                          ],
                        ),
                      ))),
        SizedBox(
          key: const ValueKey('reading-feedback'),
          height: compact ? 30 : 40,
          child: Center(
              child: Text(
            _result ? '' : _feedback,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: compact ? 13 : 16,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: _correct
                    ? const Color(0xFF388575)
                    : _attempts > 0
                        ? const Color(0xFFBB4559)
                        : const Color(0xFF594574)),
          )),
        ),
        SizedBox(
          height: compact ? 48 : 58,
          child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_result && !_correct)
                  Semantics(
                      label: 'قراءة الحروف بالميكروفون',
                      button: true,
                      child: FeedbackTap(
                        key: const ValueKey('reading-mic'),
                        onTap: _listening ? null : _listen,
                        child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: _listening
                                    ? const Color(0xFFBB4559)
                                    : const Color(0xFF438F85),
                                shape: BoxShape.circle),
                            child: Icon(
                                _listening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.mic_rounded,
                                color: Colors.white,
                                size: 28)),
                      ))
                else if (_result && _retry.isNotEmpty)
                  Flexible(
                      child: TextButton(
                          onPressed: _retrySkipped,
                          child: const Text('تدريب ما تخطيته',
                              textAlign: TextAlign.center)))
                else
                  const SizedBox(width: 48),
                if (_result)
                  LessonActionButton(
                      label: 'تم',
                      icon: Icons.west_rounded,
                      onPressed: _hadSkippedItem
                          ? widget.api.skip
                          : widget.api.completeScene)
                else if (_correct)
                  LessonActionButton(
                      label: 'متابعة',
                      icon: Icons.west_rounded,
                      onPressed: _advance)
                else if (canSkip)
                  TextButton(
                      key: const ValueKey('reading-skip-item'),
                      onPressed: () => _advance(skipped: true),
                      child: const Text('تخطي')),
              ]),
        ),
      ]);
    });
  }
}
