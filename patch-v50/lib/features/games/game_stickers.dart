import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Original transparent vector stickers for Saleh's games.
/// They replace the old opaque raster crops and stay crisp at every size.
class SalehSticker extends StatelessWidget {
  const SalehSticker(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _StickerPainter(index), child: const SizedBox.expand());
}

class _StickerPainter extends CustomPainter {
  const _StickerPainter(this.index);
  final int index;
  static const ink = Color(0xFF4D3A45);
  Paint fill(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  Paint line([double width = 2.4]) => Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas.save();
    canvas.translate((size.width - 100 * scale) / 2,
        (size.height - 100 * scale) / 2 + 2 * scale);
    canvas.scale(scale);
    canvas.drawOval(const Rect.fromLTWH(20, 88, 60, 7),
        Paint()..color = Colors.black.withValues(alpha: .12));
    switch (index) {
      case 0:
        _lion(canvas);
        break;
      case 1:
        _rabbit(canvas);
        break;
      case 2:
        _duck(canvas);
        break;
      case 3:
        _fox(canvas);
        break;
      case 4:
        _apple(canvas);
        break;
      case 5:
        _banana(canvas);
        break;
      case 6:
        _carrot(canvas);
        break;
      case 7:
        _fish(canvas);
        break;
      case 8:
        _door(canvas);
        break;
      case 9:
        _house(canvas);
        break;
      case 10:
        _robot(canvas);
        break;
      case 11:
        _tree(canvas);
        break;
      case 12:
        _crown(canvas);
        break;
      case 13:
        _dates(canvas);
        break;
      case 14:
        _needle(canvas);
        break;
      default:
        _tree(canvas);
    }
    canvas.restore();
  }

  void shape(Canvas c, Path p, Color color, {double stroke = 2.4}) {
    c.drawShadow(p, Colors.black.withValues(alpha: .2), 4, false);
    c.drawPath(p, fill(color));
    c.drawPath(p, line(stroke));
  }

  void eye(Canvas c, Offset at) {
    c.drawCircle(at, 4.2, fill(Colors.white));
    c.drawCircle(at, 2.3, fill(const Color(0xFF342C39)));
    c.drawCircle(at.translate(-.7, -.8), .7, fill(Colors.white));
  }

  void _lion(Canvas c) {
    const mane = Color(0xFFC8752D);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawCircle(
          Offset(50 + math.cos(a) * 27, 43 + math.sin(a) * 25), 13, fill(mane));
    }
    c.drawCircle(const Offset(50, 44), 32, line(2.6));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 64, 36, 27), const Radius.circular(14)),
        fill(const Color(0xFFE4A445)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(32, 64, 36, 27), const Radius.circular(14)),
        line());
    c.drawCircle(const Offset(50, 43), 24, fill(const Color(0xFFF0B958)));
    c.drawCircle(const Offset(50, 43), 24, line());
    eye(c, const Offset(42, 39));
    eye(c, const Offset(58, 39));
    c.drawOval(
        const Rect.fromLTWH(39, 47, 22, 15), fill(const Color(0xFFFFD995)));
    c.drawCircle(const Offset(50, 49), 3.4, fill(ink));
    c.drawArc(const Rect.fromLTWH(44, 49, 12, 10), .2, math.pi - .4, false,
        line(1.8));
    for (final x in [39.0, 61.0]) {
      c.drawCircle(Offset(x, 72), 4, fill(const Color(0xFFE4A445)));
    }
  }

  void _rabbit(Canvas c) {
    const white = Color(0xFFF9F4EB);
    for (final x in [39.0, 61.0]) {
      final ear = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, 22), width: 15, height: 39),
          const Radius.circular(9));
      c.drawRRect(ear, fill(white));
      c.drawRRect(ear, line());
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 22), width: 6, height: 27),
              const Radius.circular(4)),
          fill(const Color(0xFFF1A9B8)));
    }
    c.drawOval(const Rect.fromLTWH(29, 54, 42, 37), fill(white));
    c.drawOval(const Rect.fromLTWH(29, 54, 42, 37), line());
    c.drawCircle(const Offset(50, 48), 25, fill(white));
    c.drawCircle(const Offset(50, 48), 25, line());
    eye(c, const Offset(42, 45));
    eye(c, const Offset(58, 45));
    c.drawCircle(const Offset(50, 53), 3.5, fill(const Color(0xFFE991A5)));
    c.drawArc(const Rect.fromLTWH(43, 53, 14, 10), .2, math.pi - .4, false,
        line(1.7));
    c.drawCircle(const Offset(71, 72), 9, fill(white));
    c.drawCircle(const Offset(71, 72), 9, line());
  }

  void _duck(Canvas c) {
    const yellow = Color(0xFFF5C63B);
    c.drawOval(const Rect.fromLTWH(25, 51, 55, 34), fill(yellow));
    c.drawOval(const Rect.fromLTWH(25, 51, 55, 34), line());
    c.drawCircle(const Offset(43, 39), 22, fill(const Color(0xFFFFD957)));
    c.drawCircle(const Offset(43, 39), 22, line());
    final beak = Path()
      ..moveTo(26, 44)
      ..lineTo(8, 50)
      ..lineTo(27, 56)
      ..close();
    shape(c, beak, const Color(0xFFF28A35), stroke: 2);
    eye(c, const Offset(38, 36));
    eye(c, const Offset(51, 36));
    final wing = Path()
      ..moveTo(50, 62)
      ..quadraticBezierTo(75, 58, 70, 77)
      ..quadraticBezierTo(56, 82, 50, 62)
      ..close();
    shape(c, wing, const Color(0xFFE9AF29), stroke: 2);
    for (final x in [39.0, 60.0]) {
      c.drawLine(Offset(x, 83), Offset(x - 4, 91), line(2.5));
    }
  }

  void _fox(Canvas c) {
    const orange = Color(0xFFE87935);
    final tail = Path()
      ..moveTo(63, 67)
      ..cubicTo(99, 50, 95, 88, 65, 88)
      ..close();
    shape(c, tail, orange);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(33, 58, 34, 33), const Radius.circular(15)),
        fill(orange));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(33, 58, 34, 33), const Radius.circular(15)),
        line());
    final head = Path()
      ..moveTo(24, 21)
      ..lineTo(38, 28)
      ..quadraticBezierTo(50, 20, 62, 28)
      ..lineTo(77, 20)
      ..lineTo(70, 62)
      ..quadraticBezierTo(50, 76, 30, 62)
      ..close();
    shape(c, head, orange);
    final face = Path()
      ..moveTo(32, 44)
      ..quadraticBezierTo(39, 69, 50, 63)
      ..quadraticBezierTo(61, 69, 68, 44)
      ..quadraticBezierTo(50, 55, 32, 44)
      ..close();
    shape(c, face, const Color(0xFFFFE0AE), stroke: 1.5);
    eye(c, const Offset(40, 43));
    eye(c, const Offset(60, 43));
    c.drawCircle(const Offset(50, 56), 3.6, fill(ink));
    c.drawPath(
        Path()
          ..moveTo(74, 77)
          ..quadraticBezierTo(86, 72, 87, 64),
        line(5)..color = const Color(0xFFFFE0AE));
  }

  void _apple(Canvas c) {
    final p = Path()
      ..moveTo(50, 29)
      ..cubicTo(30, 16, 15, 35, 20, 61)
      ..cubicTo(25, 88, 43, 94, 50, 85)
      ..cubicTo(58, 94, 77, 87, 81, 60)
      ..cubicTo(85, 35, 69, 17, 50, 29)
      ..close();
    shape(c, p, const Color(0xFFE84D4F));
    c.drawPath(
        Path()
          ..moveTo(50, 28)
          ..quadraticBezierTo(52, 13, 62, 8),
        line(5)..color = const Color(0xFF78513B));
    final leaf = Path()
      ..moveTo(57, 18)
      ..quadraticBezierTo(75, 9, 77, 24)
      ..quadraticBezierTo(65, 29, 57, 18)
      ..close();
    shape(c, leaf, const Color(0xFF62A94F), stroke: 1.5);
    c.drawOval(const Rect.fromLTWH(29, 32, 10, 25),
        fill(Colors.white.withValues(alpha: .32)));
  }

  void _banana(Canvas c) {
    final p = Path()
      ..moveTo(18, 32)
      ..cubicTo(35, 72, 65, 79, 84, 38)
      ..cubicTo(72, 91, 29, 96, 12, 45)
      ..close();
    shape(c, p, const Color(0xFFF2CB3C));
    c.drawPath(
        Path()
          ..moveTo(21, 39)
          ..cubicTo(39, 71, 63, 76, 77, 46),
        line(2)..color = const Color(0xFFFFE98A));
    c.drawLine(const Offset(14, 43), const Offset(10, 35), line(4));
    c.drawLine(const Offset(84, 39), const Offset(88, 32), line(4));
  }

  void _carrot(Canvas c) {
    final p = Path()
      ..moveTo(29, 29)
      ..quadraticBezierTo(73, 28, 49, 88)
      ..quadraticBezierTo(22, 44, 29, 29)
      ..close();
    shape(c, p, const Color(0xFFF18432));
    for (final y in [43.0, 57.0, 69.0]) {
      c.drawLine(Offset(35, y), Offset(46, y + 3),
          line(1.4)..color = const Color(0xFFD86626));
    }
    for (final angle in [-.65, 0.0, .65]) {
      c.save();
      c.translate(34, 30);
      c.rotate(angle);
      final leaf = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-8, -24, 1, -31)
        ..quadraticBezierTo(11, -20, 0, 0)
        ..close();
      shape(c, leaf, const Color(0xFF5CAB55), stroke: 1.5);
      c.restore();
    }
  }

  void _fish(Canvas c) {
    final body = Path()
      ..moveTo(22, 54)
      ..cubicTo(37, 25, 73, 28, 83, 53)
      ..cubicTo(70, 79, 37, 80, 22, 54)
      ..close();
    shape(c, body, const Color(0xFF52B9CF));
    final tail = Path()
      ..moveTo(26, 53)
      ..lineTo(7, 32)
      ..lineTo(8, 73)
      ..close();
    shape(c, tail, const Color(0xFFEF9A4B));
    eye(c, const Offset(68, 48));
    c.drawArc(
        const Rect.fromLTWH(58, 53, 16, 10), 0, math.pi, false, line(1.7));
    final fin = Path()
      ..moveTo(45, 55)
      ..quadraticBezierTo(55, 75, 61, 57)
      ..close();
    shape(c, fin, const Color(0xFF2D9CB6), stroke: 1.5);
    for (final b in [(82.0, 31.0, 4.0), (91.0, 22.0, 2.8)]) {
      c.drawCircle(Offset(b.$1, b.$2), b.$3, line(1.4));
    }
  }

  void _door(Canvas c) {
    final p = Path()
      ..moveTo(24, 87)
      ..lineTo(24, 39)
      ..quadraticBezierTo(50, 6, 76, 39)
      ..lineTo(76, 87)
      ..close();
    shape(c, p, const Color(0xFFA7653B));
    final inner = Path()
      ..moveTo(32, 85)
      ..lineTo(32, 42)
      ..quadraticBezierTo(50, 18, 68, 42)
      ..lineTo(68, 85)
      ..close();
    c.drawPath(inner, line(2)..color = const Color(0xFF74462F));
    c.drawLine(const Offset(50, 25), const Offset(50, 85),
        line(1.5)..color = const Color(0xFFC98A57));
    c.drawCircle(const Offset(61, 58), 3.5, fill(const Color(0xFFF4C24F)));
    c.drawCircle(const Offset(61, 58), 3.5, line(1.3));
  }

  void _house(Canvas c) {
    final walls = Path()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(19, 45, 62, 43), const Radius.circular(5)));
    shape(c, walls, const Color(0xFFFFD285));
    final roof = Path()
      ..moveTo(11, 48)
      ..lineTo(50, 13)
      ..lineTo(89, 48)
      ..close();
    shape(c, roof, const Color(0xFFD96C65));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(42, 60, 17, 28), const Radius.circular(8)),
        fill(const Color(0xFF9B6446)));
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(42, 60, 17, 28), const Radius.circular(8)),
        line());
    for (final x in [27.0, 66.0]) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 53, 12, 13), const Radius.circular(3)),
          fill(const Color(0xFF77C3D2)));
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, 53, 12, 13), const Radius.circular(3)),
          line(1.5));
    }
    c.drawCircle(const Offset(50, 37), 6, fill(const Color(0xFF77C3D2)));
    c.drawCircle(const Offset(50, 37), 6, line(1.5));
  }

  void _robot(Canvas c) {
    const blue = Color(0xFF66B9CA), purple = Color(0xFF8A70D6);
    c.drawLine(const Offset(50, 18), const Offset(50, 8), line(3));
    c.drawCircle(const Offset(50, 6), 4, fill(const Color(0xFFF2B84B)));
    final head = RRect.fromRectAndRadius(
        const Rect.fromLTWH(25, 18, 50, 32), const Radius.circular(12));
    c.drawRRect(head, fill(blue));
    c.drawRRect(head, line());
    eye(c, const Offset(39, 34));
    eye(c, const Offset(61, 34));
    c.drawArc(const Rect.fromLTWH(42, 37, 16, 8), 0, math.pi, false, line(1.5));
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 52, 42, 31), const Radius.circular(8));
    c.drawRRect(body, fill(purple));
    c.drawRRect(body, line());
    c.drawCircle(const Offset(50, 65), 7, fill(const Color(0xFFF2B84B)));
    c.drawCircle(const Offset(50, 65), 7, line(1.5));
    for (final x in [24.0, 76.0]) {
      c.drawLine(
          Offset(x == 24 ? 29 : 71, 58), Offset(x, 75), line(6)..color = blue);
      c.drawCircle(Offset(x, 77), 5, fill(const Color(0xFFF2B84B)));
    }
    for (final x in [39.0, 61.0]) {
      c.drawLine(Offset(x, 83), Offset(x, 91), line(6)..color = blue);
    }
  }

  void _tree(Canvas c) {
    final trunk = RRect.fromRectAndRadius(
        const Rect.fromLTWH(43, 48, 17, 41), const Radius.circular(6));
    c.drawRRect(trunk, fill(const Color(0xFF8D5E3D)));
    c.drawRRect(trunk, line());
    const green = Color(0xFF60A958);
    for (final at in [
      const Offset(33, 43),
      const Offset(50, 28),
      const Offset(68, 43),
      const Offset(48, 49)
    ]) {
      c.drawCircle(at, 20, fill(green));
      c.drawCircle(at, 20, line(1.8));
    }
    for (final at in [
      const Offset(36, 35),
      const Offset(58, 42),
      const Offset(49, 23)
    ]) {
      c.drawCircle(at, 3.8, fill(const Color(0xFFE95D50)));
    }
    c.drawPath(
        Path()
          ..moveTo(50, 88)
          ..lineTo(29, 92)
          ..moveTo(50, 88)
          ..lineTo(71, 92),
        line(3));
  }

  void _crown(Canvas c) {
    final crown = Path()
      ..moveTo(17, 34)
      ..lineTo(30, 61)
      ..lineTo(73, 61)
      ..lineTo(85, 34)
      ..lineTo(68, 47)
      ..lineTo(58, 25)
      ..lineTo(48, 46)
      ..lineTo(34, 24)
      ..lineTo(32, 49)
      ..close();
    shape(c, crown, const Color(0xFFF2C344));
    final base = RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 60, 49, 19), const Radius.circular(7));
    c.drawRRect(base, fill(const Color(0xFFE6A934)));
    c.drawRRect(base, line());
    for (final item in [
      (38.0, const Color(0xFF5AB6CB)),
      (51.5, const Color(0xFFE66F72)),
      (65.0, const Color(0xFF8A70D6))
    ]) {
      c.drawCircle(Offset(item.$1, 68), 4, fill(item.$2));
      c.drawCircle(Offset(item.$1, 68), 4, line(1.2));
    }
  }

  void _dates(Canvas c) {
    c.drawPath(
        Path()
          ..moveTo(49, 28)
          ..quadraticBezierTo(52, 13, 62, 9),
        line(4)..color = const Color(0xFF6E914C));
    for (final at in [
      const Offset(38, 42),
      const Offset(51, 38),
      const Offset(63, 44),
      const Offset(33, 56),
      const Offset(47, 53),
      const Offset(61, 58),
      const Offset(41, 69),
      const Offset(55, 72)
    ]) {
      c.drawOval(Rect.fromCenter(center: at, width: 14, height: 21),
          fill(const Color(0xFFA85D36)));
      c.drawOval(Rect.fromCenter(center: at, width: 14, height: 21), line(1.6));
      c.drawArc(Rect.fromCenter(center: at, width: 7, height: 14), -1.2, 2.4,
          false, line(1)..color = const Color(0xFFD78B55));
    }
    for (final x in [39.0, 51.0, 63.0]) {
      c.drawLine(const Offset(50, 28), Offset(x, 35),
          line(1.5)..color = const Color(0xFF6E914C));
    }
  }

  void _needle(Canvas c) {
    c.save();
    c.translate(50, 51);
    c.rotate(-.62);
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -40, 8, 77), const Radius.circular(4));
    c.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
                  colors: [Color(0xFFF7FAFC), Color(0xFF9AA7B5)])
              .createShader(const Rect.fromLTWH(-4, -40, 8, 77)));
    c.drawRRect(body, line(1.8));
    c.drawOval(const Rect.fromLTWH(-2.2, -34, 4.4, 13), line(1.2));
    c.drawPath(
        Path()
          ..moveTo(-4, 37)
          ..lineTo(0, 47)
          ..lineTo(4, 37)
          ..close(),
        fill(const Color(0xFF8D98A5)));
    c.restore();
    final thread = Path()
      ..moveTo(38, 25)
      ..cubicTo(15, 20, 14, 64, 35, 76)
      ..cubicTo(56, 88, 76, 73, 72, 54);
    c.drawPath(thread, line(2.2)..color = const Color(0xFFE66F72));
  }

  @override
  bool shouldRepaint(_StickerPainter oldDelegate) => oldDelegate.index != index;
}
