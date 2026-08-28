import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design/widgets/letter_glyph.dart';
import '../../core/design/widgets/touch_feedback.dart';
import 'game_catalog.dart';

const gameInk = Color(0xFF3F365A);
const gameColors = [Color(0xFF8662CF), Color(0xFF208C80), Color(0xFFC57539)];
const gamePale = [Color(0xFFF0E8FB), Color(0xFFE5F4EE), Color(0xFFFFEEDB)];

class AtlasArt extends StatelessWidget {
  const AtlasArt(this.index,
      {super.key, this.world = false, this.fit = BoxFit.contain});
  final int index;
  final bool world;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    // Authored atlas row boundaries include the complete feet and shadows.
    final x = world ? index * 512.0 : (index % 4) * 384.0;
    final tops = [0.0, 380.0, 675.0, 1024.0];
    final y = world ? 0.0 : tops[index ~/ 4];
    final width = world ? 512.0 : 384.0;
    final height = world ? 1024.0 : tops[index ~/ 4 + 1] - y;
    return SizedBox.expand(
        child: FittedBox(
            fit: fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
                width: width,
                height: height,
                child: ClipRect(
                    child: Stack(children: [
                  Positioned(
                      left: -x,
                      top: -y,
                      width: 1536,
                      height: 1024,
                      child: Image.asset(
                          'assets/games/${world ? 'worlds' : 'objects'}.png',
                          width: 1536,
                          height: 1024,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.medium)),
                ])))));
  }
}

class GameButton extends StatelessWidget {
  const GameButton(
      {super.key,
      required this.child,
      required this.onTap,
      this.selected = false,
      this.color = const Color(0xFF8662CF),
      this.padding = const EdgeInsets.all(10),
      this.label});
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final Color color;
  final EdgeInsets padding;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: label,
      selected: selected,
      child: Material(
          color: Colors.transparent,
          child: FeedbackTap(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: padding,
                  constraints:
                      const BoxConstraints(minHeight: 52, minWidth: 52),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selected
                              ? [
                                  color.withValues(alpha: .16),
                                  color.withValues(alpha: .28)
                                ]
                              : [Colors.white, const Color(0xFFF8F3EB)]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: selected ? color : Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: .18),
                            offset: const Offset(0, 5),
                            blurRadius: 0),
                        BoxShadow(
                            color: color.withValues(alpha: .09),
                            offset: const Offset(0, 8),
                            blurRadius: 16)
                      ]),
                  child: child))));
}

class ItemFace extends StatelessWidget {
  const ItemFace(this.item, {super.key});
  final GameItem item;
  @override
  Widget build(BuildContext context) {
    if (item.amount != null) {
      return Quantity(item.amount!, art: item.art ?? 4);
    }
    if (item.art != null) {
      return AtlasArt(item.art!);
    }
    if (item.shape != null) {
      return CustomPaint(
          painter: ShapePainter(item.shape!, tone: item.tone),
          child: const SizedBox.expand());
    }
    if (LetterGlyph.templateFor(item.text) != null) {
      return LetterGlyph(item.text, color: gameInk);
    }
    return Center(
        child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(item.text,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: gameInk,
                    height: 1.35))));
  }
}

class Quantity extends StatelessWidget {
  const Quantity(this.count, {super.key, this.art = 4});
  final int count, art;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = math.min(5, math.max(1, count));
        final rows = (count / cols).ceil();
        final side =
            math.min(c.maxWidth / cols, c.maxHeight / math.max(1, rows));
        return Center(
            child: Wrap(alignment: WrapAlignment.center, children: [
          for (var i = 0; i < count; i++)
            SizedBox(width: side, height: side, child: AtlasArt(art))
        ]));
      });
}

class ShapePainter extends CustomPainter {
  ShapePainter(this.shape, {this.tone = 0});
  final int shape, tone;
  @override
  void paint(Canvas c, Size size) {
    final s = size.shortestSide * .72, center = size.center(Offset.zero);
    final rect = Rect.fromCenter(center: center, width: s, height: s);
    final color = [
      const Color(0xFF9D79DA),
      const Color(0xFFEEB547),
      const Color(0xFF5CB9A2)
    ][tone % 3];
    final p = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, .4)!, color])
          .createShader(rect);
    final path = Path();
    if (shape == 0) {
      path.addOval(rect);
    } else if (shape == 1) {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * .12)));
    } else if (shape == 2) {
      path.moveTo(center.dx, rect.top);
      path.lineTo(rect.right, rect.bottom);
      path.lineTo(rect.left, rect.bottom);
      path.close();
    } else if (shape == 4) {
      path.addOval(
          Rect.fromCenter(center: center, width: s * .35, height: s * .5));
    } else if (shape == 5) {
      c.drawLine(
          Offset(center.dx, rect.bottom),
          Offset(center.dx, rect.top + s * .25),
          Paint()
            ..color = const Color(0xFF479975)
            ..strokeWidth = s * .08
            ..strokeCap = StrokeCap.round);
      path.addOval(Rect.fromLTWH(
          center.dx - s * .4, center.dy - s * .25, s * .4, s * .25));
      path.addOval(
          Rect.fromLTWH(center.dx, center.dy - s * .45, s * .4, s * .25));
    } else {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * .2)));
    }
    c.drawShadow(path, Colors.black.withValues(alpha: .2), 5, false);
    c.drawPath(path, p);
    c.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape != shape || old.tone != tone;
}

class GameBackdrop extends StatelessWidget {
  const GameBackdrop({super.key, required this.world, required this.child});
  final GameWorld world;
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gamePale[world.index], const Color(0xFFFAF6EF)])),
      child: Stack(children: [
        Positioned(
            right: -110,
            bottom: -130,
            width: 380,
            height: 650,
            child: Opacity(
                opacity: .13,
                child: AtlasArt(world.index, world: true, fit: BoxFit.cover))),
        Positioned(
            left: -70,
            top: -70,
            child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .4)))),
        child
      ]));
}

class Arrival extends StatelessWidget {
  const Arrival({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
              offset: Offset(0, 22 * (1 - t)), child: child)),
      child: child);
}

class Celebration extends StatelessWidget {
  const Celebration({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1800),
          builder: (context, t, _) => CustomPaint(
              painter:
                  _Confetti(MediaQuery.disableAnimationsOf(context) ? 1 : t),
              child: const SizedBox.expand())));
}

class _Confetti extends CustomPainter {
  _Confetti(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 36; i++) {
      final angle = i * 2.399;
      final radius = (.08 + t * .7) * s.shortestSide;
      final point = Offset(s.width / 2 + math.cos(angle) * radius,
          s.height * .4 + math.sin(angle) * radius + t * t * 80);
      c.save();
      c.translate(point.dx, point.dy);
      c.rotate(angle + t * 4);
      c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(3)),
          Paint()
            ..color = [...gameColors, const Color(0xFFE9B954)][i % 4]
                .withValues(alpha: 1 - t * .85));
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_Confetti o) => o.t != t;
}
