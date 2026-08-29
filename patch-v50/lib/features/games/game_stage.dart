import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_catalog.dart';
import 'first_phase_scene.dart';

/// Decorations stay at the stage edges, outside the answer hit targets.
class GameStage extends StatelessWidget {
  const GameStage(
      {super.key, required this.game, required this.child, this.feedback});
  final GameSpec game;
  final Widget child;
  final bool? feedback;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                gamePale[game.world.index],
                const Color(0xFFFFF2CE)
              ]),
          border: Border.all(
              width: 3,
              color: feedback == null
                  ? Colors.white
                  : feedback!
                      ? const Color(0xFF56B28A)
                      : const Color(0xFFD95163)),
          boxShadow: [
            BoxShadow(
                color: gameColors[game.world.index].withValues(alpha: .12),
                offset: const Offset(0, 6),
                blurRadius: 14)
          ]),
      child: CustomPaint(
          painter: _StagePainter(game.world, game.kind.index),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: child)));
}

class _StagePainter extends CustomPainter {
  const _StagePainter(this.world, this.variant);
  final GameWorld world;
  final int variant;
  @override
  void paint(Canvas c, Size s) {
    final color = gameColors[world.index];
    // Hand-strung bunting, alternating flags.
    final rope = Path()
      ..moveTo(0, 3)
      ..quadraticBezierTo(s.width / 2, 24, s.width, 3);
    c.drawPath(
        rope,
        Paint()
          ..color = color.withValues(alpha: .24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (var i = 0; i < 13; i++) {
      final x = s.width * i / 12, y = 3 + 10 * math.sin(math.pi * i / 12);
      final flag = Path()
        ..moveTo(x - 5, y)
        ..lineTo(x + 5, y)
        ..lineTo(x, y + 10)
        ..close();
      c.drawPath(
          flag,
          Paint()
            ..color = [
              color,
              const Color(0xFFEFB34D),
              const Color(0xFF64BFA8)
            ][i % 3]
                .withValues(alpha: .5));
    }
    for (final right in [false, true]) {
      final x = right ? s.width - 13 : 13.0;
      final y = s.height * .6;
      if (world == GameWorld.words) {
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 25, height: 32),
            Paint()..color = color.withValues(alpha: .15));
        c.drawPath(
            Path()
              ..moveTo(x, y + 16)
              ..cubicTo(x - 9, y + 30, x + 9, y + 40, x, y + 55),
            Paint()
              ..color = color.withValues(alpha: .18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      } else if (world == GameWorld.numbers) {
        for (var j = 0; j < 4; j++) {
          c.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x - 9, s.height - 25 - j * 15, 18, 12),
                  const Radius.circular(4)),
              Paint()..color = color.withValues(alpha: .1 + j * .035));
        }
      } else {
        c.save();
        c.translate(x, y);
        c.rotate(math.pi / 4);
        c.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-12, -12, 24, 24),
                const Radius.circular(4)),
            Paint()..color = color.withValues(alpha: .14));
        c.restore();
      }
    }
    for (var i = 0; i < 8; i++) {
      final x = 30 + (s.width - 60) * i / 7, y = s.height - 8 - (i % 2) * 5.0;
      final p = Path();
      for (var k = 0; k < 10; k++) {
        final a = k * math.pi / 5 - math.pi / 2, r = k.isEven ? 5.0 : 2.3;
        final px = x + math.cos(a) * r, py = y + math.sin(a) * r;
        if (k == 0) {
          p.moveTo(px, py);
        } else {
          p.lineTo(px, py);
        }
      }
      p.close();
      c.drawPath(
          p, Paint()..color = const Color(0xFFE9B954).withValues(alpha: .45));
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.world != world || old.variant != variant;
}

class GameThumbnail extends StatelessWidget {
  const GameThumbnail(this.game, {super.key});
  final GameSpec game;
  static const mathLabels = {
    'feed_rabbit': '١ ٢ ٣',
    'number_picture': '٣',
    'number_train': '١ ٢ ٣',
    'compare': '٣ > ٢',
    'add': '٢ + ١',
    'subtract': '٤ - ١',
    'ten_frame': '؟ + ٦ = ١٠',
    'share': '٦ / ٣',
    'place_value': '١٠ + ٢',
    'shop': '٥ + ١',
    'measure': '١ ٢ ٣',
    'story_math': '٢ + ؟'
  };
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            child: Padding(
                padding: EdgeInsets.only(
                    bottom: game.world == GameWorld.numbers ? 28 : 0),
                child: game.isFirstPhase
                    ? FirstPhaseThumbnail(game)
                    : AtlasArt(game.art))),
        if (game.world == GameWorld.numbers)
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD7EEE6),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(mathLabels[game.id]!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontSize: 19,
                          color: gameInk,
                          fontWeight: FontWeight.w800)))),
        Positioned(
            top: 0,
            right: 0,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: gamePale[game.world.index],
                    borderRadius: BorderRadius.circular(10)),
                child: Text('مستوى ${digits(game.level)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: gameInk,
                        fontWeight: FontWeight.bold))))
      ]);
}
