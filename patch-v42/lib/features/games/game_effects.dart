import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio/interaction_audio.dart';

final gameEffectsFactoryProvider =
    Provider<GameEffects Function()>((ref) => GameEffects.new);

/// Screen-owned effects: no changes to lesson audio or shared tap assets.
class GameEffects {
  AudioPlayer? _right, _wrong;
  bool _closed = false;
  int _generation = 0;
  Future<void> prepare() async {
    try {
      final right = _right = AudioPlayer(handleAudioSessionActivation: false);
      final wrong = _wrong = AudioPlayer(handleAudioSessionActivation: false);
      await Future.wait([
        right.setAsset('assets/games/correct.wav'),
        wrong.setAsset('assets/games/try_again.wav'),
      ]);
      if (_closed) return;
      await right.setVolume(.45);
      await wrong.setVolume(.32);
    } catch (e) {
      debugPrint('Game effects unavailable: $e');
    }
  }

  Future<void> answer(bool correct) async {
    final generation = ++_generation;
    try {
      await _right?.pause();
      await _wrong?.pause();
      InteractionAudio.stopCelebration();
      if (_closed || generation != _generation) return;
      final player = correct ? _right : _wrong;
      await player?.seek(Duration.zero);
      if (_closed || generation != _generation) return;
      if (correct) unawaited(InteractionAudio.celebrate());
      await player?.play();
    } catch (e) {
      debugPrint('Game answer effect unavailable: $e');
    }
  }

  void stop() {
    _generation++;
    unawaited(_right?.pause());
    unawaited(_wrong?.pause());
    InteractionAudio.stopCelebration();
  }

  void dispose() {
    _closed = true;
    stop();
    unawaited(_right?.dispose());
    unawaited(_wrong?.dispose());
  }
}
