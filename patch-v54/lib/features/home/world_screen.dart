import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/design/widgets/classroom_background.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/progress.dart';
import '../character/video/saleh_video_renderer.dart';
import '../lesson/widgets/saleh_character.dart';
import '../lesson/foundation_track.dart';
import 'family_store.dart';
import 'profile_editor.dart';
import 'parent_dashboard.dart';
import 'learner_chooser.dart';
import 'learning_destinations.dart';
import 'learning_journal.dart';
import '../games/games_hub.dart';
import 'lessons_catalog.dart';
import '../../core/design/widgets/letter_glyph.dart';
import '../../core/design/widgets/toy_icon.dart';
import '../../services/audio/first_launch_narration.dart';

const _ink = Color(0xFF594574);
const _lavender = Color(0xFFF0E8FA);

/// A single child session owns all destinations. No profile switching inside a
/// running lesson; repositories are bound to the selected id before navigation.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});
  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  List<ChildProfile>? _children;
  ChildProfile? _child;
  String _page = 'home';
  FoundationTrack _foundationTrack = FoundationTrack.readWrite;
  String? _error;
  bool _greeting = true;
  bool _lessonOpen = false;
  bool _choosingLearner = false;
  bool _selectingLearner = false;
  Timer? _greetTimer;
  final _firstLaunchNarration = FirstLaunchNarration();

  @override
  void initState() {
    super.initState();
    _load();
    // Fire-and-forget by design: the welcome must never disable the screen.
    unawaited(_firstLaunchNarration.playOnce());
    _greetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _greeting = false);
    });
  }

  @override
  void dispose() {
    _greetTimer?.cancel();
    unawaited(_firstLaunchNarration.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(familyStoreProvider);
      final children = await store.load();
      final active = await store.activeId();
      if (!mounted) return;
      setState(() {
        _children = children;
        _error = null;
        _choosingLearner =
            children.length > 1 && !ref.read(learnerChosenThisSessionProvider);
      });
      if (children.isNotEmpty && !_choosingLearner) {
        await _select(children.firstWhere((c) => c.id == active,
            orElse: () => children.first));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر قراءة الملف. حاول مرة أخرى.');
    }
  }

  Future<void> _select(ChildProfile child) async {
    if (_selectingLearner) return;
    setState(() => _selectingLearner = true);
    try {
      await ref.read(familyStoreProvider).activate(child);
      if (!mounted) return;
      ref.read(activeChildIdProvider.notifier).state = child.id;
      ref.invalidate(childProfileProvider);
      ref.invalidate(worldProgressProvider);
      ref.invalidate(allLessonProgressProvider);
      ref.read(learnerChosenThisSessionProvider.notifier).state = true;
      setState(() {
        _child = child;
        _page = 'home';
        _choosingLearner = false;
      });
    } catch (_) {
      if (mounted) {
        if (_child == null && !_choosingLearner) {
          setState(() => _error = 'تعذر اختيار الملف. حاول مرة أخرى.');
        } else {
          _notice('تعذر اختيار الملف. حاول مرة أخرى.');
        }
      }
    } finally {
      if (mounted) setState(() => _selectingLearner = false);
    }
  }

  Future<void> _addChild() async {
    final child = await showDialog<ChildProfile>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ChildProfileEditor());
    if (child == null || !mounted) return;
    try {
      final next = [...?_children, child];
      await ref.read(familyStoreProvider).save(next);
      if (!mounted) return;
      setState(() => _children = next);
      await _select(child);
    } catch (_) {
      if (mounted) _notice('تعذر حفظ الملف، أعد المحاولة.');
    }
  }

  Future<void> _editChild(ChildProfile previous) async {
    final changed = await showDialog<ChildProfile>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChildProfileEditor(profile: previous));
    if (changed == null || !mounted) return;
    try {
      final next =
          _children!.map((c) => c.id == previous.id ? changed : c).toList();
      await ref.read(familyStoreProvider).save(next);
      if (!mounted) return;
      setState(() => _children = next);
      await _select(changed);
      if (mounted) setState(() => _page = 'parents');
    } catch (_) {
      if (mounted) _notice('تعذر حفظ التعديلات. حاول مرة أخرى.');
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _parents() async {
    final allowed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const StableParentGate());
    if (allowed == true && mounted) setState(() => _page = 'parents');
  }

  void _lesson({String lessonId = 'alif', int? scene}) {
    if (_lessonOpen) return;
    _lessonOpen = true;
    // Navigation completes when the route closes, not when it opens. Do not
    // return that Future to FeedbackTap or it spins for the entire lesson.
    final query = <String, String>{
      'mode': _foundationTrack.queryValue,
      if (scene != null) 'scene': '$scene',
    };
    final uri = Uri(path: '/lesson/$lessonId', queryParameters: query);
    unawaited(context.push<void>(uri.toString()).then((_) {
      if (!mounted) return;
      _lessonOpen = false;
      ref.invalidate(worldProgressProvider);
      ref.invalidate(allLessonProgressProvider);
      ref.invalidate(journalDataProvider);
    }).catchError((Object error) {
      if (!mounted) return;
      _lessonOpen = false;
      _notice('تعذر فتح الدرس، حاول مرة أخرى.');
    }));
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(worldProgressProvider);
    final p = progress.valueOrNull;
    return PopScope(
      canPop: _page == 'home',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backFromPage();
      },
      child: Scaffold(
          body: ClassroomBackground(
        asset: _page == 'garden' || _page == 'foundationTracks'
            ? 'assets/backgrounds/garden_v36.png'
            : 'assets/backgrounds/courtyard_v38.png',
        child: SafeArea(child: LayoutBuilder(builder: (context, size) {
          if (_error != null) {
            return Center(
                child:
                    _Tile(title: _error!, icon: Icons.refresh, onTap: _load));
          }
          if (_choosingLearner && _children != null) {
            return LearnerChooser(
                children: _children!,
                onSelect: _select,
                busy: _selectingLearner);
          }
          if (_children == null || (_children!.isNotEmpty && _child == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_children!.isEmpty) return _WelcomeJourney(onStart: _addChild);
          return Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(children: [
                  SizedBox(
                      width: size.maxWidth * .23,
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: _Pill(
                              label: _child!.name,
                              avatar: CareerAvatar(
                                  index: careerIndex(
                                      _child!.avatar, _child!.gender),
                                  size: 32),
                              onTap: _parents))),
                  Expanded(
                      child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: Text(_title,
                              key: ValueKey('world-title-$_page'),
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: _ink,
                                  fontSize: size.maxHeight < 430 ? 22 : 30,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800)))),
                  SizedBox(
                      width: size.maxWidth * .23,
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: _Pill(
                              label: _page == 'home' ? 'للأهل' : 'الرئيسية',
                              icon: _page == 'home'
                                  ? Icons.lock_outline
                                  : Icons.home_rounded,
                              onTap:
                                  _page == 'home' ? _parents : _backFromPage))),
                ])),
            Expanded(
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    reverseDuration: const Duration(milliseconds: 360),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      if (MediaQuery.disableAnimationsOf(context)) return child;
                      final curved = CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic);
                      return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                              position: Tween<Offset>(
                                      begin: const Offset(-.075, 0),
                                      end: Offset.zero)
                                  .animate(curved),
                              child: ScaleTransition(
                                  scale: Tween<double>(begin: .985, end: 1)
                                      .animate(curved),
                                  child: child)));
                    },
                    child: KeyedSubtree(
                        key: ValueKey('world-page-$_page'),
                        child: _page == 'garden'
                            ? _garden(size, p)
                            : progress.isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : progress.hasError
                                    ? Center(
                                        child: _Tile(
                                            title: 'إعادة تحميل التقدم',
                                            icon: Icons.refresh,
                                            onTap: () => ref.invalidate(
                                                worldProgressProvider)))
                                    : switch (_page) {
                                        'foundationTracks' =>
                                          _foundationTracks(size),
                                        'review' => _review(p),
                                        'achievements' => _achievements(p),
                                        'portfolio' => const PortfolioView(),
                                        'parents' => _parentContent(p),
                                        _ => _home(size, p),
                                      }))),
          ]);
        })),
      )),
    );
  }

  String get _title => switch (_page) {
        'garden' => 'تأسيس اللغة العربية',
        'foundationTracks' => 'اختر مسار التعلّم',
        'review' => 'ألعب وأراجع',
        'achievements' => 'إنجازاتي',
        'parents' => 'ركن الأهل',
        'portfolio' => 'دفتر أعمالي',
        _ => 'تعلم مع صالح',
      };

  Widget _home(BoxConstraints size, LessonProgress? p) =>
      LayoutBuilder(builder: (context, box) {
        final compact = box.maxHeight < 310;
        final start = p?.completed == true ? 0 : p?.lastSceneIndex ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: Column(children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(compact ? 10 : 16),
                      decoration: BoxDecoration(
                          color: const Color(0xF5FFFDF7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 2)),
                      child: Column(children: [
                        Text('أهلًا ${_child!.name}!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: compact ? 18 : 24,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: _ink)),
                        const SizedBox(height: 6),
                        Text('هيا نكتشف شيئًا جميلًا اليوم',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _ink,
                                fontSize: compact ? 14 : 16,
                                height: 1.25,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    Expanded(
                        child: SalehVideoRenderer(
                            pose: _greeting ? SalehPose.waving : SalehPose.idle,
                            width: box.maxWidth * .24,
                            height: box.maxHeight * .7)),
                  ]),
                )),
            Expanded(
                flex: 7,
                child: Column(
                    key: const ValueKey('home-destinations'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          height: compact ? 72 : 96,
                          child: _ResumeCard(
                              completed: p?.completed == true,
                              title: p?.completed == true
                                  ? 'نبدأ رحلة الألف من جديد'
                                  : p == null
                                      ? 'ابدأ رحلتك'
                                      : 'أكمل رحلتك',
                              subtitle: p?.completed == true
                                  ? 'أَ • الدرس كاملًا من البداية'
                                  : 'حرف الألف • ${activityLabel(start)}',
                              onTap: () => _lesson())),
                      const SizedBox(height: 8),
                      Expanded(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            Expanded(
                                child: _Destination(
                                    title: 'تأسيس اللغة العربية',
                                    subtitle: 'رحلة القراءة',
                                    icon: Icons.auto_stories_rounded,
                                    background: 'garden',
                                    onTap: () => setState(
                                        () => _page = 'foundationTracks'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _Destination(
                                    title: 'ألعب وأراجع',
                                    subtitle: 'خطوة صغيرة كل يوم',
                                    icon: Icons.extension_rounded,
                                    background: 'classroom',
                                    onTap: () =>
                                        setState(() => _page = 'review'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _Destination(
                                    title: 'إنجازاتي',
                                    subtitle: 'أحتفظ بنجاحاتي',
                                    icon: Icons.workspace_premium_rounded,
                                    background: 'courtyard',
                                    onTap: () => setState(
                                        () => _page = 'achievements'))),
                          ])),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: const Color(0xF5FFFDF7),
                              borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            const ToyIcon(Toy.flower, size: 22),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                                    _child!.age <= 5
                                        ? 'نشاط قصير مع صالح، ثم استراحة.'
                                        : 'استمع إلى الحرف، ثم جرّب كتابته.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.2,
                                        color: _ink))),
                          ])),
                    ])),
          ]),
        );
      });

  Widget _garden(BoxConstraints size, LessonProgress? p) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: LessonsCatalog(onLesson: (id) => _lesson(lessonId: id)));

  void _backFromPage() {
    setState(() {
      _page = _page == 'garden' ? 'foundationTracks' : 'home';
    });
  }

  Widget _foundationTracks(BoxConstraints size) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xF5FFFDF7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Text(
              'اختروا الرحلة الأنسب، ويمكنكم تغييرها في أي وقت',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    child: FractionallySizedBox(
                      widthFactor: .96,
                      heightFactor: .90,
                      child: _FoundationTrackCard(
                    key: const ValueKey('track-read-write'),
                    title: 'تأسيس في القراءة والكتابة',
                    subtitle: 'أقرأ الحرف، أنطقه، ثم أتدرّب على كتابته',
                    colors: const [Color(0xFF7655B2), Color(0xFF9B7BD1)],
                    icon: const _FoundationTrackIcon.readWrite(),
                    onTap: () => _chooseFoundationTrack(
                      FoundationTrack.readWrite,
                    ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    child: FractionallySizedBox(
                      widthFactor: .96,
                      heightFactor: .90,
                      child: _FoundationTrackCard(
                    key: const ValueKey('track-reading'),
                    title: 'تأسيس في القراءة',
                    subtitle: 'أستمع وأتعرّف وأنطق، من دون أنشطة الكتابة',
                    colors: const [Color(0xFF168F8B), Color(0xFF49B9A8)],
                    icon: const _FoundationTrackIcon.reading(),
                    onTap: () => _chooseFoundationTrack(
                      FoundationTrack.reading,
                    ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    child: FractionallySizedBox(
                      widthFactor: .96,
                      heightFactor: .90,
                      child: _FoundationTrackCard(
                    key: const ValueKey('track-writing'),
                    title: 'تأسيس في الكتابة',
                    subtitle: 'أتتبّع الحرف بالدليل، ثم أكتبه كتابة حرة',
                    colors: const [Color(0xFFE28B45), Color(0xFFF0B85B)],
                    icon: const _FoundationTrackIcon.writing(),
                    onTap: () => _chooseFoundationTrack(
                      FoundationTrack.writing,
                    ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );

  void _chooseFoundationTrack(FoundationTrack track) {
    setState(() {
      _foundationTrack = track;
      _page = 'garden';
    });
  }

  Widget _review(LessonProgress? p) => const GamesHub();

  Widget _achievements(LessonProgress? p) => AchievementsView(
      progress: p, onPortfolio: () => setState(() => _page = 'portfolio'));

  Widget _parentContent(LessonProgress? p) => ParentDashboard(
      child: _child!,
      children: _children!,
      progress: p,
      onSelect: _select,
      onAdd: _addChild,
      onEdit: () => _editChild(_child!));
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label, required this.onTap, this.icon, this.avatar});
  final String label;
  final FutureOr<void> Function() onTap;
  final IconData? icon;
  final Widget? avatar;
  @override
  Widget build(BuildContext context) => FeedbackTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xF5FFFDF7),
            borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (avatar != null) ...[avatar!, const SizedBox(width: 7)],
          if (icon != null) ...[
            ToyIcon(toyForIcon(icon!), size: 28),
            const SizedBox(width: 5)
          ],
          Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      color: _ink,
                      fontWeight: FontWeight.bold))),
        ]),
      ));
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.icon, this.onTap})
      : color = _lavender;
  final String title;
  final IconData icon;
  final Color color;
  final FutureOr<void> Function()? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: onTap != null,
      child: FeedbackTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x246B5285),
                    offset: Offset(0, 5),
                    blurRadius: 0)
              ]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ToyIcon(toyForIcon(icon), size: 48),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
          ]),
        ),
      ));
}

class _Destination extends StatelessWidget {
  const _Destination(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.background,
      required this.onTap});
  final String title, subtitle, background;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxHeight < 165;
        return FeedbackTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            key: ValueKey('home-card-$title'),
            padding:
                EdgeInsets.symmetric(horizontal: 6, vertical: compact ? 5 : 12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFFDF7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x24796291),
                      offset: Offset(0, 4),
                      blurRadius: 6)
                ]),
            child: Column(children: [
              Expanded(
                  child: Center(
                      child:
                          ToyIcon(toyForIcon(icon), size: compact ? 38 : 64))),
              const SizedBox(height: 3),
              SizedBox(
                  height: compact ? 38 : 50,
                  child: Center(
                      child: Text(title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: compact ? 15 : 19,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              color: _ink)))),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, height: 1.2, color: _ink)),
            ]),
          ),
        );
      });
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard(
      {required this.title,
      required this.subtitle,
      required this.onTap,
      this.completed = false});
  final bool completed;
  final String title, subtitle;
  final FutureOr<void> Function() onTap;
  @override
  Widget build(BuildContext context) => FeedbackTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7356A5), Color(0xFF9474BF)]),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x266D5695),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ]),
        child: Row(children: [
          SizedBox(
              width: 44,
              height: 44,
              child: Stack(children: [
                Positioned.fill(
                    child: Container(
                        decoration: BoxDecoration(
                            color: const Color(0x26FFFFFF),
                            borderRadius: BorderRadius.circular(16)),
                        child: const LetterGlyph('أَ', color: Colors.white))),
                if (completed)
                  const PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: CompletionBadge(
                          key: ValueKey('home-lesson-complete'))),
              ])),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 18,
                        height: 1.15,
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, height: 1.25, color: Colors.white)),
              ])),
          const Icon(Icons.west_rounded, color: Colors.white, size: 28),
        ]),
      ));
}

class _WelcomeJourney extends StatelessWidget {
  const _WelcomeJourney({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxHeight < 430;
        return Padding(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Row(children: [
            Expanded(
                flex: 3,
                child: SalehVideoRenderer(
                    pose: SalehPose.idle,
                    width: box.maxWidth * .28,
                    height: box.maxHeight * .88)),
            SizedBox(width: compact ? 8 : 14),
            Expanded(
                flex: 6,
                child: Center(
                    child: Container(
                  constraints: BoxConstraints(maxHeight: compact ? 290 : 390),
                  padding: EdgeInsets.all(compact ? 14 : 24),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFAFFFDF8), Color(0xF8F4EEFF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26705A83),
                          blurRadius: 18,
                          offset: Offset(0, 7),
                        )
                      ]),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('أهلًا بكم في',
                            style: TextStyle(
                                color: _ink, fontSize: 15, height: 1.2)),
                        const SizedBox(height: 6),
                        Text('تعلم مع صالح',
                            style: TextStyle(
                                color: _ink,
                                fontSize: compact ? 26 : 36,
                                height: 1.15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('نتعلّم، نلعب، ونفرح بكل خطوة',
                            style: TextStyle(
                                color: const Color(0xFF287C79),
                                fontSize: compact ? 16 : 21,
                                height: 1.25,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: compact ? 10 : 18),
                        Row(children: [
                          Expanded(
                              child: _WelcomeFeature(
                                  icon: Icons.menu_book_rounded,
                                  label: 'نقرأ',
                                  color: const Color(0xFF7655B2),
                                  compact: compact)),
                          SizedBox(width: compact ? 6 : 10),
                          Expanded(
                              child: _WelcomeFeature(
                                  icon: Icons.edit_rounded,
                                  label: 'نكتب',
                                  color: const Color(0xFF168F8B),
                                  compact: compact)),
                          SizedBox(width: compact ? 6 : 10),
                          Expanded(
                              child: _WelcomeFeature(
                                  icon: Icons.extension_rounded,
                                  label: 'نلعب',
                                  color: const Color(0xFFE28B45),
                                  compact: compact)),
                        ]),
                        SizedBox(height: compact ? 10 : 18),
                        Row(children: [
                          Expanded(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(children: [
                                    CareerAvatar(
                                        index: 0, size: compact ? 44 : 64),
                                    const SizedBox(width: 8),
                                    CareerAvatar(
                                        index: 8, size: compact ? 44 : 64),
                                    const SizedBox(width: 8),
                                    CareerAvatar(
                                        index: 1, size: compact ? 44 : 64),
                                  ]))),
                          const SizedBox(width: 12),
                          JourneyButton(label: 'لنبدأ', onTap: onStart),
                        ]),
                      ]),
                ))),
          ]),
        );
      });
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        height: compact ? 46 : 62,
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(compact ? 14 : 18),
          border: Border.all(color: color.withValues(alpha: .28), width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: compact ? 21 : 28),
          SizedBox(width: compact ? 4 : 7),
          Flexible(
            child: Text(label,
                maxLines: 1,
                style: TextStyle(
                    color: _ink,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

class _FoundationTrackCard extends StatelessWidget {
  const _FoundationTrackCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        child: FeedbackTap(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.white, colors.last.withValues(alpha: .14)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: colors.first.withValues(alpha: .55), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26705A83),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Flexible(
                flex: 5,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: 128, maxHeight: 128),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: colors,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: .28),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconTheme(
                      data: const IconThemeData(color: Colors.white),
                      child: icon,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF71627F),
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.first,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text('ابدأ المسار',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                    SizedBox(width: 5),
                    Icon(Icons.west_rounded, size: 18),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

enum _TrackIconKind { readWrite, reading, writing }

class _FoundationTrackIcon extends StatelessWidget {
  const _FoundationTrackIcon.readWrite() : kind = _TrackIconKind.readWrite;
  const _FoundationTrackIcon.reading() : kind = _TrackIconKind.reading;
  const _FoundationTrackIcon.writing() : kind = _TrackIconKind.writing;

  final _TrackIconKind kind;

  @override
  Widget build(BuildContext context) => switch (kind) {
        _TrackIconKind.reading => const Icon(Icons.menu_book_rounded, size: 58),
        _TrackIconKind.writing => const Icon(Icons.draw_rounded, size: 58),
        _TrackIconKind.readWrite => const Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                  right: 0,
                  bottom: 1,
                  child: Icon(Icons.menu_book_rounded, size: 53)),
              Positioned(
                  left: 0, top: 0, child: Icon(Icons.edit_rounded, size: 32)),
            ],
          ),
      };
}
