# 1.3.1+5 (builds #66-74)
- إصلاح: **استعادة حقل مفتاح Gemini في شاشة الإعدادات** (كان اتشال في 1.2.0+3
  بالمخالفة لتعليمات البريف الصريحة بالحفاظ عليه). المحرك المحلي يفضل هو
  المسار الأساسي والافتراضي دايمًا — وجود المفتاح أو غيابه ما بيأثرش على أي
  عملية محلية (§8/§9). الحقل بيحفظ مفتاح المستخدم نفسه محليًا فقط (مش في
  الكود ولا في المستودع)، مع زرار حفظ ومسح وإخفاء/إظهار النص. (build #66،
  مرجع أمان: git tag `baseline-build-66`، ثبّته المستخدم يدويًا وأكّد إنه شغال.)
- CI: `flutter analyze` و`flutter test --exclude-tags live` بقوا فعليًا بيتشغّلوا قبل بناء الـ
  APK لأول مرة في تاريخ المستودع (كانت بس `flutter build apk --release`). كشف ده عن باگ حقيقي
  كان مخفي من زمان: ملف `test/widget_test.dart` افتراضي كانت بتعيد توليده خطوة `flutter create`
  كل مرة (لأن `android/` مش متحفوظ)، وبيفشل لأنه بيشاور على كلاس `MyApp` مش موجود. اتصلح بحذف
  الملف ده أول ما يتولد. التحليل الساكن بيشتغل بـ `--no-fatal-infos` عشان الـ 55 ملاحظة أسلوب
  (style) القديمة من قبل التفعيل متوقفش البيلد، مع إبقاء الأخطاء والتحذيرات الحقيقية فاشلة للبيلد.
  (build #74، مرجع أمان: git tag `baseline-build-74-ci-verified`.)
- اختبارات: 3 اختبارات تخزين جديدة (حفظ/قراءة/مسح مفتاح Gemini) + اختبار widget يتأكد إن حقل
  المفتاح وزرار الحفظ وزرار المسح موجودين فعليًا ومفعّلين في شاشة الإعدادات — حارس انحدار ضد
  حذف الحقل تاني بالغلط (إجمالي 46 اختبارًا محليًا، متحقَّق منهم فعليًا على CI لأول مرة في build #74).
- توثيق: إضافة `HANDOFF.md` كنقطة بداية لأي جلسة قادمة، وحفظ نص المهمة الحالية في
  `.agent/mission_2026-10-16.md`، وقسم "خارطة الطريق المستقبلية" في `.agent/IMPLEMENTATION_STATE.md`
  يوثّق كل البنود المؤجلة من البريف الحالي.

# 1.3.0+4
- أُضيف (§6): تحصين التخزين — قراءة متسامحة مع السجلات التالفة (تُتخطّى وتُسجَّل، **بدون مسح أي بيانات**)، كتابة مؤكَّدة ترمي خطأً لو فشل الحفظ (فمافيش نجاح وهمي)، وتسلسل الكتابات المتزامنة حتى لا يضيع أي تعديل.
- أُضيف (§7): سجل محادثة دائم (`chat_history_service.dart`) — الرسائل تُحفظ بنوعها (مستخدم/مساعد/حالة) ووقتها، وتُستعاد عند فتح الشاشة، مع «مسح المحادثة» بطلب صريح.
- أُضيف (§7): رسالة المستخدم تُحفظ فورًا ولا تُفقد لو فشلت العملية، مع فقاعة حالة «جارٍ التنفيذ…»، ومنع الإرسال المزدوج (زر + صوت) نهائيًا، وعرض النص المسموع كرسالة المستخدم.
- أُضيف (§8): طبقة أخطاء موحّدة (`app_error_service.dart`) — تصنيف الخطأ وإرجاع رسالة عربية واضحة **بدون أي نص استثناء أو أسماء ملفات أو مسارات داخلية**، مع سجل تشخيص محلي مُنقّى من أي مفاتيح.
- إصلاح (§8): إزالة طباعة الاستثناء الخام من المحادثة، وإعادة صياغة رسالة فشل جدولة التذكير بلغة موجّهة للمستخدم، وتحويل أي فشل حفظ إلى رسالة صادقة بدل نجاح وهمي.
- إصلاح: بدء التطبيق لم يعد يتوقف لو فشلت خدمة الإشعارات.
- نظافة: `flutter analyze` أصبح **بدون أي ملاحظة** (إزالة الاستيرادات/العناصر غير المستخدمة وتحديث واجهات مهجورة).
- اختبارات: 11 اختبارًا جديدًا للتخزين وطبقة الأخطاء وسجل المحادثة (إجمالي 42 اختبارًا محليًا).

# 1.2.0+3
- أُضيف: **محرك أوامر محلي** كامل — التطبيق يفهم العامي المصري وينفّذ العمليات **بدون إنترنت وبدون أي مفتاح API**.
- أُضيف: محلل أوامر محلي (`lib/services/local_command_parser.dart`) يغطّي الحضور والسلف والخصومات والمكافآت والتوريدات والدفعات والموردين والموظفين والالتزامات والقواعد المتكررة، مع دعم الأرقام العربية والهندية وكلمات الأعداد (ألف / ألفين / خمسة آلاف).
- أُضيف: سياق محادثة دائم (`lib/services/conversation_context_service.dart`) — يفهم «سجلهم حضور» بعد استعلام الغياب، ويستكمل على **معرّفات السجلات** مش على نص المحادثة، ويحل التباس الأسماء بـ«التاني/الأول»، وله مهلة صلاحية.
- تغيير: **Gemini أصبح اختياريًا بالكامل** — غيابه أو فشل الاتصال لا يعطّل أي عملية محلية.
- تغيير: إزالة حقل مفتاح Gemini من واجهة العميل نهائيًا (لا يوجد أي مفتاح في الكود أو التطبيق المنشور).
- إصلاح: منع اختراع الراتب عند إضافة موظف، ومنع إنشاء سجلات موظفين مكررة، ومنع تنفيذ عملية مالية على سجل غير مقصود عند تشابه الأسماء.
- إضافة اختبارات: 18 اختبارًا للمحلل المحلي تعمل offline بدون مفتاح.

# 1.1.0+2
- أُضيف: موديول الموردين الكامل (Suppliers) — تسجيل مورد، توريدات متوقعة، تأكيد استلام، مديونية ودفعات.
- أُضيف: شاشة الذاكرة (Memory) — بحث شامل بالاسم عبر العملاء/الموردين/العاملين.
- أُضيف: شاشة القواعد والتنبيهات المتكررة (Follow-up Rules) — قواعد شهرية/أسبوعية/يومية تتحول تلقائياً لتذكيرات.
- إصلاح: موديل Gemini تم تثبيته على gemini-2.5-flash-lite ليتوافق مع صلاحيات المفتاح الحالي (كان مضبوط على gemini-2.5-flash وبيرجع خطأ صلاحيات).
- تحديث: الشات والمساعد الذكي يفهمون الآن نوايا الموردين والقواعد المتكررة بالإضافة للنوايا السابقة.
- تحديث: التنقل أصبح 5 شاشات أساسية (شات/اليوم/الذاكرة/العاملين/الموردين) + قائمة جانبية (القواعد/البريف/الإعدادات).
- تحديث: AndroidManifest يُضاف له تلقائياً أثناء الـ CI أذونات RECORD_AUDIO وPOST_NOTIFICATIONS وINTERNET.
- بريف الأسبوع أصبح يشمل ملخص مستحقات الموردين والتوريدات المنتظرة.

# 1.0.0+1
- MVP: commitments, staff, attendance, advances, local notifications, Arabic voice input.
- Gemini REST API with structured JSON output.
- Local API key storage; no key shipped in source.

## Session 4 — 2026-10-17 (branch `phase-b/from-32df13f`)
- `16e09ec`: pin `shared_preferences_android` to 2.4.28 (dependency_overrides); startup failures now show
  a readable error screen instead of a black screen; CI guard fails on plugin version drift.
  CI #78 green. Device behavior of APK 78 not yet confirmed by the owner.
- `3c8a886`/`6134afd` Phase B: quantity is not money; explicit day+hour for reminders and expected deliveries (asked, never defaulted);
  expected-delivery item/quantity/unit/total; attached-waw multi-names; short-reply slot filling; Gemini quantity/date fixes; duplicate-send guard.
- Phase C: supplier archive filter root-cause fix; archived suppliers excluded from new transactions; real notification settings
  (3 categories + lead time); Memory Reminders/Commitments cards open read-only lists.
- CI: toolchain fingerprint in release notes, release targets built commit, Flutter pinned to 3.47.7.
  Builds: #79 red (unused function), #80 red (case-grouping regression), #81 green (CI only).
- Docs: `implementation.md` created (inventory, Brief roadmap, platform audit).
- Docs: Build 75 (`32df13f`) designated as start; Build 76 (`25dbffe`) marked untrusted (tags
  `baseline-build-75-user-confirmed`, `build-76-untrusted`).

