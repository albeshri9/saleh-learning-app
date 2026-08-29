import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_catalog.dart';
import 'game_stickers.dart';

const _phasePurple = Color(0xFF8662CF);
const _phaseMint = Color(0xFF61B9A5);
const _phaseGold = Color(0xFFE6B44A);

const firstPhaseGameIds = <String>{
  'picture_word',
  'letter_basket',
  'build_word',
  'word_memory',
  'letter_lens',
  'feed_rabbit',
  'number_picture',
  'compare',
  'add',
  'share',
  'sort',
  'jigsaw',
  'pattern',
  'maze',
  'tangram',
};

extension FirstPhaseSpec on GameSpec {
  bool get isFirstPhase => firstPhaseGameIds.contains(id);
}

class FirstPhaseThumbnail extends StatelessWidget {
  const FirstPhaseThumbnail(this.game, {super.key});
  final GameSpec game;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFF7DF),
                [
                  const Color(0xFFEAE0FA),
                  const Color(0xFFDFF3ED),
                  const Color(0xFFFFEAD1)
                ][game.world.index]
              ]),
          borderRadius: BorderRadius.circular(18)),
      child: Stack(alignment: Alignment.center, children: [
        if (game.id == 'picture_word') SalehSticker(game.art),
        if (game.id == 'letter_basket') ...[
          const Positioned(
              top: 5, left: 12, width: 42, height: 42, child: SalehSticker(0)),
          const Positioned(
              top: 7,
              right: 16,
              width: 38,
              height: 38,
              child: SalehSticker(14)),
          const Positioned(
              bottom: 5,
              child: Icon(Icons.shopping_basket_rounded,
                  size: 58, color: Color(0xFFC18349)))
        ],
        if (game.id == 'build_word') _trainMini(),
        if (game.id == 'word_memory') _memoryMini(),
        if (game.id == 'letter_lens') ...[
          const SizedBox(width: 65, height: 65, child: SalehSticker(8)),
          const Icon(Icons.search_rounded, size: 96, color: Color(0x996E91C8))
        ],
        if (game.id == 'feed_rabbit')
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 72, height: 90, child: SalehSticker(1)),
            SizedBox(width: 45, height: 70, child: SalehSticker(6))
          ]),
        if (game.id == 'number_picture') _numberMini(),
        if (game.id == 'compare') _scaleMini(),
        if (game.id == 'add') _addMini(),
        if (game.id == 'share') _shareMini(),
        if (game.id == 'sort') _sortMini(),
        if (game.id == 'jigsaw') _puzzleMini(),
        if (game.id == 'pattern') _patternMini(),
        if (game.id == 'maze') _mazeMini(),
        if (game.id == 'tangram') _tangramMini(),
      ]));

  Widget _trainMini() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.train_rounded, color: Color(0xFF4A91A5), size: 48),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final l in ['ب', 'ا', 'ب'])
            Container(
                width: 29,
                height: 29,
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFFE98C78),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(l,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)))
        ])
      ]);
  Widget _memoryMini() => Wrap(alignment: WrapAlignment.center, children: [
        for (var i = 0; i < 4; i++)
          Container(
              width: 42,
              height: 48,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: i == 0 ? Colors.white : const Color(0xFF8662CF),
                  borderRadius: BorderRadius.circular(10)),
              child: i == 0
                  ? const SalehSticker(7)
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.white))
      ]);
  Widget _numberMini() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xFF208C80), shape: BoxShape.circle),
            child: const Text('٣',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold))),
        const SizedBox(width: 5),
        ...List.generate(
            3,
            (_) =>
                const SizedBox(width: 27, height: 35, child: SalehSticker(4)))
      ]);
  Widget _scaleMini() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Text('٣',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
          Text('٥', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold))
        ]),
        Container(width: 120, height: 5, color: const Color(0xFF588A8A)),
        Container(width: 7, height: 42, color: const Color(0xFF588A8A))
      ]);
  Widget _addMini() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final t in ['٢', '+', '٢', '=', '٤'])
          Padding(
              padding: const EdgeInsets.all(3),
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 24,
                      color: Color(0xFF208C80),
                      fontWeight: FontWeight.bold)))
      ]);
  Widget _shareMini() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 3; i++)
          Container(
              width: 45,
              height: 45,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: [_phasePurple, _phaseMint, _phaseGold][i],
                      width: 4)),
              child: const SalehSticker(4))
      ]);
  Widget _sortMini() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final c in [_phasePurple, _phaseGold])
          Container(
              width: 55,
              height: 65,
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: .25),
                  border: Border.all(color: c, width: 3),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.category_rounded, color: c, size: 30))
      ]);
  Widget _puzzleMini() => GridView.count(
          padding: const EdgeInsets.all(18),
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          children: [
            for (var i = 0; i < 4; i)
              Container(
                  margin: const EdgeInsets.all(2),
                  color: [
                    _phasePurple,
                    _phaseMint,
                    _phaseGold,
                    const Color(0xFFE98C78)
                  ][i]
                      .withValues(alpha: .75),
                  child: const Icon(Icons.extension_rounded,
                      color: Colors.white, size: 20))
          ]);
  Widget _patternMini() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final c in [_phasePurple, _phaseGold, _phasePurple, _phaseGold])
          Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const Text('؟',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
      ]);
  Widget _mazeMini() => Stack(children: [
        CustomPaint(
            painter: _MazeMiniPainter(), child: const SizedBox.expand()),
        const Positioned(
            right: 8, bottom: 4, width: 48, height: 55, child: SalehSticker(9)),
        Positioned(
            left: 8,
            top: 4,
            width: 35,
            height: 65,
            child: Image.asset('assets/character/saleh_idle.png'))
      ]);
  Widget _tangramMini() => Center(
      child: CustomPaint(
          painter: _TangramMiniPainter(),
          child: const SizedBox(width: 105, height: 85)));
}

class _MazeMiniPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(28, s.height - 15)
      ..cubicTo(s.width * .25, s.height * .25, s.width * .7, s.height * .8,
          s.width - 34, 34);
    c.drawPath(
        p,
        Paint()
          ..color = const Color(0xFFE6B44A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TangramMiniPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final roof = Path()
      ..moveTo(5, 42)
      ..lineTo(s.width / 2, 4)
      ..lineTo(s.width - 5, 42)
      ..close();
    c.drawPath(roof, Paint()..color = _phasePurple);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(18, 42, s.width - 36, s.height - 44),
            const Radius.circular(5)),
        Paint()..color = _phaseGold);
    c.drawRect(Rect.fromLTWH(s.width / 2 - 9, s.height - 31, 18, 29),
        Paint()..color = const Color(0xFF61B9A5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Each flagship game gets a distinct place while retaining Saleh's palette.
class FirstPhaseScene extends StatelessWidget {
  const FirstPhaseScene({super.key, required this.game, required this.child});
  final GameSpec game;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!game.isFirstPhase) return child;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: CustomPaint(
        painter: _ScenePainter(game.id),
        child: Padding(padding: const EdgeInsets.all(7), child: child),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.id);
  final String id;
  static const purple = Color(0xFF8662CF),
      mint = Color(0xFF61B9A5),
      gold = Color(0xFFE6B44A);
  Paint p(Color color) => Paint()..color = color;
  @override
  void paint(Canvas c, Size s) {
    final palette = switch (id) {
      'picture_word' => const [Color(0xFFFFF1C9), Color(0xFFDDF3CF)],
      'letter_basket' => const [Color(0xFFE8F5D8), Color(0xFFFFE6B8)],
      'build_word' => const [Color(0xFFDDF1F4), Color(0xFFF1E4FA)],
      'word_memory' => const [Color(0xFFF4E0C5), Color(0xFFEBD7BA)],
      'letter_lens' => const [Color(0xFFDDEAF9), Color(0xFFE8E2FA)],
      'feed_rabbit' => const [Color(0xFFDDF1D4), Color(0xFFFFEDC8)],
      'number_picture' => const [Color(0xFFE1F5F0), Color(0xFFFFF0C9)],
      'compare' => const [Color(0xFFE9F5F0), Color(0xFFD9EBF6)],
      'add' => const [Color(0xFFFFE8D1), Color(0xFFFFF4C7)],
      'share' => const [Color(0xFFDDF3EC), Color(0xFFF9E7C8)],
      'sort' => const [Color(0xFFE3E1F7), Color(0xFFD9F1EA)],
      'jigsaw' => const [Color(0xFFF1D7B4), Color(0xFFE1B98C)],
      'pattern' => const [Color(0xFFE7E3FA), Color(0xFFFFE8C5)],
      'maze' => const [Color(0xFFDDF2D4), Color(0xFFCFE9C7)],
      _ => const [Color(0xFFE4ECFA), Color(0xFFD9E6F5)],
    };
    c.drawRect(
        Offset.zero & s,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette)
              .createShader(Offset.zero & s));
    switch (id) {
      case 'picture_word':
        _garden(c, s);
        break;
      case 'letter_basket':
        _orchard(c, s);
        break;
      case 'build_word':
        _rails(c, s);
        break;
      case 'word_memory':
        _table(c, s);
        break;
      case 'letter_lens':
        _library(c, s);
        break;
      case 'feed_rabbit':
        _garden(c, s, carrots: true);
        break;
      case 'number_picture':
        _abacus(c, s);
        break;
      case 'compare':
        _scale(c, s);
        break;
      case 'add':
        _market(c, s);
        break;
      case 'share':
        _picnic(c, s);
        break;
      case 'sort':
        _shelves(c, s);
        break;
      case 'jigsaw':
        _table(c, s, wood: true);
        break;
      case 'pattern':
        _garland(c, s);
        break;
      case 'maze':
        _forest(c, s);
        break;
      case 'tangram':
        _blueprint(c, s);
        break;
    }
  }

  void _garden(Canvas c, Size s, {bool carrots = false}) {
    c.drawRect(Rect.fromLTWH(0, s.height * .72, s.width, s.height * .28),
        p(const Color(0xFF8BCB72).withValues(alpha: .38)));
    for (var i = 0; i < 9; i++) {
      final x = s.width * (i + .5) / 9, y = s.height - 9 - (i % 3) * 3;
      c.drawLine(
          Offset(x, y),
          Offset(x, y - 10),
          Paint()
            ..color = const Color(0xFF4F9D62)
            ..strokeWidth = 2);
      c.drawCircle(Offset(x - 3, y - 11), 3,
          p([const Color(0xFFF39A9A), gold, purple][i % 3]));
      c.drawCircle(Offset(x + 3, y - 11), 3,
          p([gold, purple, const Color(0xFFF39A9A)][i % 3]));
      if (carrots && i.isEven) {
        c.drawPath(
            Path()
              ..moveTo(x - 3, y)
              ..lineTo(x + 3, y)
              ..lineTo(x, y + 8)
              ..close(),
            p(const Color(0xFFF18432)));
      }
    }
    for (final x in [20.0, s.width - 20]) {
      c.drawCircle(Offset(x, 32), 20, p(Colors.white.withValues(alpha: .28)));
    }
  }

  void _orchard(Canvas c, Size s) {
    for (final x in [22.0, s.width - 22]) {
      c.drawRect(Rect.fromLTWH(x - 3, 20, 6, s.height * .62),
          p(const Color(0xFF8D6543).withValues(alpha: .28)));
      c.drawCircle(
          Offset(x, 27), 25, p(const Color(0xFF69AB62).withValues(alpha: .24)));
      for (var i = 0; i < 4; i++) {
        c.drawCircle(Offset(x - 10 + i * 7, 20 + (i % 2) * 8), 3,
            p(const Color(0xFFE85D57).withValues(alpha: .55)));
      }
    }
    final basket = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(s.width / 2, s.height - 10), width: 110, height: 30),
        const Radius.circular(12));
    c.drawRRect(basket, p(const Color(0xFFC89455).withValues(alpha: .25)));
  }

  void _rails(Canvas c, Size s) {
    for (final y in [s.height - 20, s.height - 9]) {
      c.drawLine(
          Offset(0, y),
          Offset(s.width, y),
          Paint()
            ..color = const Color(0xFF698A91).withValues(alpha: .3)
            ..strokeWidth = 3);
    }
    for (var x = 0.0; x < s.width; x += 24) {
      c.drawLine(
          Offset(x, s.height - 25),
          Offset(x + 6, s.height - 4),
          Paint()
            ..color = const Color(0xFF8D6B4F).withValues(alpha: .25)
            ..strokeWidth = 4);
    }
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(25 + i * (s.width - 50) / 4, 20), 8,
          p([purple, mint, gold][i % 3].withValues(alpha: .12)));
    }
  }

  void _table(Canvas c, Size s, {bool wood = false}) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(5, 8, s.width - 10, s.height - 16),
            const Radius.circular(24)),
        p((wood ? const Color(0xFFB77A49) : const Color(0xFFE2B96F))
            .withValues(alpha: .18)));
    for (var y = 24.0; y < s.height; y += 35) {
      c.drawLine(
          Offset(8, y),
          Offset(s.width - 8, y + 5),
          Paint()
            ..color = const Color(0xFF8E6748).withValues(alpha: .08)
            ..strokeWidth = 2);
    }
  }

  void _library(Canvas c, Size s) {
    for (final x in [10.0, s.width - 18]) {
      for (var y = 25.0; y < s.height - 20; y += 22) {
        c.drawRect(Rect.fromLTWH(x, y, 8, 18),
            p([purple, mint, gold][(y ~/ 22) % 3].withValues(alpha: .18)));
      }
    }
    c.drawCircle(
        Offset(s.width / 2, s.height / 2),
        math.min(s.width, s.height) * .42,
        Paint()
          ..color = Colors.white.withValues(alpha: .11)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
  }

  void _abacus(Canvas c, Size s) {
    for (var y = 26.0; y < s.height - 20; y += 25) {
      c.drawLine(
          Offset(12, y),
          Offset(s.width - 12, y),
          Paint()
            ..color = mint.withValues(alpha: .16)
            ..strokeWidth = 3);
      for (var i = 0; i < 5; i++) {
        c.drawCircle(Offset(28 + i * 17, y), 6,
            p([purple, mint, gold][i % 3].withValues(alpha: .18)));
      }
    }
  }

  void _scale(Canvas c, Size s) {
    c.drawLine(
        Offset(s.width / 2, 20),
        Offset(s.width / 2, s.height - 6),
        Paint()
          ..color = const Color(0xFF527E83).withValues(alpha: .22)
          ..strokeWidth = 7);
    c.drawLine(
        Offset(s.width * .2, 44),
        Offset(s.width * .8, 44),
        Paint()
          ..color = const Color(0xFF527E83).withValues(alpha: .22)
          ..strokeWidth = 5);
    for (final x in [s.width * .25, s.width * .75]) {
      c.drawArc(
          Rect.fromCenter(center: Offset(x, 72), width: 90, height: 45),
          0,
          math.pi,
          false,
          Paint()
            ..color = gold.withValues(alpha: .16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
    }
  }

  void _market(Canvas c, Size s) {
    for (var i = 0; i < 6; i++) {
      final x = i * s.width / 5;
      c.drawPath(
          Path()
            ..moveTo(x, 0)
            ..lineTo(x + s.width / 10, 18)
            ..lineTo(x + s.width / 5, 0)
            ..close(),
          p([const Color(0xFFE7796F), const Color(0xFFFFD47A)][i % 2]
              .withValues(alpha: .35)));
    }
    c.drawRect(Rect.fromLTWH(0, s.height - 18, s.width, 18),
        p(const Color(0xFFBA8151).withValues(alpha: .18)));
  }

  void _picnic(Canvas c, Size s) {
    for (var y = 0.0; y < s.height; y += 28) {
      for (var x = 0.0; x < s.width; x += 28) {
        c.drawRect(Rect.fromLTWH(x, y, 14, 14),
            p(const Color(0xFFE99191).withValues(alpha: .07)));
      }
    }
  }

  void _shelves(Canvas c, Size s) {
    for (var y = 35.0; y < s.height; y += 55) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, 6),
          p(const Color(0xFF87634B).withValues(alpha: .15)));
    }
  }

  void _garland(Canvas c, Size s) {
    final path = Path()
      ..moveTo(10, 25)
      ..quadraticBezierTo(s.width / 2, 60, s.width - 10, 25);
    c.drawPath(
        path,
        Paint()
          ..color = purple.withValues(alpha: .2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    for (var i = 0; i < 9; i++) {
      c.drawCircle(
          Offset(
              18 + i * (s.width - 36) / 8, 28 + 12 * math.sin(i * math.pi / 8)),
          5,
          p([purple, mint, gold][i % 3].withValues(alpha: .25)));
    }
  }

  void _forest(Canvas c, Size s) {
    for (final x in [15.0, s.width - 15]) {
      for (var y = 25.0; y < s.height; y += 38) {
        c.drawRect(Rect.fromLTWH(x - 2, y, 4, 24),
            p(const Color(0xFF805B43).withValues(alpha: .16)));
        c.drawCircle(Offset(x, y), 13,
            p(const Color(0xFF4F9B61).withValues(alpha: .18)));
      }
    }
  }

  void _blueprint(Canvas c, Size s) {
    for (var x = 0.0; x < s.width; x += 25) {
      c.drawLine(
          Offset(x, 0),
          Offset(x, s.height),
          Paint()
            ..color = Colors.white.withValues(alpha: .16)
            ..strokeWidth = 1);
    }
    for (var y = 0.0; y < s.height; y += 25) {
      c.drawLine(
          Offset(0, y),
          Offset(s.width, y),
          Paint()
            ..color = Colors.white.withValues(alpha: .16)
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.id != id;
}
