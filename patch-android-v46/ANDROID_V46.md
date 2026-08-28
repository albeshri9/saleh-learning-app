# Android APK — تعلم مع صالح v46

أضيف غلاف Android فقط؛ لم يتغير محتوى الدروس أو كود Flutter في النسخة 46.

- Universal release APK: ARM32، ARM64، x86_64.
- اسم التطبيق: تعلم مع صالح. معرف الحزمة: com.example.saleh_app.
- رقم البناء 46؛ الإصدار 0.1.0 من pubspec.yaml.
- الميكروفون والتعرف على الكلام مهيآن، والنبضات لها إذن VIBRATE. التطبيق يدعم RTL والاتجاه الأفقي.
- الأيقونة هي الأيقونة الأصلية للمشروع دون تغيير الرسم.
- هذه نسخة تجريبية موقعة بمفتاح Android debug، مع كود release غير قابل للتنقيح؛ ليست إصدار Google Play. مفتاح الاختبار محلي لبيئة البناء ولا يُنشر ضمن الملفات. أي إصدار لاحق بمفتاح مختلف قد يتطلب إزالة نسخة الاختبار أولًا، لذلك يلزم اعتماد مفتاح إصدار خاص ثابت قبل التوزيع الدائم.
- يحتاج النطق إلى خدمة تعرف عربية متاحة على جهاز Android وإذن الميكروفون؛ بعض الأجهزة تستخدم اتصال الإنترنت لهذه الخدمة. لم يُدّعَ اختبار النطق على هاتف Android فعلي.

البناء: flutter build apk --release --build-name=0.1.0 --build-number=46.
التحقق: apksigner verify --verbose --print-certs، وaapt dump badging، وفحص CRC والبصمة وأصول v46.

المراجع: https://docs.flutter.dev/deployment/android وhttps://github.com/csdcorp/speech_to_text/tree/main/speech_to_text#android.
