import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'game_catalog.dart';

class GameSession extends ChangeNotifier {
  GameSession(this.game, {int round = 0, Random? random})
      : _random = random ?? Random(),
        roundIndex = round {
    _load();
  }
  final GameSpec game;
  final Random _random;
  int roundIndex, mistakes = 0, hints = 0;
  late GameRound data;
  late List<GameItem> items;
  final selected = <String>[], matched = <String>{};
  final placed = <int, int>{};
  final commands = <int>[];
  List<int> bins = [0, 0, 0], rotations = [];
  int count = 0, tens = 0, ones = 0, position = 0;
  String feedback = '';
  int feedbackSerial = 0;
  bool feedbackCorrect = false;
  final correctIds = <String>{}, wrongIds = <String>{};
  bool solved = false, busy = false, disposed = false;
  Timer? _timer;
  int get roundCount => game.roundCount;
  bool get complete => solved && roundIndex == roundCount - 1;
  void _load() {
    data = roundFor(game, roundIndex);
    items = shuffledItems(data.items, _random);
    selected.clear();
    correctIds.clear();
    wrongIds.clear();
    matched.clear();
    placed.clear();
    commands.clear();
    bins = [0, 0, 0];
    rotations = [...data.grid];
    count = data.start;
    tens = 0;
    ones = 0;
    position = 0;
    feedback = '';
    solved = false;
    busy = false;
  }

  void resetRound() {
    _timer?.cancel();
    _load();
    notifyListeners();
  }

  void next() {
    if (!solved || roundIndex >= roundCount - 1) return;
    roundIndex++;
    _load();
    notifyListeners();
  }

  void retry() {
    roundIndex = 0;
    mistakes = 0;
    hints = 0;
    resetRound();
  }

  void hint() {
    if (solved) return;
    hints++;
    feedback = data.hint.isEmpty ? data.caption : data.hint;
    notifyListeners();
  }

  void fail([String message = 'لنجرّب مرة أخرى، خذ وقتك']) {
    if (solved) return;
    mistakes++;
    feedbackSerial++;
    feedbackCorrect = false;
    feedback = message;
    notifyListeners();
  }

  void win() {
    if (solved) return;
    solved = true;
    busy = false;
    feedback = 'أحسنت! ${game.skill}';
    feedbackSerial++;
    feedbackCorrect = true;
    wrongIds.clear();
    notifyListeners();
  }

  void encourage() {
    feedbackSerial++;
    feedbackCorrect = true;
    wrongIds.clear();
    feedback = 'أحسنت! واصل الاكتشاف';
    notifyListeners();
  }

  void choose(GameItem item) {
    if (solved || busy) return;
    if (game.kind == PlayKind.memory) {
      _flip(item);
      return;
    }
    if (game.kind == PlayKind.order) {
      if (selected.contains(item.id)) return;
      selected.add(item.id);
      notifyListeners();
      return;
    }
    if (data.answer.contains(item.id)) {
      if (correctIds.contains(item.id)) return;
      correctIds.add(item.id);
      wrongIds.clear();
      if (game.kind == PlayKind.collect) {
        if (selected.contains(item.id)) return;
        selected.add(item.id);
        if (selected.length == data.answer.length) {
          win();
        } else {
          encourage();
        }
      } else {
        win();
      }
    } else {
      wrongIds
        ..clear()
        ..add(item.id);
      fail();
    }
  }

  void undo() {
    if (solved || busy) return;
    if (selected.isNotEmpty) selected.removeLast();
    notifyListeners();
  }

  void checkOrder() {
    if (solved || busy) return;
    if (listEquals(selected, data.answer)) {
      win();
    } else {
      fail('راجع الترتيب. يمكنك التراجع عن آخر قطعة');
    }
  }

  void _flip(GameItem item) {
    if (selected.contains(item.id) || matched.contains(item.id)) return;
    selected.add(item.id);
    notifyListeners();
    if (selected.length < 2) return;
    if (selected[0].substring(1) == selected[1].substring(1)) {
      matched.addAll(selected);
      correctIds.addAll(selected);
      selected.clear();
      if (matched.length == items.length) {
        win();
      } else {
        encourage();
      }
    } else {
      busy = true;
      wrongIds
        ..clear()
        ..addAll(selected);
      fail('تذكر مكان الصورة والكلمة');
      _timer = Timer(const Duration(milliseconds: 950), () {
        if (disposed) return;
        selected.clear();
        wrongIds.clear();
        busy = false;
        feedback = 'تذكر مكان الصورة والكلمة';
        notifyListeners();
      });
    }
  }

  void adjustCount(int delta) {
    if (solved) return;
    count = (count + delta).clamp(0, game.id == 'measure' ? 6 : 12);
    notifyListeners();
  }

  void checkCount() {
    if (solved) return;
    if (count == data.target) {
      win();
    } else {
      fail('عدّ العناصر مرة أخرى');
    }
  }

  void distribute(int bin, {bool remove = false}) {
    if (solved) return;
    final total = bins.fold(0, (a, b) => a + b);
    if (remove) {
      if (bins[bin] > 0) bins[bin]--;
    } else if (total < data.target) {
      bins[bin]++;
    }
    notifyListeners();
  }

  void checkDistribution() {
    if (solved) return;
    if (bins.every((n) => n == data.b)) {
      win();
    } else {
      fail('لكل طبق العدد نفسه');
    }
  }

  void adjustValue(bool big, int delta) {
    if (solved) return;
    if (big) {
      tens = (tens + delta).clamp(0, 4);
    } else {
      ones = (ones + delta).clamp(0, 12);
    }
    notifyListeners();
  }

  void checkValue() {
    if (solved) return;
    if (tens * data.a + ones * data.b == data.target) {
      win();
    } else {
      fail('عدّ قيمة القطع، وليس عددها فقط');
    }
  }

  void sortInto(GameItem item, int bin) {
    if (solved || matched.contains(item.id)) return;
    final expected = data.a == 1 ? item.tone : item.shape;
    if (expected == bin) {
      matched.add(item.id);
      correctIds.add(item.id);
      bins[bin]++;
      if (matched.length == items.length) {
        win();
      } else {
        encourage();
      }
    } else {
      wrongIds
        ..clear()
        ..add(item.id);
      fail('انظر إلى قاعدة الفرز');
    }
  }

  void putPiece(int piece, int slot) {
    if (solved || placed.containsValue(piece) || placed.containsKey(slot)) {
      return;
    }
    // Mosaic interchangeable squares/triangles may fill either equal slot.
    final valid = game.kind == PlayKind.mosaic
        ? data.grid[piece] == data.grid[slot]
        : piece == slot;
    if (valid) {
      placed[slot] = piece;
      if (placed.length == 4) {
        win();
      } else {
        encourage();
      }
    } else {
      fail('جرّب مكانًا آخر لهذه القطعة');
    }
  }

  void toggleMirror(int index) {
    if (solved) return;
    if (placed.containsKey(index)) {
      placed.remove(index);
    } else {
      placed[index] = 1;
    }
    notifyListeners();
  }

  void checkMirror() {
    if (solved) return;
    final expected = <int>{
      for (var i = 0; i < 6; i++)
        if (data.grid[i] == 1) (i ~/ 2) * 2 + (1 - i % 2)
    };
    if (setEquals(placed.keys.toSet(), expected)) {
      win();
    } else {
      fail('قارن الخانات القريبة من خط المرآة');
    }
  }

  void move(int target) {
    if (solved || busy) return;
    if (!adjacent(position, target, 4) || !data.grid.contains(target)) {
      fail('اختر مربعًا مجاورًا على الطريق');
      return;
    }
    position = target;
    if (position == data.target) {
      win();
    } else {
      notifyListeners();
    }
  }

  void rotate(int i) {
    if (solved) return;
    rotations[i] = (rotations[i] + 1) % 4;
    notifyListeners();
  }

  void checkPipes() {
    if (solved) return;
    if (rotations.every((r) => r % 2 == 0)) {
      win();
    } else {
      fail('فتحات كل قطعة يجب أن تصل بالقطعة المجاورة');
    }
  }

  void bridge(int length) {
    if (solved) return;
    if (count + length > data.target) {
      fail('هذه القطعة أطول من المساحة الباقية');
      return;
    }
    commands.add(length);
    count += length;
    notifyListeners();
  }

  void undoBridge() {
    if (solved) return;
    if (commands.isNotEmpty) count -= commands.removeLast();
    notifyListeners();
  }

  void addCommand(int command) {
    if (solved || busy || commands.length >= 12) return;
    commands.add(command);
    notifyListeners();
  }

  void undoCommand() {
    if (solved || busy) return;
    if (commands.isNotEmpty) commands.removeLast();
    notifyListeners();
  }

  void runRobot() {
    if (solved || busy) return;
    if (commands.isEmpty) {
      fail('أضف خطوة أولًا');
      return;
    }
    busy = true;
    position = 0;
    var index = 0;
    notifyListeners();
    _timer = Timer.periodic(const Duration(milliseconds: 420), (timer) {
      if (disposed) {
        timer.cancel();
        return;
      }
      if (index == commands.length) {
        timer.cancel();
        busy = false;
        if (position == data.target) {
          win();
        } else {
          fail('وصل الروبوت هنا. عدّل الخطة ثم جرّب');
        }
        return;
      }
      final next = robotStep(position, commands[index++]);
      if (next < 0 || !data.grid.contains(next)) {
        timer.cancel();
        busy = false;
        fail('هناك عائق. عدّل خطوات الروبوت');
        return;
      }
      position = next;
      notifyListeners();
    });
  }

  void pause() {
    _timer?.cancel();
    busy = false;
    if (game.kind == PlayKind.memory) selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
