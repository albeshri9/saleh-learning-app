import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../../domain/models/child_profile.dart';

const profileInk = Color(0xFF493562);
const careers = [
  'مهندس',
  'طيار',
  'طبيب',
  'معلّم',
  'إطفائي',
  'رائد فضاء',
  'مهندسة',
  'طيارة',
  'طبيبة',
  'معلّمة',
  'إطفائية',
  'رائدة فضاء'
];

int careerIndex(String value, ChildGender gender) {
  final index = int.tryParse(value.replaceFirst('career_', ''));
  return index != null && index >= 0 && index < careers.length
      ? index
      : gender == ChildGender.female
          ? 8
          : 0;
}

class CareerAvatar extends StatelessWidget {
  const CareerAvatar({super.key, required this.index, this.size = 64});
  final int index;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      label: careers[index],
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: SizedBox.square(
            dimension: size,
            child: Stack(children: [
              Positioned(
                  left: -(index % 6) * size,
                  top: -(index ~/ 6) * size * 1.5,
                  width: size * 6,
                  height: size * 3,
                  child: Image.asset('assets/avatars/careers_v37.png',
                      fit: BoxFit.fill, filterQuality: FilterQuality.high)),
            ])),
      ));
}

/// Direction is physical, never mirrored by Arabic Directionality.
class JourneyButton extends StatelessWidget {
  const JourneyButton(
      {super.key, required this.label, this.onTap, this.secondary = false});
  final String label;
  final VoidCallback? onTap;
  final bool secondary;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      enabled: onTap != null,
      child: FeedbackTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
              color: onTap == null
                  ? const Color(0xFFE2DFE8)
                  : secondary
                      ? Colors.white
                      : const Color(0xFF7960AD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: secondary ? const Color(0xFFD9CEE8) : Colors.white,
                  width: 2),
              boxShadow: onTap == null || secondary
                  ? []
                  : const [
                      BoxShadow(
                          color: Color(0x2856407C),
                          offset: Offset(0, 4),
                          blurRadius: 10)
                    ]),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: TextDirection.ltr,
              children: [
                Icon(Icons.west_rounded,
                    size: 22, color: secondary ? profileInk : Colors.white),
                const SizedBox(width: 10),
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: secondary ? profileInk : Colors.white))),
              ]),
        ),
      ));
}

class ChildProfileEditor extends StatefulWidget {
  const ChildProfileEditor({super.key, this.profile});
  final ChildProfile? profile;
  @override
  State<ChildProfileEditor> createState() => _ChildProfileEditorState();
}

class _ChildProfileEditorState extends State<ChildProfileEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile?.name ?? '');
  late int? _age = widget.profile?.age;

  late int _avatar = careerIndex(
      widget.profile?.avatar ?? '', widget.profile?.gender ?? ChildGender.male);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _age != null;
  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: const Color(0xFFF8F6FD),
        insetPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: LayoutBuilder(builder: (context, bounds) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final wide = bounds.maxWidth > 480;
          final height = min(590.0, bounds.maxHeight);
          final content = Column(children: [
            SizedBox(
                height: 48,
                child: Row(children: [
                  const SizedBox(width: 16),
                  Expanded(
                      child: Text(
                          widget.profile == null
                              ? 'لنصنع رحلتك!'
                              : 'تعديل ملف الطفل',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: profileInk))),
                  IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded)),
                ])),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                                Expanded(flex: 3, child: _details()),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: _avatars()),
                              ])
                        : Column(children: [
                            SizedBox(height: 130, child: _details()),
                            const SizedBox(height: 8),
                            Expanded(child: _avatars()),
                          ]))),
            Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          _valid ? 'جاهز للانطلاق!' : 'أدخل الاسم واختر العمر',
                          style: const TextStyle(
                              color: profileInk, fontSize: 14))),
                  JourneyButton(
                      key: const ValueKey('save-profile'),
                      label: widget.profile == null
                          ? 'حفظ وابدأ'
                          : 'حفظ التعديلات',
                      onTap: !_valid
                          ? null
                          : () => Navigator.pop(
                              context,
                              ChildProfile(
                                  id: widget.profile?.id ??
                                      'child_${DateTime.now().microsecondsSinceEpoch}',
                                  name: _name.text.trim(),
                                  age: _age!,
                                  gender: _avatar < 6
                                      ? ChildGender.male
                                      : ChildGender.female,
                                  avatar: 'career_$_avatar',
                                  level: widget.profile?.level ?? 'beginner'))),
                ])),
          ]);
          // Keyboard is the sole temporary exception: keep fields reachable, then
          // return to the full no-scroll layout when it is dismissed.
          return SizedBox(
              width: 940,
              height: height,
              child: keyboard
                  ? SingleChildScrollView(
                      child: SizedBox(height: max(height, 330), child: content))
                  : content);
        }),
      );

  Widget _details() =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextField(
            key: const ValueKey('child-name'),
            controller: _name,
            style:
                const TextStyle(fontSize: 16, height: 1.25, color: profileInk),
            maxLength: 18,
            textInputAction: TextInputAction.done,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onChanged: (_) => setState(() {}),
            decoration: _field('أدخل الاسم', Icons.person_outline_rounded)
                .copyWith(counterText: '')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
            key: const ValueKey('child-age'),
            initialValue: _age,
            style:
                const TextStyle(fontSize: 16, height: 1.25, color: profileInk),
            hint: const Text('اختر العمر'),
            isExpanded: true,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              InteractionEffects.pulse();
            },
            decoration: _field('العمر', Icons.cake_outlined),
            items: [3, 4, 5, 6, 7, 8, 9]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n سنوات')))
                .toList(),
            onChanged: (n) {
              InteractionEffects.pulse();
              setState(() => _age = n);
            }),
      ]);

  Widget _avatars() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('اختر شخصيتك',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: profileInk)),
        const SizedBox(height: 6),
        Expanded(child: LayoutBuilder(builder: (context, b) {
          final columns = b.maxWidth > 410 || b.maxHeight < 230 ? 6 : 4;
          final rows = (12 / columns).ceil();
          final tileWidth = (b.maxWidth - (columns - 1) * 6) / columns;
          final tileHeight = (b.maxHeight - (rows - 1) * 6) / rows;
          final portrait =
              max(28.0, min(70.0, min(tileWidth - 10, tileHeight - 32)));
          return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  mainAxisExtent: tileHeight),
              itemCount: careers.length,
              itemBuilder: (context, i) => Semantics(
                    selected: i == _avatar,
                    button: true,
                    label: careers[i],
                    child: FeedbackTap(
                        key: ValueKey('career-$i'),
                        onTap: () => setState(() => _avatar = i),
                        child: Container(
                            decoration: BoxDecoration(
                                color: i == _avatar
                                    ? const Color(0xFFE2D6F1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: i == _avatar
                                        ? const Color(0xFF7960AD)
                                        : const Color(0xFFE2DFEB),
                                    width: 2)),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CareerAvatar(index: i, size: portrait),
                                  const SizedBox(height: 3),
                                  SizedBox(
                                      height: 22,
                                      child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(careers[i],
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.2,
                                                  color: profileInk)))),
                                ]))),
                  ));
        })),
      ]);

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 14, height: 1.2, color: profileInk),
        prefixIcon: Icon(icon, color: const Color(0xFF7960AD)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD9CEE8))),
      );
}

/// Persistent question + on-screen keypad: no software keyboard can cover it.
class StableParentGate extends StatefulWidget {
  const StableParentGate({super.key, this.random});
  @visibleForTesting
  final Random? random;
  @override
  State<StableParentGate> createState() => _StableParentGateState();
}

class _StableParentGateState extends State<StableParentGate> {
  static const _numberWords = [
    'صفر',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة'
  ];
  late final List<int> _code = (List<int>.generate(10, (i) => i)
        ..shuffle(widget.random ?? Random()))
      .take(3)
      .toList();
  String _answer = '';
  bool _wrong = false;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFFF8F6FD),
        insetPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: LayoutBuilder(builder: (context, bounds) {
          final split = bounds.maxWidth >= 480 && bounds.maxHeight < 460;
          final height = min(split ? 330.0 : 520.0, bounds.maxHeight);
          return SizedBox(
            width: split ? 760 : 460,
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          Expanded(
                            child: Column(children: [
                              Expanded(child: Center(child: _question())),
                              const SizedBox(height: 8),
                              _actions(),
                            ]),
                          ),
                          const SizedBox(width: 18),
                          Expanded(child: _keypad()),
                        ])
                  : Column(children: [
                      _question(),
                      const SizedBox(height: 12),
                      Expanded(child: _keypad()),
                      const SizedBox(height: 10),
                      _actions(),
                    ]),
            ),
          );
        }),
      ));

  Widget _question() => Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('خطوة صغيرة لولي الأمر',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                height: 1.2,
                fontWeight: FontWeight.bold,
                color: profileInk)),
        const SizedBox(height: 10),
        Text(_code.map((d) => _numberWords[d]).join(' — '),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            key: const ValueKey('parent-question'),
            style: const TextStyle(
                fontSize: 20,
                height: 1.25,
                fontWeight: FontWeight.w500,
                color: profileInk)),
        const SizedBox(height: 6),
        Text(
            List.generate(3, (i) => i < _answer.length ? _answer[i] : '•')
                .join('  '),
            textDirection: TextDirection.ltr,
            key: const ValueKey('parent-answer'),
            style: const TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.bold,
                color: Color(0xFF258D89))),
        const SizedBox(height: 6),
        Text(
            _wrong
                ? 'لم تتطابق الإجابة، حاول مرة أخرى'
                : 'اختر الأرقام المكتوبة بالترتيب، ثم اضغط متابعة',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                height: 1.25,
                color: _wrong ? const Color(0xFFA46718) : profileInk)),
      ]);

  Widget _keypad() => LayoutBuilder(builder: (context, bounds) {
        // Reserve an actual touch target, not whatever sliver the text leaves.
        // A tiny/keyboard-constrained viewport can scroll; digits never get clipped.
        final keyHeight = max(44.0, (bounds.maxHeight - 18) / 4);
        return Directionality(
          textDirection: TextDirection.ltr,
          child: GridView.count(
            key: const ValueKey('parent-keypad'),
            padding: EdgeInsets.zero,
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: ((bounds.maxWidth - 12) / 3) / keyHeight,
            children: [
              for (final digit in [
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
                '⌫',
                '0',
                'مسح'
              ])
                Semantics(
                  button: true,
                  label: digit == '⌫' ? 'حذف الرقم الأخير' : digit,
                  child: FeedbackTap(
                    key: ValueKey('digit-$digit'),
                    onTap: () => setState(() {
                      _wrong = false;
                      if (digit == 'مسح') {
                        _answer = '';
                      } else if (digit == '⌫') {
                        if (_answer.isNotEmpty) {
                          _answer = _answer.substring(0, _answer.length - 1);
                        }
                      } else if (_answer.length < 3) {
                        _answer += digit;
                      }
                    }),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD9CEE8))),
                      child: digit == '⌫'
                          ? const Icon(Icons.backspace_outlined,
                              color: profileInk, size: 22)
                          : Text(digit,
                              style: TextStyle(
                                  fontSize: digit == 'مسح' ? 16 : 22,
                                  height: 1.1,
                                  color: profileInk)),
                    ),
                  ),
                ),
            ],
          ),
        );
      });

  Widget _actions() => Row(children: [
        Expanded(
            child: JourneyButton(
                label: 'عودة',
                secondary: true,
                onTap: () => Navigator.pop(context, false))),
        const SizedBox(width: 8),
        Expanded(
            child: JourneyButton(
                label: 'متابعة',
                onTap: () {
                  if (_answer == _code.join()) {
                    Navigator.pop(context, true);
                  } else {
                    setState(() {
                      _wrong = true;
                      _answer = '';
                    });
                  }
                })),
      ]);
}
