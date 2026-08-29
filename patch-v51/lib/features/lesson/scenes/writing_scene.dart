import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';
import '../foundation_track.dart';
import '../writing/handwriting_validator.dart';
import '../writing/letter_trace_template.dart';
import '../writing/letter_strokes.dart';
import '../writing/writing_canvases.dart';
import '../../home/learning_journal.dart';

/// مشهد الكتابة — بالدليل أو حرًا حسب نوع المشهد وإعدادات المحتوى.
/// عدد المحاولات يأتي من [WritingConfig] في بيانات المشهد، لا من الكود.
class WritingScene extends ConsumerStatefulWidget {
  const WritingScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<WritingScene> createState() => _WritingSceneState();
}

class _WritingSceneState extends ConsumerState<WritingScene> {
  late final WritingConfig _config = WritingConfig.fromJson(
    (widget.scene.data['writing'] as Map<String, dynamic>?) ?? const {},
  );
  late final LetterTraceTemplate? _traceTemplate = LetterTraceTemplate.fromId(
    widget.scene.data['traceTemplateId'] as String?,
  );
  late final List<StrokeSpec> _strokes = _traceTemplate?.strokes ??
      StrokeSpec.listFromJson(widget.scene.data['strokes'] as List?);
  late final bool _guided = widget.scene.type == SceneType.guidedWriting;

  final _freeCanvasKey = GlobalKey<FreeWritingCanvasState>();

  int _attempt = 1;
  bool _attemptDone = false;
  bool _hasFreeInk = false;
  String? _freeValidationMessage;
  bool _freeValidationPassed = false;
  bool _validatingFree = false;
  bool _showDemo = false;

  @override
  void initState() {
    super.initState();
    _showDemo = _guided;
  }

  int get _totalAttempts =>
      widget.api.foundationTrack == FoundationTrack.writing
          ? 2
          : (_guided ? _config.guidedAttempts : _config.freeAttempts);

  void _finishAttempt() {
    widget.api.recordAttempt();
    if (_attempt >= _totalAttempts) {
      widget.api.completeScene();
    } else {
      // أوقف حركة التشجيع السابقة؛ صوت «مرة أخرى» سيحوّل صالح تلقائيًا
      // إلى talking، ثم يعود طبيعيًا عند نهاية الصوت.
      widget.api.triggerSaleh('idle');
      setState(() {
        _attempt++;
        _attemptDone = false;
        _hasFreeInk = false;
        _freeValidationMessage = null;
        _freeValidationPassed = false;
        _validatingFree = false;
      });
      _freeCanvasKey.currentState?.clear();
      final againAudio = widget.scene.data['againAudio'] as String?;
      if (againAudio != null) {
        unawaited(ref.read(audioServiceProvider).play(againAudio));
      }
    }
  }

  void _guidedCompleted() {
    if (_attemptDone) return;
    setState(() => _attemptDone = true);
    widget.api.triggerSaleh('happyOnce');
    widget.api.channel.interruptScript();
    final praiseAudio = widget.scene.data['guidedPraiseAudio'] as String?;
    if (praiseAudio != null) {
      unawaited(ref.read(audioServiceProvider).play(praiseAudio));
    }
  }

  Future<void> _validateFreeWriting() async {
    if (_validatingFree) return;
    final canvas = _freeCanvasKey.currentState;
    if (canvas == null || !canvas.hasInk) {
      setState(() {
        _freeValidationPassed = false;
        _freeValidationMessage = 'اكتب الحرف أولًا، ثم اضغط انتهيت';
      });
      return;
    }
    if (_traceTemplate == null) {
      _finishAttempt();
      return;
    }

    final isAlif = _traceTemplate.id == alifFathaVideoTemplate.id;
    final result = isAlif
        ? validateAlifFathaChildFriendly(canvas.sample)
        : validateDottedLetterWriting(canvas.sample, _traceTemplate);
    unawaited(_saveDrawing(canvas.sample, result.isValid));
    if (result.isValid) {
      const message = 'ممتاز! أحسنتم كتابة الحرف';
      setState(() {
        _validatingFree = true;
        _freeValidationPassed = true;
        _freeValidationMessage = message;
      });
      widget.api.triggerSaleh('happyOnce');
      // A fast writer must not let the still-running introduction resume and
      // replace the praise. Keep the feedback readable even on audio failure.
      widget.api.channel.interruptScript();
      final successAudio = widget.scene.data['successAudio'] as String?;
      final readable = Future<void>.delayed(const Duration(seconds: 3));
      try {
        await ref.read(audioServiceProvider).stop();
        if (mounted && successAudio != null) {
          await ref.read(audioServiceProvider).play(successAudio);
        }
      } catch (_) {
        // The visible encouragement remains usable when the audio device fails.
      }
      await readable;
      if (mounted) _finishAttempt();
      return;
    }
    widget.api.recordAttempt();
    setState(() {
      _freeValidationPassed = false;
      _freeValidationMessage = !isAlif
          ? 'حاول مرة أخرى واتبع شكل الحرف كاملًا'
          : switch (result.reason) {
              'missingParts' => 'اكتب جسم الألف، وأضف العلامة فوقه',
              'bodyShape' => 'اكتب خط الألف بشكل واضح من الأعلى إلى الأسفل',
              _ => 'حاول مرة أخرى، واكتب حرف أَ بوضوح',
            };
    });
  }

  Future<void> _saveDrawing(WritingSample sample, bool passed) async {
    final journal = ref.read(journalProvider);
    try {
      await journal.saveDrawing(
          widget.scene.data['lessonId'] as String? ?? 'alif', sample,
          passed: passed);
      if (mounted) ref.invalidate(journalDataProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر حفظ هذه المحاولة في دفتر الأعمال.')));
      }
    }
  }

  void _finishDemoPass() {
    if (!mounted) return;
    setState(() => _showDemo = false);
  }

  void _repeatGuided() {
    widget.api.recordAttempt();
    widget.api.channel.interruptScript();
    widget.api.triggerSaleh('idle');
    setState(() {
      _attemptDone = false;
    });
    final prompt = widget.scene.lines.lastOrNull?.audio;
    if (prompt != null) unawaited(ref.read(audioServiceProvider).play(prompt));
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? 'ث';
    final compact = MediaQuery.sizeOf(context).height < 760;
    final showHeader = _showDemo;
    final actionHeight = compact ? 72.0 : 80.0;
    return Column(
      children: [
        if (showHeader)
          SizedBox(
            height: compact ? 36 : 52,
            child: Center(
              child: Text(
                _showDemo ? 'شاهد كيف نكتب الحرف' : 'اكتب الحرف بنفسك',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subtitle.copyWith(
                  fontSize: compact ? 18 : null,
                ),
              ),
            ),
          ),
        SizedBox(height: showHeader ? AppSpacing.sm : 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.letterGuide, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (_showDemo)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: WatchLetterAnimation(
                      key: const ValueKey('writing-demo-once'),
                      letter: letter,
                      strokes: _strokes,
                      traceTemplate: _traceTemplate,
                      duration: Duration(
                          milliseconds:
                              (widget.scene.data['demoPassDurationMs'] as num?)
                                      ?.toInt() ??
                                  5200),
                      onFinished: _finishDemoPass,
                    ),
                  )
                else if (_guided)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: _attemptDone
                        ? _CompletedLetter(
                            letter: letter,
                            strokes: _strokes,
                            traceTemplate: _traceTemplate,
                          )
                        : GuidedTracingCanvas(
                            key: ValueKey('trace_$_attempt'),
                            letter: letter,
                            strokes: _strokes,
                            traceTemplate: _traceTemplate,
                            onStrokeCompleted: (_) {},
                            onAllCompleted: _guidedCompleted,
                          ),
                  )
                else
                  AbsorbPointer(
                      absorbing: _validatingFree,
                      child: FreeWritingCanvas(
                        key: _freeCanvasKey,
                        traceTemplate: _traceTemplate,
                        onInkChanged: (hasInk) {
                          if (!_validatingFree &&
                              (_hasFreeInk != hasInk ||
                                  _freeValidationMessage != null)) {
                            setState(() {
                              _hasFreeInk = hasInk;
                              _freeValidationMessage = null;
                              _freeValidationPassed = false;
                            });
                          }
                        },
                      )),
                if (!_guided &&
                    _freeValidationMessage != null &&
                    !_freeValidationPassed)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: IgnorePointer(
                      child: Container(
                        key: const ValueKey('free-writing-feedback-panel'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _freeValidationPassed
                                  ? AppColors.successDark
                                  : AppColors.danger),
                          boxShadow: const [
                            BoxShadow(color: Color(0x18000000), blurRadius: 8)
                          ],
                        ),
                        child: Text(_freeValidationMessage!,
                            key: const ValueKey(
                                'free-writing-validation-message'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: AppTypography.body.copyWith(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: _freeValidationPassed
                                    ? AppColors.successDark
                                    : AppColors.danger)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? 4 : AppSpacing.sm),
        SizedBox(
          height: actionHeight,
          child: !_guided && _freeValidationPassed
              ? Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    key: const ValueKey('free-writing-feedback-panel'),
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.successDark),
                    ),
                    child: Text(
                      _freeValidationMessage!,
                      key: const ValueKey('free-writing-validation-message'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.body.copyWith(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successDark,
                      ),
                    ),
                  ),
                )
              : Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!_guided) ...[
                      Flexible(
                          child: LessonActionButton(
                        label: 'مسح',
                        icon: Icons.refresh_rounded,
                        onPressed: () {
                          if (_validatingFree) return;
                          _freeCanvasKey.currentState?.clear();
                          setState(() {
                            _hasFreeInk = false;
                            _freeValidationMessage = null;
                            _freeValidationPassed = false;
                          });
                        },
                      )),
                      Flexible(
                          child: LessonActionButton(
                        label: _hasFreeInk ? 'انتهيت' : 'اكتب الحرف أولًا',
                        icon: Icons.check_rounded,
                        onPressed: _validatingFree
                            ? null
                            : (_hasFreeInk
                                ? () {
                                    unawaited(_validateFreeWriting());
                                  }
                                : null),
                      )),
                    ] else ...[
                      if (!_showDemo && _attemptDone) ...[
                        Flexible(
                            child: LessonActionButton(
                          label: 'تكرار الكتابة بالدليل',
                          labelMaxLines: 2,
                          icon: Icons.replay_rounded,
                          onPressed: _repeatGuided,
                        )),
                        Flexible(
                            child: LessonActionButton(
                          label: 'فهمت طريقة الكتابة',
                          labelMaxLines: 2,
                          icon: Icons.check_rounded,
                          onPressed: _finishAttempt,
                        )),
                      ] else ...[
                        const Spacer(),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// عرض الحرف مكتملًا باللون الأخضر بعد نجاح التتبع.
class _CompletedLetter extends StatelessWidget {
  const _CompletedLetter({
    required this.letter,
    required this.strokes,
    this.traceTemplate,
  });

  final String letter;
  final List<StrokeSpec> strokes;
  final LetterTraceTemplate? traceTemplate;

  @override
  Widget build(BuildContext context) {
    return CompletedTracingCanvas(
      key: const ValueKey('completed-letter-only'),
      letter: letter,
      strokes: strokes,
      traceTemplate: traceTemplate,
      glow: true,
    );
  }
}
