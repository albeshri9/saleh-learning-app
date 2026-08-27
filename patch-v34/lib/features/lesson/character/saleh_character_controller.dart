import 'package:flutter/foundation.dart';

import '../widgets/saleh_character.dart' show SalehPose;

/// طبقة التحكم الدلالية بشخصية صالح.
///
/// هذه هي الواجهة الوحيدة التي يخاطب بها Lesson Engine الشخصية:
/// حالات دلالية ([SalehPose]) لا ملفات صور ولا تفاصيل عرض. طريقة العرض
/// الحالية (صور PNG عبر SalehView مع fallback مرسوم) وطريقة الغد
/// عارض الفيديو يستهلك [pose] نفسها عند إضافة المقاطع التالية.
/// لاحقًا لا يلمس المحرك ولا هذا الصف.
///
/// قاعدة talking (المرحلة الأولى من Character Animation):
/// «talking» ليست حالة يطلبها المحرك، بل تُشتق من تشغيل الصوت الفعلي:
/// يبدأ صوت صالح ← talking، ينتهي ← عودة إلى حالة المشهد.
/// التشجيع والاحتفال فقط لهما الأولوية على الكلام؛ بقية الحالات
/// تتحول إلى الكلام أثناء التعليق ثم تعود بعد انتهائه.
class SalehCharacterController extends ChangeNotifier {
  SalehCharacterController({required ValueListenable<bool> audioPlaying})
      : _audioPlaying = audioPlaying {
    _audioPlaying.addListener(_onAudioChanged);
  }

  final ValueListenable<bool> _audioPlaying;
  SalehPose _basePose = SalehPose.idle;
  bool _narrating = false;

  /// الحالة الفعالة التي يعرضها عارض الشخصية.
  SalehPose get pose {
    if (_basePose == SalehPose.encouraging ||
        _basePose == SalehPose.celebrating) {
      return _basePose;
    }
    return (_audioPlaying.value || _narrating) ? SalehPose.talking : _basePose;
  }

  /// يحرّك صالح أثناء الفقرات النصية حتى قبل إضافة التسجيل الصوتي النهائي.
  void setNarrating(bool value) {
    if (_narrating == value) return;
    _narrating = value;
    notifyListeners();
  }

  /// طلب دلالي من المحرك (أحداث الخط الزمني: أشِر، لوّح، احتفل...).
  ///
  /// [SalehPose.talking] لا تُقبل كطلب — الكلام يقوده الصوت وحده،
  /// فطلبها يعادل العودة إلى idle (فيظهر talking تلقائيًا إن كان
  /// الصوت يعمل).
  void setPose(SalehPose pose) {
    final requested = pose == SalehPose.talking ? SalehPose.idle : pose;
    if (_basePose == requested) return;
    _basePose = requested;
    notifyListeners();
  }

  /// إعادة الضبط عند بداية كل مشهد.
  void reset() => setPose(SalehPose.idle);

  /// انتهاء دورة الفيديو لا يغيّر الحالة الدلالية. تبقى حركة المشهد
  /// متكررة حتى ينتقل الدرس أو يطلب المحرك حالة أخرى صراحةً.
  void notifyPoseCompleted(SalehPose pose) {
    // متعمد: دورة الفيديو ليست نهاية حالة المشهد.
  }

  void _onAudioChanged() {
    // يعيد العرض حساب حركة الكلام عند تغير الصوت في أي حالة.
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlaying.removeListener(_onAudioChanged);
    super.dispose();
  }
}
