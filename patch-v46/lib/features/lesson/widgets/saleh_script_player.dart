import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_card.dart';
import '../../../domain/models/child_profile.dart';
import '../../../domain/models/saleh_script.dart';
import '../../../domain/models/timeline_event.dart';
import '../../../services/audio/audio_service.dart';

/// مشغّل سكربت صالح — قلب نظام التزامن.
///
/// يعرض جمل صالح واحدة تلو الأخرى في فقاعة كلام، يشغّل صوت كل جملة
/// (إن وجد)، ويطلق أحداث الخط الزمني [TimelineEvent] في توقيتها
/// ليتفاعل معها المشهد (إظهار حرف، نبض، رسم مسار...).
class SalehScriptPlayer extends ConsumerStatefulWidget {
  const SalehScriptPlayer({
    super.key,
    required this.lines,
    required this.profile,
    this.tailDirection = SpeechTailDirection.down,
    this.onEvent,
    this.onFinished,
    this.compact = false,
    this.onNarratingChanged,
    this.stopSignal,
  });

  final List<SalehLine> lines;
  final ChildProfile profile;

  /// اتجاه ذيل الفقاعة نحو صالح (يختلف بين تخطيط الهاتف والشاشات الواسعة).
  final SpeechTailDirection tailDirection;
  final void Function(TimelineEvent event)? onEvent;
  final VoidCallback? onFinished;
  final bool compact;
  final ValueChanged<bool>? onNarratingChanged;
  final ValueListenable<bool>? stopSignal;

  @override
  ConsumerState<SalehScriptPlayer> createState() => _SalehScriptPlayerState();
}

class _SalehScriptPlayerState extends ConsumerState<SalehScriptPlayer> {
  int _lineIndex = -1;
  final List<Timer> _timers = [];
  bool _finished = false;
  bool _interrupted = false;
  int _playGeneration = 0;
  late final AudioService _audio;
  VoidCallback? _removeClock;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    _interrupted = widget.stopSignal?.value ?? false;
    widget.stopSignal?.addListener(_interrupt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // iOS may ignore playback requested in the same frame that creates the
      // route. Give the audio session and the first scene time to become active.
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) unawaited(_playLine(0));
      });
    });
  }

  @override
  void dispose() {
    widget.stopSignal?.removeListener(_interrupt);
    _removeClock?.call();
    for (final t in _timers) {
      t.cancel();
    }
    _playGeneration++;
    unawaited(_audio.stop());
    widget.onNarratingChanged?.call(false);
    super.dispose();
  }

  Future<void> _playLine(int index) async {
    if (!mounted || _interrupted) return;
    if (index >= widget.lines.length) {
      widget.onNarratingChanged?.call(false);
      setState(() => _finished = true);
      widget.onFinished?.call();
      return;
    }
    setState(() => _lineIndex = index);
    widget.onNarratingChanged?.call(true);

    // حالة talking لا تُدار من هنا: تشغيل الصوت عبر AudioService هو ما
    // يقودها (انظر SalehCharacterController) — لا مؤقتات ثابتة للكلام.
    final line = widget.lines[index];
    final generation = ++_playGeneration;
    _removeClock?.call();
    _removeClock = null;
    if (_audio is AudioClock && line.audio != null) {
      final clock = _audio as AudioClock;
      final fired = <int>{};
      void onPosition() {
        if (!mounted ||
            generation != _playGeneration ||
            clock.activeAsset != line.audio) {
          return;
        }
        for (var i = 0; i < line.events.length; i++) {
          if (!fired.contains(i) && clock.position.value >= line.events[i].at) {
            fired.add(i);
            widget.onEvent?.call(line.events[i]);
          }
        }
      }

      clock.position.addListener(onPosition);
      _removeClock = () => clock.position.removeListener(onPosition);
    } else {
      for (final event in line.events) {
        _timers.add(Timer(event.at, () {
          if (mounted && generation == _playGeneration) {
            widget.onEvent?.call(event);
          }
        }));
      }
    }
    if (line.audio != null) {
      // مدة الملف الفعلية هي مصدر التوقيت. انتظارها يمنع السطر التالي أو
      // انتقال المشهد من إيقاف الترحيب والشرح قبل أن يصبحا مسموعين.
      await _playNarrationReliably(line.audio!);
    } else {
      await _audio.stop();
      await Future<void>.delayed(line.duration);
    }
    if (!mounted || generation != _playGeneration) return;
    _removeClock?.call();
    _removeClock = null;
    await _playLine(index + 1);
  }

  Future<void> _playNarrationReliably(String asset) async {
    var completed = false;
    var started = false;
    void observePlayback() {
      if (_audio.playing.value) started = true;
    }

    _audio.playing.addListener(observePlayback);
    try {
      var playback = _audio.play(asset).whenComplete(() => completed = true);

      // If AVAudioSession was still activating, the first request can remain
      // silent without failing. Retry once only when playback never started.
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted || _interrupted) return;
      // A short clip that actually played must not be mistaken for a silent
      // startup failure and repeated before the first assessment question.
      if (completed && started) return;
      if (!completed && _audio.playing.value) {
        await playback;
        return;
      }
      if (!_audio.playing.value) {
        playback = _audio.play(asset);
      }
      await playback;
    } finally {
      _audio.playing.removeListener(observePlayback);
    }
  }

  void _interrupt() {
    if (!mounted || widget.stopSignal?.value != true || _interrupted) return;
    _interrupted = true;
    _playGeneration++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _removeClock?.call();
    _removeClock = null;
    widget.onNarratingChanged?.call(false);
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_lineIndex < 0 || widget.lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final line = widget.lines[_lineIndex.clamp(0, widget.lines.length - 1)];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: SpeechBubble(
        key: ValueKey(_finished ? 'done_$_lineIndex' : _lineIndex),
        tail: widget.tailDirection,
        compact: widget.compact,
        child: Text(
          line.resolve(widget.profile),
          maxLines: widget.compact ? 3 : null,
          overflow: widget.compact ? TextOverflow.ellipsis : null,
          style: AppTypography.speech.copyWith(
            fontSize: widget.compact ? 13.5 : null,
            height: widget.compact ? 1.18 : null,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
