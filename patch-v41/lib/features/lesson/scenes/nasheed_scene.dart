import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/widgets/app_button.dart';
import '../../../domain/models/lesson.dart';
import '../../../services/audio/audio_service.dart';
import '../scene_registry.dart';

/// مشهد الأنشودة: الوسيط (صوت/فيديو) يأتي من المحتوى.
/// يشغَّل الصوت عبر AudioService مع مؤشر تقدم،
/// وينتقل تلقائيًا عند الانتهاء.
class NasheedScene extends ConsumerStatefulWidget {
  const NasheedScene({super.key, required this.scene, required this.api});

  final Scene scene;
  final SceneApi api;

  @override
  ConsumerState<NasheedScene> createState() => _NasheedSceneState();
}

class _NasheedSceneState extends ConsumerState<NasheedScene>
    with SingleTickerProviderStateMixin {
  late final Duration _length = Duration(
    milliseconds:
        (((widget.scene.data['durationSec'] as num?) ?? 8) * 1000).round(),
  );
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _length);

  /// يُحتفظ بالخدمة منذ initState: قراءة `ref` داخل dispose ترمي
  /// «Cannot use "ref" after the widget was disposed» عند مغادرة المشهد،
  /// لأن ConsumerState يبطل الـ ref قبل استدعاء dispose.
  late final AudioService _audio;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    // ننتظر تقديم صالح ثم نشغل الأنشودة.
    widget.api.channel.scriptFinished.addListener(_maybeStart);
  }

  void _maybeStart() {
    if (widget.scene.data['media'] == null ||
        !widget.api.channel.scriptFinished.value ||
        _progress.isAnimating) {
      return;
    }
    _play();
  }

  Future<void> _play() async {
    if (widget.scene.data['media'] == null) return;
    await _audio.stop();
    if (!mounted) return;
    _progress
      ..stop()
      ..value = 0;
    final media = widget.scene.data['media'] as String?;
    if (media != null) unawaited(_audio.play(media));
    _progress.forward();
  }

  @override
  void dispose() {
    widget.api.channel.scriptFinished.removeListener(_maybeStart);
    _progress.dispose();
    unawaited(_audio.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.scene.data['label'] as String? ??
                      widget.scene.title ??
                      'أنشودة الحرف',
                  style: AppTypography.title,
                ),
                if (widget.scene.data['media'] == null)
                  const Text('ستضاف الأنشودة لاحقًا'),
                SizedBox(height: compact ? 16 : AppSpacing.xl),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => _AudioWaveform(
                      progress: _progress.value,
                      active: _progress.isAnimating,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LessonActionButton(
              label: 'إعادة الاستماع',
              icon: Icons.replay_rounded,
              onPressed: widget.scene.data['media'] == null ? null : _play,
            ),
            const SizedBox(width: 4),
            LessonActionButton(
              label: 'التالي',
              icon: Icons.west_rounded,
              // التخطي متاح منذ اللحظة الأولى ولا ينتظر نهاية الأنشودة.
              onPressed: widget.api.completeScene,
            ),
          ],
        ),
      ],
    );
  }
}

class _AudioWaveform extends StatelessWidget {
  const _AudioWaveform({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 760;
    const heights = <double>[
      .35,
      .62,
      .9,
      .55,
      .78,
      .42,
      .96,
      .68,
      .48,
      .82,
      .58,
      .92,
      .46,
      .72,
      .38,
      .86,
      .64,
      .98,
      .52,
      .76,
      .4,
      .88,
      .6,
      .7
    ];
    return SizedBox(
      height: compact ? 72 : 100,
      child: Row(
        // يبدأ التقدم من يمين الشاشة بما يوافق اتجاه العربية.
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < heights.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: (compact ? 68 : 94) *
                      heights[i] *
                      (active && i / heights.length <= progress ? 1 : .72),
                  decoration: BoxDecoration(
                    color: i / heights.length <= progress
                        ? AppColors.primary
                        : AppColors.letterGuide,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
