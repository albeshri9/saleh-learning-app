# تعلم مع صالح — النسخة 38

## نطاق التحديث المعتمد

- تغيير مواقع إجابات التقويم بعد المحاولة مع الحفاظ على ارتباط الإجابة بصورتها.
- ثلاث ألعاب: أسمع وأختار، بطاقات الذاكرة، سلة الألف؛ ومسار حروف متصل يبدأ من اليمين.
- الحرف يفتح آخر مشهد غير مكتمل مباشرة؛ الدرس المكتمل يبدأ من أوله، بلا قائمة اختيار نشاط.
- أربع محطات مصورة: أسمع، أنطق، أكتب، ألعب. رأس الدرس يعرض اسم الطفل وصورته المسجلة.
- توسيع الكتابة الحرة وإظهار نموذج خافت تحت الحبر دون تقييد حركة اليد، وإضاءة الحرف عند اكتمال التتبع.
- دفتر محلي لكل طفل يحفظ محاولات الكتابة المرسلة، مع التاريخ ورسم اليد. المسودات غير المرسلة لا تُحفظ.
- نقاط محلية غير قابلة للشراء: 10 للنشاط، 15 لكل لعبة، 20 لإكمال الدرس، مرة واحدة لكل إنجاز. تُحتسب الأنشطة القديمة المسجلة دون إعادتها.
- ملف شخصي قابل للتعديل، صور مهن متساوية بأسماء ظاهرة دون تمرير عند إغلاق لوحة المفاتيح؛ إزالة نقطة البداية.
- خلفية بداية أهدأ، أيقونات مجسمة موحدة، صفحات إنجازات ودفتر أعمال.
- دليل حزم المحتوى في CONTENT_AUTHORING.md، وفحص آلي للأصول والأسئلة والمسارات قبل البناء.
- بقيت خلفية الفصل السابقة ومسارات الهمزة المعتمدة والبيانات المحلية واسم التطبيق كما هي. الأنشودة مؤجلة؛ بقية المقترحات غير المعتمدة لم تُنفذ.

## الصوت والحركة

تسجيل المستخدم محفوظ دون تعديل في assets/audio/assessment_applause_user.mp3.
SHA-256: 504606ee9abd7d965fa3270595e6fedfb521923da48aacb72514e612bbf2618e.
مشغّل المؤثر مستقل عن التعليق؛ مستوى التصفيق 0.65 والتعليق 1.0. القياس بالملف الأصلي: متوسط التصفيق -32.9 dB مقابل -13.4 dB للتعليق الختامي؛ بعد الضبط يبقى التصفيق أخفض بنحو 23 dB في المتوسط. لا يتكرر مع كل إجابة، بل يبدأ في مشهد ختام التقويم ويتوقف بالخروج.
حدث الوداع عند 8.65 ثانية من ملف closing.mp3، مرتبط بموضع التشغيل الفعلي بدل وقت فتح الشاشة. يحتاج المزيج وتزامن الفم/الوداع إلى تأكيد بالسماع والمشاهدة على الجهاز؛ الاختبار البرمجي يثبت توقيت إرسال الحدث.

## الأصول المولّدة

استخدمت أداة image_gen المدمجة، لا CLI. أنشئت الملفات بأسماء جديدة دون مسح الخلفيات السابقة، ونُسخت الأصول المختارة إلى المشروع. حفظت ملفات المصدر المولدة تحت C:/Users/FIN/.codex/generated_images/01a03e95-d45d-7d92-bb5e-8a9cb3fbebb8/.

الخلفية النهائية: assets/backgrounds/courtyard_v38.png
المصدر: exec-086739b1-b421-45d3-b403-e50894422936.png
الطلب النهائي:

Use case: stylized-concept. Asset type: landscape mobile children's learning app background, 16:9. Create a calm, softly shaded Arabic courtyard learning garden in a premium rounded 3D animated-film style. Muted lavender, sage, cream stone and teal palette; diffuse overcast light, no visible sun, no yellow glare, no dramatic shadows. Minimal arched architecture and a few rounded plants only around edges, very spacious uncluttered center-left for UI panels, clear level stone floor at bottom right for the existing Saleh character to stand. Inviting, cheerful and comfortable, not dark or sleepy. No people, no letters, no labels, no interface, no logos. Environment only; composition compatible with landscape phone UI.

الأيقونات النهائية: assets/ui/icons_v38.png
المصدر النهائي: exec-80f77098-3d69-4a8b-a12f-76c900c051d2.png
الطلب الأول:

Use case: stylized-concept. Asset type: a single production sprite atlas for a children's Arabic learning application. EXACT 4 columns by 3 rows uniform square cells on one square canvas, no visible grid. Twelve separate rounded 3D toy-like icons with identical scale, camera and soft studio lighting, each fully centered with 15 percent padding in its cell. Background solid very pale lavender #F6F3FB; limited lavender, teal, cream and small gold accents. Order left-to-right top row: open story book, microphone, pencil tracing on paper, two interlocking puzzle pieces. Middle row: gold trophy, closed portfolio scrapbook, stack of gold star coins, small rounded house. Bottom row: headphones, two matching picture cards, potted sprout flower, protective padlock. No people, no letters, no words, no numbers, no emojis, no cropped parts, no cast shadows beyond cell. Polished volumetric sculpted objects suitable beside a high quality 3D child mascot.

طلب تعديل ترتيب اللوحة فقط، مع استخدام الصورة الأولى هدفًا:

Edit this UI icon atlas only in layout, keep exactly the same twelve icon designs, order, material and colors. Repack into a landscape 4:3 canvas with EXACT FOUR columns and THREE rows of identical SQUARE cells. Each cell contains one icon scaled to at most 70% of cell width and 70% of cell height, centered precisely in its own square cell. Even generous padding all around each icon, no crossing cell boundaries. No visible gridlines. Solid pale lavender background. Output a 4:3 atlas, not a square canvas. Preserve all twelve icons: book, mic, writing, puzzle; trophy, album, coins, home; headphones, cards, flower, lock.

تُعرض الأيقونات بقصاصات برمجية متساوية دون تعديل ملف الصورة خارجيًا. راجعت الصور داخل الواجهات للتأكد من اكتمال الأيقونات وعدم قصها.

## معيار الجوال والتحقق

الأزرار الأساسية بارتفاع 48 نقطة على الأقل، والخيارات اللمسية المستهدفة لا تقل عن 44 نقطة على المقاسات المختبرة؛ عناوين 18–24 ونصوص رئيسية 16–18، وتسميات قصيرة 14. اختبر الملف على 568×320 و667×375 و844×390 و390×844. التمرير في تحرير الملف مسموح فقط عند ظهور لوحة المفاتيح كي لا تحجب الحقول. معاينة الشاشات الأخرى عند 844×390. لا يعد هذا ادعاءً بتغطية كل جهاز أو كل إعداد لتكبير الخط.

الرسومات مخزنة محليًا، وليست مزامنة سحابية أو نسخة احتياطية. حذف التطبيق قد يزيل البيانات. يُحافظ على معرف الحزمة عند التحديث.
