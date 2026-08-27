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
import 'family_store.dart';
import 'profile_editor.dart';

const _ink = Color(0xFF594574);
const _lavender = Color(0xFFF0E8FA);
const _mint = Color(0xFFE6F4E9);

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
  String? _error;
  bool _greeting = true;
  Timer? _greetTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _greetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _greeting = false);
    });
  }

  @override
  void dispose() {
    _greetTimer?.cancel();
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
      });
      if (children.isNotEmpty) {
        await _select(children.firstWhere((c) => c.id == active,
            orElse: () => children.first));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر قراءة الملف. حاول مرة أخرى.');
    }
  }

  Future<void> _select(ChildProfile child) async {
    await ref.read(familyStoreProvider).activate(child);
    if (!mounted) return;
    ref.read(activeChildIdProvider.notifier).state = child.id;
    ref.invalidate(childProfileProvider);
    ref.invalidate(worldProgressProvider);
    setState(() {
      _child = child;
      _page = 'home';
    });
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

  Future<void> _lesson({int? scene}) async {
    await context.push('/lesson/alif${scene == null ? '' : '?scene=$scene'}');
    if (mounted) ref.invalidate(worldProgressProvider);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(worldProgressProvider);
    final p = progress.valueOrNull;
    return PopScope(
      canPop: _page == 'home',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _page = 'home');
      },
      child: Scaffold(
          body: ClassroomBackground(
        asset:
            'assets/backgrounds/${_page == 'garden' ? 'garden' : 'courtyard'}_v36.png',
        child: SafeArea(child: LayoutBuilder(builder: (context, size) {
          if (_error != null) {
            return Center(
                child:
                    _Tile(title: _error!, icon: Icons.refresh, onTap: _load));
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
                  _Pill(
                      label: _child!.name,
                      avatar: CareerAvatar(
                          index: careerIndex(_child!.avatar, _child!.gender),
                          size: 32),
                      onTap: _parents),
                  const Spacer(),
                  Text(_title,
                      style: TextStyle(
                          color: _ink,
                          fontSize: size.maxHeight < 430 ? 22 : 30,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  _Pill(
                      label: _page == 'home' ? 'للأهل' : 'الرئيسية',
                      icon: _page == 'home'
                          ? Icons.lock_outline
                          : Icons.home_rounded,
                      onTap: _page == 'home'
                          ? _parents
                          : () => setState(() => _page = 'home')),
                ])),
            Expanded(
                child: progress.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : progress.hasError
                        ? Center(
                            child: _Tile(
                                title: 'إعادة تحميل التقدم',
                                icon: Icons.refresh,
                                onTap: () =>
                                    ref.invalidate(worldProgressProvider)))
                        : switch (_page) {
                            'garden' => _garden(size, p),
                            'review' => _review(p),
                            'achievements' => _achievements(p),
                            'parents' => _parentContent(p),
                            _ => _home(size, p),
                          }),
          ]);
        })),
      )),
    );
  }

  String get _title => switch (_page) {
        'garden' => 'حديقة الحروف',
        'review' => 'ألعب وأراجع',
        'achievements' => 'إنجازاتي',
        'parents' => 'ركن الأهل',
        _ => 'تعلّم مع صالح',
      };

  Widget _home(BoxConstraints size, LessonProgress? p) {
    final small = size.maxHeight < 450;
    final start =
        p == null && _child!.level != 'beginner' ? 2 : p?.lastSceneIndex ?? 0;
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          flex: 3,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 18, 8),
              child: Column(children: [
                _Panel(
                    child: Column(children: [
                  Text('أهلًا ${_child!.name}!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: small ? 22 : 28,
                          fontWeight: FontWeight.w800,
                          color: _ink)),
                  const SizedBox(height: 4),
                  const Text('هيا نكتشف شيئًا جميلًا اليوم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                ])),
                Expanded(
                    child: SalehVideoRenderer(
                        pose: _greeting ? SalehPose.waving : SalehPose.idle,
                        width: size.maxWidth * .24,
                        height: size.maxHeight * .7)),
              ]))),
      Expanded(
          flex: 7,
          child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 6, 8, 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResumeCard(
                        title: p?.completed == true
                            ? 'لنراجع حرف الألف'
                            : p == null
                                ? 'ابدأ رحلتك'
                                : 'أكمل رحلتك',
                        subtitle: p?.completed == true
                            ? 'أَ • أنشطة تعلمتها مع صالح'
                            : 'حرف الألف • ${activityLabel(start)}',
                        onTap: () => _lesson(
                            scene: p?.completed == true
                                ? reviewScene(p, _child!)
                                : start)),
                    const SizedBox(height: 12),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: _Destination(
                                  title: 'دروسي',
                                  subtitle: 'حديقة الحروف',
                                  icon: Icons.auto_stories_rounded,
                                  background: 'garden',
                                  onTap: () =>
                                      setState(() => _page = 'garden'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _Destination(
                                  title: 'ألعب وأراجع',
                                  subtitle: 'خطوة صغيرة كل يوم',
                                  icon: Icons.extension_rounded,
                                  background: 'classroom',
                                  onTap: () =>
                                      setState(() => _page = 'review'))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _Destination(
                                  title: 'إنجازاتي',
                                  subtitle: 'أحتفظ بنجاحاتي',
                                  icon: Icons.workspace_premium_rounded,
                                  background: 'courtyard',
                                  onTap: () =>
                                      setState(() => _page = 'achievements'))),
                        ]),
                    const SizedBox(height: 10),
                    _Panel(
                        child: Row(children: [
                      const Icon(Icons.wb_sunny_rounded,
                          color: Color(0xFFD99D36)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_child!.age <= 5
                              ? 'خطوتك اليوم: نشاط قصير مع صالح، ثم استراحة.'
                              : 'خطوتك اليوم: استمع إلى الحرف، ثم جرّب كتابته.'))
                    ])),
                  ]))),
    ]);
  }

  Widget _garden(BoxConstraints size, LessonProgress? p) =>
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
        child: Column(children: [
          const _Panel(
              child: Text('تأسيس اللغة العربية  •  تعليم الحروف  •  الفتح',
                  style: TextStyle(color: _ink, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 24,
              runSpacing: 14,
              children: List.generate(
                  4,
                  (i) => Padding(
                        padding: EdgeInsets.only(top: i.isOdd ? 26 : 0),
                        child: SizedBox(
                          width: size.maxWidth < 700 ? 110 : 140,
                          child: _Tile(
                              title: ['أَ', 'بَ', 'تَ', 'ثَ'][i],
                              subtitle: i == 0
                                  ? (p?.completed == true
                                      ? 'اكتمل ✓'
                                      : 'ابدأ هنا')
                                  : 'قريبًا',
                              icon: i == 0
                                  ? Icons.local_florist_rounded
                                  : Icons.lock_outline,
                              color:
                                  i == 0 ? _lavender : const Color(0xFFEFEFE7),
                              onTap: i == 0 ? () => _showAlif(p) : null),
                        ),
                      ))),
          const SizedBox(height: 20),
          const _Panel(
              child: Text(
                  'المتاح الآن: حرف الألف. بقية الحروف والمراحل تأتي تباعًا.',
                  textAlign: TextAlign.center)),
        ]),
      );

  Future<void> _showAlif(LessonProgress? p) => showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
            title: const Text('حرف الألف — أَ'),
            content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                    child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final entry in [
                      (Icons.hearing_rounded, 'أستمع', 2),
                      (Icons.mic_rounded, 'أنطق', 3),
                      (Icons.edit_rounded, 'أكتب', 4),
                      (Icons.extension_rounded, 'ألعب', 6)
                    ])
                      SizedBox(
                          width: 112,
                          child: _Tile(
                              title: entry.$2,
                              icon: entry.$1,
                              onTap: () {
                                Navigator.pop(dialogContext);
                                _lesson(scene: entry.$3);
                              })),
                  ],
                ))),
            actions: [
              _Pill(
                  label: 'الدرس كاملًا',
                  onTap: () {
                    Navigator.pop(dialogContext);
                    _lesson(scene: 0);
                  }),
              _Pill(label: 'عودة', onTap: () => Navigator.pop(dialogContext))
            ],
          ));

  Widget _review(LessonProgress? p) {
    final scene = reviewScene(p, _child!);
    return Center(
        child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
          width: 580,
          child: _Panel(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.extension_rounded, size: 56, color: _ink),
            const SizedBox(height: 12),
            Text(
                p == null ? 'نكتشف الألف أولًا' : 'نتدرّب قليلًا، ونفرح كثيرًا',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: _ink)),
            const SizedBox(height: 10),
            Text(
                '${activityLabel(scene)}\nبلا وقت ضاغط، ويمكنك المحاولة مرة أخرى.',
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            _Tile(
                title: 'هيا يا صالح',
                icon: Icons.play_arrow_rounded,
                onTap: () => _lesson(scene: scene)),
          ]))),
    ));
  }

  Widget _achievements(LessonProgress? p) {
    final completed = p?.completedScenes ?? [];
    final badges = [
      ('مستكشف الألف', Icons.explore_rounded, completed.contains('explain_1')),
      ('قلمي الجميل', Icons.draw_rounded, completed.contains('write_guided_1')),
      ('أكملت الدرس', Icons.emoji_events_rounded, p?.completed == true),
    ];
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const _Panel(
              child:
                  Text('كل خطوة تستحق الفرح. الملصقات تضيء بعد إنجاز نشاطها.')),
          const SizedBox(height: 24),
          Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                for (final badge in badges)
                  SizedBox(
                      width: 180,
                      child: _Tile(
                          title: badge.$1,
                          icon: badge.$2,
                          subtitle: badge.$3 ? 'أنجزتها ✓' : 'بانتظار رحلتك',
                          color: badge.$3 ? _mint : const Color(0xFFF0EEEB))),
              ]),
        ]));
  }

  Widget _parentContent(LessonProgress? p) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('تقدم ${_child!.name}',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _ink)),
                Text(
                    'أنشطة منجزة دون تخطي: ${p?.completedScenes.length ?? 0}  •  '
                    'محاولات مسجلة: ${p?.attempts.values.fold<int>(0, (a, b) => a + b) ?? 0}'),
                Text(p?.completed == true
                    ? 'أكمل رحلة درس الألف.'
                    : 'المتابعة: ${activityLabel(p?.lastSceneIndex ?? 0)}'),
                const SizedBox(height: 6),
                const Text(
                    'هذه مؤشرات ممارسة وليست حكمًا على إتقان النطق. استمع لطفلك وشجعه.\nبيانات النسخ القديمة قد لا تتضمن تفاصيل الأنشطة.'),
                Text(
                    'نقترح: ${activityLabel(reviewScene(p, _child!))} مع استراحة قصيرة.'),
              ])),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (final child in _children!)
              SizedBox(
                  width: 170,
                  child: _Tile(
                      title: child.name,
                      artwork: CareerAvatar(
                          index: careerIndex(child.avatar, child.gender)),
                      subtitle: child.id == _child!.id
                          ? 'الملف الحالي'
                          : 'تبديل الطفل',
                      icon: Icons.person_rounded,
                      onTap: () => _select(child))),
            SizedBox(
                width: 170,
                child: _Tile(
                    title: 'إضافة طفل',
                    icon: Icons.person_add_alt_1,
                    onTap: _addChild)),
            JourneyButton(
                label: 'تعديل ملف الطفل', onTap: () => _editChild(_child!)),
          ]),
          const SizedBox(height: 12),
          const Text('نسخة تجريبية 37 • الملفات محلية، بلا حساب أو صور شخصية',
              style: TextStyle(color: _ink)),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xF5FFFDF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x18645132),
                  blurRadius: 14,
                  offset: Offset(0, 5))
            ]),
        child: child,
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xF5FFFDF7),
            borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (avatar != null) ...[avatar!, const SizedBox(width: 7)],
          if (icon != null) ...[
            Icon(icon, size: 20, color: _ink),
            const SizedBox(width: 5)
          ],
          Text(label,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.bold)),
        ]),
      ));
}

class _Tile extends StatelessWidget {
  const _Tile(
      {required this.title,
      required this.icon,
      this.subtitle,
      this.onTap,
      this.color = _lavender,
      this.artwork});
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? artwork;
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
            artwork ?? Icon(icon, color: _ink, size: 30),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
            if (subtitle != null)
              Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _ink, height: 1.35))),
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
  Widget build(BuildContext context) => FeedbackTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
            color: const Color(0xFFFFFDF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x24796291), offset: Offset(0, 5), blurRadius: 6)
            ]),
        child: Column(children: [
          ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(21)),
              child: SizedBox(
                  height: 68,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.asset('assets/backgrounds/${background}_v36.png',
                        fit: BoxFit.cover),
                    Center(
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                                color: Color(0xDEFFFFFF),
                                shape: BoxShape.circle),
                            child: Icon(icon, size: 30, color: _ink))),
                  ]))),
          Padding(
              padding: const EdgeInsets.fromLTRB(6, 9, 6, 12),
              child: Column(children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _ink)),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _ink)),
              ])),
        ]),
      ));
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard(
      {required this.title, required this.subtitle, required this.onTap});
  final String title, subtitle;
  final FutureOr<void> Function() onTap;
  @override
  Widget build(BuildContext context) => FeedbackTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
          Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(16)),
              child: const Text('أَ',
                  style: TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 23,
                        color: Colors.white,
                        fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ])),
          const Icon(Icons.west_rounded, color: Colors.white, size: 28),
        ]),
      ));
}

class _WelcomeJourney extends StatelessWidget {
  const _WelcomeJourney({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Expanded(
              flex: 3,
              child: SalehVideoRenderer(
                  pose: SalehPose.idle,
                  width: MediaQuery.sizeOf(context).width * .28,
                  height: MediaQuery.sizeOf(context).height * .85)),
          const SizedBox(width: 14),
          Expanded(
              flex: 6,
              child: SingleChildScrollView(
                  child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xF5F8F6FD),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x247A6289),
                          blurRadius: 24,
                          offset: Offset(0, 8))
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أهلًا بكم في',
                          style: TextStyle(color: _ink, fontSize: 18)),
                      const Text('تعلّم مع صالح',
                          style: TextStyle(
                              color: _ink,
                              fontSize: 36,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('نتعلّم، نلعب، ونفرح بكل خطوة',
                          style: TextStyle(
                              color: Color(0xFF287C79),
                              fontSize: 21,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      const Row(children: [
                        CareerAvatar(index: 0, size: 58),
                        SizedBox(width: 10),
                        CareerAvatar(index: 8, size: 58),
                        SizedBox(width: 10),
                        CareerAvatar(index: 1, size: 58)
                      ]),
                      const SizedBox(height: 18),
                      Row(children: [
                        const Expanded(
                            child: Text('شخصيتك… ورحلتك الخاصة',
                                style: TextStyle(color: _ink, fontSize: 15))),
                        JourneyButton(label: 'لنبدأ', onTap: onStart)
                      ]),
                    ]),
              ))),
        ]),
      );
}
