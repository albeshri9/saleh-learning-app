import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/design/widgets/touch_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_typography.dart';
import '../../core/design/widgets/app_card.dart';
import '../../core/design/widgets/classroom_background.dart';
import '../../domain/models/lesson.dart';
import '../../domain/models/timeline_event.dart';
import '../character/video/saleh_video_renderer.dart';
import 'character/saleh_character_controller.dart';
import 'lesson_controller.dart';
import '../home/profile_editor.dart';
import '../../core/design/widgets/toy_icon.dart';
import 'scene_registry.dart';
import 'foundation_track.dart';
import 'widgets/saleh_character.dart' show SalehPose;
import 'widgets/saleh_script_player.dart';

/// الأنشطة التفاعلية تُكمل نفسها من داخل اللوحة فقط. إبقاء زر «التالي»
/// العام فعالًا هنا كان يسمح بتجاوز الكتابة الحرة قبل أن يكتب الطفل.
bool lessonSceneAllowsGlobalNext(SceneType type) => switch (type) {
      SceneType.review ||
      SceneType.pronunciation ||
      SceneType.guidedWriting ||
      SceneType.freeWriting ||
      SceneType.multipleChoice ||
      SceneType.assessment ||
      SceneType.checkpoint ||
      SceneType.success =>
        false,
      _ => true,
    };

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.lessonId,
    this.initialScene,
    this.foundationTrack = FoundationTrack.readWrite,
  });

  final String lessonId;
  final int? initialScene;
  final FoundationTrack foundationTrack;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  SceneChannel? _channel;
  StreamSubscription<TimelineEvent>? _salehEvents;
  String? _channelSceneId;
  bool _jumpedToInitial = false;
  int? _pendingTrackJump;
  int _replayGeneration = 0;
  late final SalehCharacterController _saleh;
  Timer? _salehReactionTimer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _saleh = SalehCharacterController(
      audioPlaying: ref.read(audioServiceProvider).playing,
    )..addListener(_onSalehChanged);
  }

  void _onSalehChanged() {
    if (!mounted || _closing) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_closing) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _triggerSaleh(String action) {
    if (_closing) return;
    if (action == 'farewell') {
      _playSalehFor(SalehPose.waving, const Duration(milliseconds: 3000));
      return;
    }
    if (action == 'narratingStart' || action == 'narratingStop') {
      _saleh.setNarrating(action == 'narratingStart');
      return;
    }
    if (action == 'happyOnce' || action == 'encouragingOnce') {
      _playSalehOnce(SalehPose.encouraging);
      return;
    }
    if (action == 'encouragingThenWave') {
      _playSalehOnce(SalehPose.encouraging);
      return;
    }
    if (action == 'celebratingThenWave') {
      _playSalehOnce(SalehPose.celebrating);
      return;
    }
    if (action == 'pointThenTalk') {
      _playSalehFor(
        SalehPose.pointing,
        const Duration(milliseconds: 1450),
      );
      return;
    }
    if (action == 'greetThenTalk') {
      _playSalehFor(
        SalehPose.waving,
        const Duration(milliseconds: 900),
      );
      return;
    }
    _salehReactionTimer?.cancel();
    _salehReactionTimer = null;
    final pose = switch (action) {
      'pointing' || 'point' => SalehPose.pointing,
      'thinking' => SalehPose.thinking,
      'waving' || 'greeting' => SalehPose.waving,
      'happy' || 'encouraging' => SalehPose.encouraging,
      'celebrating' || 'celebrate' => SalehPose.celebrating,
      // Listening intentionally reuses the approved Idle clip.
      'idle' || 'listening' || 'surprised' => SalehPose.idle,
      _ => SalehPose.idle,
    };
    if (pose == SalehPose.encouraging ||
        pose == SalehPose.celebrating ||
        pose == SalehPose.waving ||
        pose == SalehPose.pointing) {
      _playSalehFor(pose, const Duration(milliseconds: 1100));
    } else {
      _saleh.endGesture();
      _saleh.setPose(pose);
    }
  }

  /// تشجيع قصير، ثم الكلام إن استمر التعليق الصوتي.
  void _playSalehOnce(SalehPose pose) {
    _playSalehFor(pose, const Duration(milliseconds: 1200));
  }

  /// أداء افتتاحي قصير ثم تحرير الحالة إلى idle. إن كان التعليق الصوتي
  /// مستمرًا يتحول صالح فورًا إلى talking؛ وإن انتهى يعود طبيعيًا.
  void _playSalehFor(
    SalehPose pose,
    Duration duration, {
    SalehPose after = SalehPose.idle,
  }) {
    _salehReactionTimer?.cancel();
    _saleh.setPose(SalehPose.idle);
    _saleh.beginGesture(pose);
    _salehReactionTimer = Timer(duration, () {
      if (!mounted) return;
      _saleh.endGesture();
      _saleh.setPose(after);
      _salehReactionTimer = null;
    });
  }

  void _replayScene() {
    final channel = _channel;
    if (channel == null) return;
    channel.scriptFinished.value = false;
    channel.scriptInterrupted.value = false;
    _saleh.reset();
    setState(() => _replayGeneration++);
  }

  SceneChannel _channelFor(Scene scene) {
    if (_channelSceneId != scene.id) {
      _salehReactionTimer?.cancel();
      _salehReactionTimer = null;
      _salehEvents?.cancel();
      _channel?.dispose();
      _channel = SceneChannel();
      _channelSceneId = scene.id;
      _saleh.reset();
      _salehEvents = _channel!.events.listen(_onTimelineEvent);
      final entryPose = switch (scene.type) {
        SceneType.welcome => SalehPose.waving,
        SceneType.explanation => SalehPose.pointing,
        SceneType.multipleChoice || SceneType.assessment => SalehPose.thinking,
        SceneType.checkpoint => SalehPose.thinking,
        // تبدأ النهاية بقفزة الفرح فور دخولها، ثم يحوّلها حدث التعليق
        // إلى التلويح المتكرر بعد دورة واحدة.
        SceneType.success => SalehPose.celebrating,
        _ => SalehPose.idle,
      };
      // تبدأ الحركة الدلالية الصحيحة مع المشهد نفسه، ولا تعتمد على وصول
      // مؤقت متأخر من سطر الكلام كي تظهر الإشارة أو التحية.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _channelSceneId == scene.id) {
          if (entryPose == SalehPose.waving ||
              entryPose == SalehPose.pointing ||
              entryPose == SalehPose.celebrating) {
            _playSalehFor(entryPose, const Duration(milliseconds: 900));
          } else {
            _saleh.setPose(entryPose);
          }
        }
      });
    }
    return _channel!;
  }

  void _onTimelineEvent(TimelineEvent event) {
    switch (event.action) {
      case TimelineAction.salehPointAt:
        _triggerSaleh('pointThenTalk');
        break;
      case TimelineAction.salehCelebrate:
        _triggerSaleh('celebrating');
        break;
      case TimelineAction.playAnimation:
        final name = event.params['name'];
        if (name == 'farewell') {
          _triggerSaleh('farewell');
          break;
        }
        _triggerSaleh(
          name == 'encourageThenWave'
              ? 'encouragingThenWave'
              : name == 'celebrateThenWave'
                  ? 'celebratingThenWave'
                  : name == 'greetThenTalk'
                      ? 'greetThenTalk'
                      : name == 'wave'
                          ? 'greeting'
                          : 'idle',
        );
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _closing = true;
    _salehReactionTimer?.cancel();
    _salehEvents?.cancel();
    _channel?.dispose();
    _saleh
      ..removeListener(_onSalehChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(childProfileProvider);
    final stateAsync = ref.watch(lessonControllerProvider(widget.lessonId));
    final controller = ref.read(
      lessonControllerProvider(widget.lessonId).notifier,
    );

    return Scaffold(
      body: ClassroomBackground(
        child: SafeArea(
          child: stateAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('تعذر تحميل الدرس\n$error')),
            data: (state) {
              final profile = profileAsync.valueOrNull;
              if (profile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final allowed = lessonSceneIndicesForTrack(
                state.lesson,
                widget.foundationTrack,
              );
              if (allowed.isEmpty) {
                return const Center(child: Text('لا توجد أنشطة في هذا المسار'));
              }
              if (_pendingTrackJump == state.sceneIndex) {
                _pendingTrackJump = null;
              }
              if (!_jumpedToInitial) {
                _jumpedToInitial = true;
                final requested = widget.initialScene;
                final target = requested != null && allowed.contains(requested)
                    ? requested
                    : allowed.contains(state.sceneIndex)
                        ? state.sceneIndex
                        : widget.foundationTrack == FoundationTrack.writing
                            ? allowed.first
                            : allowed.firstWhere(
                                (index) => index > state.sceneIndex,
                                orElse: () => allowed.first,
                              );
                if (target != state.sceneIndex) {
                  _pendingTrackJump = target;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => controller.jumpToScene(target),
                  );
                  return const Center(child: CircularProgressIndicator());
                }
              }

              if (!allowed.contains(state.sceneIndex)) {
                final target = allowed.firstWhere(
                  (index) => index > state.sceneIndex,
                  orElse: () => allowed.first,
                );
                if (_pendingTrackJump != target) {
                  _pendingTrackJump = target;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => controller.jumpToScene(target),
                  );
                }
                return const Center(child: CircularProgressIndicator());
              }

              final scene = state.currentScene;
              final channel = _channelFor(scene);
              final api = SceneApi(
                profile: profile,
                channel: channel,
                completeScene: controller.completeScene,
                skipScene: () => controller.completeScene(skipped: true),
                recordAttempt: controller.recordAttempt,
                recordAnswer: ({required bool correct}) =>
                    controller.recordAnswer(correct: correct),
                triggerSaleh: _triggerSaleh,
                replayScene: _replayScene,
                replayGeneration: _replayGeneration,
                foundationTrack: widget.foundationTrack,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 1100 ||
                      constraints.maxHeight < 760) {
                    return _CompactLesson(
                      state: state,
                      scene: scene,
                      api: api,
                      onExit: () => _exitLesson(context),
                      salehPose: _saleh.pose,
                      onSalehCompleted: _saleh.notifyPoseCompleted,
                    );
                  }
                  return _DesktopLesson(
                    state: state,
                    scene: scene,
                    api: api,
                    onExit: () => _exitLesson(context),
                    onSkip: scene.canSkip
                        ? () => controller.completeScene(skipped: true)
                        : null,
                    salehPose: _saleh.pose,
                    onSalehCompleted: _saleh.notifyPoseCompleted,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

void _exitLesson(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

class _DesktopLesson extends StatelessWidget {
  const _DesktopLesson({
    required this.state,
    required this.scene,
    required this.api,
    required this.onExit,
    required this.onSkip,
    required this.salehPose,
    required this.onSalehCompleted,
  });

  final LessonRunState state;
  final Scene scene;
  final SceneApi api;
  final VoidCallback onExit;
  final VoidCallback? onSkip;
  final SalehPose salehPose;
  final ValueChanged<SalehPose> onSalehCompleted;

  @override
  Widget build(BuildContext context) => _CompactLesson(
      state: state,
      scene: scene,
      api: api,
      onExit: onExit,
      salehPose: salehPose,
      onSalehCompleted: onSalehCompleted);
}

class _CompactLesson extends StatelessWidget {
  const _CompactLesson(
      {required this.state,
      required this.scene,
      required this.api,
      required this.onExit,
      required this.salehPose,
      required this.onSalehCompleted});
  final LessonRunState state;
  final Scene scene;
  final SceneApi api;
  final VoidCallback onExit;
  final SalehPose salehPose;
  final ValueChanged<SalehPose> onSalehCompleted;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final characterWidth = (bounds.maxWidth * .20).clamp(112.0, 190.0);
        final stepsWidth = (bounds.maxWidth * .13).clamp(100.0, 136.0);
        const headerHeight = 48.0;
        const gap = 6.0;
        if (scene.type == SceneType.checkpoint) {
          return _checkpointLayout(
            bounds,
            characterWidth,
            headerHeight,
            gap,
          );
        }
        return Padding(
            padding: const EdgeInsets.fromLTRB(gap, 4, gap, 4),
            child: Column(children: [
              SizedBox(
                  height: headerHeight,
                  child:
                      _CompactTopBar(state: state, api: api, onExit: onExit)),
              const SizedBox(height: gap),
              Expanded(
                  child: Stack(children: [
                Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: characterWidth + gap),
                      Expanded(
                          child: SizedBox(
                              key: const ValueKey('lesson-board'),
                              child: _LessonBoard(
                                  title: scene.title ?? state.lesson.title,
                                  compact: true,
                                  revealOnWelcome:
                                      scene.type == SceneType.welcome,
                                  child: SceneRegistry.build(scene, api)))),
                      const SizedBox(width: gap),
                      SizedBox(
                          key: const ValueKey('lesson-steps-right'),
                          width: stepsWidth,
                          child: Padding(
                              padding: EdgeInsets.only(
                                  bottom: _lessonActionClearance(context)),
                              child: _StepsRail(
                                  scenes: state.lesson.scenes,
                                  currentIndex: state.sceneIndex,
                                  foundationTrack: api.foundationTrack,
                                  compact: true))),
                    ]),
                Positioned(
                    left: 0,
                    bottom: 0,
                    width: characterWidth * 1.35,
                    child: Transform.translate(
                        offset:
                            Offset(0, (bounds.maxHeight - headerHeight) * .075),
                        child: IgnorePointer(
                            child: SalehVideoRenderer(
                                key: const ValueKey('lesson-saleh'),
                                pose: salehPose,
                                width: characterWidth * 1.35,
                                height: bounds.maxHeight - headerHeight - gap,
                                onCompleted: onSalehCompleted)))),
                _HiddenScriptPlayer(scene: scene, api: api, compact: true),
              ])),
            ]));
      });

  Widget _checkpointLayout(
    BoxConstraints bounds,
    double characterWidth,
    double headerHeight,
    double gap,
  ) =>
      Padding(
        key: const ValueKey('checkpoint-layout'),
        padding: EdgeInsets.fromLTRB(gap, 4, gap, 4),
        child: Column(children: [
          SizedBox(
            height: headerHeight,
            child: _CompactTopBar(state: state, api: api, onExit: onExit),
          ),
          SizedBox(height: gap),
          Expanded(
            child: Stack(children: [
              Row(
                textDirection: TextDirection.ltr,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: characterWidth + gap),
                  Expanded(
                    child: SizedBox(
                      key: const ValueKey('lesson-board'),
                      child: _LessonBoard(
                        title: scene.title ?? 'الاختبار المرحلي',
                        compact: true,
                        extendToBottom: true,
                        child: SceneRegistry.build(scene, api),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                bottom: 0,
                width: characterWidth * 1.35,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    (bounds.maxHeight - headerHeight) * .075,
                  ),
                  child: IgnorePointer(
                    child: SalehVideoRenderer(
                      key: const ValueKey('lesson-saleh'),
                      pose: salehPose,
                      width: characterWidth * 1.35,
                      height: bounds.maxHeight - headerHeight - gap,
                      onCompleted: onSalehCompleted,
                    ),
                  ),
                ),
              ),
              _HiddenScriptPlayer(scene: scene, api: api, compact: true),
            ]),
          ),
        ]),
      );
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar(
      {required this.state, required this.api, required this.onExit});
  final LessonRunState state;
  final SceneApi api;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) =>
      Row(textDirection: TextDirection.rtl, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xF5FFFDF7),
                borderRadius: BorderRadius.circular(18)),
            child: Row(textDirection: TextDirection.rtl, children: [
              CareerAvatar(
                  key: const ValueKey('lesson-child-avatar'),
                  index: careerIndex(api.profile.avatar, api.profile.gender),
                  size: 38),
              const SizedBox(width: 7),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(api.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: profileInk))),
            ])),
        const SizedBox(width: 8),
        Expanded(
            child: Text(state.lesson.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: profileInk))),
        _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: RewardStars(count: state.correctAnswers)),
        const SizedBox(width: 6),
        IconButton(
            tooltip: 'الرئيسية',
            onPressed: onExit,
            icon: const ToyIcon(Toy.home, size: 40)),
      ]);
}

class _LessonBoard extends StatefulWidget {
  const _LessonBoard({
    required this.title,
    required this.child,
    this.compact = false,
    this.revealOnWelcome = false,
    this.extendToBottom = false,
  });

  final String title;
  final Widget child;
  final bool compact;
  final bool revealOnWelcome;
  final bool extendToBottom;

  @override
  State<_LessonBoard> createState() => _LessonBoardState();
}

class _LessonBoardState extends State<_LessonBoard> {
  Timer? _revealTimer;
  late bool _visible = !widget.revealOnWelcome;

  @override
  void initState() {
    super.initState();
    _scheduleRevealIfNeeded();
  }

  @override
  void didUpdateWidget(_LessonBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealOnWelcome != widget.revealOnWelcome) {
      _revealTimer?.cancel();
      _visible = !widget.revealOnWelcome;
      _scheduleRevealIfNeeded();
    }
  }

  void _scheduleRevealIfNeeded() {
    if (!widget.revealOnWelcome) return;
    _revealTimer = Timer(const Duration(milliseconds: 720), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outerPadding = widget.compact ? 7.0 : 13.0;
    final contentTop = outerPadding + (widget.compact ? 30.0 : 42.0);
    final edgeClearance =
        widget.extendToBottom ? 0.0 : _lessonActionClearance(context);
    final board = Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // تنتهي السبورة قبل نهاية صندوقها بمقدار نصف ارتفاع الزر. أما محتوى
        // المشهد فيمتد إلى نهاية الصندوق؛ وهكذا يقع مركز كل زر فوق الحد
        // السفلي فعلًا، مع بقاء كامل مساحة الزر قابلة للمس من أول ضغطة.
        Positioned.fill(
          bottom: edgeClearance,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4EA7A3),
              borderRadius: BorderRadius.circular(widget.compact ? 28 : 42),
              border: Border.all(color: const Color(0xFF2F817F), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D684C37),
                  offset: Offset(0, 12),
                  blurRadius: 24,
                ),
              ],
            ),
            padding: EdgeInsets.all(outerPadding),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  // شفافية خفيفة تكشف دفء الخلفية من دون التأثير في
                  // السبورات البيضاء الداخلية التي تبقى معتمة تمامًا.
                  colors: [Color(0xF4FFF8E8), Color(0xF4FFE8BF)],
                ),
                borderRadius: BorderRadius.circular(widget.compact ? 21 : 30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x305A432F),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: contentTop,
          left: outerPadding + 12,
          right: outerPadding + 12,
          bottom: 0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: widget.compact ? -23 : -29,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: widget.compact ? 4 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EA),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadow, blurRadius: 10),
                      ],
                    ),
                    child: Text(
                      widget.title,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: widget.compact ? 15 : null,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: widget.child),
            ],
          ),
        ),
      ],
    );

    return AnimatedSlide(
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, .25),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutBack,
        scale: _visible ? 1 : .84,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          opacity: _visible ? 1 : 0,
          child: IgnorePointer(ignoring: !_visible, child: board),
        ),
      ),
    );
  }
}

double _lessonActionClearance(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 760 ? 36 : 40;

/// يبقي التعليق الصوتي وأحداث التزامن فعّالة من دون شغل مساحة مرئية.
/// أزيل شريط النص السفلي بناءً على التصميم المعتمد، لكن المشغّل يظل مركّبًا
/// حتى لا تتوقف أصوات الترحيب والشرح أو حركات صالح المرتبطة بها.
class _HiddenScriptPlayer extends StatelessWidget {
  const _HiddenScriptPlayer({
    required this.scene,
    required this.api,
    this.compact = false,
  });

  final Scene scene;
  final SceneApi api;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: compact ? 420 : 640,
        child: SalehScriptPlayer(
          key: ValueKey('script_${scene.id}_${api.replayGeneration}'),
          lines: scene.lines,
          stopSignal: api.channel.scriptInterrupted,
          profile: api.profile,
          tailDirection: SpeechTailDirection.start,
          compact: compact,
          onNarratingChanged: (narrating) => api.triggerSaleh(
            narrating ? 'narratingStart' : 'narratingStop',
          ),
          onEvent: api.channel.emit,
          onFinished: api.channel.markFinished,
        ),
      ),
    );
  }
}

int lessonMilestone(SceneType type) => switch (type) {
      SceneType.pronunciation => 1,
      SceneType.guidedWriting || SceneType.freeWriting => 2,
      SceneType.multipleChoice ||
      SceneType.assessment ||
      SceneType.checkpoint ||
      SceneType.success =>
        3,
      _ => 0,
    };

class _StepsRail extends StatelessWidget {
  const _StepsRail(
      {required this.scenes,
      required this.currentIndex,
      required this.foundationTrack,
      this.compact = false});
  final List<Scene> scenes;
  final int currentIndex;
  final FoundationTrack foundationTrack;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final active = foundationTrack == FoundationTrack.writing
        ? 2
        : lessonMilestone(scenes[currentIndex].type);
    final milestones = switch (foundationTrack) {
      FoundationTrack.readWrite => const [0, 1, 2, 3],
      FoundationTrack.reading => const [0, 1, 3],
      FoundationTrack.writing => const [2],
    };
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Column(children: [
              for (final i in milestones) ...[
                if (i != milestones.first) const SizedBox(height: 8),
                Expanded(
                  child: Semantics(
                      label: '${[
                        'أسمع',
                        'أنطق',
                        'أكتب',
                        'ألعب'
                      ][i]}${i == active ? '، المرحلة الحالية' : ''}',
                      child: Container(
                          key: ValueKey('milestone-$i'),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                              color: i == active
                                  ? const Color(0xFFE6D9F5)
                                  : const Color(0xEDFFFDF9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: i == active
                                      ? const Color(0xFF7960AD)
                                      : const Color(0xFFDCD4E6),
                                  width: i == active ? 2 : 1)),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              textDirection: TextDirection.rtl,
                              children: [
                                ToyIcon(
                                    [
                                      Toy.book,
                                      Toy.mic,
                                      Toy.pencil,
                                      Toy.puzzle
                                    ][i],
                                    size: compact ? 32 : 48),
                                const SizedBox(width: 4),
                                Flexible(
                                    child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                            ['أسمع', 'أنطق', 'أكتب', 'ألعب'][i],
                                            maxLines: 1,
                                            style: const TextStyle(
                                                fontSize: 16,
                                                height: 1.2,
                                                color: profileInk,
                                                fontWeight: FontWeight.bold)))),
                              ]))),
                ),
              ],
            ])));
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBF4), Color(0xFFF7E8D5)],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFFFF8EA), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D71523B),
            offset: Offset(0, 5),
            blurRadius: 14,
          ),
        ],
      ),
      child: child,
    );
  }
}
