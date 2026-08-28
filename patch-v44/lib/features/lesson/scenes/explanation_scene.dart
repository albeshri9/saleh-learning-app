import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/design/widgets/touch_feedback.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/letter_glyph.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/app_card.dart';
import '../../../domain/models/lesson.dart';
import '../../../domain/models/timeline_event.dart';
import '../scene_registry.dart';
import '../widgets/lesson_letter_size.dart';

/// مشهد الشرح — إثبات التزامن الكامل بين كلام صالح والمحتوى:
/// «انظر» → يظهر الحرف ويشير صالح، «ثاء» → ينبض الحرف،
/// «انظر كيف نكتب» → يُرسم المسار تدريجيًا، ثم يظهر مثال الكلمة.
class ExplanationScene extends ConsumerStatefulWidget {
  const ExplanationScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<ExplanationScene> createState() => _ExplanationSceneState();
}

class _ExplanationSceneState extends ConsumerState<ExplanationScene>
    with TickerProviderStateMixin {
  StreamSubscription<TimelineEvent>? _sub;

  // عناصر الشرح الأساسية ظاهرة من البداية مثل نموذج الواجهة المرجعي،
  // بينما تبقى أحداث الخط الزمني مسؤولة عن النبض والرسم.
  bool _letterVisible = true;
  bool _exampleVisible = false;
  bool _exampleHighlight = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppDurations.pulse,
  );

  @override
  void initState() {
    super.initState();
    _sub = widget.api.channel.events.listen(_onEvent);
  }

  void _onEvent(TimelineEvent event) {
    if (!mounted) return;
    switch (event.action) {
      case TimelineAction.show:
        setState(() {
          if (event.target == 'letter') _letterVisible = true;
          if (event.target == 'example') _exampleVisible = true;
        });
        break;
      case TimelineAction.hide:
        setState(() {
          if (event.target == 'letter') _letterVisible = false;
          if (event.target == 'example') _exampleVisible = false;
        });
        break;
      case TimelineAction.pulse:
        _pulse.forward(from: 0).then((_) => _pulse.reverse());
        break;
      case TimelineAction.highlight:
        setState(() => _exampleHighlight = true);
        break;
      case TimelineAction.drawPath:
        _pulse.forward(from: 0).then((_) => _pulse.reverse());
        break;
      default:
        break;
    }
  }

  void _replayExplanation() {
    _pulse.reset();
    setState(() {
      _letterVisible = true;
      _exampleVisible = false;
      _exampleHighlight = false;
    });
    widget.api.triggerSaleh('pointing');
    widget.api.replayScene();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.scene.data['letter'] as String? ?? '';
    final compact = MediaQuery.sizeOf(context).height < 760;
    final example =
        (widget.scene.data['example'] as Map<String, dynamic>?) ?? const {};
    final exampleImage = example['imageAsset'] as String?;

    return Column(children: [
      Expanded(child: LayoutBuilder(builder: (context, box) {
        final glyphSize = lessonLetterDisplaySize(context);
        return Stack(children: [
          AnimatedAlign(
              duration: AppDurations.normal,
              alignment:
                  _exampleVisible ? const Alignment(.85, 0) : Alignment.center,
              child: SizedBox(
                  width: glyphSize.width,
                  height: glyphSize.height,
                  child: AnimatedOpacity(
                      duration: AppDurations.normal,
                      opacity: _letterVisible ? 1 : 0,
                      child: ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.10).animate(_pulse),
                          child: ValueListenableBuilder<bool>(
                              valueListenable:
                                  widget.api.channel.scriptFinished,
                              builder: (context, finished, _) => FeedbackTap(
                                    onTap: !finished
                                        ? null
                                        : () async {
                                            if (InteractionEffects.animate(
                                                context)) {
                                              _pulse.forward(from: 0).then((_) {
                                                if (mounted) _pulse.reverse();
                                              });
                                            }
                                            await ref
                                                .read(audioServiceProvider)
                                                .play(widget.scene
                                                            .data['letterAudio']
                                                        as String? ??
                                                    'assets/audio/alif/explain_2.mp3');
                                          },
                                    child: LetterGlyph(letter,
                                        key: const ValueKey(
                                            'explanation-letter')),
                                  )))))),
          Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                  width: box.maxWidth * .48,
                  height: box.maxHeight * .9,
                  child: IgnorePointer(
                      ignoring: !_exampleVisible,
                      child: AnimatedOpacity(
                          duration: AppDurations.normal,
                          opacity: _exampleVisible ? 1 : 0,
                          child: AppCard(
                              padding: const EdgeInsets.all(8),
                              borderColor: _exampleHighlight
                                  ? AppColors.highlight
                                  : null,
                              child: Column(children: [
                                Expanded(
                                    child: exampleImage == null
                                        ? const SizedBox.shrink()
                                        : Image.asset(exampleImage,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high)),
                                SizedBox(
                                    height: compact ? 36 : 50,
                                    width: double.infinity,
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: _HighlightedWord(
                                            word: example['word'] as String? ??
                                                '',
                                            prefix: example['highlightPrefix']
                                                    as String? ??
                                                '',
                                            highlighted: _exampleHighlight,
                                            compact: compact))),
                              ])))))),
        ]);
      })),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        LessonActionButton(
            label: 'إعادة الشرح',
            icon: Icons.replay_rounded,
            onPressed: _replayExplanation),
        SizedBox(width: compact ? 4 : AppSpacing.md),
        LessonActionButton(
            label: 'فهمت!',
            icon: Icons.thumb_up_alt_rounded,
            onPressed: widget.api.completeScene),
      ]),
    ]);
  }
}

/// كلمة يُبرز أولها (حرف الدرس) بلون مختلف — مثل «ثوم».
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
    required this.word,
    required this.prefix,
    required this.highlighted,
    required this.compact,
  });

  final String word;
  final String prefix;
  final bool highlighted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rest = word.startsWith(prefix) && prefix.isNotEmpty
        ? word.substring(prefix.length)
        : word;
    return Text.rich(
      TextSpan(
        children: [
          if (word.startsWith(prefix) && prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: AppTypography.display.copyWith(
                fontSize: compact ? 34 : 48,
                color: highlighted ? AppColors.letterPrimary : AppColors.ink,
              ),
            ),
          TextSpan(
            text: rest,
            style: AppTypography.display.copyWith(fontSize: compact ? 34 : 48),
          ),
        ],
      ),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
    );
  }
}
