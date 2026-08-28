import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../home/review_games.dart';
import 'game_art.dart';
import 'game_stage.dart';
import 'game_catalog.dart';
import 'game_screen.dart';
import 'game_store.dart';

class GamesHub extends ConsumerStatefulWidget {
  const GamesHub({super.key});
  @override
  ConsumerState<GamesHub> createState() => _GamesHubState();
}

class _GamesHubState extends ConsumerState<GamesHub> {
  bool opening = false;
  void _open(GameWorld world) {
    if (opening) return;
    opening = true;
    unawaited(Navigator.of(context)
        .push<void>(_gameRoute(GamesWorldScreen(world: world)))
        .whenComplete(() => opening = false));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 12),
          child: Column(children: [
            if (c.maxHeight > 190)
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('ثلاثة عوالم… ومغامرات تتجدد',
                      style: TextStyle(
                          fontSize: 20,
                          color: gameInk,
                          fontWeight: FontWeight.w800))),
            Expanded(
                child: Row(children: [
              for (final world in GameWorld.values)
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: Arrival(
                            child: GameButton(
                                key: ValueKey('world-${world.name}'),
                                padding: EdgeInsets.zero,
                                onTap: () => _open(world),
                                color: gameColors[world.index],
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: Stack(children: [
                                      Positioned.fill(
                                          child: AtlasArt(world.index,
                                              world: true, fit: BoxFit.cover)),
                                      Positioned.fill(
                                          child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      stops: const [
                                            0,
                                            .4,
                                            1
                                          ],
                                                      colors: [
                                            Colors.white.withValues(alpha: .7),
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: .6)
                                          ])))),
                                      Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: .85),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Text('١٢ لعبة',
                                                  style: TextStyle(
                                                      color: gameColors[
                                                          world.index],
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold)))),
                                      Positioned(
                                          bottom: 12,
                                          left: 8,
                                          right: 8,
                                          child: Column(children: [
                                            Text(worldTitles[world.index],
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight:
                                                        FontWeight.w800)),
                                            Text(worldDescriptions[world.index],
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12))
                                          ])),
                                    ]))))))
            ])),
          ])));
}

Route<void> _gameRoute(Widget child) => PageRouteBuilder<void>(
    pageBuilder: (context, a, b) => child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, a, b, child) => MediaQuery
            .disableAnimationsOf(context)
        ? child
        : FadeTransition(
            opacity: a,
            child: SlideTransition(
                position: Tween(begin: const Offset(.04, 0), end: Offset.zero)
                    .animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
                child: child)));

class GamesWorldScreen extends ConsumerStatefulWidget {
  const GamesWorldScreen({super.key, required this.world});
  final GameWorld world;
  @override
  ConsumerState<GamesWorldScreen> createState() => _GamesWorldScreenState();
}

class _GamesWorldScreenState extends ConsumerState<GamesWorldScreen> {
  Map<String, dynamic> progress = {};
  bool opening = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await GameStore(ref.read(activeChildIdProvider)).load();
      if (mounted) setState(() => progress = p);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل علامات الإنجاز');
    }
  }

  int level = 0;

  void _open(GameSpec spec) {
    if (opening) return;
    opening = true;
    unawaited(Navigator.of(context)
        .push<void>(_gameRoute(LearningGameScreen(game: spec)))
        .whenComplete(() {
      opening = false;
      if (mounted) unawaited(_load());
    }));
  }

  @override
  Widget build(BuildContext context) {
    final games = gameCatalog
            .where((e) =>
                e.world == widget.world && (level == 0 || e.level == level))
            .toList(),
        color = gameColors[widget.world.index];
    return Scaffold(
        body: Directionality(
            textDirection: TextDirection.rtl,
            child: GameBackdrop(
                world: widget.world,
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(worldTitles[widget.world.index],
                                      style: TextStyle(
                                          fontSize: 26,
                                          color: color,
                                          fontWeight: FontWeight.w800)),
                                  Text(worldDescriptions[widget.world.index],
                                      style: const TextStyle(
                                          color: gameInk, fontSize: 14))
                                ])),
                            if (widget.world == GameWorld.words)
                              TextButton(
                                  onPressed: () {
                                    if (opening) return;
                                    opening = true;
                                    unawaited(Navigator.push<void>(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const _OriginalGames()))
                                        .whenComplete(() => opening = false));
                                  },
                                  child: const Text('مراجعة الألف السابقة')),
                            GameButton(
                                label: 'عودة للعوالم',
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.close_rounded,
                                    color: gameInk)),
                          ]),
                          SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: [
                                for (var n = 0; n <= 3; n++)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: ChoiceChip(
                                          label: Text(n == 0
                                              ? 'كل الألعاب (١٢)'
                                              : 'المستوى ${digits(n)}'),
                                          selected: level == n,
                                          onSelected: (_) =>
                                              setState(() => level = n))),
                              ])),
                          if (error != null) Text(error!),
                          const SizedBox(height: 12),
                          Expanded(
                              child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 265,
                                          mainAxisExtent: 190,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 18),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: games.length,
                                  itemBuilder: (context, i) {
                                    final g = games[i];
                                    final complete = (progress[g.id]
                                            as Map?)?['completed'] ==
                                        true;
                                    return GameButton(
                                        key: ValueKey('game-${g.id}'),
                                        onTap: () => _open(g),
                                        color: color,
                                        padding: const EdgeInsets.all(10),
                                        child: Column(children: [
                                          Expanded(
                                              child: Stack(children: [
                                            Positioned.fill(
                                                child: GameThumbnail(g)),
                                            if (complete)
                                              Positioned(
                                                  top: 0,
                                                  left: 0,
                                                  child: Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: color,
                                                      size: 20))
                                          ])),
                                          Text(g.title,
                                              maxLines: 1,
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  color: color,
                                                  fontWeight: FontWeight.w800)),
                                          Text(g.skill,
                                              maxLines: 1,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: gameInk)),
                                        ]));
                                  })),
                        ]))))));
  }
}

class _OriginalGames extends StatelessWidget {
  const _OriginalGames();
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('مراجعة الألف السابقة')),
      body: Row(children: [
        for (final game in ReviewGame.values)
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: GameButton(
                      onTap: () {
                        unawaited(Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReviewGameScreen(game: game))));
                      },
                      child: Center(
                          child: Text(gameNames[game.index],
                              style: const TextStyle(
                                  fontSize: 22, color: gameInk))))))
      ]));
}
