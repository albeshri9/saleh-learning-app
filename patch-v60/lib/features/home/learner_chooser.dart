import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../../domain/models/child_profile.dart';
import 'profile_editor.dart';

class LearnerChooser extends StatelessWidget {
  const LearnerChooser(
      {super.key,
      required this.children,
      required this.onSelect,
      this.busy = false});
  final List<ChildProfile> children;
  final FutureOr<void> Function(ChildProfile) onSelect;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text('من يتعلم اليوم؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: profileInk)),
              const SizedBox(height: 6),
              const Text('اختر شخصيتك لنبدأ رحلتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: profileInk)),
              const SizedBox(height: 18),
              Expanded(child: LayoutBuilder(builder: (context, box) {
                final columns =
                    math.min(children.length, box.maxWidth >= 650 ? 4 : 3);
                final rows = (children.length / columns).ceil();
                final height = ((box.maxHeight - 8 - 12 * (rows - 1)) / rows)
                    .clamp(150.0, 230.0);
                return GridView.count(
                  padding: const EdgeInsets.all(4),
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio:
                      ((box.maxWidth - 8 - 12 * (columns - 1)) / columns) /
                          height,
                  children: [
                    for (final child in children)
                      FeedbackTap(
                        onTap: busy ? null : () => onSelect(child),
                        child: Container(
                          key: ValueKey('learner-choice-${child.id}'),
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: const Color(0xFAFFFDF9),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: const Color(0xFFCCBAE6), width: 2)),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                    child: Center(
                                        child: CareerAvatar(
                                            index: careerIndex(
                                                child.avatar, child.gender),
                                            size: 112))),
                                const SizedBox(height: 8),
                                Text(child.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: profileInk)),
                              ]),
                        ),
                      ),
                  ],
                );
              })),
            ]),
          ),
        ),
      );
}
