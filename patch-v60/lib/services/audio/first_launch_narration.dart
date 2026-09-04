import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays the short product introduction once, without ever gating the UI.
///
/// The child or parent can press any button while the introduction is playing.
/// Navigation is deliberately independent from this player's lifecycle.
class FirstLaunchNarration {
  static const preferenceKey = 'first_launch_welcome_v55_played';
  static const asset = 'assets/audio/first_launch_welcome_v55.mp3';

  AudioPlayer? _player;

  Future<void> playOnce() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(preferenceKey) == true) return;
      // Widget tests do not provide just_audio's native method channel.
      if (Platform.environment['FLUTTER_TEST'] == 'true') return;
      final player = AudioPlayer(
        handleAudioSessionActivation: false,
        handleInterruptions: false,
      );
      await player.setAsset(asset);
      _player = player;
      await player.setVolume(.92);
      await preferences.setBool(preferenceKey, true);
      unawaited(player.play());
    } catch (error) {
      debugPrint('First-launch narration unavailable: $error');
    }
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    await player?.dispose();
  }
}
