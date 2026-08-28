import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'saleh_character.dart';

/// نقطة الاستبدال الوحيدة لشخصية صالح.
///
/// يبحث هذا الـ Widget عن أصل بصري احترافي في `assets/character/` ويعرضه
/// إن وُجد مع حركة حياة خفيفة (تنفس/طفو/ميلان عبر Transform فقط — بلا
/// إعادة رسم). وإن لم يوجد الأصل بعد، يعرض النسخة البرمجية المرحلية
/// [SalehSketchCharacter] كما هي.
///
/// الأصول المتوقعة (PNG بخلفية شفافة، بارتفاع أكبر من العرض):
///   - assets/character/saleh_idle.png         (وقفة هادئة)
///   - assets/character/saleh_talking.png      (يتحدث)
///   - assets/character/saleh_pointing.png     (يشير بعصا التعليم الخشبية)
///   - assets/character/saleh_celebrating.png  (يحتفل)
///   - assets/character/saleh_waving.png       (يلوّح)
///
/// هذه النسخة القديمة للصور الساكنة باقية كبديل احتياطي فقط؛ واجهة الدرس
/// الحالية تستخدم عارض الفيديو الشفاف.
class SalehView extends StatefulWidget {
  const SalehView({super.key, this.pose = SalehPose.idle, this.size = 260});

  final SalehPose pose;
  final double size;

  @override
  State<SalehView> createState() => _SalehViewState();
}

class _SalehViewState extends State<SalehView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _resolveAsset();
  }

  @override
  void didUpdateWidget(SalehView old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) _resolveAsset();
  }

  String get _assetKey => 'assets/character/saleh_${widget.pose.name}.png';

  void _resolveAsset() {
    if (_CharacterAssets.peek(_assetKey) != null) return;
    _CharacterAssets.probe(_assetKey).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ما لم يتأكد وجود الأصل الاحترافي، تبقى النسخة البرمجية المرحلية.
    if (_CharacterAssets.peek(_assetKey) != true) {
      return SalehSketchCharacter(pose: widget.pose, size: widget.size);
    }

    // انتقال سلس بين حالتي idle وtalking (تبديل الصورة بتلاشٍ قصير
    // هادئ بدل القفز المفاجئ). المفتاح هو مسار الأصل نفسه.
    final image = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Image.asset(
        _assetKey,
        key: ValueKey(_assetKey),
        height: widget.size * 0.94,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        // شبكة أمان أخيرة: أي فشل في فك الصورة يعيد النسخة البرمجية
        errorBuilder: (context, error, stack) =>
            SalehSketchCharacter(pose: widget.pose, size: widget.size),
      ),
    );

    final talking = widget.pose == SalehPose.talking;

    return SizedBox(
      width: widget.size * 0.72,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        child: image,
        builder: (context, child) {
          final t = _c.value;
          final wave = math.sin(t * 2 * math.pi);
          // أثناء الكلام: إيماء رأس/جسم طفيف بإيقاع أسرع قليلًا من
          // التنفس — محسوب ليبقى هادئًا غير مشتت (أقل من درجة ونصف).
          final talkSway = talking ? math.sin(t * 2 * math.pi * 2.5) : 0.0;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // ظل تلامس أرضي ناعم يتنفس مع الشخصية
              Transform.scale(
                scaleX: 1 - wave * 0.03,
                child: Container(
                  width: widget.size * 0.52,
                  height: widget.size * 0.05,
                  margin: EdgeInsets.only(bottom: widget.size * 0.005),
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x2E6B4E3D), Color(0x006B4E3D)],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // تنفس/طفو/ميلان خفيف — Transform فقط، بلا إعادة رسم
              Transform.translate(
                offset: Offset(talkSway * 1.5, wave * 3 + talkSway * 1.2),
                child: Transform.rotate(
                  angle: wave * 0.012 + talkSway * 0.014,
                  child: Transform.scale(
                    scaleY: 1 + wave * 0.012,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// فحص وجود أصول الشخصية مرة واحدة لكل مسار (نتيجة مشتركة بين كل النسخ).
class _CharacterAssets {
  static final Map<String, bool> _resolved = {};
  static final Map<String, Future<bool>> _pending = {};

  static bool? peek(String key) => _resolved[key];

  static Future<bool> probe(String key) {
    return _pending.putIfAbsent(key, () async {
      try {
        final data = await rootBundle.load(key);
        // على الويب قد يعيد الخادم صفحة HTML بدل 404 للأصل المفقود،
        // فنتحقق من توقيع PNG الفعلي قبل اعتماد الأصل.
        _resolved[key] = data.lengthInBytes > 8 &&
            data.getUint32(0) == 0x89504E47 &&
            data.getUint32(4) == 0x0D0A1A0A;
      } catch (_) {
        _resolved[key] = false;
      }
      return _resolved[key]!;
    });
  }
}
