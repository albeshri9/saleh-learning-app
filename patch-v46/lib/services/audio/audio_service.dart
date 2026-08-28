import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// خدمة الصوت — واجهة موحدة لتشغيل أصوات صالح والمؤثرات والأناشيد.
///
/// [playing] تبث حالة التشغيل الفعلية لحظة بلحظة، وهي مصدر الحقيقة
/// الوحيد لحالة «talking» عند صالح: التنفيذ الحقيقي القادم (just_audio)
/// يرفعها عند بدء الملف ويسقطها عند انتهائه أو إيقافه، فلا يعتمد أي
/// مستهلك على مؤقتات ثابتة.
abstract interface class AudioService {
  Future<void> play(String assetPath);

  Future<void> stop();

  /// حالة التشغيل الحية: true من بداية الصوت حتى نهايته الفعلية.
  ValueListenable<bool> get playing;

  Future<void> dispose();
}

/// Optional playback clock for accurate visual cues; silent test/fallback
/// services can still implement AudioService without a real audio engine.
abstract interface class AudioClock {
  ValueListenable<Duration> get position;
  String? get activeAsset;
}

/// تنفيذ صامت مؤقت — لا توجد ملفات صوت بعد، لذا [playing] تبقى false
/// دائمًا، وبالتالي يبقى صالح idle أثناء الجمل (حسب قاعدة المرحلة:
/// لا صوت = لا talking). عند رفع الأصوات يُستبدل هذا الصف فقط.
class SilentAudioService implements AudioService {
  final ValueNotifier<bool> _playing = ValueNotifier(false);

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> play(String assetPath) async {
    debugPrint('[audio] play: $assetPath');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    _playing.dispose();
  }
}

/// مشغّل الأصول الصوتية الحقيقي.
///
/// لا يرفع [playing] إلا بعد أن يبدأ المشغّل فعليًا، ويعيده إلى false عند
/// الاكتمال أو الإيقاف أو فشل تحميل الأصل. لذلك تتزامن حركة فم صالح مع الصوت
/// نفسه، لا مع مدة تقديرية مكتوبة في محتوى الدرس.
class AssetAudioService implements AudioService, AudioClock {
  AssetAudioService() {
    _sessionReady = _configureSession();
    _stateSubscription = _player.playerStateStream.listen(
      _onPlayerState,
      onError: (Object error, StackTrace stackTrace) {
        _setPlaying(false);
        debugPrint('[audio] player error: $error');
      },
    );
    _positionSubscription =
        _player.positionStream.listen((value) => _position.value = value);
  }

  final AudioPlayer _player = AudioPlayer();
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  late final StreamSubscription<Duration> _positionSubscription;
  String? _activeAsset;
  @override
  ValueListenable<Duration> get position => _position;
  @override
  String? get activeAsset => _activeAsset;
  late final Future<void> _sessionReady;
  AudioSession? _session;
  late final StreamSubscription<PlayerState> _stateSubscription;
  int _requestId = 0;

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    // وضع playback يجعل الشرح مسموعًا من سماعة الجهاز على iOS، ويمنع
    // تحويل تعليق الدرس إلى مسار المكالمات/السماعة العلوية الهادئة.
    await session.configure(const AudioSessionConfiguration.music());
    _session = session;
  }

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> play(String assetPath) async {
    final requestId = ++_requestId;
    try {
      await _sessionReady;
      if (requestId != _requestId) return;
      await _session?.setActive(true);
      if (requestId != _requestId) return;
      await _player.stop();
      if (requestId != _requestId) return;
      _activeAsset = assetPath;
      _position.value = Duration.zero;
      await _player.setVolume(1);
      if (requestId != _requestId) return;
      await _player.setAsset(assetPath);
      if (requestId != _requestId) return;
      await _player.play();
    } catch (error) {
      if (requestId == _requestId) _setPlaying(false);
      debugPrint('[audio] failed to play $assetPath: $error');
    }
  }

  @override
  Future<void> stop() async {
    _requestId++;
    _setPlaying(false);
    await _player.stop();
  }

  void _onPlayerState(PlayerState state) {
    final isAudible = state.playing &&
        state.processingState != ProcessingState.completed &&
        state.processingState != ProcessingState.idle;
    _setPlaying(isAudible);
  }

  void _setPlaying(bool value) {
    if (_playing.value != value) _playing.value = value;
  }

  @override
  Future<void> dispose() async {
    _requestId++;
    await _stateSubscription.cancel();
    await _positionSubscription.cancel();
    await _player.dispose();
    _playing.dispose();
    _position.dispose();
  }
}
