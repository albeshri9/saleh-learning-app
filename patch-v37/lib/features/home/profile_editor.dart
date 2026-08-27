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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                Text(label,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: secondary ? profileInk : Colors.white)),
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
  late String _level = widget.profile?.level ?? 'beginner';
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
      insetPadding: const EdgeInsets.all(14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF7960AD)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        widget.profile == null
                            ? 'لنصنع رحلتك!'
                            : 'تعديل ملف الطفل',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: profileInk))),
                FeedbackTap(
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.close_rounded))),
              ])),
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        flex: 2,
                        child: Column(children: [
                          TextField(
                              key: const ValueKey('child-name'),
                              controller: _name,
                              maxLength: 18,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              decoration: _field(
                                  'أدخل الاسم', Icons.person_outline_rounded)),
                          DropdownButtonFormField<int>(
                              key: const ValueKey('child-age'),
                              initialValue: _age,
                              hint: const Text('اختر العمر'),
                              onTap: InteractionEffects.pulse,
                              decoration: _field('العمر', Icons.cake_outlined),
                              items: [3, 4, 5, 6, 7, 8, 9]
                                  .map((n) => DropdownMenuItem(
                                      value: n, child: Text('$n سنوات')))
                                  .toList(),
                              onChanged: (n) {
                                InteractionEffects.pulse();
                                setState(() => _age = n);
                              }),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                              initialValue: _level,
                              isExpanded: true,
                              decoration: _field(
                                  'نقطة البداية', Icons.auto_stories_outlined),
                              onTap: InteractionEffects.pulse,
                              items: const [
                                DropdownMenuItem(
                                    value: 'beginner',
                                    child: Text('أبدأ تعلم الحروف')),
                                DropdownMenuItem(
                                    value: 'letters',
                                    child: Text('أعرف بعض الحروف')),
                                DropdownMenuItem(
                                    value: 'vowels',
                                    child: Text('أتدرب على الحركات'))
                              ],
                              onChanged: (v) {
                                InteractionEffects.pulse();
                                setState(() => _level = v!);
                              }),
                        ])),
                    const SizedBox(width: 18),
                    Expanded(
                        flex: 3,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('من تحب أن تكون؟',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: profileInk)),
                              const SizedBox(height: 8),
                              LayoutBuilder(builder: (context, bounds) {
                                final width = (bounds.maxWidth - 30) / 6;
                                final avatarSize = min(56.0, width - 6);
                                return Wrap(
                                    spacing: 6,
                                    runSpacing: 12,
                                    children: List.generate(
                                        12,
                                        (i) => SizedBox(
                                              width: width,
                                              child: FeedbackTap(
                                                onTap: () =>
                                                    setState(() => _avatar = i),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 5),
                                                  decoration: BoxDecoration(
                                                      color: i == _avatar
                                                          ? const Color(
                                                              0xFFE6DCF7)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                      border: Border.all(
                                                          color: i == _avatar
                                                              ? const Color(
                                                                  0xFF7960AD)
                                                              : const Color(
                                                                  0xFFE7E2ED),
                                                          width: 2)),
                                                  child: Column(children: [
                                                    CareerAvatar(
                                                        index: i,
                                                        size: avatarSize),
                                                    SizedBox(
                                                        height: 30,
                                                        child: Center(
                                                            child: Text(
                                                                careers[i],
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color:
                                                                        profileInk,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold)))),
                                                    Icon(
                                                        i == _avatar
                                                            ? Icons
                                                                .check_circle_rounded
                                                            : Icons
                                                                .circle_outlined,
                                                        size: 14,
                                                        color: const Color(
                                                            0xFF7960AD)),
                                                  ]),
                                                ),
                                              ),
                                            )));
                              }),
                            ])),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                      'يمكن لولي الأمر تعديل البيانات لاحقًا. تُحفظ على هذا الجهاز فقط.',
                      style: TextStyle(fontSize: 12, color: profileInk)),
                ]),
          )),
          Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 14),
              child: Row(children: [
                Expanded(
                    child: Text(
                        _valid
                            ? 'كل شيء جاهز!'
                            : 'أدخل الاسم واختر العمر للمتابعة',
                        style: const TextStyle(color: profileInk))),
                JourneyButton(
                    key: const ValueKey('save-profile'),
                    label:
                        widget.profile == null ? 'حفظ وابدأ' : 'حفظ التعديلات',
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
                                level: _level))),
              ])),
        ]),
      ));
  InputDecoration _field(String label, IconData icon) => InputDecoration(
        labelText: label,
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
  const StableParentGate({super.key});
  @override
  State<StableParentGate> createState() => _StableParentGateState();
}

class _StableParentGateState extends State<StableParentGate> {
  final int _a = 12 + Random().nextInt(8), _b = 6 + Random().nextInt(9);
  String _answer = '';
  bool _wrong = false;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFFF8F6FD),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: SizedBox(
          width: 460,
          height: min(440, MediaQuery.sizeOf(context).height - 32),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Text('خطوة صغيرة لولي الأمر',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: profileInk)),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.ltr,
                    children: [
                      Text('$_a + $_b = ',
                          textDirection: TextDirection.ltr,
                          key: const ValueKey('parent-question'),
                          style:
                              const TextStyle(fontSize: 26, color: profileInk)),
                      Text(_answer.isEmpty ? '؟' : _answer,
                          textDirection: TextDirection.ltr,
                          key: const ValueKey('parent-answer'),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF258D89))),
                    ]),
                Text(
                    _wrong
                        ? 'لم تتطابق الإجابة، حاول مرة أخرى'
                        : 'استخدم الأرقام أدناه، ثم اضغط متابعة',
                    style: TextStyle(
                        fontSize: 13,
                        color: _wrong ? const Color(0xFFA46718) : profileInk)),
                const SizedBox(height: 6),
                Expanded(
                    child: LayoutBuilder(
                        builder: (context, bounds) => GridView.count(
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 6,
                              childAspectRatio: ((bounds.maxWidth - 12) / 3) /
                                  ((bounds.maxHeight - 12) / 4),
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
                                  FeedbackTap(
                                      key: ValueKey('digit-$digit'),
                                      onTap: () => setState(() {
                                            _wrong = false;
                                            if (digit == 'مسح') {
                                              _answer = '';
                                            } else if (digit == '⌫') {
                                              if (_answer.isNotEmpty) {
                                                _answer = _answer.substring(
                                                    0, _answer.length - 1);
                                              }
                                            } else if (_answer.length < 3) {
                                              _answer += digit;
                                            }
                                          }),
                                      child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFD9CEE8))),
                                          child: digit == '⌫'
                                              ? const Icon(
                                                  Icons.backspace_outlined,
                                                  color: profileInk,
                                                  size: 22)
                                              : Text(digit,
                                                  style: const TextStyle(
                                                      fontSize: 22,
                                                      color: profileInk)))),
                              ],
                            ))),
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      JourneyButton(
                          label: 'عودة',
                          secondary: true,
                          onTap: () => Navigator.pop(context, false)),
                      JourneyButton(
                          label: 'متابعة',
                          onTap: () {
                            if (int.tryParse(_answer) == _a + _b) {
                              Navigator.pop(context, true);
                            } else {
                              setState(() {
                                _wrong = true;
                                _answer = '';
                              });
                            }
                          }),
                    ]),
              ])),
        ),
      ));
}
