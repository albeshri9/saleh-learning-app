import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/interaction_audio.dart';
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
  int saveGeneration = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store = GameStore(ref.read(activeChildIdProvider));
    audio = ref.read(audioServiceProvider);
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
              : ((old['round'] as int?) ?? 0).clamp(0, 2));
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
    if (s.solved && !wasSolved) {
      wasSolved = true;
      saved = false;
      unawaited(audio.stop());
      if (s.complete) unawaited(InteractionAudio.celebrate());
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
    InteractionAudio.stopCelebration();
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
      InteractionAudio.stopCelebration();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    saveGeneration++;
    session?.removeListener(_changed);
    session?.dispose();
    unawaited(audio.stop());
    InteractionAudio.stopCelebration();
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
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      child: Column(children: [
                        SizedBox(
                            height: 54,
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
                                        style: TextStyle(
                                            fontSize: 22,
                                            color: color,
                                            fontWeight: FontWeight.w800)),
                                    if (child != null)
                                      Text(child.name,
                                          style: const TextStyle(
                                              fontSize: 13, color: gameInk)),
                                  ])),
                              if (s != null && started)
                                Row(children: [
                                  for (var i = 0; i < 3; i++)
                                    AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 250),
                                        width: i == s.roundIndex ? 30 : 12,
                                        height: 12,
                                        margin: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                            color: i <= s.roundIndex
                                                ? color
                                                : color.withValues(alpha: .15),
                                            borderRadius:
                                                BorderRadius.circular(10)))
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
                  Text(s.data.prompt,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: gameInk)),
                  const SizedBox(height: 8),
                  Text(
                      s.data.caption.isEmpty
                          ? widget.game.skill
                          : s.data.caption,
                      style: const TextStyle(fontSize: 15, color: gameInk)),
                  const SizedBox(height: 8),
                  Text('٣ جولات قصيرة • بلا مؤقت',
                      style: TextStyle(fontSize: 14, color: color)),
                  const SizedBox(height: 10),
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
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: gameInk))
                      ])),
                ])),
        const SizedBox(width: 10),
      ]));
  Widget _play(GameSession s, Color color) => Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 82,
              child: Column(children: [
                Expanded(
                    child: ValueListenableBuilder<bool>(
                        valueListenable: audio.playing,
                        builder: (context, talking, _) =>
                            MediaQuery.disableAnimationsOf(context)
                                ? Image.asset('assets/character/saleh_idle.png',
                                    fit: BoxFit.contain)
                                : SalehVideoRenderer(
                                    pose: s.solved
                                        ? SalehPose.celebrating
                                        : talking
                                            ? SalehPose.talking
                                            : SalehPose.idle,
                                    width: 80,
                                    posterOnly: MediaQuery.disableAnimationsOf(
                                        context)))),
                if (s.data.audio != null)
                  GameButton(
                      key: const ValueKey('listen-game'),
                      onTap: () => unawaited(_speak()),
                      label: 'اسمع الكلمة',
                      color: color,
                      child: Icon(Icons.volume_up_rounded, color: color)),
                const SizedBox(height: 8),
                GameButton(
                    label: 'تلميح',
                    onTap: s.solved ? null : s.hint,
                    color: color,
                    child: Icon(Icons.lightbulb_outline_rounded, color: color)),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .84),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Column(children: [
                    Text(s.data.prompt,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            color: gameInk,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Expanded(
                        child: AnimatedSwitcher(
                            duration: Duration(
                                milliseconds:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? 0
                                        : 220),
                            child: GameBoard(s,
                                key:
                                    ValueKey('${s.game.id}:${s.roundIndex}')))),
                    if (audioError != null)
                      Text(audioError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    if (!s.solved && s.feedback.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(s.feedback,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold))),
                  ]))),
        ]),
        if (s.solved)
          Positioned.fill(
              child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xF2F8F5EE),
                      borderRadius: BorderRadius.circular(28)),
                  child: Stack(children: [
                    if (!MediaQuery.disableAnimationsOf(context))
                      const Positioned.fill(child: Celebration()),
                    Center(
                        child: Arrival(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          Icon(
                              s.complete
                                  ? Icons.emoji_events_rounded
                                  : Icons.stars_rounded,
                              size: 52,
                              color: const Color(0xFFE0AB38)),
                          Text(
                              s.complete
                                  ? 'أكملت ${widget.game.title}!'
                                  : 'رائع! خطوة جديدة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 24,
                                  color: color,
                                  fontWeight: FontWeight.w800)),
                          Text(
                              s.complete
                                  ? (alreadyRewarded
                                      ? 'لعبت مرة أخرى، وما زلت تتعلم'
                                      : saved
                                          ? 'حصلت على ١٥ نقطة'
                                          : 'نحفظ إنجازك…')
                                  : widget.game.skill,
                              style: const TextStyle(
                                  fontSize: 17, color: gameInk)),
                          const SizedBox(height: 10),
                          if (saving)
                            const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          if (saveError) ...[
                            const Text('تعذر حفظ التقدم. يمكنك إعادة المحاولة.',
                                style: TextStyle(color: gameInk)),
                            TextButton(
                                onPressed: _save,
                                child: const Text('إعادة الحفظ'))
                          ],
                          if (saved && !saving)
                            GameButton(
                                key: const ValueKey('next-game-round'),
                                color: color,
                                onTap: _next,
                                child: Text(
                                    s.complete
                                        ? 'ألعب مجددًا'
                                        : 'الجولة التالية',
                                    style: TextStyle(
                                        fontSize: 22,
                                        color: color,
                                        fontWeight: FontWeight.w800))),
                        ]))),
                  ]))),
      ]);
}
