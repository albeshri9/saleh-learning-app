import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/design/widgets/touch_feedback.dart';
import '../../../core/design/widgets/letter_glyph.dart';
import '../../../services/speech/speech_service.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../scene_registry.dart';
import '../widgets/lesson_letter_size.dart';

enum _MicState { idle, listening, correct, tryAgain }

/// تدريب النطق: الميكروفون يعمل هنا فقط (وليس في الشرح).
/// التقييم عبر التعرف الحقيقي على الكلام ثم تغذية راجعة من صالح.
class PronunciationScene extends ConsumerStatefulWidget {
  const PronunciationScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<PronunciationScene> createState() => _PronunciationSceneState();
}

class _PronunciationSceneState extends ConsumerState<PronunciationScene> {
  _MicState _state = _MicState.idle;
  bool _skipping = false;

  void _skipListening() {
    if (_skipping) return;
    _skipping = true;
    // الانتقال فوري من أول ضغطة، والتنظيف يتم في الخلفية.
    ref.read(audioServiceProvider).stop().ignore();
    ref.read(speechServiceProvider).dispose().ignore();
    widget.api.completeScene();
  }

  Future<void> _playFeedback(bool correct) async {
    final key = correct ? 'successAudio' : 'retryAudio';
    final asset = widget.scene.data[key] as String?;
    if (asset != null) await ref.read(audioServiceProvider).play(asset);
  }

  Future<void> _listen() async {
    if (_state == _MicState.listening) return;
    await ref.read(audioServiceProvider).stop();
    if (!mounted) return;
    setState(() => _state = _MicState.listening);
    widget.api.recordAttempt();
    final expected = widget.scene.data['expected'] as String? ?? '';
    final result = await ref.read(speechServiceProvider).listenFor(expected);
    if (!mounted) return;
    setState(
      () => _state = result.correct ? _MicState.correct : _MicState.tryAgain,
    );
    widget.api.recordAnswer(correct: result.correct);
    if (result.correct) RewardStars.fly(context);
    widget.api.triggerSaleh(result.correct ? 'happyOnce' : 'surprised');
    await _playFeedback(result.correct);
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? '';
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.clamp(160.0, double.infinity);
        final glyphSize = lessonLetterDisplaySize(context);
        final glyphHeight = glyphSize.height;
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: glyphSize.width,
                      height: glyphHeight,
                      child: ValueListenableBuilder<bool>(
                        valueListenable: widget.api.channel.scriptFinished,
                        builder: (context, finished, _) => FeedbackTap(
                          onTap: !finished || _state == _MicState.listening
                              ? null
                              : () => ref.read(audioServiceProvider).play(
                                  widget.scene.data['letterAudio'] as String? ??
                                      'assets/audio/alif/explain_2.mp3'),
                          child: LetterGlyph(letter,
                              key: const ValueKey('pronunciation-letter')),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _state == _MicState.correct
                          ? 'أحسنت، نطقك رائع!'
                          : _state == _MicState.tryAgain
                              ? 'لنحاول مرة أخرى!'
                              : _state == _MicState.listening
                                  ? 'أسمعك الآن... انطق $letter'
                                  : 'اضغط وانطق $letter',
                      textAlign: TextAlign.center,
                      style: AppTypography.subtitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_state != _MicState.correct)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MicButton(
                              soundLevel: ref.read(speechServiceProvider)
                                      is DeviceSpeechService
                                  ? (ref.read(speechServiceProvider)
                                          as DeviceSpeechService)
                                      .soundLevel
                                  : null,
                              listening: _state == _MicState.listening,
                              onTap: _state == _MicState.listening
                                  ? null
                                  : _listen,
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        LessonActionButton(
                          label:
                              _state == _MicState.correct ? 'متابعة' : 'تخطي',
                          icon: Icons.west_rounded,
                          onPressed: _state == _MicState.correct
                              ? widget.api.completeScene
                              : _skipListening,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton(
      {required this.listening, required this.onTap, this.soundLevel});
  final ValueNotifier<double>? soundLevel;

  final bool listening;
  final VoidCallback? onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  final _silent = ValueNotifier<double>(0);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.9,
    upperBound: 1.1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _silent.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    final size = compact ? 60.0 : 76.0;
    return ScaleTransition(
      scale: widget.listening && InteractionEffects.animate(context)
          ? _c
          : const AlwaysStoppedAnimation(1),
      child: Material(
        color: widget.listening ? AppColors.danger : AppColors.success,
        shape: const CircleBorder(),
        elevation: 6,
        child: FeedbackTap(
          customBorder: const CircleBorder(),
          onTap: widget.onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: ValueListenableBuilder<double>(
              valueListenable: widget.soundLevel ?? _silent,
              builder: (context, level, _) => AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: widget.listening
                            ? Colors.white70
                            : Colors.transparent,
                        width: widget.listening &&
                                InteractionEffects.animate(context)
                            ? 2 + level * 6
                            : 2)),
                child: Icon(
                  widget.listening
                      ? Icons.graphic_eq_rounded
                      : Icons.mic_rounded,
                  color: Colors.white,
                  size: compact ? 38 : 56,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
