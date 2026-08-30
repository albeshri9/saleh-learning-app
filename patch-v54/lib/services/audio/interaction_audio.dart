import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// Independent effects players never replace the narrator's audio source.
class InteractionAudio {
  static AudioPlayer? _tap;
  static AudioPlayer? _applause;
  static bool _tapBusy = false;
  static Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      _tap = AudioPlayer(
          handleAudioSessionActivation: false, handleInterruptions: false);
      _applause = AudioPlayer(
          handleAudioSessionActivation: false, handleInterruptions: false);
      await Future.wait([
        _tap!.setAsset('assets/audio/ui_tap_gentle_v54.mp3'),
        _applause!.setAsset('assets/audio/assessment_applause_user.mp3'),
      ]);
      await _tap!.setVolume(.30);
      // This recording is already quiet: measured mean -32.9 dB vs narrator
      // -13.4 dB. Keep it audible but below narration, including its peaks.
      await _applause!.setVolume(.65);
    } catch (error) {
      debugPrint('Effects unavailable: $error');
    }
  }

  static Future<void> tap() async {
    final player = _tap;
    if (player == null || _tapBusy) return;
    _tapBusy = true;
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (error) {
      debugPrint('Tap effect: $error');
    } finally {
      _tapBusy = false;
    }
  }

  static Future<void> celebrate() async {
    try {
      await _applause?.seek(Duration.zero);
      await _applause?.play();
    } catch (error) {
      debugPrint('Applause: $error');
    }
  }

  static void stopCelebration() {
    unawaited(_applause?.pause());
  }
}
