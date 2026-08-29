import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../services/audio/audio_service.dart';
import 'game_effects.dart';
import 'game_stage.dart';
import '../character/video/saleh_video_renderer.dart';
import '../lesson/widgets/saleh_character.dart';
import '../home/learning_journal.dart';
import '../home/profile_editor.dart';
import 'game_art.dart';
import 'game_board.dart';
import 'game_catalog.dart';
import 'game_session.dart';
import 'game_store.dart';

class LearningGameScreen extends ConsumerStatefulWidget {
  const LearningGameScreen({super.key, required this.game});
  final GameSpec game;
  @override
  ConsumerState<LearningGameScreen> createState() => _LearningGameScreenState();
}

class _LearningGameScreenState extends ConsumerState<LearningGameScreen>
    with WidgetsBindingObserver {
  late final GameStore store;
  late final AudioService audio;
  GameSession? session;
  bool started = false,
      saving = false,
      saved = false,
      wasSolved = false,
      saveError = false,
      alreadyRewarded = false;
  String? loadError, audioError;
  int saveGeneration = 0, lastFeedbackSerial = 0;
  late final GameEffects effects;
  Timer? encouragementTimer;
  bool cheering = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = GameStore(ref.read(activeChildIdProvider));
    audio = ref.read(audioServiceProvider);
    effects = ref.read(gameEffectsFactoryProvider)();
    unawaited(effects.prepare());
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await store.load();
      final old = Map<String, dynamic>.from(all[widget.game.id] as Map? ?? {});
      final journal = await LearningJournal(store.childId).load();
      if (!mounted) return;
      alreadyRewarded =
          journal.awards.containsKey('game:worlds:${widget.game.id}');
      session = GameSession(widget.game,
          round: old['completed'] == true
              ? 0
              : ((old['round'] as int?) ?? 0)
                  .clamp(0, widget.game.roundCount - 1));
      if (old['completed'] != true) {
        session!.mistakes = (old['mistakes'] as int?) ?? 0;
        session!.hints = (old['hints'] as int?) ?? 0;
      }
      session!.addListener(_changed);
      setState(() => loadError = null);
    } catch (_) {
      if (mounted) {
        setState(() => loadError = 'تعذر تحميل التقدم. لم نغير بياناتك.');
      }
    }
  }

  Future<void> _speak() async {
    final path = session?.data.audio;
    if (path == null) return;
    try {
      await audio.play(path);
    } catch (_) {
      if (mounted) {
        setState(() => audioError = 'تعذر تشغيل الصوت. حاول مرة أخرى.');
      }
    }
  }

  void _changed() {
    final s = session!;
    if (lastFeedbackSerial != s.feedbackSerial) {
      lastFeedbackSerial = s.feedbackSerial;
      unawaited(effects.answer(s.feedbackCorrect));
      encouragementTimer?.cancel();
      cheering = s.feedbackCorrect;
      if (cheering) {
        encouragementTimer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => cheering = false);
        });
      }
    }
    if (s.solved && !wasSolved) {
      wasSolved = true;
      saved = false;
      unawaited(audio.stop());

      unawaited(_save());
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (saving || session == null) return;
    final generation = ++saveGeneration;
    final s = session!;
    final round = s.complete
        ? 0
        : s.solved
            ? s.roundIndex + 1
            : s.roundIndex;
    setState(() {
      saving = true;
      saveError = false;
    });
    try {
      await store.save(widget.game.id,
          nextRound: round,
          mistakes: s.mistakes,
          hints: s.hints,
          complete: s.complete);
      if (mounted && generation == saveGeneration) {
        ref.invalidate(journalDataProvider);
        setState(() => saved = true);
      }
    } catch (_) {
      if (mounted && generation == saveGeneration) {
        setState(() => saveError = true);
      }
    } finally {
      if (mounted && generation == saveGeneration) {
        setState(() => saving = false);
      }
    }
  }

  void _next() {
    if (saving || !saved) return;
    effects.stop();
    cheering = false;
    encouragementTimer?.cancel();
    wasSolved = false;
    saved = false;
    if (session!.complete) {
      alreadyRewarded = true;
      session!.retry();
    } else {
      session!.next();
    }
    unawaited(_speak());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      session?.pause();
      unawaited(audio.stop());
      effects.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    saveGeneration++;
    session?.removeListener(_changed);
    session?.dispose();
    unawaited(audio.stop());
    effects.stop();
    encouragementTimer?.cancel();
    effects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = session, color = gameColors[widget.game.world.index];
    final child = ref.watch(childProfileProvider).valueOrNull;
    return Scaffold(
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: GameBackdrop(
                world: widget.game.world,
                child: SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                      child: Column(children: [
                        SizedBox(
                            height: 44,
                            child: Row(children: [
                              if (child != null) ...[
                                CareerAvatar(
                                    index:
                                        careerIndex(child.avatar, child.gender),
                                    size: 38),
                                const SizedBox(width: 8)
                              ],
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                    Text(widget.game.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 19,
                                            height: 1.15,
                                            color: color,
                                            fontWeight: FontWeight.w800)),
                                    if (child != null)
                                      Text(child.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.15,
                                              color: gameInk)),
                                  ])),
                              if (s != null && started)
                                Row(children: [
                                  for (var i = 0; i < s.roundCount; i++)
                                    Container(
                                        key: ValueKey('round-progress-$i'),
                                        width: 25,
                                        height: 25,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: i < s.roundIndex ||
                                                    (i == s.roundIndex &&
                                                        s.solved)
                                                ? const Color(0xFF29966C)
                                                : i == s.roundIndex
                                                    ? color
                                                    : color.withValues(
                                                        alpha: .15)),
                                        child: Center(
                                            child: i < s.roundIndex ||
                                                    (i == s.roundIndex &&
                                                        s.solved)
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: Colors.white)
                                                : Text(digits(i + 1),
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: i == s.roundIndex
                                                            ? Colors.white
                                                            : color))))
                                ]),
                              const SizedBox(width: 12),
                              GameButton(
                                  label: 'عودة للألعاب',
                                  padding: const EdgeInsets.all(8),
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(Icons.close_rounded,
                                      color: gameInk)),
                            ])),
                        const SizedBox(height: 5),
                        Expanded(
                            child: s == null
                                ? Center(
                                    child: loadError == null
                                        ? const CircularProgressIndicator()
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                Text(loadError!),
                                                TextButton(
                                                    onPressed: _load,
                                                    child: const Text(
                                                        'إعادة المحاولة'))
                                              ]))
                                : !started
                                    ? _intro(s, color)
                                    : _play(s, color)),
                      ])),
                ))));
  }

  Widget _intro(GameSession s, Color color) => Arrival(
          child: Row(children: [
        Expanded(
            flex: 3,
            child: Container(
                margin: const EdgeInsets.all(8),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: .18),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
                    ]),
                child: AtlasArt(widget.game.world.index,
                    world: true, fit: BoxFit.cover))),
        const SizedBox(width: 22),
        Expanded(
            flex: 5,
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لنلعب مع صالح',
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Flexible(
                      child: Text(s.data.prompt,
                          style: const TextStyle(
                              fontSize: 19,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              color: gameInk))),
                  const SizedBox(height: 6),
                  Flexible(
                      child: Text(
                          s.data.caption.isEmpty
                              ? widget.game.skill
                              : s.data.caption,
                          style: const TextStyle(
                              fontSize: 14, height: 1.2, color: gameInk))),
                  const SizedBox(height: 6),
                  Text('${digits(s.roundCount)} جولات قصيرة • بلا مؤقت',
                      style:
                          TextStyle(fontSize: 13, height: 1.2, color: color)),
                  const SizedBox(height: 6),
                  GameButton(
                      key: const ValueKey('start-game'),
                      onTap: () {
                        setState(() => started = true);
                        unawaited(_speak());
                      },
                      color: color,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.play_arrow_rounded, color: gameInk),
                        Text(s.roundIndex == 0 ? 'هيا نبدأ' : 'نكمل اللعب',
                            style: const TextStyle(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: gameInk))
                      ])),
                ])),
        const SizedBox(width: 10),
      ]));
  Widget _play(GameSession s, Color color) =>
      LayoutBuilder(builder: (context, constraints) {
        final characterWidth = constraints.maxWidth < 650 ? 104.0 : 148.0;
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: characterWidth,
              child: Column(children: [
                Expanded(
                    child: Stack(children: [
                  Positioned.fill(
                      child: ValueListenableBuilder<bool>(
                          valueListenable: audio.playing,
                          builder: (context, talking, _) => MediaQuery
                                  .disableAnimationsOf(context)
                              ? Image.asset('assets/character/saleh_idle.png',
                                  fit: BoxFit.contain)
                              : SalehVideoRenderer(
                                  key: ValueKey(
                                      'saleh-${cheering ? lastFeedbackSerial : 0}'),
                                  pose: cheering
                                      ? SalehPose.celebrating
                                      : talking
                                          ? SalehPose.talking
                                          : SalehPose.idle,
                                  width: characterWidth))),
                  if (cheering)
                    const Positioned(
                        top: 0,
                        left: 0,
                        child: Icon(Icons.auto_awesome_rounded,
                            color: Color(0xFFE9B954), size: 28)),
                ])),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (s.data.audio != null)
                    GameButton(
                        key: const ValueKey('listen-game'),
                        label: 'اسمع الكلمة',
                        padding: const EdgeInsets.all(4),
                        onTap: () => unawaited(_speak()),
                        color: color,
                        child: Icon(Icons.volume_up_rounded, color: color)),
                  GameButton(
                      label: 'تلميح',
                      padding: const EdgeInsets.all(4),
                      onTap: s.solved ? null : s.hint,
                      color: color,
                      child:
                          Icon(Icons.lightbulb_outline_rounded, color: color)),
                ]),
              ])),
          const SizedBox(width: 8),
          Expanded(
              child: GameStage(
                  game: widget.game,
                  feedback: s.feedback.isEmpty
                      ? null
                      : s.feedbackSerial == 0
                          ? null
                          : s.feedbackCorrect,
                  child: Column(children: [
                    Text(s.data.prompt,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            color: gameInk,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Expanded(
                        child: Stack(children: [
                      Positioned.fill(
                          child: AnimatedSwitcher(
                              duration: Duration(
                                  milliseconds:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? 0
                                          : 220),
                              child: GameBoard(s,
                                  key: ValueKey(
                                      '${s.game.id}:${s.roundIndex}')))),
                      if (s.complete)
                        Positioned.fill(
                            child: Container(
                                decoration: BoxDecoration(
                                    color: const Color(0xF2F2F8EE),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Center(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      const Icon(Icons.emoji_events_rounded,
                                          size: 46, color: Color(0xFFE0AB38)),
                                      Text('أكملت ${widget.game.title}!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 22,
                                              color: color,
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          alreadyRewarded
                                              ? 'لعبت مرة أخرى، وما زلت تتعلم'
                                              : saved
                                                  ? 'حصلت على ١٥ نقطة'
                                                  : 'نحفظ إنجازك…',
                                          style: const TextStyle(
                                              fontSize: 15, color: gameInk)),
                                    ])))),
                      if (cheering && !MediaQuery.disableAnimationsOf(context))
                        Positioned.fill(
                            child: Celebration(
                                key: ValueKey(
                                    'celebration-$lastFeedbackSerial'))),
                    ])),
                    if (audioError != null)
                      Text(audioError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    if (saveError)
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Flexible(
                                child: Text('تعذر حفظ التقدم.',
                                    style: TextStyle(color: gameInk))),
                            TextButton(
                                onPressed: _save,
                                child: const Text('إعادة الحفظ'))
                          ]),
                    if (s.solved)
                      SizedBox(
                          height: 56,
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    s.complete ? 'كل الجولات مكتملة' : 'أحسنت!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Color(0xFF29966C),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17))),
                            if (saving)
                              const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            if (saved && !saving)
                              GameButton(
                                  key: const ValueKey('next-game-round'),
                                  color: color,
                                  onTap: _next,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  child: Text(
                                      s.complete
                                          ? 'ألعب مجددًا'
                                          : 'الجولة التالية',
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: color,
                                          fontWeight: FontWeight.w800))),
                          ]))
                    else if (s.feedback.isNotEmpty)
                      Text(s.feedback,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: TextStyle(
                              color: s.feedbackCorrect
                                  ? const Color(0xFF29966C)
                                  : color,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                  ]))),
        ]);
      });
}
