import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../services/audio/audio_service.dart';
import '../../core/design/widgets/classroom_background.dart';
import '../../core/design/widgets/toy_icon.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../lesson/option_order.dart';
import 'learning_journal.dart';
import 'profile_editor.dart';

enum ReviewGame { listen, memory, collect }

const gameNames = ['أسمع وأختار', 'بطاقات الذاكرة', 'سلة الألف'];
const gameDescriptions = [
  'اسمع الصوت واعثر على الحرف',
  'اكتشف البطاقات المتشابهة',
  'اجمع الألف بين الحروف'
];
const gameToys = [Toy.headphones, Toy.cards, Toy.flower];

class ReviewGameScreen extends ConsumerStatefulWidget {
  const ReviewGameScreen({super.key, required this.game});
  final ReviewGame game;
  @override
  ConsumerState<ReviewGameScreen> createState() => _ReviewGameScreenState();
}

class _ReviewGameScreenState extends ConsumerState<ReviewGameScreen> {
  final _random = Random();
  final Set<int> _matched = {}, _collected = {};
  final List<int> _open = [];
  late List<int> _order = shuffledOptions(4, _random);
  late final List<int> _memory = [0, 0, 1, 1, 2, 2]..shuffle(_random);
  late final List<String> _letters = ['أَ', 'بَ', 'أَ', 'ثَ', 'تَ', 'أَ']
    ..shuffle(_random);
  int _round = 0;
  bool _busy = false, _won = false;
  String _feedback = '';
  Timer? _timer;
  late final AudioService _audio;
  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.game == ReviewGame.listen) _listen();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_audio.stop());
    super.dispose();
  }

  Future<void> _listen() => _audio.play('assets/audio/alif/explain_2.mp3');
  Future<void> _win() async {
    if (_won) return;
    setState(() {
      _won = true;
      _feedback = 'أحسنت! أكملت اللعبة';
    });
    RewardStars.fly(context);
    unawaited(_audio.play('assets/audio/alif/assessment_success.mp3'));
    try {
      await ref
          .read(journalProvider)
          .award('game:alif:${widget.game.name}', 15);
      if (mounted) ref.invalidate(journalDataProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'أحسنت! تعذر حفظ النقاط، حاول لاحقًا.');
      }
    }
  }

  void _choose(int index) {
    if (_busy || _won) return;
    if (index != 0) {
      setState(() {
        _feedback = 'اسمع الصوت، ثم حاول مرة أخرى';
        _order = shuffledOptions(4, _random, _order);
      });
      return;
    }
    _round++;
    if (_round == 3) {
      _win();
      return;
    }
    setState(() {
      _feedback = 'رائع! بقي ${3 - _round}';
      _order = shuffledOptions(4, _random, _order);
    });
    _listen();
  }

  void _flip(int i) {
    if (_busy || _won || _open.contains(i) || _matched.contains(i)) return;
    setState(() => _open.add(i));
    if (_open.length < 2) return;
    if (_memory[_open.first] == _memory[i]) {
      setState(() {
        _matched.addAll(_open);
        _open.clear();
        _feedback = 'وجدت بطاقتين متشابهتين!';
      });
      if (_matched.length == _memory.length) _win();
    } else {
      _busy = true;
      _timer = Timer(const Duration(milliseconds: 850), () {
        if (mounted) {
          setState(() {
            _open.clear();
            _busy = false;
            _feedback = 'تذكّر مكان البطاقات وجرّب';
          });
        }
      });
    }
  }

  void _collect(int i) {
    if (_won || _collected.contains(i)) return;
    if (_letters[i] != 'أَ') {
      setState(() => _feedback = 'نبحث عن أَ، حاول مرة أخرى');
      return;
    }
    setState(() {
      _collected.add(i);
      _feedback = 'جمعت ${_collected.length} من 3';
    });
    if (_collected.length == 3) _win();
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(childProfileProvider).valueOrNull;
    return Scaffold(
        body: ClassroomBackground(
            asset: 'assets/backgrounds/courtyard_v38.png',
            child: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        if (child != null)
                          CareerAvatar(
                              index: careerIndex(child.avatar, child.gender),
                              size: 40),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(gameNames[widget.game.index],
                                style: const TextStyle(
                                    fontSize: 24,
                                    color: profileInk,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                            tooltip: 'عودة للألعاب',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded)),
                      ]),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFAF8F6FD),
                                  borderRadius: BorderRadius.circular(24)),
                              child: Column(children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          _won
                                              ? 'كل خطوة تستحق الفرح'
                                              : gameDescriptions[
                                                  widget.game.index],
                                          style: const TextStyle(
                                              fontSize: 18,
                                              color: profileInk))),
                                  if (widget.game != ReviewGame.memory)
                                    IconButton(
                                        tooltip: 'اسمع الحرف',
                                        onPressed: _listen,
                                        icon: const ToyIcon(Toy.headphones,
                                            size: 44))
                                ]),
                                Expanded(child: _board()),
                                SizedBox(
                                    height: 32,
                                    child: Center(
                                        child: Text(_feedback,
                                            style: const TextStyle(
                                                color: profileInk,
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold)))),
                                if (_won)
                                  JourneyButton(
                                      label: 'عودة للألعاب',
                                      onTap: () => Navigator.pop(context)),
                              ]))),
                    ])))));
  }

  Widget _board() => LayoutBuilder(builder: (context, b) {
        final count = widget.game == ReviewGame.listen ? 4 : 6;
        final columns = count == 4 ? 4 : 3;
        final rows = count == 4 ? 1 : 2;
        return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
                mainAxisExtent: (b.maxHeight - (rows - 1) * 8) / rows),
            itemCount: count,
            itemBuilder: (context, i) {
              final visible = _open.contains(i) || _matched.contains(i) || _won;
              final selected =
                  widget.game == ReviewGame.collect && _collected.contains(i);
              return Semantics(
                  button: true,
                  label: widget.game == ReviewGame.memory && !visible
                      ? 'بطاقة مغلقة ${i + 1}'
                      : null,
                  child: FeedbackTap(
                      key: ValueKey('game-card-$i'),
                      onTap: () => switch (widget.game) {
                            ReviewGame.listen => _choose(_order[i]),
                            ReviewGame.memory => _flip(i),
                            ReviewGame.collect => _collect(i)
                          },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: selected || _matched.contains(i)
                                ? const Color(0xFFD8EFE7)
                                : Colors.white,
                            border: Border.all(
                                color: const Color(0xFFD5C7E7), width: 2),
                            borderRadius: BorderRadius.circular(18)),
                        child: widget.game == ReviewGame.memory
                            ? visible
                                ? Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: _memoryFace(_memory[i]))
                                : ToyIcon(Toy.cards,
                                    size: min(72.0, b.maxHeight / 2 - 16))
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                    widget.game == ReviewGame.listen
                                        ? ['أَ', 'بَ', 'تَ', 'ثَ'][_order[i]]
                                        : selected
                                            ? '✓'
                                            : _letters[i],
                                    style: const TextStyle(
                                        fontSize: 62,
                                        color: profileInk,
                                        fontWeight: FontWeight.bold))),
                      )));
            });
      });
  Widget _memoryFace(int i) => i == 0
      ? const FittedBox(
          child: Text('أَ', style: TextStyle(fontSize: 60, color: profileInk)))
      : Image.asset(
          'assets/images/assessment/${i == 1 ? 'alif_lion' : 'duck'}.png',
          fit: BoxFit.contain);
}
