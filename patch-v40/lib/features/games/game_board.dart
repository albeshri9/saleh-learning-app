import 'dart:math';
import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_catalog.dart';
import 'game_session.dart';

class GameBoard extends StatefulWidget {
  const GameBoard(this.session, {super.key});
  final GameSession session;
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  int? picked;
  String? sortPick;
  GameSession get s => widget.session;
  Color get color => gameColors[s.game.world.index];
  @override
  Widget build(BuildContext context) => switch (s.game.kind) {
        PlayKind.choose || PlayKind.collect => _choices(),
        PlayKind.order => _order(),
        PlayKind.memory => _memory(),
        PlayKind.counter =>
          s.game.id == 'feed_rabbit' ? _feeding() : _counter(),
        PlayKind.distribute => _distribute(),
        PlayKind.value => _value(),
        PlayKind.sort => _sort(),
        PlayKind.puzzle || PlayKind.mosaic => _pieces(),
        PlayKind.mirror => _mirror(),
        PlayKind.maze || PlayKind.robot => _path(),
        PlayKind.pipes => _pipes(),
        PlayKind.bridge => _bridge(),
      };

  Widget _action(String text, VoidCallback action, {IconData? icon}) =>
      GameButton(
          onTap: s.solved || s.busy ? null : action,
          color: color,
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 6)
                ],
                Text(text,
                    style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800))
              ]));

  Widget _card(GameItem item,
          {bool selected = false, VoidCallback? onTap, Key? key}) =>
      GameButton(
          key: key ?? ValueKey('item-${item.id}'),
          label: item.art != null ? objectWords[item.art!] : item.text,
          selected: selected,
          color: color,
          onTap: s.solved || s.busy ? null : onTap ?? () => s.choose(item),
          child: ItemFace(item));

  Widget _grid(List<Widget> children, {int columns = 3}) =>
      LayoutBuilder(builder: (context, c) {
        final rows = (children.length / columns).ceil();
        return GridView.count(
            padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: ((c.maxWidth - 10 - (columns - 1) * 12) /
                    columns) /
                max(52, (c.maxHeight - 15 - (rows - 1) * 12) / max(1, rows)),
            physics: const ClampingScrollPhysics(),
            children: children);
      });

  Widget _hero() => Container(
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F3ED),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 3)),
      child: Column(children: [
        Expanded(child: AtlasArt(s.data.hero!)),
        if (s.data.caption.isNotEmpty && s.game.id == 'build_word')
          Text(s.data.caption,
              style: const TextStyle(
                  fontSize: 28, color: gameInk, fontWeight: FontWeight.bold))
      ]));

  Widget _choices() => Column(children: [
        if (s.data.grid.isNotEmpty && s.game.id == 'pattern')
          SizedBox(
              height: 65,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final n in s.data.grid)
                  SizedBox(width: 52, child: ItemFace(shape(n))),
                const SizedBox(
                    width: 45,
                    child: Center(
                        child: Text('؟', style: TextStyle(fontSize: 36))))
              ])),
        if (s.data.a > 0 && s.data.b > 0)
          SizedBox(
              height: 72,
              child: Row(children: [
                Expanded(child: Quantity(s.data.a, art: s.data.hero ?? 4)),
                Text(s.game.id == 'compare' ? '↔' : '+',
                    style: TextStyle(fontSize: 28, color: color)),
                Expanded(child: Quantity(s.data.b, art: s.data.hero ?? 4))
              ])),
        if (s.data.caption.isNotEmpty &&
            ['missing_letter', 'word_workshop', 'letter_lens', 'number_picture']
                .contains(s.game.id))
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(s.data.caption,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: gameInk))),
        Expanded(
            child: Row(children: [
          if (s.data.hero != null) Expanded(flex: 2, child: _hero()),
          Expanded(
              flex: 5,
              child: _grid([
                for (final item in s.items)
                  AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      opacity: s.selected.contains(item.id) ? 0.35 : 1,
                      child:
                          _card(item, selected: s.selected.contains(item.id)))
              ], columns: s.items.length > 4 ? 3 : s.items.length))
        ])),
        if (s.game.kind == PlayKind.collect)
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_basket_rounded, color: color),
                const SizedBox(width: 8),
                Text(
                    'جمعت ${digits(s.selected.length)} من ${digits(s.data.answer.length)}',
                    style: TextStyle(
                        fontSize: 17,
                        color: color,
                        fontWeight: FontWeight.bold))
              ])),
      ]);

  Widget _order() => Column(children: [
        Expanded(
            child: Row(children: [
          if (s.data.hero != null) Expanded(flex: 2, child: _hero()),
          Expanded(
              flex: 5,
              child: Column(children: [
                Expanded(
                    child: Row(children: [
                  for (var i = 0; i < s.data.answer.length; i++)
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Container(
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: color.withValues(alpha: .3),
                                        width: 2)),
                                child: i < s.selected.length
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: ItemFace(s.items.firstWhere(
                                            (item) =>
                                                item.id == s.selected[i])))
                                    : Center(
                                        child: Text(digits(i + 1),
                                            style: TextStyle(
                                                color: color.withValues(
                                                    alpha: .35),
                                                fontSize: 32))))))
                ])),
                if (s.game.id == 'build_word' && s.selected.isNotEmpty)
                  Text(
                      s.selected
                          .map((id) =>
                              s.items.firstWhere((e) => e.id == id).text)
                          .join(),
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: gameInk)),
              ]))
        ])),
        Expanded(
            child: _grid([
          for (final item in s.items)
            Opacity(
                opacity: s.selected.contains(item.id) ? 0.3 : 1,
                child: _card(item, selected: s.selected.contains(item.id)))
        ], columns: s.items.length)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _action('تحقق', s.checkOrder, icon: Icons.check_rounded),
          const SizedBox(width: 16),
          _action('تراجع', s.undo, icon: Icons.undo_rounded)
        ]),
      ]);

  Widget _memory() => _grid([
        for (final item in s.items)
          GameButton(
              key: ValueKey('item-${item.id}'),
              onTap: s.busy || s.solved || s.matched.contains(item.id)
                  ? null
                  : () => s.choose(item),
              color: color,
              selected: s.matched.contains(item.id),
              label: s.selected.contains(item.id) || s.matched.contains(item.id)
                  ? (item.art == null ? item.text : objectWords[item.art!])
                  : 'بطاقة مغلقة',
              child: AnimatedSwitcher(
                  duration: Duration(
                      milliseconds:
                          MediaQuery.disableAnimationsOf(context) ? 0 : 260),
                  transitionBuilder: (child, a) => ScaleTransition(
                      scale: a,
                      child: FadeTransition(opacity: a, child: child)),
                  child: s.selected.contains(item.id) ||
                          s.matched.contains(item.id)
                      ? ItemFace(item, key: ValueKey(item.id))
                      : Center(
                          key: const ValueKey('back'),
                          child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(18)),
                              child: const Icon(Icons.auto_awesome_rounded,
                                  color: Colors.white, size: 32)))))
      ], columns: 3);

  Widget _feeding() => Column(children: [
        Expanded(
            child: Row(children: [
          Expanded(
              flex: 2,
              child: DragTarget<int>(
                  onAcceptWithDetails: (_) {
                    if (!s.solved) s.adjustCount(1);
                  },
                  builder: (context, candidates, rejected) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: candidates.isEmpty
                              ? const Color(0xFFF7F3ED)
                              : const Color(0xFFD5EDCD),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: color.withValues(alpha: .25), width: 2)),
                      child: Column(children: [
                        const Expanded(child: AtlasArt(1)),
                        Text('أكلت ${digits(s.count)} جزرات',
                            style: TextStyle(
                                fontSize: 17,
                                color: color,
                                fontWeight: FontWeight.bold))
                      ])))),
          const SizedBox(width: 12),
          Expanded(
              flex: 3,
              child: Column(children: [
                const Text('اسحب الجزرة إلى الأرنب أو اضغط عليها',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gameInk, fontSize: 15)),
                Expanded(
                    child: _grid([
                  for (var i = 0; i < 6; i++)
                    Draggable<int>(
                        data: i,
                        maxSimultaneousDrags: s.solved ? 0 : 1,
                        feedback: const Material(
                            color: Colors.transparent,
                            child: SizedBox(
                                width: 70, height: 90, child: AtlasArt(6))),
                        childWhenDragging:
                            const Opacity(opacity: .2, child: AtlasArt(6)),
                        child: GameButton(
                            key: ValueKey('carrot-$i'),
                            color: color,
                            padding: EdgeInsets.zero,
                            onTap: s.solved ? null : () => s.adjustCount(1),
                            child: const AtlasArt(6)))
                ], columns: 3)),
              ])),
        ])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _action('أعد جزرة', () => s.adjustCount(-1)),
          const SizedBox(width: 12),
          _action('تحقق', s.checkCount, icon: Icons.check_rounded)
        ]),
      ]);
  Widget _counter() => Row(children: [
        SizedBox(
            width: 100,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(height: 90, child: AtlasArt(s.data.hero ?? s.data.a)),
              Text(digits(s.count),
                  style: TextStyle(
                      fontSize: 40, color: color, fontWeight: FontWeight.w800)),
            ])),
        const SizedBox(width: 8),
        Expanded(
            child: Column(children: [
          Expanded(child: LayoutBuilder(builder: (context, c) {
            final slots = s.game.id == 'measure'
                ? s.data.target
                : s.game.id == 'ten_frame'
                    ? 10
                    : max(6, s.count);
            final cols = slots > 6 ? 5 : slots;
            return _grid([
              for (var i = 0; i < slots; i++)
                GameButton(
                    key: ValueKey('count-slot-$i'),
                    color: color,
                    padding: const EdgeInsets.all(3),
                    onTap: s.solved
                        ? null
                        : () => s.adjustCount(i < s.count ? -1 : 1),
                    selected: i < s.count,
                    child: i < s.count
                        ? AtlasArt(s.data.a == 9 ? 9 : s.data.a)
                        : Center(
                            child: Icon(Icons.add_rounded,
                                color: color.withValues(alpha: .4))))
            ], columns: cols);
          })),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _action('أضف', () => s.adjustCount(1), icon: Icons.add_rounded),
            const SizedBox(width: 12),
            _action('أعد', () => s.adjustCount(-1), icon: Icons.remove_rounded),
            const SizedBox(width: 12),
            _action('تحقق', s.checkCount, icon: Icons.check_rounded),
          ]),
        ])),
      ]);

  Widget _distribute() => Column(children: [
        Text(
            'المتبقي: ${digits(s.data.target - s.bins.fold(0, (a, b) => a + b))}',
            style: TextStyle(
                fontSize: 22, color: color, fontWeight: FontWeight.bold)),
        Expanded(
            child: Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: GestureDetector(
                        onLongPress: () => s.distribute(i, remove: true),
                        child: GameButton(
                            key: ValueKey('plate-$i'),
                            onTap: s.solved ? null : () => s.distribute(i),
                            color: color,
                            child: Column(children: [
                              Expanded(child: Quantity(s.bins[i])),
                              Text(digits(s.bins[i]),
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold))
                            ])))))
        ])),
        _action('تحقق من التوزيع', s.checkDistribution,
            icon: Icons.check_rounded),
      ]);

  Widget _value() => Column(children: [
        Expanded(
            child: Row(children: [
          for (final big in [true, false])
            Expanded(
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Column(children: [
                      Text(
                          big
                              ? (s.game.id == 'shop'
                                  ? 'قطع بخمس'
                                  : 'حزم العشرات')
                              : 'الآحاد',
                          style: TextStyle(
                              fontSize: 16,
                              color: color,
                              fontWeight: FontWeight.bold)),
                      Expanded(
                          child: Center(
                              child: SingleChildScrollView(
                                  child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                            for (var i = 0; i < (big ? s.tens : s.ones); i++)
                              Container(
                                  width: big ? 40 : 22,
                                  height: big ? 34 : 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: color.withValues(alpha: .8),
                                      borderRadius: BorderRadius.circular(7)),
                                  child: Text(digits(big ? s.data.a : s.data.b),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                          ])))),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _action('+', () => s.adjustValue(big, 1)),
                            const SizedBox(width: 8),
                            _action('−', () => s.adjustValue(big, -1))
                          ]),
                    ]))),
        ])),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('المجموع: ${digits(s.tens * s.data.a + s.ones * s.data.b)}',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          _action('تحقق', s.checkValue, icon: Icons.check_rounded)
        ]),
      ]);
  Widget _sort() => Row(children: [
        Expanded(
            flex: 3,
            child: _grid([
              for (final item in s.items)
                Opacity(
                    opacity: s.matched.contains(item.id) ? 0.2 : 1,
                    child: _card(item,
                        selected: sortPick == item.id,
                        onTap: () => setState(() => sortPick = item.id)))
            ], columns: 3)),
        const SizedBox(width: 16),
        Expanded(
            flex: 2,
            child: Column(children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: GameButton(
                            key: ValueKey('sort-bin-$i'),
                            color: color,
                            onTap: s.solved || sortPick == null
                                ? null
                                : () {
                                    s.sortInto(
                                        s.items.firstWhere(
                                            (e) => e.id == sortPick),
                                        i);
                                    setState(() => sortPick = null);
                                  },
                            child: Row(children: [
                              Expanded(
                                  child: ItemFace(shape(s.data.a == 1 ? 1 : i,
                                      tone: s.data.a == 1 ? i : 0))),
                              Text(digits(s.bins[i]),
                                  style: TextStyle(color: color, fontSize: 28))
                            ]))))
            ])),
      ]);

  Widget _pieceFace(int i, {bool ghost = false}) {
    if (s.game.kind == PlayKind.mosaic) {
      return Opacity(
          opacity: ghost ? 0.2 : 1,
          child: ItemFace(shape(s.data.grid[i], tone: i % 3)));
    }
    return LayoutBuilder(
        builder: (context, c) => ClipRect(
                child: Stack(children: [
              Positioned(
                  left: -(i % 2) * c.maxWidth,
                  top: -(i ~/ 2) * c.maxHeight,
                  width: c.maxWidth * 2,
                  height: c.maxHeight * 2,
                  child: AtlasArt(s.data.hero!, fit: BoxFit.fill)),
            ])));
  }

  Widget _pieces() => Row(children: [
        SizedBox(
            width: 75,
            child: Column(children: [
              const Text('النموذج',
                  style:
                      TextStyle(color: gameInk, fontWeight: FontWeight.bold)),
              Expanded(child: AtlasArt(s.data.hero!))
            ])),
        Expanded(
            child: Directionality(
                textDirection: TextDirection.ltr,
                child: _grid([
                  for (var i = 0; i < 4; i++)
                    DragTarget<int>(
                        onAcceptWithDetails: (details) {
                          s.putPiece(details.data, i);
                        },
                        builder: (context, candidates, rejected) => GameButton(
                            key: ValueKey('piece-slot-$i'),
                            padding: EdgeInsets.zero,
                            color: color,
                            selected: s.placed.containsKey(i) ||
                                candidates.isNotEmpty,
                            onTap: s.solved || picked == null
                                ? null
                                : () {
                                    s.putPiece(picked!, i);
                                    setState(() => picked = null);
                                  },
                            child: s.placed.containsKey(i)
                                ? _pieceFace(s.placed[i]!)
                                : s.game.kind == PlayKind.mosaic
                                    ? _pieceFace(i, ghost: true)
                                    : Center(
                                        child: Text(digits(i + 1),
                                            style: TextStyle(
                                                color: color.withValues(
                                                    alpha: .25),
                                                fontSize: 30))))),
                ], columns: 2))),
        const SizedBox(width: 18),
        Expanded(
            child: _grid([
          for (final i in [2, 0, 3, 1])
            Draggable<int>(
                data: i,
                maxSimultaneousDrags:
                    s.solved || s.placed.containsValue(i) ? 0 : 1,
                feedback: Material(
                    color: Colors.transparent,
                    child:
                        SizedBox(width: 85, height: 85, child: _pieceFace(i))),
                childWhenDragging: const SizedBox(),
                child: Opacity(
                    opacity: s.placed.containsValue(i) ? 0.2 : 1,
                    child: GameButton(
                        key: ValueKey('piece-$i'),
                        padding: EdgeInsets.zero,
                        selected: picked == i,
                        color: color,
                        onTap: s.solved || s.placed.containsValue(i)
                            ? null
                            : () => setState(() => picked = i),
                        child: _pieceFace(i)))),
        ], columns: 2)),
      ]);
  Widget _mirror() => Column(children: [
        Expanded(
            child: Center(
                child: AspectRatio(
                    aspectRatio: 1.7,
                    child: Row(children: [
                      Expanded(
                          child: _grid([
                        for (var i = 0; i < 6; i++)
                          Container(
                              decoration: BoxDecoration(
                                  color: s.data.grid[i] == 1
                                      ? color
                                      : Colors.white.withValues(alpha: .7),
                                  borderRadius: BorderRadius.circular(10)))
                      ], columns: 2)),
                      Container(
                          width: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: color.withValues(alpha: .4)),
                      Expanded(
                          child: _grid([
                        for (var i = 0; i < 6; i++)
                          GameButton(
                              key: ValueKey('mirror-$i'),
                              color: color,
                              selected: s.placed.containsKey(i),
                              onTap: s.solved ? null : () => s.toggleMirror(i),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: s.placed.containsKey(i)
                                          ? color
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8))))
                      ], columns: 2)),
                    ])))),
        _action('تحقق من التناظر', s.checkMirror, icon: Icons.check_rounded)
      ]);

  Widget _path() => Row(children: [
        Expanded(
            flex: 3,
            child: Center(
                child: AspectRatio(
                    aspectRatio: 1,
                    child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: LayoutBuilder(builder: (context, c) {
                          final cell = c.maxWidth / 4;
                          return Stack(children: [
                            GridView.count(
                                crossAxisCount: 4,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                children: [
                                  for (var i = 0; i < 16; i++)
                                    Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: GameButton(
                                            key: ValueKey('path-$i'),
                                            padding: EdgeInsets.zero,
                                            color: color,
                                            onTap:
                                                s.game.kind == PlayKind.maze &&
                                                        !s.solved
                                                    ? () => s.move(i)
                                                    : null,
                                            selected: i == s.data.target,
                                            child: !s.data.grid.contains(i)
                                                ? const AtlasArt(11)
                                                : i == s.data.target
                                                    ? const AtlasArt(9)
                                                    : const SizedBox.expand()))
                                ]),
                            AnimatedPositioned(
                                duration: Duration(
                                    milliseconds:
                                        MediaQuery.disableAnimationsOf(context)
                                            ? 0
                                            : 250),
                                left: (s.position % 4) * cell,
                                top: (s.position ~/ 4) * cell,
                                width: cell,
                                height: cell,
                                child: IgnorePointer(
                                    child: s.game.kind == PlayKind.robot
                                        ? const AtlasArt(10)
                                        : Image.asset(
                                            'assets/character/saleh_idle.png',
                                            fit: BoxFit.contain))),
                          ]);
                        }))))),
        const SizedBox(width: 18),
        Expanded(
            flex: 2,
            child: s.game.kind == PlayKind.maze
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const SizedBox(
                            width: 90, height: 90, child: AtlasArt(9)),
                        Text('خطوة بخطوة إلى البيت',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: color,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ])
                : Column(children: [
                    Expanded(
                        child: SingleChildScrollView(
                            child: Wrap(spacing: 5, runSpacing: 5, children: [
                      for (final cmd in s.commands)
                        Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(
                                [
                                  Icons.east,
                                  Icons.south,
                                  Icons.west,
                                  Icons.north
                                ][cmd],
                                color: color))
                    ]))),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (var cmd = 0; cmd < 4; cmd++)
                        GameButton(
                            key: ValueKey('command-$cmd'),
                            color: color,
                            onTap: s.solved || s.busy
                                ? null
                                : () => s.addCommand(cmd),
                            child: Icon(
                                [
                                  Icons.east,
                                  Icons.south,
                                  Icons.west,
                                  Icons.north
                                ][cmd],
                                color: color))
                    ]),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _action('شغّل', s.runRobot),
                      const SizedBox(width: 8),
                      _action('تراجع', s.undoCommand)
                    ]),
                  ])),
      ]);

  Widget _pipes() => Column(children: [
        Expanded(
            child: Row(children: [
          const SizedBox(width: 55, child: AtlasArt(8)),
          for (var i = 0; i < 4; i++)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: GameButton(
                        key: ValueKey('pipe-$i'),
                        onTap: s.solved ? null : () => s.rotate(i),
                        color: color,
                        child: AnimatedRotation(
                            turns: s.rotations[i] / 4,
                            duration: const Duration(milliseconds: 220),
                            child: Center(
                                child: Container(
                                    height: 25,
                                    decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.white,
                                            width: 3)))))))),
          const SizedBox(width: 55, child: AtlasArt(9)),
        ])),
        _action('اختبر الطريق', s.checkPipes, icon: Icons.route_rounded)
      ]);

  Widget _bridge() => Column(children: [
        Expanded(
            child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
              child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFBFE7EE), Color(0xFF79B9C7)]),
                      borderRadius: BorderRadius.circular(25)))),
          Row(children: [
            const SizedBox(width: 45, child: AtlasArt(11)),
            Expanded(
                child: Row(children: [
              for (var i = 0; i < s.data.target; i++)
                Expanded(
                    child: Container(
                        height: 55,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: i < s.count
                                ? const Color(0xFFB98959)
                                : Colors.white.withValues(alpha: .25),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .7))),
                        child: Center(
                            child: Text(digits(i + 1),
                                style: TextStyle(
                                    color: i < s.count
                                        ? Colors.white
                                        : gameInk)))))
            ])),
            const SizedBox(width: 45, child: AtlasArt(9))
          ]),
        ])),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var n = 1; n <= 3; n++)
            Padding(
                padding: const EdgeInsets.all(5),
                child: _action('+ ${digits(n)}', () => s.bridge(n))),
          _action('تراجع', s.undoBridge),
          const SizedBox(width: 10),
          _action('تحقق', s.checkCount)
        ]),
      ]);
}
