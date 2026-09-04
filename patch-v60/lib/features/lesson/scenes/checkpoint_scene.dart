import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../core/design/widgets/letter_glyph.dart';
import '../../../core/design/widgets/touch_feedback.dart';
import '../../../core/config/experimental_release.dart';
import '../../../domain/models/lesson.dart';
import '../../../services/audio/audio_service.dart';
import '../../../services/audio/interaction_audio.dart';
import '../../../services/speech/speech_service.dart';
import '../scene_registry.dart';
import '../foundation_track.dart';
import '../writing/handwriting_validator.dart';
import '../writing/letter_trace_template.dart';
import '../writing/writing_canvases.dart';

/// الكتابة الحرة مهارة نمائية؛ لذلك لا تُجعل بوابة مانعة لطفل الثالثة
/// أو الرابعة، مع بقائها جزءًا من الاختبار للأعمار الأكبر.
bool canSkipCheckpointFreeWriting(int age) => age <= 4;

List<T> _randomSample<T>(
  List<T> source,
  int requested,
  math.Random random,
) {
  final shuffled = List<T>.of(source)..shuffle(random);
  return shuffled.take(requested.clamp(0, shuffled.length)).toList();
}

/// Builds the approved four-phase checkpoint from the reusable letter data.
/// Keeping the flow data-driven lets the next letter group use the same
/// professional assessment without duplicating scene code.
List<Map<String, dynamic>> checkpointTaskFlow(
  Map<String, dynamic> data, {
  math.Random? random,
  FoundationTrack foundationTrack = FoundationTrack.readWrite,
}) {
  final source =
      ((data['tasks'] as List?) ?? const []).cast<Map<String, dynamic>>();
  if (data['standardizedFlow'] != true) {
    return source
        .where((task) => foundationTrack
            .allowsCheckpointTask(task['type'] as String? ?? 'choice'))
        .toList();
  }

  final rng = random ?? math.Random();
  final letters =
      ((data['letters'] as List?) ?? const []).cast<Map<String, dynamic>>();
  final glyphs = letters.map((entry) => entry['letter'] as String).toList();
  final recognitionLetters = _randomSample(
    letters,
    (data['recognitionCount'] as num? ?? letters.length).toInt(),
    rng,
  );
  final dragLetters = _randomSample(
    letters,
    (data['dragMatchCount'] as num? ?? letters.length).toInt(),
    rng,
  );
  final pronunciationLetters = _randomSample(
    letters,
    (data['pronunciationCount'] as num? ?? letters.length).toInt(),
    rng,
  );
  final writingLetterIds =
      ((data['writingLetterIds'] as List?) ?? const []).cast<String>().toSet();
  final writingLetters = writingLetterIds.isEmpty
      ? letters
      : letters
          .where((entry) => writingLetterIds.contains(entry['id']))
          .toList();

  final recognition = <Map<String, dynamic>>[
    for (final entry in recognitionLetters)
      {
        'id': 'recognize_${entry['id']}',
        'type': 'choice',
        'phase': 'letters',
        'letter': entry['letter'],
        'prompt': 'استمع جيدًا واختر الحرف الصحيح',
        'showPrompt': false,
        'options': glyphs,
        'correctIndex': letters.indexOf(entry),
        'audio': entry['letterAudio'],
      },
  ];

  final pronunciation = <Map<String, dynamic>>[
    for (final entry in pronunciationLetters)
      {
        'id': 'pronounce_${entry['id']}',
        'type': 'pronounce',
        'phase': 'pronunciation',
        'letter': entry['letter'],
        'prompt': 'هيا يا أبطال، انطقوا هذا الحرف',
        'expected': entry['expected'],
        'audio': data['pronunciationPromptAudio'],
      },
  ];

  final writing = <Map<String, dynamic>>[
    for (final entry in writingLetters)
      {
        'id': 'free_${entry['id']}',
        'type': 'free',
        'phase': 'writing',
        'letter': entry['letter'],
        'prompt': 'اكتب الحرف كتابة حرة',
        'traceTemplateId': entry['traceTemplateId'],
        'audio': entry['freeAudio'],
      },
  ]..shuffle(rng);

  return [
    ...recognition,
    {
      'id': 'match_all_words',
      'type': 'dragMatch',
      'phase': 'words',
      'letter': glyphs.isEmpty ? '' : glyphs.first,
      'prompt': 'اسحب كل حرف إلى الصورة التي تبدأ به',
      'audio': data['dragMatchPromptAudio'],
      'pairs': [
        for (final entry in dragLetters)
          {
            'letter': entry['letter'],
            'word': entry['word'],
            'image': entry['image'],
          },
      ],
    },
    ...pronunciation,
    ...writing,
  ]
      .where((task) => foundationTrack
          .allowsCheckpointTask(task['type'] as String? ?? 'choice'))
      .toList();
}

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
  final _random = math.Random();
  late final List<Map<String, dynamic>> _tasks = checkpointTaskFlow(
    widget.scene.data,
    random: _random,
    foundationTrack: widget.api.foundationTrack,
  );
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
  int _pronunciationAttempts = 0;
  int _audioEpoch = 0;
  bool? _feedback;
  String? _feedbackMessage;
  int _lastPraiseIndex = -1;
  Timer? _feedbackTimer;
  late List<int> _order = _newOrder;
  late List<int> _matchImageOrder = _newMatchOrder;
  late List<int> _dragLetterOrder = _newMatchOrder;
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
      ((_tasks.isEmpty ? const [] : _task['pairs'] as List?) ?? const [])
          .length,
      (i) => i)
    ..shuffle(_random);
  List<int> get _newRemediationOrder =>
      List<int>.generate(_letters.length, (i) => i)..shuffle(_random);

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

  Future<void> _playPrompt({int? epoch}) async {
    if (epoch != null && epoch != _audioEpoch) return;
    final audio = _currentPromptAudio;
    if (audio != null) {
      await _audio.play(audio);
    }
  }

  String? get _currentPromptAudio {
    if (_remediation) {
      final letters = _remediationLetters;
      if (letters.isEmpty) return null;
      final data = _letterData(letters[_remediationIndex]);
      return data[_remediationPhase == 0 ? 'letterAudio' : 'wordAudio']
          as String?;
    }
    return _task['audio'] as String?;
  }

  ({String text, String? audio}) _nextPraise() {
    final configured =
        ((widget.scene.data['successFeedbacks'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
    final fallback = <Map<String, dynamic>>[
      {
        'text': 'أحسنتم، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_well_done_v58.mp3'
      },
      {
        'text': 'ممتاز، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_excellent_v58.mp3'
      },
      {
        'text': 'يا سلام، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_wow_v58.mp3'
      },
      {
        'text': 'بارك الله فيكم، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_bless_v58.mp3'
      },
      {
        'text': 'رائع جدًا، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_wonderful_v58.mp3'
      },
      {
        'text': 'ما شاء الله، إجابة صحيحة.',
        'audio': 'assets/audio/praise_v58/praise_correct_mashallah_v58.mp3'
      },
      {
        'text': 'أحسنتم يا أبطال.',
        'audio': 'assets/audio/praise_v58/praise_heroes_v58.mp3'
      },
    ];
    final choices = configured.isEmpty ? fallback : configured;
    var index = _random.nextInt(choices.length);
    if (choices.length > 1 && index == _lastPraiseIndex) {
      index = (index + 1) % choices.length;
    }
    _lastPraiseIndex = index;
    final choice = choices[index];
    return (
      text: choice['text'] as String? ?? 'أحسنتم، إجابة صحيحة.',
      audio: choice['audio'] as String? ??
          widget.scene.data['successAudio'] as String?,
    );
  }

  void _announceFeedback(
    bool correct, {
    String? feedbackAsset,
    String? nextPrompt,
  }) {
    final epoch = ++_audioEpoch;
    widget.api.channel.interruptScript();
    widget.api.triggerSaleh(correct ? 'happyOnce' : 'surprised');
    InteractionAudio.stopCelebration();
    if (correct) unawaited(InteractionAudio.celebrate());
    final asset = feedbackAsset ??
        widget.scene.data[correct ? 'successAudio' : 'wrongAudio'] as String?;
    unawaited(() async {
      await _audio.stop();
      if (!mounted || epoch != _audioEpoch) return;
      if (asset != null) await _audio.play(asset);
      if (!mounted || epoch != _audioEpoch || nextPrompt == null) return;
      await _audio.play(nextPrompt);
    }());
  }

  void _setFeedback(bool value, {String? message}) {
    _feedbackTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _feedback = value;
      _feedbackMessage = message;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _feedback = null;
        _feedbackMessage = null;
      });
    });
  }

  Future<void> _wrong({
    String? letter,
    String? retryAudio,
    bool pronunciation = false,
  }) async {
    _taskHadError = true;
    _weakLetters.add(letter ?? _letter);
    if (pronunciation) _pronunciationAttempts++;
    final taskIndex = _index;
    final remediationIndex = _remediationIndex;
    final remediationPhase = _remediationPhase;
    _setFeedback(false,
        message:
            pronunciation ? 'لنحاول نطق الحرف مرة أخرى' : 'حاولوا مرة أخرى');
    _announceFeedback(false,
        feedbackAsset: retryAudio, nextPrompt: _currentPromptAudio);
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted ||
        taskIndex != _index ||
        remediationIndex != _remediationIndex ||
        remediationPhase != _remediationPhase) {
      return;
    }
    setState(() {
      _selected = null;
      _selectedLetter = null;
      _selectedImage = null;
      _order = _newOrder;
      _matchImageOrder = _newMatchOrder;
      _dragLetterOrder = _newMatchOrder;
      _remediationOrder = _newRemediationOrder;
    });
  }

  Future<void> _correctTask() async {
    if (_busy) return;
    if (!_taskHadError) _firstTryCorrect++;
    final praise = _nextPraise();
    if (_index + 1 >= _tasks.length) {
      setState(() {
        _showResult = true;
      });
      _announceFeedback(true, feedbackAsset: praise.audio);
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
      _pronunciationAttempts = 0;
      _order = _newOrder;
      _matchImageOrder = _newMatchOrder;
      _dragLetterOrder = _newMatchOrder;
    });
    _setFeedback(true, message: praise.text);
    _announceFeedback(true,
        feedbackAsset: praise.audio, nextPrompt: _currentPromptAudio);
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
    ++_audioEpoch;
    widget.api.channel.interruptScript();
    InteractionAudio.stopCelebration();
    _feedbackTimer?.cancel();
    setState(() {
      _busy = true;
      _feedback = null;
      _feedbackMessage = null;
    });
    await _audio.stop();
    final result = await _speech.listenFor(
      _task['expected'] as String? ?? '',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.correct) {
      await _correctTask();
    } else {
      final retry = _letterData(_letter)['pronunciationRetryAudio'] as String?;
      await _wrong(pronunciation: true, retryAudio: retry, letter: _letter);
    }
  }

  void _advanceWithoutPraise() {
    if (_index + 1 >= _tasks.length) {
      setState(() => _showResult = true);
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
      _pronunciationAttempts = 0;
      _feedback = null;
      _feedbackMessage = null;
      _order = _newOrder;
      _matchImageOrder = _newMatchOrder;
      _dragLetterOrder = _newMatchOrder;
    });
    unawaited(_playPrompt());
  }

  void _skipPronunciation() {
    _weakLetters.add(_letter);
    _audioEpoch++;
    unawaited(_audio.stop());
    _advanceWithoutPraise();
  }

  void _skipCurrentTask() {
    if (_busy) return;
    _audioEpoch++;
    widget.api.channel.interruptScript();
    unawaited(_audio.stop());
    _advanceWithoutPraise();
  }

  Future<void> _checkFree() async {
    final canvas = _freeKey.currentState;
    final template =
        LetterTraceTemplate.fromId(_task['traceTemplateId'] as String?);
    if (canvas == null || !canvas.hasInk || template == null) {
      await _wrong();
      return;
    }
    final result = validateCheckpointLetterWriting(canvas.sample, template);
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
      await _wrong(
          letter: (_task['pairs'] as List)[chosen]['letter'] as String);
      return;
    }
    _matched.add('$index');
    _selectedLetter = null;
    final finished = _matched.length == (_task['pairs'] as List).length;
    if (finished) {
      await _correctTask();
      return;
    }
    final praise = _nextPraise();
    _setFeedback(true, message: praise.text);
    _announceFeedback(true, feedbackAsset: praise.audio);
  }

  Future<void> _dropLetter(int letterIndex, int targetIndex) async {
    if (_busy || _matched.contains('$letterIndex')) return;
    final pairs = (_task['pairs'] as List).cast<Map<String, dynamic>>();
    if (letterIndex != targetIndex) {
      setState(() {
        _selectedLetter = letterIndex;
        _selectedImage = targetIndex;
      });
      await _wrong(letter: pairs[letterIndex]['letter'] as String);
      return;
    }

    setState(() {
      _matched.add('$letterIndex');
      _selectedLetter = null;
      _selectedImage = null;
    });
    if (_matched.length == pairs.length) {
      await _correctTask();
      return;
    }

    final praise = _nextPraise();
    _setFeedback(true, message: praise.text);
    _announceFeedback(true, feedbackAsset: praise.audio);
  }

  void _startRemediation() {
    setState(() {
      _remediation = true;
      _showResult = false;
      _remediationIndex = 0;
      _remediationPhase = 0;
      _selected = null;
      _feedback = null;
      _feedbackMessage = null;
      _remediationOrder = _newRemediationOrder;
    });
  }

  List<Map<String, dynamic>> get _letters =>
      ((widget.scene.data['letters'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  Map<String, dynamic> _letterData(String letter) =>
      _letters.firstWhere((entry) => entry['letter'] == letter);

  List<String> get _remediationLetters => _weakLetters.toList()
    ..sort((a, b) => _letters
        .indexOf(_letterData(a))
        .compareTo(_letters.indexOf(_letterData(b))));

  Future<void> _chooseRemediation(int index) async {
    if (_busy) return;
    final letters = _remediationLetters;
    final current = letters[_remediationIndex];
    final data = _letterData(current);
    final correct = _letters[index]['letter'] == current;
    setState(() => _selected = index);
    if (!correct) {
      await _wrong(letter: current);
      return;
    }
    if (_remediationPhase == 0) {
      setState(() {
        _remediationPhase = 1;
        _selected = null;
        _remediationOrder = _newRemediationOrder;
      });
      final praise = _nextPraise();
      _setFeedback(true, message: praise.text);
      _announceFeedback(true,
          feedbackAsset: praise.audio,
          nextPrompt: data['wordAudio'] as String?);
      return;
    }
    _weakLetters.remove(current);
    if (_weakLetters.isEmpty) {
      setState(() {
        _remediation = false;
        _showResult = true;
        _feedback = null;
        _feedbackMessage = null;
      });
      _announceFeedback(true);
      return;
    }
    setState(() {
      _remediationIndex =
          math.min(_remediationIndex, _remediationLetters.length - 1);
      _remediationPhase = 0;
      _selected = null;
      _remediationOrder = _newRemediationOrder;
    });
    final next = _letterData(_remediationLetters[_remediationIndex]);
    final praise = _nextPraise();
    _setFeedback(true, message: praise.text);
    _announceFeedback(true,
        feedbackAsset: praise.audio,
        nextPrompt: next['letterAudio'] as String?);
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
    _feedbackTimer?.cancel();
    _audioEpoch++;
    _audio.stop().ignore();
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
      Expanded(
          child: AnimatedSwitcher(
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
      if (ExperimentalRelease.skipEveryLessonSection)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            key: const ValueKey('checkpoint-task-skip'),
            onPressed: _busy ? null : _skipCurrentTask,
            icon: const Icon(Icons.west_rounded, size: 18),
            label: const Text('تخطي'),
          ),
        ),
      _FeedbackStrip(value: _feedback, message: _feedbackMessage),
    ]);
  }

  Widget _activity() => switch (_type) {
        'dragMatch' => _dragMatching(),
        'match' => _matching(),
        'pronounce' => _pronunciation(),
        'guided' => _guided(),
        'free' => _free(),
        _ => _choice(),
      };

  Widget _choice() => Column(children: [
        Text(
            _task['showPrompt'] == false
                ? 'استمع جيدًا واختر الحرف الصحيح'
                : (_task['prompt'] as String? ?? ''),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
                fontSize: 18,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF594574))),
        const SizedBox(height: 6),
        Expanded(child: LayoutBuilder(builder: (context, bounds) {
          Widget card(int i) => _ChoiceCard(
                key: ValueKey('checkpoint-choice-$i'),
                label: _options[i],
                image: i < _images.length ? _images[i] : null,
                selected: _selected == i,
                correct: _selected == i ? _feedback : null,
                onTap: _busy || !_ready ? null : () => _choose(i),
              );
          if (_order.length <= 4) {
            return Row(
              textDirection: TextDirection.rtl,
              children: [
                for (final i in _order)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: card(i),
                    ),
                  ),
              ],
            );
          }
          final columns = _order.length > 8 ? 6 : 4;
          return GridView.builder(
            key: const ValueKey('checkpoint-choice-grid'),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: (bounds.maxWidth / columns) /
                  (bounds.maxHeight / (_order.length / columns).ceil()),
            ),
            itemCount: _order.length,
            itemBuilder: (context, index) => card(_order[index]),
          );
        })),
      ]);

  Widget _dragMatching() {
    final pairs = (_task['pairs'] as List).cast<Map<String, dynamic>>();
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'اسحب كل حرف إلى صورته',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 17,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      const SizedBox(height: 4),
      Expanded(
          child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            for (final targetIndex in _matchImageOrder)
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _WordDropCard(
                  image: pairs[targetIndex]['image'] as String,
                  word: pairs[targetIndex]['word'] as String,
                  letter: pairs[targetIndex]['letter'] as String,
                  completed: _matched.contains('$targetIndex'),
                  wrong: _selectedImage == targetIndex && _feedback == false,
                  onAccept: (letterIndex) =>
                      unawaited(_dropLetter(letterIndex, targetIndex)),
                ),
              )),
          ])),
      const SizedBox(height: 4),
      SizedBox(
          height: 50,
          child: Row(textDirection: TextDirection.rtl, children: [
            for (final letterIndex in _dragLetterOrder)
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DraggableLetter(
                  index: letterIndex,
                  letter: pairs[letterIndex]['letter'] as String,
                  enabled: !_busy && !_matched.contains('$letterIndex'),
                ),
              )),
          ])),
    ]);
  }

  Widget _matching() {
    final pairs = (_task['pairs'] as List).cast<Map<String, dynamic>>();
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'صِل كل حرف بصورته',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      const SizedBox(height: 5),
      Expanded(
          child: Row(children: [
        Expanded(
            child: Column(children: [
          for (var i = 0; i < pairs.length; i++)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _MiniMatchCard(
                        selected: _selectedLetter == i,
                        wrong: _selectedLetter == i && _feedback == false,
                        done: _matched.contains('$i'),
                        onTap: () => _matchLetter(i),
                        child: _CheckpointLetterGlyph(
                            pairs[i]['letter'] as String))))
        ])),
        const SizedBox(
            width: 14,
            child: Icon(Icons.compare_arrows_rounded,
                color: Color(0xFF8B72B6), size: 18)),
        Expanded(
            child: Column(children: [
          for (var display = 0; display < pairs.length; display++)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: _MiniMatchCard(
                        selected: false,
                        wrong: _selectedImage == display && _feedback == false,
                        done: _matched.contains('${_matchImageOrder[display]}'),
                        onTap: () => _matchImage(display),
                        child: Image.asset(
                            pairs[_matchImageOrder[display]]['image'] as String,
                            fit: BoxFit.contain))))
        ])),
      ])),
    ]);
  }

  Widget _pronunciation() => Column(children: [
        Text(_task['prompt'] as String? ?? 'انطق الحرف',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF594574))),
        Expanded(
            child: Center(
                child: SizedBox(
                    width: 150,
                    height: 130,
                    child: _CheckpointLetterGlyph(_letter)))),
        FeedbackTap(
          key: const ValueKey('checkpoint-mic'),
          onTap: _busy ? null : () => unawaited(_listen()),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _busy ? AppColors.danger : AppColors.success),
              child: Icon(_busy ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 38)),
        ),
        if (_pronunciationAttempts >= 2) ...[
          const SizedBox(height: 4),
          LessonActionButton(
            label: 'تخطي هذا الحرف',
            icon: Icons.west_rounded,
            onPressed: _busy ? null : _skipPronunciation,
          ),
        ],
      ]);

  Widget _guided() {
    final template =
        LetterTraceTemplate.fromId(_task['traceTemplateId'] as String?);
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'اكتب الحرف فوق المسار',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      Expanded(
          child: template == null
              ? const Center(child: Text('تعذر تحميل المسار'))
              : GuidedTracingCanvas(
                  letter: _letter,
                  strokes: template.strokes,
                  traceTemplate: template,
                  onStrokeCompleted: (_) {},
                  onAllCompleted: () => unawaited(_correctTask()))),
    ]);
  }

  Widget _free() {
    final template =
        LetterTraceTemplate.fromId(_task['traceTemplateId'] as String?);
    return Column(children: [
      Text(_task['prompt'] as String? ?? 'اكتب الحرف كتابة حرة',
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF594574))),
      Expanded(
          child: FreeWritingCanvas(key: _freeKey, traceTemplate: template)),
      SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LessonActionButton(
                  label: 'تحقق',
                  icon: Icons.check_rounded,
                  onPressed: _busy ? null : _checkFree),
              const SizedBox(width: 10),
              LessonActionButton(
                  label: 'مسح',
                  icon: Icons.refresh_rounded,
                  onPressed:
                      _busy ? null : () => _freeKey.currentState?.clear()),
            ],
          )),
    ]);
  }

  Widget _result() {
    final mastered = _weakLetters.isEmpty;
    final percent =
        mastered ? 100 : (_firstTryCorrect * 100 / _tasks.length).round();
    return Center(
        child: Container(
      key: const ValueKey('checkpoint-result'),
      constraints: const BoxConstraints(maxWidth: 650),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: mastered ? AppColors.success : const Color(0xFFE2B960),
            width: 3),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(mastered ? Icons.emoji_events_rounded : Icons.auto_awesome_rounded,
            color: mastered ? AppColors.starGold : const Color(0xFF8B72B6),
            size: 56),
        Text(
            mastered
                ? 'تهانينا! تجاوزتم الاختبار بتفوق'
                : 'أداء جميل… وبقي تدريب قصير',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF594574))),
        Text('$percent٪',
            style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: mastered
                    ? AppColors.successDark
                    : const Color(0xFFB67835))),
        if (!mastered)
          Text('سنراجع: ${_weakLetters.join('  •  ')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: Color(0xFF594574))),
        const SizedBox(height: 10),
        LessonActionButton(
          label: mastered ? 'تم' : 'ابدأ التدريب الذكي',
          icon: mastered ? Icons.check_rounded : Icons.psychology_alt_rounded,
          onPressed: mastered ? _completeMastery : _startRemediation,
        ),
      ]),
    ));
  }

  Widget _remediationView() {
    final current = _remediationLetters[_remediationIndex];
    final wordPhase = _remediationPhase == 1;
    final options = wordPhase
        ? _letters.map((entry) => entry['word'] as String).toList()
        : _letters.map((entry) => entry['letter'] as String).toList();
    final images = wordPhase
        ? _letters.map((entry) => entry['image'] as String).toList()
        : <String>[];
    return Column(children: [
      _ProgressHeader(
          current: _remediationIndex + 1,
          total: _remediationLetters.length,
          remedial: true),
      Expanded(
          child: Container(
        key: ValueKey('remediation-$current-$_remediationPhase'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFCF4),
            borderRadius: BorderRadius.circular(24)),
        child: Column(children: [
          Text(
              wordPhase
                  ? 'اختر الصورة التي تبدأ بالحرف الذي سمعته'
                  : 'استمع جيدًا واختر الحرف الصحيح',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF594574))),
          const SizedBox(height: 8),
          Expanded(
              child: Row(children: [
            for (final i in _remediationOrder)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: _ChoiceCard(
                          label: options[i],
                          image: i < images.length ? images[i] : null,
                          selected: _selected == i,
                          correct: _selected == i ? _feedback : null,
                          onTap: _busy ? null : () => _chooseRemediation(i))))
          ])),
        ]),
      )),
      _FeedbackStrip(value: _feedback, message: _feedbackMessage),
    ]);
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader(
      {required this.current, required this.total, this.remedial = false});
  final int current;
  final int total;
  final bool remedial;
  @override
  Widget build(BuildContext context) => Row(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 118),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: remedial
                    ? const Color(0xFFFFE9C8)
                    : const Color(0xFFEDE5F8),
                borderRadius: BorderRadius.circular(18)),
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(remedial ? 'تدريب ذكي' : 'الاختبار المرحلي',
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF594574)))),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: total == 0 ? 0 : current / total,
                    minHeight: 9,
                    backgroundColor: const Color(0xFFE9E3EF),
                    color: remedial
                        ? const Color(0xFFE49B43)
                        : const Color(0xFF8265B2)))),
        const SizedBox(width: 8),
        Text('$current / $total',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF594574))),
      ]);
}

class _FeedbackStrip extends StatelessWidget {
  const _FeedbackStrip({required this.value, this.message});
  final bool? value;
  final String? message;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: value == null
                ? Colors.transparent
                : value!
                    ? const Color(0xFFE2F6E9)
                    : const Color(0xFFFFE4E4),
            borderRadius: BorderRadius.circular(16)),
        child: Text(
            value == null
                ? ''
                : message ??
                    (value! ? 'أحسنتم، إجابة صحيحة.' : 'حاول مرة أخرى'),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color:
                    value == true ? AppColors.successDark : AppColors.danger)),
      );
}

/// يضبط المركز البصري لجسم الحرف؛ فالنقاط العلوية والسفلية تغيّر صندوق
/// الخط تقنيًا رغم أن جسم الحرف يجب أن يبقى على خط واحد داخل البطاقات.
class _CheckpointLetterGlyph extends StatelessWidget {
  const _CheckpointLetterGlyph(this.letter);

  final String letter;

  double get _opticalOffset {
    if (letter.startsWith('ت') ||
        letter.startsWith('ث') ||
        letter.startsWith('خ')) {
      return -4;
    }
    if (letter.startsWith('ب')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Transform.translate(
          offset: Offset(0, _opticalOffset),
          child: LetterGlyph(letter),
        ),
      );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard(
      {super.key,
      required this.label,
      required this.image,
      required this.selected,
      required this.correct,
      required this.onTap});
  final String label;
  final String? image;
  final bool selected;
  final bool? correct;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = !selected
        ? const Color(0xFFB9A8CF)
        : correct == true
            ? AppColors.success
            : AppColors.danger;
    final background = !selected
        ? Colors.white
        : correct == true
            ? const Color(0xFFE5F7EB)
            : const Color(0xFFFFE4E4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: selected ? 4 : 2)),
      child: FeedbackTap(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Expanded(
                  child: image == null
                      ? LayoutBuilder(builder: (context, bounds) {
                          final side = math
                              .min(bounds.maxWidth, bounds.maxHeight)
                              .clamp(34.0, 76.0);
                          return Center(
                              child: SizedBox.square(
                                  dimension: side,
                                  child: _CheckpointLetterGlyph(label)));
                        })
                      : Image.asset(image!, fit: BoxFit.contain)),
              if (image != null)
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF594574))),
            ]),
          )),
    );
  }
}

class _WordDropCard extends StatelessWidget {
  const _WordDropCard({
    required this.image,
    required this.word,
    required this.letter,
    required this.completed,
    required this.wrong,
    required this.onAccept,
  });

  final String image;
  final String word;
  final String letter;
  final bool completed;
  final bool wrong;
  final ValueChanged<int> onAccept;

  @override
  Widget build(BuildContext context) => DragTarget<int>(
        onWillAcceptWithDetails: (_) => !completed,
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidates, rejected) {
          final active = candidates.isNotEmpty;
          final border = wrong
              ? AppColors.danger
              : completed
                  ? AppColors.success
                  : active
                      ? const Color(0xFF8265B2)
                      : const Color(0xFFD5CBE3);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFFE8F7E9)
                  : wrong
                      ? const Color(0xFFFFE4E4)
                      : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: active ? 3 : 2),
            ),
            child: Column(children: [
              Expanded(
                  child: Image.asset(image,
                      fit: BoxFit.contain, filterQuality: FilterQuality.high)),
              SizedBox(
                height: 27,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFD9F3E2)
                        : const Color(0xFFF2EDF8),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: completed
                            ? AppColors.success
                            : const Color(0xFFC7B8DA)),
                  ),
                  child: Center(
                    child: completed
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(letter,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF397A50))),
                              const SizedBox(width: 2),
                              const Icon(Icons.check_rounded,
                                  size: 14, color: AppColors.successDark),
                            ],
                          )
                        : const Text('اسحب هنا',
                            maxLines: 1,
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7D6B93))),
                  ),
                ),
              ),
              Semantics(label: word, child: const SizedBox(height: 1)),
            ]),
          );
        },
      );
}

class _DraggableLetter extends StatelessWidget {
  const _DraggableLetter({
    required this.index,
    required this.letter,
    required this.enabled,
  });

  final int index;
  final String letter;
  final bool enabled;

  Widget _tile({double opacity = 1}) => Opacity(
        opacity: opacity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFF8265B2), width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x228265B2),
                  blurRadius: 5,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: _CheckpointLetterGlyph(letter),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!enabled) return _tile(opacity: .24);
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 58, height: 50, child: _tile()),
      ),
      childWhenDragging: _tile(opacity: .25),
      child: _tile(),
    );
  }
}

class _MiniMatchCard extends StatelessWidget {
  const _MiniMatchCard(
      {required this.selected,
      required this.done,
      required this.wrong,
      required this.onTap,
      required this.child});
  final bool selected;
  final bool done;
  final bool wrong;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
            color: done ? const Color(0xFFE5F7EB) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: wrong
                    ? AppColors.danger
                    : done
                        ? AppColors.success
                        : selected
                            ? const Color(0xFF8265B2)
                            : const Color(0xFFD5CBE3),
                width: wrong || selected || done ? 3 : 2)),
        child: FeedbackTap(
            onTap: done ? null : onTap,
            child: Padding(padding: const EdgeInsets.all(3), child: child)),
      );
}
