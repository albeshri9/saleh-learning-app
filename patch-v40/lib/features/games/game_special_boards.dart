import 'dart:math';
import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_catalog.dart';
import 'game_session.dart';

class HouseAssembly extends StatefulWidget {
  const HouseAssembly(this.session, {super.key});
  final GameSession session;
  @override
  State<HouseAssembly> createState() => _HouseAssemblyState();
}

class _HouseAssemblyState extends State<HouseAssembly> {
  int? selected;
  GameSession get s => widget.session;
  Widget piece(int id, {bool ghost = false}) => CustomPaint(
      painter: HousePart(s.data.grid[id], id, ghost),
      child: const SizedBox.expand());
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 3,
            child: Center(
                child: AspectRatio(
                    aspectRatio: 1.2,
                    child: LayoutBuilder(builder: (context, c) {
                      final w = c.maxWidth / 2, h = c.maxHeight / 2;
                      return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Stack(children: [
                            for (var i = 0; i < 4; i++)
                              Positioned(
                                  left: (i % 2) * w,
                                  top: (i ~/ 2) * h,
                                  width: w,
                                  height: h,
                                  child: DragTarget<int>(
                                      onAcceptWithDetails: (d) =>
                                          s.putPiece(d.data, i),
                                      builder: (context, candidates,
                                              rejected) =>
                                          GestureDetector(
                                              key: ValueKey('house-slot-$i'),
                                              onTap: s.solved ||
                                                      selected == null
                                                  ? null
                                                  : () {
                                                      s.putPiece(selected!, i);
                                                      setState(() =>
                                                          selected = null);
                                                    },
                                              child: AnimatedSwitcher(
                                                  duration: const Duration(
                                                      milliseconds: 240),
                                                  child: Padding(
                                                      key:
                                                          ValueKey(s.placed[i]),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              1),
                                                      child: piece(i,
                                                          ghost: !s.placed
                                                              .containsKey(
                                                                  i))))))),
                          ]));
                    })))),
        const SizedBox(width: 18),
        Expanded(
            flex: 2,
            child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  for (final id in [2, 0, 3, 1])
                    Draggable<int>(
                        data: id,
                        maxSimultaneousDrags:
                            s.solved || s.placed.containsValue(id) ? 0 : 1,
                        feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                                width: 100, height: 85, child: piece(id))),
                        childWhenDragging: const SizedBox(),
                        child: GameButton(
                            key: ValueKey('house-piece-$id'),
                            selected: selected == id,
                            padding: const EdgeInsets.all(8),
                            color: gameColors[2],
                            onTap: s.solved || s.placed.containsValue(id)
                                ? null
                                : () => setState(() => selected = id),
                            child: Opacity(
                                opacity: s.placed.containsValue(id) ? 0.2 : 1,
                                child: piece(id)))),
                ])),
      ]);
}

class HousePart extends CustomPainter {
  HousePart(this.shape, this.index, this.ghost);
  final int shape, index;
  final bool ghost;
  @override
  void paint(Canvas c, Size s) {
    final path = Path();
    if (shape == 6) {
      path.moveTo(0, s.height);
      path.lineTo(s.width, 0);
      path.lineTo(s.width, s.height);
      path.close();
    } else if (shape == 7) {
      path.moveTo(0, 0);
      path.lineTo(s.width, s.height);
      path.lineTo(0, s.height);
      path.close();
    } else {
      path.addRRect(
          RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(5)));
    }
    final color = index < 2 ? const Color(0xFFD28B6E) : const Color(0xFFE6BC77);
    if (!ghost) {
      c.drawShadow(path, Colors.black.withValues(alpha: .2), 5, false);
    }
    c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ghost
                      ? [const Color(0xFFE3DDD2), const Color(0xFFE3DDD2)]
                      : [Color.lerp(color, Colors.white, .3)!, color])
              .createShader(Offset.zero & s));
    c.drawPath(
        path,
        Paint()
          ..color = ghost
              ? const Color(0xFFB6AAA0)
              : Colors.white.withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    if (!ghost && index >= 2) {
      final window = Rect.fromCenter(
          center: s.center(Offset.zero),
          width: s.width * .4,
          height: s.height * .45);
      c.drawRRect(RRect.fromRectAndRadius(window, const Radius.circular(8)),
          Paint()..color = const Color(0xFF91C9CB));
      c.drawLine(
          Offset(window.center.dx, window.top),
          Offset(window.center.dx, window.bottom),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(HousePart old) =>
      old.shape != shape || old.ghost != ghost || old.index != index;
}

class BridgeMeasure extends StatelessWidget {
  const BridgeMeasure(this.s, {super.key});
  final GameSession s;
  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: LayoutBuilder(builder: (context, c) {
          final unit = min(65.0, (c.maxWidth - 40) / 9),
              width = unit * s.data.target;
          return Stack(alignment: Alignment.center, children: [
            Positioned(
                left: 8,
                right: 8,
                top: 5,
                bottom: 42,
                child: Container(
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFB6E0E0), Color(0xFF6FBACD)]),
                        borderRadius: BorderRadius.circular(24)))),
            Positioned(
                top: 20,
                width: width,
                height: 62,
                child: CustomPaint(painter: _MeasureBridge(s.data.target))),
              Positioned(
                bottom: 8,
                left: (c.maxWidth - width) / 2,
                width: unit * 6,
                height: 48,
                child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(children: [
                      for (var i = 0; i < 6; i++)
                        SizedBox(
                            width: unit,
                            child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    decoration: BoxDecoration(
                                        color: i < s.count
                                            ? gameColors[1]
                                            : Colors.white
                                                .withValues(alpha: .4),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Center(
                                        child: Text(
                                            i < s.count ? digits(i + 1) : '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight:
                                                    FontWeight.bold))))))
                    ]))),
          ]);
        })),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GameButton(
              onTap: s.solved ? null : () => s.adjustCount(1),
              child: const Text('أضف وحدة',
                  style: TextStyle(color: gameInk, fontSize: 18))),
          const SizedBox(width: 10),
          GameButton(
              onTap: s.solved ? null : () => s.adjustCount(-1),
              child: const Text('أعد وحدة',
                  style: TextStyle(color: gameInk, fontSize: 18))),
          const SizedBox(width: 10),
          GameButton(
              onTap: s.solved ? null : s.checkCount,
              child: const Text('تحقق',
                  style: TextStyle(color: gameInk, fontSize: 18))),
        ]),
      ]);
}

class _MeasureBridge extends CustomPainter {
  _MeasureBridge(this.units);
  final int units;
  @override
  void paint(Canvas c, Size size) {
    final step = size.width / units;
    for (var i = 0; i < units; i++) {
      final r = Rect.fromLTWH(i * step + 1, 17, step - 2, 32);
      c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)),
          Paint()
            ..shader = const LinearGradient(
                    colors: [Color(0xFFE9C18D), Color(0xFFA87343)])
                .createShader(r));
      c.drawCircle(Offset(i * step + step / 2, 25), 2,
          Paint()..color = const Color(0xFF865F3E));
    }
    for (final y in [8.0, 56.0]) {
      c.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()
            ..color = const Color(0xFF976741)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round);
    }
    for (final x in [3.0, size.width - 3]) {
      c.drawLine(
          Offset(x, 0),
          Offset(x, 62),
          Paint()
            ..color = const Color(0xFFB38452)
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_MeasureBridge old) => old.units != units;
}
