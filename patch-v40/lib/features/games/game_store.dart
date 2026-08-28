import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../home/learning_journal.dart';

/// The child identity is captured when the game opens, never on completion.
/// No lesson/family key is changed. Replaying a result is idempotent.
class GameStore {
  GameStore(this.childId);
  final String childId;
  String get key => 'games_v1_$childId';
  static final Map<String, Future<void>> _pending = {};
  Future<Map<String, dynamic>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> save(String gameId,
      {required int nextRound,
      required int mistakes,
      required int hints,
      required bool complete}) {
    final future = (_pending[key] ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final all = await load();
      final old = Map<String, dynamic>.from(all[gameId] as Map? ?? {});
      all[gameId] = {
        'round': nextRound,
        'mistakes': mistakes,
        'hints': hints,
        'completed': complete || old['completed'] == true,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (!await prefs.setString(key, jsonEncode(all))) {
        throw StateError('Game progress was not saved');
      }
      // Stable reward key shared across retries and later app versions.
      if (complete) {
        await LearningJournal(childId).award('game:worlds:$gameId', 15);
      }
    });
    _pending[key] = future;
    return future.whenComplete(() {
      if (identical(_pending[key], future)) _pending.remove(key);
    });
  }
}
