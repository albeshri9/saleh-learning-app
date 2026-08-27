import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../lesson/widgets/saleh_character.dart' show SalehPose;
import 'saleh_video_renderer.dart';

/// صفحة تطوير معزولة لمراجعة المقاطع والشفافية والانتقالات.
class SalehVideoDevScreen extends StatefulWidget {
  const SalehVideoDevScreen({super.key});

  @override
  State<SalehVideoDevScreen> createState() => _SalehVideoDevScreenState();
}

class _SalehVideoDevScreenState extends State<SalehVideoDevScreen> {
  SalehVideoDiagnostics? _diagnostics;
  SalehPose _pose = SalehPose.idle;

  static const _labels = <SalehPose, String>{
    SalehPose.idle: 'Idle / الاستماع',
    SalehPose.talking: 'Talking',
    SalehPose.pointing: 'الإشارة',
    SalehPose.waving: 'الترحيب',
    SalehPose.encouraging: 'التشجيع',
    SalehPose.celebrating: 'الاحتفال',
  };

  void _updateDiagnostics(SalehVideoDiagnostics value) {
    final old = _diagnostics;
    if (old?.ready == value.ready &&
        old?.playing == value.playing &&
        old?.duration == value.duration &&
        old?.error == value.error) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _diagnostics = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة فيديوهات صالح')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _TransparencyTestBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight;
                  if (landscape) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: _buildVideo()),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            child: _buildControls(diagnostics),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      Expanded(child: _buildVideo()),
                      _buildControls(diagnostics),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideo() => Center(
        child: SalehVideoRenderer(
          key: const Key('saleh_video_renderer'),
          pose: _pose,
          onCompleted: (completedPose) {
            if (mounted && _pose == completedPose) {
              setState(() => _pose = SalehPose.idle);
            }
          },
          onDiagnostics: _updateDiagnostics,
        ),
      );

  Widget _buildControls(SalehVideoDiagnostics? diagnostics) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final pose in SalehPose.values)
                FilledButton.tonal(
                  onPressed:
                      _pose == pose ? null : () => setState(() => _pose = pose),
                  child: Text(_labels[pose]!),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                diagnostics == null
                    ? 'جارٍ تجهيز ${_labels[_pose]}…'
                    : diagnostics.error != null
                        ? 'تعذّر التشغيل: ${diagnostics.error}'
                        : '${_labels[_pose]} • ${diagnostics.playing ? 'يعمل' : 'متوقف'}'
                            ' • ${diagnostics.duration.inMilliseconds}ms',
                key: const Key('video_status'),
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
}

class _TransparencyTestBackground extends StatelessWidget {
  const _TransparencyTestBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CheckerPainter());
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tile = 48.0;
    final colors = [
      AppColors.brandYellow.withValues(alpha: .42),
      AppColors.brandGreen.withValues(alpha: .30),
      AppColors.primary.withValues(alpha: .18),
    ];
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        final index = ((x / tile).floor() + (y / tile).floor()) % colors.length;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tile, tile),
          Paint()..color = colors[index],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
