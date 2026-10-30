import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/legal_config.dart';
import '../../shared/ui.dart';

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading, body;
}

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.sections});
  final String title;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Centered(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (LegalConfig.isDraft)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('مسودة: هذا النص يحتاج استكمال البيانات بين الأقواس [ ] ومراجعة قانونية قبل الإطلاق.'),
              ),
            ),
          Text('آخر تحديث: ${LegalConfig.lastUpdated}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          for (var i = 0; i < sections.length; i++) ...[
            Text('${i + 1}. ${sections[i].heading}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(sections[i].body, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 16),
          ],
        ]),
      ),
    );
  }
}

class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(alignment: WrapAlignment.center, children: [
          TextButton(onPressed: () => context.push('/privacy'), child: const Text('سياسة الخصوصية')),
          TextButton(onPressed: () => context.push('/terms'), child: const Text('شروط الاستخدام')),
          TextButton(onPressed: () => context.push('/refund'), child: const Text('الاسترداد والإلغاء')),
        ]),
      );
}

const _p = LegalConfig.platformName;
const _owner = LegalConfig.ownerName;
const _mail = LegalConfig.contactEmail;
const _tel = LegalConfig.contactPhone;

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => const LegalPage(title: 'سياسة الخصوصية', sections: [
        LegalSection('من نحن',
            'تُدار منصة $_p بواسطة $_owner. للتواصل بشأن بياناتك: $_mail — $_tel.'),
        LegalSection('البيانات التي نجمعها',
            'بيانات الحساب: الاسم والبريد الإلكتروني ورقم الهاتف (اختياري). كلمة المرور تُحفظ لدى خدمة المصادقة بصورة مشفّرة ولا نطّلع عليها.\n'
            'بيانات التعلم: الدورات المشترك بها، الحضور، إجابات الامتحانات ودرجاتها.\n'
            'بيانات الدفع اليدوي: مبلغ الطلب ورقم العملية والملف الذي ترفعه كإثبات للدفع.\n'
            'بيانات تقنية محدودة: سجلات الأخطاء والاستخدام لأغراض الحماية والتحسين.\n'
            'لا نجمع الرقم القومي ولا صور الهوية ولا بيانات البطاقات المصرفية.'),
        LegalSection('لماذا نستخدم بياناتك',
            'لتقديم الخدمة التعليمية، والتحقق من الاشتراك والدفع، ومتابعة الحضور والدرجات، وإرسال الإعلانات والإشعارات، وحماية المنصة من إساءة الاستخدام.'),
        LegalSection('الطلاب القُصّر',
            'قد يكون بعض الطلاب دون 18 سنة. نطلب إقرارًا بموافقة ولي الأمر عند التسجيل، ويحق لولي الأمر طلب الاطلاع على بيانات ابنه أو تصحيحها أو حذفها.'),
        LegalSection('مشاركة البيانات',
            'لا نبيع بياناتك. نستعين بخدمات Google (Firebase للمصادقة وقواعد البيانات والتخزين والاستضافة، وYouTube لعرض الفيديو، وGoogle Meet للحصص) كمزوّدي خدمة، ولكل منها سياسة خصوصية خاصة بها. لا نشارك بياناتك مع جهات أخرى إلا إذا أوجب القانون ذلك.'),
        LegalSection('مدة الاحتفاظ',
            'نحتفظ ببيانات الحساب والدرجات والمدفوعات طوال فترة استخدامك للمنصة، ثم ${LegalConfig.retentionNote}. قد نحتفظ ببعض السجلات (مثل المدفوعات) للمدة التي يوجبها القانون.'),
        LegalSection('حقوقك',
            'يحق لك الاطلاع على بياناتك وتصحيحها وطلب حذفها أو تقييد معالجتها أو الاعتراض عليها، وذلك بمراسلتنا على $_mail. نراعي في ذلك أحكام قانون حماية البيانات الشخصية المصري رقم 151 لسنة 2020.'),
        LegalSection('الأمان',
            'نطبّق قواعد وصول تمنع اطلاع أي مستخدم على بيانات غيره، ونقيّد صلاحيات الإدارة. ومع ذلك لا يوجد نظام آمن بصورة مطلقة، ونوصي بكلمة مرور قوية وعدم مشاركة الحساب.'),
        LegalSection('التخزين المحلي',
            'نستخدم تخزينًا محليًا ضروريًا في المتصفح لإبقائك مسجّل الدخول فقط، ولا نستخدمه لأغراض إعلانية.'),
      ]);
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) => const LegalPage(title: 'شروط الاستخدام', sections: [
        LegalSection('القبول والتسجيل',
            'باستخدامك منصة $_p فإنك توافق على هذه الشروط. يجب أن تكون بيانات التسجيل صحيحة، والحساب شخصي ولا يجوز مشاركته مع الغير.'),
        LegalSection('الاشتراك ومدة الإتاحة',
            'الاشتراك لكل دورة على حدة ولمدة إتاحة محددة في صفحة الدورة. لا يُمنح الوصول إلى محتوى الدورة إلا بعد اعتماد الاشتراك، وينتهي بانتهاء المدة.'),
        LegalSection('الدفع',
            'يتم الدفع خارج المنصة بالوسائل المعلنة. رفع إيصال الدفع وحده لا يعني تفعيل الاشتراك؛ إذ يُعتمد الطلب بعد التحقق من وصول المبلغ فعليًا. تُراجع الطلبات في أقرب وقت ممكن.'),
        LegalSection('المحتوى وحقوق الملكية',
            'المحتوى التعليمي مملوك للمنصة أو لصاحبه. يُحظر نسخه أو تسجيله أو إعادة نشره أو مشاركة روابط الفيديوهات خارج المنصة. الاستخدام للأغراض التعليمية الشخصية فقط.'),
        LegalSection('الحصص المباشرة',
            'روابط الحصص للمشتركين فقط ولا يجوز مشاركتها. يُرجى الالتزام بالآداب العامة، ويُحظر تسجيل الحصص أو نشرها دون إذن.'),
        LegalSection('الامتحانات',
            'يلتزم الطالب بأداء الامتحان بنفسه دون مساعدة. يُحسب وقت الامتحان من الخادم، ويُسلَّم تلقائيًا عند انتهائه. انقطاع الاتصال من جهة الطالب لا يوقف الوقت، وتُحفظ الإجابات الأخيرة المحفوظة. قد تُلغى نتيجة أي محاولة يثبت فيها الغش.'),
        LegalSection('إيقاف الحساب',
            'يجوز تعطيل الحساب أو سحب الوصول عند مخالفة هذه الشروط أو إساءة استخدام المنصة.'),
        LegalSection('حدود المسؤولية',
            'تُقدَّم الخدمة بحالتها، ولا نضمن خلوها من الانقطاع ولا نضمن نتيجة دراسية معينة، وذلك بالقدر الذي يسمح به القانون.'),
        LegalSection('التعديل والقانون الواجب التطبيق',
            'قد نعدّل هذه الشروط وننشر النسخة المحدّثة هنا. تخضع هذه الشروط للقانون المصري، والاختصاص للمحاكم المصرية المختصة [تحديد المحكمة].'),
      ]);
}

class RefundPage extends StatelessWidget {
  const RefundPage({super.key});
  @override
  Widget build(BuildContext context) => const LegalPage(title: 'سياسة الاسترداد والإلغاء', sections: [
        LegalSection('قبل الدفع',
            'يمكنك تجاهل طلب الاشتراك دون أي التزام. تنتهي الطلبات غير المدفوعة تلقائيًا بعد 7 أيام، ويمكنك إنشاء طلب جديد.'),
        LegalSection('بعد اعتماد الاشتراك',
            'يمكن طلب الاسترداد خلال ${LegalConfig.refundWindowDays} أيام من اعتماد الاشتراك، بشرط ألا تكون قد حضرت حصة مباشرة أو دخلت امتحانًا ضمن الدورة [تأكيد الشروط من صاحب المشروع].'),
        LegalSection('كيفية الطلب',
            'راسلنا على $_mail أو $_tel مع ذكر رقم طلب الاشتراك الظاهر في صفحة «طلباتي ومدفوعاتي».'),
        LegalSection('طريقة الرد',
            'عند الموافقة يُردّ المبلغ بنفس وسيلة الدفع خلال [عدد] أيام عمل، ويُسحب الوصول إلى الدورة.'),
        LegalSection('حالات لا يشملها الاسترداد',
            'مخالفة شروط الاستخدام، أو مشاركة الحساب أو المحتوى، أو انتهاء المدة المحددة أعلاه.'),
      ]);
}
