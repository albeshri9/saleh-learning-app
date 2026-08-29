import 'dart:math';
import 'package:flutter/material.dart';
import 'game_art.dart';
import 'game_catalog.dart';
import 'game_session.dart';
import 'game_special_boards.dart';
import 'first_phase_scene.dart';

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
  Widget build(BuildContext context) => FirstPhaseScene(
      game: s.game,
      child: switch (s.game.kind) {
        PlayKind.choose || PlayKind.collect => _choiceBoard(),
        PlayKind.order => s.game.id == 'build_word' ? _wordTrain() : _order(),
        PlayKind.memory => _memory(),
        PlayKind.counter => s.game.id == 'feed_rabbit'
            ? _feeding()
            : s.game.id == 'measure'
                ? BridgeMeasure(s)
                : s.game.id == 'add'
                    ? _additionMarket()
                    : _counter(),
        PlayKind.distribute =>
          s.game.id == 'share' ? _shareTable() : _distribute(),
        PlayKind.value => _value(),
        PlayKind.sort => s.game.id == 'sort' ? _sortBoxes() : _sort(),
        PlayKind.puzzle => _pieces(),
        PlayKind.mosaic => HouseAssembly(s),
        PlayKind.mirror => _mirror(),
        PlayKind.maze || PlayKind.robot => _path(),
        PlayKind.pipes => _pipes(),
        PlayKind.bridge => _bridge(),
      });

  Widget _choiceBoard() => switch (s.game.id) {
        'picture_word' => _pictureWord(),
        'letter_basket' => _letterBasket(),
        'letter_lens' => _letterLens(),
        'number_picture' => _numberPicture(),
        'compare' => _compareScale(),
        'pattern' => _patternGarland(),
        _ => _choices(),
      };

  Widget _action(String text, VoidCallback action, {IconData? icon}) =>
      GameButton(
          answerControl:
              text.contains('تحقق') || text.contains('اختبر') || text == 'شغّل',
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
      {bool selected = false, VoidCallback? onTap, Key? key}) {
    final correct = s.correctIds.contains(item.id);
    final wrong = s.wrongIds.contains(item.id);
    return GameButton(
        key: key ?? ValueKey('item-${item.id}'),
        answerControl: s.game.kind != PlayKind.order,
        label: item.art != null ? objectWords[item.art!] : item.text,
        selected: selected || correct || wrong,
        color: wrong
            ? const Color(0xFFD95163)
            : correct
                ? const Color(0xFF29966C)
                : color,
        onTap: s.solved || s.busy ? null : onTap ?? () => s.choose(item),
        child: Stack(children: [
          Positioned.fill(child: ItemFace(item)),
          if (correct || wrong)
            Positioned(
                top: 0,
                left: 0,
                child: Container(
                    key:
                        ValueKey('${correct ? 'correct' : 'wrong'}-${item.id}'),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .78),
                        shape: BoxShape.circle),
                    child: Icon(
                        correct ? Icons.check_rounded : Icons.close_rounded,
                        color: correct
                            ? const Color(0xB329966C)
                            : const Color(0xFFD95163),
                        size: 28)))
        ]));
  }

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

  Widget _pictureWord() => Row(children: [
        Expanded(
            flex: 3,
            child: Container(
                margin: const EdgeInsets.all(7),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7DF).withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(34),
                    border:
                        Border.all(color: const Color(0xFFE7B94F), width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x24000000),
                          offset: Offset(0, 7),
                          blurRadius: 10)
                    ]),
                child: Column(children: [
                  Expanded(child: AtlasArt(s.data.hero!)),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE9B954),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Text('ما اسمها؟',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)))
                ]))),
        const SizedBox(width: 8),
        Expanded(
            flex: 5,
            child:
                _grid([for (final item in s.items) _card(item)], columns: 2)),
      ]);

  Widget _letterBasket() => Column(children: [
        Expanded(
            child: _grid([
          for (final item in s.items)
            Draggable<GameItem>(
                data: item,
                maxSimultaneousDrags:
                    s.solved || s.selected.contains(item.id) ? 0 : 1,
                feedback: Material(
                    color: Colors.transparent,
                    child:
                        SizedBox(width: 82, height: 82, child: ItemFace(item))),
                childWhenDragging: Opacity(
                    opacity: .25,
                    child: _card(item, selected: s.selected.contains(item.id))),
                child: _card(item, selected: s.selected.contains(item.id)))
        ], columns: 3)),
        DragTarget<GameItem>(
            onAcceptWithDetails: (details) => s.choose(details.data),
            builder: (context, candidates, rejected) => AnimatedContainer(
                key: const ValueKey('letter-basket-target'),
                duration: const Duration(milliseconds: 160),
                height: 62,
                margin: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: candidates.isEmpty
                            ? const [Color(0xFFD6A15B), Color(0xFFB8783F)]
                            : const [Color(0xFF7AC29C), Color(0xFF3D9A76)]),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10), bottom: Radius.circular(28)),
                    border: Border.all(
                        color: candidates.isEmpty
                            ? const Color(0xFF855330)
                            : Colors.white,
                        width: candidates.isEmpty ? 2 : 4),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x30000000),
                          offset: Offset(0, 5),
                          blurRadius: 8)
                    ]),
                child: Row(children: [
                  const Icon(Icons.shopping_basket_rounded,
                      color: Colors.white, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Row(children: [
                    for (final id in s.selected)
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: ItemFace(
                                  s.items.firstWhere((e) => e.id == id))))
                  ])),
                  Text(
                      '${digits(s.selected.length)} / ${digits(s.data.answer.length)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))
                ])))
      ]);

  Widget _letterLens() => Row(children: [
        Expanded(
            flex: 2,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 20, 24),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .78),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFF6E91C8), width: 8),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x30000000),
                            blurRadius: 12,
                            offset: Offset(0, 6))
                      ]),
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: AtlasArt(s.data.hero!))),
              Positioned(
                  left: 4,
                  bottom: 4,
                  child: Transform.rotate(
                      angle: -.7,
                      child: Container(
                          width: 13,
                          height: 58,
                          decoration: BoxDecoration(
                              color: const Color(0xFF5A74A7),
                              borderRadius: BorderRadius.circular(8)))))
            ])),
        Expanded(
            flex: 4,
            child: Column(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .75),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(s.data.caption,
                      style: const TextStyle(
                          fontSize: 29,
                          color: gameInk,
                          fontWeight: FontWeight.w800))),
              const SizedBox(height: 7),
              Expanded(
                  child: _grid([
                for (final item in s.items)
                  _card(item, selected: s.selected.contains(item.id))
              ], columns: s.items.length)),
            ]))
      ]);

  Widget _numberPicture() => Row(children: [
        Expanded(
            flex: 2,
            child: Center(
                child: Container(
                    width: 108,
                    height: 108,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: const Color(0xFF208C80),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 7),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x40208C80),
                              blurRadius: 14,
                              offset: Offset(0, 7))
                        ]),
                    child: Text(s.data.caption,
                        style: const TextStyle(
                            fontSize: 50,
                            color: Colors.white,
                            fontWeight: FontWeight.w800))))),
        Expanded(
            flex: 5,
            child: _grid([for (final item in s.items) _card(item)], columns: 2))
      ]);

  Widget _compareScale() => Column(children: [
        Expanded(
            child: Stack(children: [
          Positioned(
              left: 18,
              right: 18,
              top: 42,
              child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                      color: const Color(0xFF588A8A),
                      borderRadius: BorderRadius.circular(6)))),
          Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                  child: Container(
                      width: 13,
                      height: 100,
                      decoration: BoxDecoration(
                          color: const Color(0xFF588A8A),
                          borderRadius: BorderRadius.circular(8))))),
          Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                  child: Container(
                      width: 95,
                      height: 12,
                      decoration: BoxDecoration(
                          color: const Color(0xFF588A8A),
                          borderRadius: BorderRadius.circular(10))))),
          Row(children: [
            for (final item in s.items)
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 57, 12, 18),
                      child: _card(item)))
          ])
        ])),
        if (s.data.a > 0)
          Text('${digits(s.data.a)}  =  ${digits(s.data.b)}',
              style: const TextStyle(
                  fontSize: 24, color: gameInk, fontWeight: FontWeight.w800))
      ]);

  Widget _patternGarland() => Column(children: [
        SizedBox(
            height: 88,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < s.data.grid.length; i++) ...[
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .72),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: [
                              const Color(0xFF8662CF),
                              const Color(0xFFE6B44A),
                              const Color(0xFF61B9A5)
                            ][i % 3],
                            width: 3)),
                    child: ItemFace(shape(s.data.grid[i]))),
                if (i < s.data.grid.length - 1)
                  Container(
                      width: 18,
                      height: 3,
                      color: const Color(0xFF8662CF).withValues(alpha: .25))
              ],
              Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFE6B44A), width: 3)),
                  child: const Text('؟',
                      style: TextStyle(
                          fontSize: 31,
                          color: gameInk,
                          fontWeight: FontWeight.w800)))
            ])),
        Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final item in s.items)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(9), child: _card(item)))
        ]))
      ]);

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
                  _card(item, selected: s.selected.contains(item.id))
              ], columns: s.items.length > 4 ? 3 : 2))
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

  Widget _wordTrain() => Column(children: [
        Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(
              width: 105,
              child: Column(children: [
                Expanded(child: AtlasArt(s.data.hero!)),
                Container(
                    height: 55,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF6AAFC1), Color(0xFF3F8299)]),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(14),
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10)),
                        border: Border.all(
                            color: const Color(0xFF315C6B), width: 2)),
                    child: const Center(
                        child: Icon(Icons.train_rounded,
                            color: Colors.white, size: 40)))
              ])),
          const SizedBox(width: 5),
          for (var i = 0; i < s.data.answer.length; i++)
            Expanded(child: LayoutBuilder(builder: (context, constraints) {
              final wheelSize = min(14.0, constraints.maxHeight * .18);
              final carriageHeight =
                  max(28.0, constraints.maxHeight - wheelSize);
              return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                        height: carriageHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                            color: [
                              const Color(0xFFE98C78),
                              const Color(0xFFE6B44A),
                              const Color(0xFF72B6A3),
                              const Color(0xFF8A70D6)
                            ][i % 4],
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x25000000),
                                  offset: Offset(0, 5),
                                  blurRadius: 7)
                            ]),
                        child: i < s.selected.length
                            ? ItemFace(s.items
                                .firstWhere((e) => e.id == s.selected[i]))
                            : Center(
                                child: Text(digits(i + 1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800)))),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var n = 0; n < 2; n++)
                            Container(
                                width: wheelSize,
                                height: wheelSize,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF4E4757),
                                    shape: BoxShape.circle))
                        ])
                  ]);
            }))
        ])),
        const SizedBox(height: 6),
        SizedBox(
            height: 70,
            child: Row(children: [
              for (final item in s.items)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Opacity(
                            opacity: s.selected.contains(item.id) ? .25 : 1,
                            child: _card(item,
                                selected: s.selected.contains(item.id)))))
            ])),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _action('تحقق', s.checkOrder, icon: Icons.check_rounded),
          const SizedBox(width: 12),
          _action('تراجع', s.undo, icon: Icons.undo_rounded)
        ])
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
              answerControl: s.selected.isNotEmpty,
              onTap: s.busy || s.solved || s.matched.contains(item.id)
                  ? null
                  : () => s.choose(item),
              color: s.wrongIds.contains(item.id)
                  ? const Color(0xFFD95163)
                  : s.matched.contains(item.id)
                      ? const Color(0xFF29966C)
                      : color,
              selected:
                  s.matched.contains(item.id) || s.wrongIds.contains(item.id),
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
      ], columns: s.items.length ~/ 2);

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

  Widget _additionMarket() => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _numberBadge(s.data.start, const Color(0xFFE87968)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('+',
                  style: TextStyle(
                      fontSize: 34,
                      color: gameInk,
                      fontWeight: FontWeight.w800))),
          _numberBadge(s.data.target - s.data.start, const Color(0xFFE6B44A)),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('=',
                  style: TextStyle(
                      fontSize: 32,
                      color: gameInk,
                      fontWeight: FontWeight.w800))),
          _numberBadge(s.solved ? s.count : null, const Color(0xFF61B9A5)),
        ]),
        Expanded(
            child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFD39A55).withValues(alpha: .28),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15), bottom: Radius.circular(34)),
                    border:
                        Border.all(color: const Color(0xFF9A673A), width: 3)),
                child: Quantity(s.count, art: 4))),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _action('أضف تفاحة', () => s.adjustCount(1), icon: Icons.add_rounded),
          const SizedBox(width: 10),
          _action('أعد تفاحة', () => s.adjustCount(-1),
              icon: Icons.remove_rounded),
          const SizedBox(width: 10),
          _action('تحقق', s.checkCount, icon: Icons.check_rounded)
        ])
      ]);

  Widget _numberBadge(int? value, Color color) => Container(
      width: 60,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x25000000), offset: Offset(0, 4), blurRadius: 6)
          ]),
      child: Text(value == null ? '؟' : digits(value),
          style: const TextStyle(
              fontSize: 27, color: Colors.white, fontWeight: FontWeight.w800)));

  Widget _shareTable() => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.apple_rounded, color: Color(0xFFE65B55)),
          const SizedBox(width: 6),
          Text(
              'المتبقي ${digits(s.data.target - s.bins.fold(0, (a, b) => a + b))}',
              style: const TextStyle(
                  fontSize: 19, color: gameInk, fontWeight: FontWeight.w800))
        ]),
        Expanded(
            child: Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: GestureDetector(
                        onLongPress: () => s.distribute(i, remove: true),
                        child: GameButton(
                            key: ValueKey('plate-$i'),
                            answerControl: false,
                            onTap: s.solved ? null : () => s.distribute(i),
                            color: [
                              const Color(0xFF8A70D6),
                              const Color(0xFF61B9A5),
                              const Color(0xFFE6B44A)
                            ][i],
                            padding: const EdgeInsets.all(5),
                            child: Stack(children: [
                              Positioned.fill(
                                  child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .72),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: [
                                                const Color(0xFF8A70D6),
                                                const Color(0xFF61B9A5),
                                                const Color(0xFFE6B44A)
                                              ][i],
                                              width: 4)))),
                              Positioned.fill(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Quantity(s.bins[i], art: 4))),
                              Positioned(
                                  bottom: 2,
                                  left: 0,
                                  right: 0,
                                  child: Text(digits(s.bins[i]),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 22,
                                          color: gameInk,
                                          fontWeight: FontWeight.w800)))
                            ])))))
        ])),
        _action('تحقق من التوزيع', s.checkDistribution,
            icon: Icons.check_rounded)
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
  Widget _sortBoxes() => Row(children: [
        Expanded(
            flex: 3,
            child: _grid([
              for (final item in s.items)
                Opacity(
                    opacity: s.matched.contains(item.id) ? .18 : 1,
                    child: _card(item,
                        selected: sortPick == item.id,
                        onTap: () => setState(() => sortPick = item.id)))
            ], columns: 3)),
        const SizedBox(width: 10),
        Expanded(
            flex: 2,
            child: Column(children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: GameButton(
                            key: ValueKey('sort-bin-$i'),
                            answerControl: true,
                            color: [
                              const Color(0xFF8A70D6),
                              const Color(0xFFE6B44A)
                            ][i],
                            onTap: s.solved || sortPick == null
                                ? null
                                : () {
                                    s.sortInto(
                                        s.items.firstWhere(
                                            (e) => e.id == sortPick),
                                        i);
                                    setState(() => sortPick = null);
                                  },
                            child: Stack(children: [
                              Positioned(
                                  top: 6,
                                  left: 8,
                                  right: 8,
                                  child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF4D3A45)
                                              .withValues(alpha: .22),
                                          borderRadius:
                                              BorderRadius.circular(8)))),
                              Positioned.fill(
                                  top: 18,
                                  child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: ItemFace(shape(
                                          s.data.a == 1 ? 1 : i,
                                          tone: s.data.a == 1 ? i : 0)))),
                              Positioned(
                                  bottom: 2,
                                  left: 4,
                                  child: Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle),
                                      child: Text(digits(s.bins[i]),
                                          style: const TextStyle(
                                              color: gameInk,
                                              fontWeight: FontWeight.w800))))
                            ]))))
            ]))
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
