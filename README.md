# مدرستي — الهيكل الأولي (المرحلتان 2 و3)

## الإعداد (مرة واحدة)
```bash
# داخل مشروع Flutter الذي أنشأته (flutter create --platforms web madrasty)
# انسخ محتويات هذا المجلد فوقه، ثم:
flutter pub add go_router intl flutter_localizations --sdk=flutter   # الأخيرة قد تحتاج: flutter pub add flutter_localizations --sdk=flutter
flutter pub add firebase_core firebase_auth cloud_firestore cloud_functions firebase_storage firebase_app_check web

flutterfire configure --project=<project-id> --platforms=web --out=lib/firebase_options.dart
# عدّل .firebaserc بمعرّف مشروعك

cd functions && npm install && cd ..
```
خط Cairo: نزّله وضعه في `assets/fonts/` ثم عرّفه في `pubspec.yaml` تحت `flutter: fonts:` باسم `Cairo`.

## التشغيل محليًا (Emulator)
```bash
firebase emulators:start
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

## اختبار قواعد الأمان
```bash
cd rules_tests && npm install --save-dev @firebase/rules-unit-testing firebase && cd ..
firebase emulators:exec --only firestore --project demo-madrasty "cd rules_tests && npm test"
```

## أول مدير
سجّل حسابًا من الواجهة، ثم:
```bash
cd functions
GOOGLE_CLOUD_PROJECT=<project-id> node scripts/make_admin.js you@example.com
```
(يحتاج `gcloud auth application-default login`). ثم سجّل خروج/دخول.

## النشر
```bash
flutter build web --release
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage,functions
```

## ملاحظات
- الدور في الواجهة للعرض فقط؛ الحماية الفعلية في `firestore.rules` و Functions.
- منطقة Functions: `europe-west1` (تغييرها يتطلب تعديل `index.js` و `app_config.dart` معًا).
- App Check غير مفعّل بعد (انظر TODO في `bootstrap.dart`).
- نص إقرار موافقة ولي الأمر في `register_page.dart` مؤقت ويحتاج مراجعة قانونية.

## المرحلة 4: الدورات والدروس
- المدير: `/admin/courses` لإنشاء الدورات والوحدات والدروس (رابط YouTube أو المعرّف).
- العامة: `/courses` (الدورات المنشورة) و `/courses/:id`؛ الدرس يتطلب دخولًا واشتراكًا نشطًا أو أن يكون «معاينة».
- لاختبار الوصول قبل بناء الدفع: أنشئ مستند `enrollments/{studentUid}_{courseId}` يدويًا من Emulator UI بالحقول
  `studentId, courseId, status:"active", endAt:<timestamp مستقبلي>`.
- بعد التحديث أعد نشر القواعد: `firebase deploy --only firestore:rules`.

## المرحلة 5: الدفع اليدوي والوصول
```bash
flutter pub add file_picker            # اختيار ملف الإثبات
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```
- المدير: `/admin/settings` (تعليمات الدفع)، `/admin/payments` (مراجعة الإثباتات)، `/admin/students` (تعطيل/تفعيل الحساب ومنح/سحب الوصول بسبب إلزامي).
- التدفق: الطالب «طلب الاشتراك» → يدفع خارج المنصة → يرفع الإثبات → المدير يتحقق من وصول المبلغ فعليًا ثم يعتمد أو يرفض بسبب.
- الاعتماد دالة واحدة (`reviewPaymentRequest`) تحدّث الطلب وتنشئ/تمدّد التسجيل وتكتب الإشعار وسجل التدقيق في معاملة واحدة، وتكرارها لا ينشئ تسجيلًا ثانيًا.
- الدورة المجانية تُسجَّل فورًا. الطلبات غير المدفوعة تنتهي تلقائيًا بعد 7 أيام (`EXPIRY_DAYS` في `functions/payments.js`) عبر دالة مجدولة (تحتاج Blaze وCloud Scheduler).
- فتح الإثبات يتم في تبويب جديد برابط تنزيل مؤقت (لا يحتاج إعداد CORS).
- فهرس جديد في `firestore.indexes.json` لدالة الانتهاء، فانشره مع القواعد.

## المرحلة 5 (تكملة): الحصص المباشرة والحضور
```bash
flutter pub add timezone   # ثم: flutter pub get
firebase deploy --only firestore:rules
```
- المدير: `/admin/sessions` لإضافة الحصص (الدورة، التاريخ والوقت **بتوقيت القاهرة**، المدة، رابط Meet) وتعديلها وإلغائها. ومن الحصة تُسجَّل الحضور (حاضر/متأخر/غائب) يدويًا.
- الطالب: `/sessions` (القادمة والسابقة لدوراته النشطة مع زر الانضمام) و `/attendance` (سجل حضوره).
- الأوقات تُخزَّن UTC وتُعرض بتوقيت القاهرة عبر حزمة `timezone` (تراعي التوقيت الصيفي).
- رابط Meet يُنشأ يدويًا في Google Meet ويُلصق هنا (حسب نطاق الإصدار الأول).

## المرحلة 6: الامتحانات (تصحيح آلي)
```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```
- المدير: `/admin/exams` لإنشاء الامتحان (الدورة، وقت الفتح والإغلاق بتوقيت القاهرة، المدة، المحاولات، إظهار النتيجة، ترتيب عشوائي)، ثم إضافة الأسئلة (اختيار من متعدد / صح-خطأ) مع الإجابة الصحيحة والشرح، ثم **النشر**. ومن صفحة الامتحان زر «النتائج».
- الطالب: `/exams` ← فتح الامتحان ← بدء المحاولة. العدّ التنازلي من وقت الخادم، حفظ تلقائي كل 60 ثانية عند وجود تغيير، تسليم تلقائي عند انتهاء الوقت.
- **الأمان:** الإجابات الصحيحة في `examKeys` (لا يقرؤها أي عميل). الأسئلة لا يقرؤها الطالب مباشرة؛ يستلمها من `startExamAttempt` بدون إجاباتها. التصحيح في `submitExamAttempt`. النتائج لا يقرؤها الطالب من Firestore؛ يجلبها عبر `getMyExamResults` حسب وضع الإظهار. المراجعة والإجابات الصحيحة بعد إغلاق الامتحان فقط (`getAttemptReview`).
- **قرارات تصميم:** (1) لا يمكن تعديل/حذف أسئلة امتحان بدأ الطلاب حله. (2) وقت المحاولة = min(المدة، وقت الإغلاق). (3) مهلة 30 ثانية لتأخر الشبكة عند التسليم؛ بعدها تُصحَّح الإجابات المحفوظة آليًا فقط. (4) دالة مجدولة كل 15 دقيقة تُسلّم تلقائيًا المحاولات المنتهية التي لم يعد لها الطالب.
- **اختبار الحمل (100 طالب متزامنين):** قبل الإطلاق أنشئ 100 حساب تجريبي وجرّب في بيئة dev (وليس Emulator): بدء المحاولة، الحفظ الدوري، والتسليم في نفس الدقيقة، وراقب Functions logs واستهلاك Firestore. الدالة `startExamAttempt` و`submitExamAttempt` هما نقطتا الضغط.
- الأسئلة هنا لكل امتحان على حدة (بدون «بنك أسئلة» مشترك بعد).

## المرحلة 7: الإعلانات والإشعارات والصفحات القانونية
```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```
- المدير: `/admin/announcements` لنشر إعلان لكل الطلاب أو لمشتركي دورة، مع تاريخ انتهاء اختياري. النشر دالة واحدة تنشئ الإعلان وإشعارًا لكل مستلم، والحذف يحذف الإعلان وإشعاراته.
- الطالب: أيقونة الجرس في لوحته (عدّاد غير المقروء) ← `/notifications`، و`/announcements` لقراءة الإعلانات. الإشعارات تصله أيضًا عند اعتماد/رفض الدفع ومنح الوصول.
- الصفحات القانونية: `/privacy` و`/terms` و`/refund`، مرتبطة بصفحة الرئيسية وبشاشة التسجيل. **كلها مسودات**: عبّئ القيم في `lib/core/legal_config.dart`، واعرضها على مستشار قانوني، ثم اجعل `isDraft = false`.
- فهرس جديد للإشعارات في `firestore.indexes.json` (انشره).

## إعادة التصميم (Modern Egyptian EdTech)
تم تطبيق التصميم المرفق (ألوان دافئة ورقية، أزرق نيلي، تيل، عنبر؛ خطوط Cairo للعناوين وTajawal للنص).

**الخطوط** (لا تُحمَّل من الإنترنت؛ ضعها في `assets/fonts/` من Google Fonts ثم أضف في `pubspec.yaml`):
```yaml
flutter:
  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
        - asset: assets/fonts/Cairo-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Cairo-Bold.ttf
          weight: 700
        - asset: assets/fonts/Cairo-ExtraBold.ttf
          weight: 800
    - family: Tajawal
      fonts:
        - asset: assets/fonts/Tajawal-Regular.ttf
        - asset: assets/fonts/Tajawal-Medium.ttf
          weight: 500
        - asset: assets/fonts/Tajawal-Bold.ttf
          weight: 700
```
**البنية:** `core/theme.dart` (الألوان والمكوّنات) · `shared/design.dart` (AppCard، شارات الحالات، بطاقات المؤشرات، شريط التقدم، ساعة القاهرة) · `shell/student_shell.dart` (شريط علوي) · `shell/admin_shell.dart` (قائمة جانبية يمينًا) · الصفحات المُعاد تصميمها: الرئيسية العامة، لوحة الطالب، مشغّل الدرس، لوحة المدير، طلبات الاشتراك. باقي الصفحات ورثت الثيم والإطار.
**هوية المنصة:** عدّل `core/brand_config.dart` (اسم المدرس) و`core/legal_config.dart`.
**جديد وظيفيًا لدعم التصميم:** تتبّع إكمال الدروس (`progress/{uid_courseId}`) لشريط التقدّم وزر «تم إكمال الدرس». انشر القواعد: `firebase deploy --only firestore:rules`.
**قرارات:** لم أضف محتوى غير مدعوم ببياناتك (شهادات طلاب، أرقام إحصائية، رصيد محفظة، باقات). تبويبات «المرفقات والواجب» في مشغّل الدرس غير مبنية لأنه لا يوجد لها مصدر بيانات بعد.

## مشروع Firebase واحد (بدون dev/prod)
- ملف واحد للإعدادات `lib/firebase_options.dart` ونقطة دخول واحدة `lib/main.dart`؛ لا يوجد `main_prod.dart`.
- لأن كل شيء على المشروع الحقيقي: **جرّب بالـ Emulator** (`firebase emulators:start` ثم `--dart-define=USE_EMULATOR=true`، ويعمل في وضع التطوير فقط) ولا تختبر بحسابات وهمية على البيانات الحقيقية.
- اختبار الحمل (100 حساب تجريبي) على المشروع الحقيقي يترك حسابات وبيانات اختبار: أنشئها بوسم واضح واحذفها بعده، أو نفّذه قبل استقبال طلاب فعليين.
- أول مدير: `GOOGLE_CLOUD_PROJECT=<project-id> node scripts/make_admin.js you@example.com`.
#   m a d r a s t y  
 