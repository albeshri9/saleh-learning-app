import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/letter_glyph.dart';
import '../../../core/design/widgets/touch_feedback.dart';
import '../../../domain/models/lesson.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/audio/interaction_audio.dart';
import '../../../services/speech/speech_service.dart';
import '../scene_registry.dart';
import '../writing/handwriting_validator.dart';
import '../writing/letter_trace_template.dart';
import '../writing/writing_canvases.dart';

/// اختبار مرحلي واحد يحافظ على إيقاع بصري ثابت بينما يبدّل نوع النشاط.
/// لا يغادر الطفل هذا المشهد حتى يعالج كل حرف أخطأ فيه.
class CheckpointScene extends ConsumerStatefulWidget {
  const CheckpointScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<CheckpointScene> createState() => _CheckpointSceneState();
}

class _CheckpointSceneState extends ConsumerState<CheckpointScene> {
  late final AudioService _audio;
  late final SpeechService _speech;
  late final List<Map<String, dynamic>> _tasks =
      ((widget.scene.data['tasks'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
  final _random = math.Random();
  GlobalKey<FreeWritingCanvasState> _freeKey =
      GlobalKey<FreeWritingCanvasState>();
  final Set<String> _weakLetters = {};
  final Set<String> _matched = {};

  int _index = 0;
  int _firstTryCorrect = 0;
  int? _selected;
  int? _selectedLetter;
  int? _selectedImage;
  bool _busy = false;
  bool _taskHadError = false;
  bool _showResult = false;
  bool _remediation = false;
  bool _ready = false;
  int _remediationIndex = 0;
  int _remediationPhase = 0;
  bool? _feedback;
  late List<int> _order = _newOrder;
  late List<int> _matchImageOrder = _newMatchOrder;
  late List<int> _remediationOrder = _newRemediationOrder;

  Map<String, dynamic> get _task => _tasks[_index];
  String get _type => _task['type'] as String? ?? 'choice';
  String get _letter => _task['letter'] as String? ?? '';
  List<String> get _options =>
      ((_task['options'] as List?) ?? const []).cast<String>();
  List<String> get _images =>
      ((_task['optionImages'] as List?) ?? const []).cast<String>();
  int get _correct => (_task['correctIndex'] as num? ?? 0).toInt();
  List<int> get _newOrder =>
      List<int>.generate(_options.length, (i) => i)..shuffle(_random);
  List<int> get _newMatchOrder => List<int>.generate(
      ((_tasks.isEmpty ? const [] : _task['pairs'] as List?) ?? const []).length,
      (i) => i)..shuffle(_random);
  List<int> get _newRemediationOrder =>
      List<int>.generate(3, (i) => i)..shuffle(_random);

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    _speech = ref.read(speechServiceProvider);
    _ready = widget.scene.lines.isEmpty;
    if (!_ready) {
      widget.api.channel.scriptFinished.addListener(_introFinished);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ready) _playPrompt();
    });
  }

  void _introFinished() {
    if (!mounted || _ready || !widget.api.channel.scriptFinished.value) return;
    setState(() => _ready = true);
    unawaited(_playPrompt());
  }

  Future<void> _playPrompt() async {
    final audio = _task['audio'] as String?;
    if (audio != null) {
      await _audio.play(audio);
    }
  }

  Future<void> _feedbackAudio(bool correct) async {
    widget.api.channel.interruptScript();
    widget.api.triggerSaleh(correct ? 'happyOnce' : 'surprised');
    if (correct) unawaited(InteractionAudio.celebrate());
    final asset = widget.scene.data[
        correct ? 'successAudio' : 'wrongAudio'] as String?;
    if (asset != null) {
      await _audio.play(asset);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  Future<void> _wrong({String? letter}) async {
    if (_busy) return;
    _busy = true;
    _taskHadError = true;
    _weakLetters.add(letter ?? _letter);
    setState(() => _feedback = false);
    await _feedbackAudio(false);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = null;
      _selected = null;
      _selectedLetter = null;
      _selectedImage = null;
      _order = _newOrder;
      _matchImageOrder = _newMatchOrder;
      _remediationOrder = _newRemediationOrder;
    });
    if (_remediation) {
      final current = _remediationLetters[_remediationIndex];
      final data = _letterData(current);
      final audio = data[_remediationPhase == 0 ? 'letterAudio' : 'wordAudio']
          as String?;
      if (audio != null) unawaited(_audio.play(audio));
    } else {
      unawaited(_playPrompt());
    }
  }

  Future<void> _correctTask() async {
    if (_busy) return;
    _busy = true;
    setState(() => _feedback = true);
    if (!_taskHadError) _firstTryCorrect++;
    await _feedbackAudio(true);
    if (!mounted) return;
    InteractionAudio.stopCelebration();
    if (_index + 1 >= _tasks.length) {
      setState(() {
        _busy = false;
        _showResult = true;
      });
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _selectedLetter = null;
      _selectedImage = null;
      _matched.clear();
      _freeKey = GlobalKey<FreeWritingCanvasState>();
      _taskHadError = false;
      _feedback = null;
      _busy = false;
      _order = _newOrder;
      _matchImageOrder = _newMatchOrder;
    });
    unawaited(_playPrompt());
  }

  Future<void> _choose(int index) async {
    if (_busy) return;
    setState(() => _selected = index);
    if (index == _correct) {
      await _correctTask();
    } else {
      await _wrong();
    }
  }

  Future<void> _listen() async {
    if (_busy) return;
    setState(() => _busy = true);
    widget.api.channel.interruptScript();
    await _audio.stop();
    final result = await _speech.listenFor(
      _task['expected'] as String? ?? '',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.correct) {
      await _correctTask();
    } else {
      await _wrong();
    }
  }

  Future<void> _checkFree() async {
    final canvas = _freeKey.currentState;
    final template = LetterTraceTemplate.fromId(
        _task['traceTemplateId'] as String?);
    if (canvas == null || !canvas.hasInk || template == null) {
      await _wrong();
      return;
    }
    final result = template.id == alifFathaVideoTemplate.id
        ? validateAlifFathaChildFriendly(canvas.sample)
        : validateDottedLetterWriting(canvas.sample, template);
    if (result.isValid) {
      await _correctTask();
    } else {
      canvas.clear();
      await _wrong();
    }
  }

  Future<void> _matchLetter(int index) async {
    if (_busy || _matched.contains('$index')) return;
    setState(() => _selectedLetter = index);
  }

  Future<void> _matchImage(int displayIndex) async {
    final chosen = _selectedLetter;
    final index = _matchImageOrder[displayIndex];
    if (_busy || chosen == null || _matched.contains('$index')) return;
    if (chosen != index) {
      setState(() => _selectedImage = displayIndex);
      await _wrong(letter: (_task['pairs'] as List)[chosen]['letter'] as String);
      return;
    }
    _matched.add('$index');
    _selectedLetter = null;
    final finished = _matched.length == (_task['pairs'] as List).length;
    if (finished) {
      await _correctTask();
      return;
    }
    _busy = true;
    await _feedbackAudio(true);
    if (!mounted) return;
    InteractionAudio.stopCelebration();
    setState(() => _busy = false);
  }

  void _startRemediation() {
    setState(() {
      _remediation = true;
      _showResult = false;
      _remediationIndex = 0;
      _remediationPhase = 0;
      _selected = null;
      _feedback = null;
      _remediationOrder = _newRemediationOrder;
    });
  }

  List<Map<String, dynamic>> get _letters =>
      ((widget.scene.data['letters'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> _letterData(String letter) =>
      _letters.firstWhere((entry) => entry['letter'] == letter);

  List<String> get _remediationLetters => _weakLetters.toList()
    ..sort((a, b) => _letters.indexOf(_letterData(a))
        .compareTo(_letters.indexOf(_letterData(b))));

  Future<void> _chooseRemediation(int index) async {
    if (_busy) return;
    final letters = _remediationLetters;
    final current = letters[_remediationIndex];
    final data = _letterData(current);
    final correct = index == 0;
    setState(() => _selected = index);
    if (!correct) {
      await _wrong(letter: current);
      return;
    }
    _busy = true;
    setState(() => _feedback = true);
    await _feedbackAudio(true);
    if (!mounted) return;
    InteractionAudio.stopCelebration();
    if (_remediationPhase == 0) {
      setState(() {
        _remediationPhase = 1;
        _selected = null;
        _feedback = null;
        _busy = false;
        _remediationOrder = _newRemediationOrder;
      });
      final audio = data['wordAudio'] as String?;
      if (audio != null) unawaited(_audio.play(audio));
      return;
    }
    _weakLetters.remove(current);
    if (_weakLetters.isEmpty) {
      setState(() {
        _remediation = false;
        _showResult = true;
        _busy = false;
        _feedback = null;
      });
      return;
    }
    setState(() {
      _remediationIndex = math.min(_remediationIndex,
          _remediationLetters.length - 1);
      _remediationPhase = 0;
      _selected = null;
      _feedback = null;
      _busy = false;
      _remediationOrder = _newRemediationOrder;
    });
  }

  Future<void> _completeMastery() async {
    for (var i = 0; i < _tasks.length; i++) {
      widget.api.recordAnswer(correct: true);
    }
    await widget.api.completeScene();
  }

  @override
  void dispose() {
    widget.api.channel.scriptFinished.removeListener(_introFinished);
    InteractionAudio.stopCelebration();
    _speech.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) return _result();
    if (_remediation) return _remediationView();
    return Column(children: [
      _ProgressHeader(current: _index + 1, total: _tasks.length),
      const SizedBox(height: 4),
      Expanded(child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Container(
          key: ValueKey('checkpoint-$_index-$_type'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8D8A8), width: 2),
          ),
          child: _activity(),
        ),
      )),
      _FeedbackStrip(value: _feedback),
    ]);
  }

  Widget _activity() => switch (_type) {
        'match' => _matching(),
        'pronounce' => _pronunciation(),
        'guided' => _guided(),
        'free' => _free(),
        _ => _choice(),
      };

  Widget _choice() => Column(children: [
        Text(_task['prompt'] as String? ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 18, height: 1.15, fontWeight: FontWeight.w800,
                color: Color(0xFF594574))),
        const SizedBox(height: 6),
        Expanded(child: Row(
          textDirection: TextDirection.rtl,
          children: [for (final i in _order) Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ChoiceCard(
              label: _options[i],
              image: i < _images.length ? _images[i] : null,
              selected: _selected == i,
              correct: _selected == i ? _feedback : null,
              onTap: _busy || !_ready ? null : () => _choose(i),
            ),
          ))],
        )),
      ]);

  Widget _matching() {
    final pairs = (_task['pairs'] as List).cast<Map<String, dynamic>>();
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'صِل كل حرف بصورته',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      const SizedBox(height: 5),
      Expanded(child: Row(children: [
        Expanded(child: Column(children: [for (var i = 0; i < pairs.length; i++)
          Expanded(child: Padding(padding: const EdgeInsets.all(3), child:
            _MiniMatchCard(selected: _selectedLetter == i,
                wrong: _selectedLetter == i && _feedback == false,
                done: _matched.contains('$i'), onTap: () => _matchLetter(i),
                child: LetterGlyph(pairs[i]['letter'] as String))))])),
        const SizedBox(width: 14, child: Icon(Icons.compare_arrows_rounded,
            color: Color(0xFF8B72B6), size: 18)),
        Expanded(child: Column(children: [for (var display = 0; display < pairs.length; display++)
          Expanded(child: Padding(padding: const EdgeInsets.all(3), child:
            _MiniMatchCard(selected: false,
                wrong: _selectedImage == display && _feedback == false,
                done: _matched.contains('${_matchImageOrder[display]}'),
                onTap: () => _matchImage(display), child: Image.asset(
                  pairs[_matchImageOrder[display]]['image'] as String,
                  fit: BoxFit.contain))))])),
      ])),
    ]);
  }

  Widget _pronunciation() => Column(children: [
        Text(_task['prompt'] as String? ?? 'انطق الحرف',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF594574))),
        Expanded(child: Center(child: SizedBox(width: 150, height: 130,
            child: LetterGlyph(_letter)))),
        FeedbackTap(
          key: const ValueKey('checkpoint-mic'),
          onTap: _busy ? null : () => unawaited(_listen()),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(duration: const Duration(milliseconds: 180),
            width: 62, height: 62,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _busy ? AppColors.danger : AppColors.success),
            child: Icon(_busy ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                color: Colors.white, size: 38)),
        ),
      ]);

  Widget _guided() {
    final template = LetterTraceTemplate.fromId(
        _task['traceTemplateId'] as String?);
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'اكتب الحرف فوق المسار',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      Expanded(child: template == null ? const Center(child: Text('تعذر تحميل المسار'))
          : GuidedTracingCanvas(letter: _letter, strokes: template.strokes,
              traceTemplate: template, onStrokeCompleted: (_) {},
              onAllCompleted: () => unawaited(_correctTask()))),
    ]);
  }

  Widget _free() {
    final template = LetterTraceTemplate.fromId(
        _task['traceTemplateId'] as String?);
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'اكتب الحرف كتابة حرة',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      Expanded(child: FreeWritingCanvas(key: _freeKey, traceTemplate: template)),
      SizedBox(height: 42, child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LessonActionButton(label: 'تحقق', icon: Icons.check_rounded,
              onPressed: _busy ? null : _checkFree),
          const SizedBox(width: 10),
          LessonActionButton(label: 'مسح', icon: Icons.refresh_rounded,
              onPressed: _busy ? null : () => _freeKey.currentState?.clear()),
        ],
      )),
    ]);
  }

  Widget _result() {
    final mastered = _weakLetters.isEmpty;
    final percent = mastered ? 100 : (_firstTryCorrect * 100 / _tasks.length).round();
    return Center(child: Container(
      key: const ValueKey('checkpoint-result'),
      constraints: const BoxConstraints(maxWidth: 650),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF4), borderRadius: BorderRadius.circular(28),
        border: Border.all(color: mastered ? AppColors.success : const Color(0xFFE2B960), width: 3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(mastered ? Icons.emoji_events_rounded : Icons.auto_awesome_rounded,
            color: mastered ? AppColors.starGold : const Color(0xFF8B72B6), size: 56),
        Text(mastered ? 'أحسنت! أتقنت حروف المجموعة' : 'أداء جميل… وبقي تدريب قصير',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                color: Color(0xFF594574))),
        Text('$percent٪', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
            color: mastered ? AppColors.successDark : const Color(0xFFB67835))),
        if (!mastered) Text('سنراجع: ${_weakLetters.join('  •  ')}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: Color(0xFF594574))),
        const SizedBox(height: 10),
        LessonActionButton(
          label: mastered ? 'متابعة الرحلة' : 'ابدأ التدريب الذكي',
          icon: mastered ? Icons.west_rounded : Icons.psychology_alt_rounded,
          onPressed: mastered ? _completeMastery : _startRemediation,
        ),
      ]),
    ));
  }

  Widget _remediationView() {
    final current = _remediationLetters[_remediationIndex];
    final data = _letterData(current);
    final wordPhase = _remediationPhase == 1;
    final options = wordPhase
        ? [data['word'] as String, 'أَسَد', 'بَطَّة']
        : [current, ..._letters.map((e) => e['letter'] as String)
            .where((value) => value != current).take(2)];
    final images = wordPhase
        ? [data['image'] as String,
            'assets/images/assessment/alif_lion.png',
            'assets/images/assessment/duck.png']
        : <String>[];
    return Column(children: [
      _ProgressHeader(current: _remediationIndex + 1,
          total: _remediationLetters.length, remedial: true),
      Expanded(child: Container(
        key: ValueKey('remediation-$current-$_remediationPhase'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Text(wordPhase ? 'اختر الصورة التي تبدأ بحرف $current' : 'استمع واختر حرف $current',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF594574))),
          const SizedBox(height: 8),
          Expanded(child: Row(children: [for (final i in _remediationOrder)
            Expanded(child: Padding(padding: const EdgeInsets.all(5), child:
              _ChoiceCard(label: options[i], image: i < images.length ? images[i] : null,
                  selected: _selected == i, correct: _selected == i ? _feedback : null,
                  onTap: _busy ? null : () => _chooseRemediation(i)))) ])),
        ]),
      )),
      _FeedbackStrip(value: _feedback),
    ]);
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.current, required this.total,
      this.remedial = false});
  final int current;
  final int total;
  final bool remedial;
  @override
  Widget build(BuildContext context) => Row(children: [
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: remedial ? const Color(0xFFFFE9C8)
            : const Color(0xFFEDE5F8), borderRadius: BorderRadius.circular(18)),
        child: FittedBox(fit: BoxFit.scaleDown, child:
          Text(remedial ? 'تدريب ذكي' : 'الاختبار المرحلي',
            maxLines: 1,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: Color(0xFF594574)))),
      ),
    ),
    const SizedBox(width: 10),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(value: total == 0 ? 0 : current / total,
        minHeight: 9, backgroundColor: const Color(0xFFE9E3EF),
        color: remedial ? const Color(0xFFE49B43) : const Color(0xFF8265B2)))),
    const SizedBox(width: 8),
    Text('$current / $total', style: const TextStyle(fontSize: 13,
        fontWeight: FontWeight.bold, color: Color(0xFF594574))),
  ]);
}

class _FeedbackStrip extends StatelessWidget {
  const _FeedbackStrip({required this.value});
  final bool? value;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220), height: 30,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: value == null ? Colors.transparent
        : value! ? const Color(0xFFE2F6E9) : const Color(0xFFFFE4E4),
        borderRadius: BorderRadius.circular(16)),
    child: Text(value == null ? '' : value! ? 'إجابة صحيحة! أحسنت' : 'إجابة خاطئة… حاول مرة أخرى',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
          color: value == true ? AppColors.successDark : AppColors.danger)),
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.label, required this.image,
      required this.selected, required this.correct, required this.onTap});
  final String label;
  final String? image;
  final bool selected;
  final bool? correct;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = !selected ? const Color(0xFFB9A8CF)
        : correct == true ? AppColors.success : AppColors.danger;
    final background = !selected ? Colors.white
        : correct == true ? const Color(0xFFE5F7EB) : const Color(0xFFFFE4E4);
    return AnimatedContainer(duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: selected ? 4 : 2)),
      child: FeedbackTap(onTap: onTap, child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Expanded(child: image == null ? LetterGlyph(label)
              : Image.asset(image!, fit: BoxFit.contain)),
          if (image != null) Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: Color(0xFF594574))),
        ]),
      )),
    );
  }
}

class _MiniMatchCard extends StatelessWidget {
  const _MiniMatchCard({required this.selected, required this.done,
      required this.wrong, required this.onTap, required this.child});
  final bool selected;
  final bool done;
  final bool wrong;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(color: done ? const Color(0xFFE5F7EB) : Colors.white,
      borderRadius: BorderRadius.circular(14), border: Border.all(
        color: wrong ? AppColors.danger : done ? AppColors.success : selected ? const Color(0xFF8265B2)
            : const Color(0xFFD5CBE3),
        width: wrong || selected || done ? 3 : 2)),
    child: FeedbackTap(onTap: done ? null : onTap,
      child: Padding(padding: const EdgeInsets.all(3), child: child)),
  );
}
