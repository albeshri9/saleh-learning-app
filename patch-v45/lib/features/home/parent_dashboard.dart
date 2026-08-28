import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/design/widgets/touch_feedback.dart';
import '../../core/design/widgets/toy_icon.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/progress.dart';
import 'profile_editor.dart';

class ParentDashboard extends StatelessWidget {
  const ParentDashboard(
      {super.key,
      required this.child,
      required this.children,
      required this.progress,
      required this.onSelect,
      required this.onAdd,
      required this.onEdit});
  final ChildProfile child;
  final List<ChildProfile> children;
  final LessonProgress? progress;
  final FutureOr<void> Function(ChildProfile) onSelect;
  final FutureOr<void> Function() onAdd, onEdit;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(children: [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xF5FFFDF7),
                borderRadius: BorderRadius.circular(22)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ملف ${child.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: profileInk)),
              Text(
                  'درس الألف • أنشطة مكتملة: ${progress?.completedScenes.length ?? 0} • محاولات: ${progress?.attempts.values.fold<int>(0, (a, b) => a + b) ?? 0}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: profileInk)),
              const Text(
                  'مؤشرات ممارسة، وليست حكمًا على إتقان النطق. استمع لطفلك وشجعه.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: profileInk)),
            ])),
        const SizedBox(height: 10),
        Expanded(child: LayoutBuilder(builder: (context, bounds) {
          final tiles = <Widget>[
            for (final profile in children)
              _ProfileAction(
                  id: profile.id,
                  title: profile.name,
                  subtitle:
                      profile.id == child.id ? 'الملف الحالي' : 'تبديل الطفل',
                  artwork: CareerAvatar(
                      index: careerIndex(profile.avatar, profile.gender),
                      size: 52),
                  onTap: () => onSelect(profile),
                  selected: profile.id == child.id),
            _ProfileAction(
                id: 'add',
                title: 'إضافة طفل',
                subtitle: 'ملف جديد',
                artwork: const ToyIcon(Toy.album, size: 52),
                onTap: onAdd),
            _ProfileAction(
                id: 'edit',
                title: 'تعديل ملف الطفل',
                subtitle: 'الاسم والعمر والشخصية',
                artwork: const ToyIcon(Toy.pencil, size: 52),
                onTap: onEdit),
          ];
          final columns =
              math.min(tiles.length, bounds.maxWidth >= 650 ? 4 : 3);
          final rows = (tiles.length / columns).ceil();
          final tileHeight =
              math.max(118.0, (bounds.maxHeight - 8 * (rows - 1)) / rows);
          return GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio:
                  ((bounds.maxWidth - 8 * (columns - 1)) / columns) /
                      tileHeight,
              children: tiles);
        })),
      ]));
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction(
      {required this.id,
      required this.title,
      required this.subtitle,
      required this.artwork,
      required this.onTap,
      this.selected = false});
  final String id, title, subtitle;
  final Widget artwork;
  final FutureOr<void> Function() onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => FeedbackTap(
      onTap: onTap,
      child: Container(
          key: ValueKey('profile-action-$id'),
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFFE7DCF7) : const Color(0xFFF7F2FC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: selected ? const Color(0xFF9072C4) : Colors.white,
                  width: 2)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox.square(dimension: 52, child: artwork),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: profileInk)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: profileInk)),
          ])));
}
