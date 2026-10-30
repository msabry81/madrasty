import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand_config.dart';
import '../../core/legal_config.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../shared/design.dart';
import '../courses/models.dart';
import '../legal/legal_pages.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = Services.session.user != null;
    final wide = isWide(context, 900);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        child: Column(children: [
          _Header(loggedIn: loggedIn, wide: wide),
          _Section(child: _Hero(loggedIn: loggedIn, wide: wide)),
          _Section(child: _Features(wide: wide)),
          _Section(child: _Courses()),
          _Section(child: _Steps(wide: wide)),
          _Section(child: _Faq()),
          _Section(child: _Cta(loggedIn: loggedIn)),
          const _Footer(),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28), child: child),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.loggedIn, required this.wide});
  final bool loggedIn, wide;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          const BrandMark(),
          const Spacer(),
          if (wide) TextButton(onPressed: () => context.go('/courses'), child: const Text('الدورات')),
          const SizedBox(width: 8),
          if (loggedIn)
            FilledButton(onPressed: () => context.go(Services.session.homePath), child: const Text('لوحتي'))
          else ...[
            OutlinedButton(onPressed: () => context.go('/login'), child: const Text('تسجيل الدخول')),
            const SizedBox(width: 8),
            if (wide) FilledButton(onPressed: () => context.go('/register'), child: const Text('إنشاء حساب')),
          ],
        ]),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.loggedIn, required this.wide});
  final bool loggedIn, wide;

  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(999)),
        child: const Text('منصة تعليمية عربية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
      const SizedBox(height: 12),
      Text('تعلّم بذكاء ومنهجية مع أ. ${BrandConfig.teacherName}',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: wide ? 40 : 30, height: 1.5)),
      const SizedBox(height: 12),
      const Text(
        'دروس مسجلة مرتبة في وحدات، وحصص مباشرة عبر Google Meet، وامتحانات إلكترونية بتصحيح فوري، '
        'ومتابعة لحضورك وتقدّمك في مكان واحد.',
        style: TextStyle(fontSize: 16, height: 1.8, color: AppColors.onVariant),
      ),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton.icon(onPressed: () => context.go('/courses'), icon: const Icon(Icons.menu_book_outlined), label: const Text('تصفّح الدورات')),
        if (!loggedIn)
          OutlinedButton(onPressed: () => context.go('/register'), child: const Text('إنشاء حساب طالب')),
      ]),
    ]);
    final card = AppCard(
      color: AppColors.navyDeep,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.verified_outlined, color: Color(0xFF7CD6C9)),
          SizedBox(width: 8),
          Text('كيف تعمل المنصة؟', style: TextStyle(color: Colors.white, fontFamily: kHeadFont, fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        const SizedBox(height: 12),
        for (final t in const [
          'اختر الدورة وأرسل طلب الاشتراك',
          'حوّل المبلغ وارفع إثبات الدفع',
          'نتحقق من وصول المبلغ ونفعّل الدورة',
          'شاهد الدروس واحضر الحصص وأدِّ الامتحانات',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFFFFBA47)),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: const TextStyle(color: Color(0xFFE5E2DB)))),
            ]),
          ),
      ]),
    );
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(flex: 6, child: text),
            const SizedBox(width: 32),
            Expanded(flex: 4, child: card),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 20), card]);
  }
}

class _Features extends StatelessWidget {
  const _Features({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.play_circle_outline, 'دروس مسجلة منظّمة', 'وحدات ودروس مرتبة، وتتبّع لتقدّمك في كل دورة.'),
      (Icons.sensors, 'حصص مباشرة', 'جدول حصص بتوقيت القاهرة ورابط انضمام مباشر.'),
      (Icons.quiz_outlined, 'امتحانات إلكترونية', 'تصحيح آلي فوري ووقت يُحسب من الخادم.'),
      (Icons.fact_check_outlined, 'حضور ونتائج', 'سجل حضور ودرجات واضح للطالب.'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      final w = (c.maxWidth - (cols - 1) * 16) / cols;
      return Wrap(spacing: 16, runSpacing: 16, children: [
        for (final i in items)
          SizedBox(
            width: w,
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(14)),
                  child: Icon(i.$1, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text(i.$2, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(i.$3, style: const TextStyle(color: AppColors.onVariant)),
              ]),
            ),
          ),
      ]);
    });
  }
}

class _Courses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('اختر الدورة المناسبة لمرحلتك الدراسية', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
      const SizedBox(height: 16),
      StreamBuilder<List<Course>>(
        stream: Services.courses.watchPublished(),
        builder: (context, snap) {
          if (snap.hasError) return const Text('تعذّر تحميل الدورات الآن.');
          if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
          final list = snap.data!;
          if (list.isEmpty) return const Text('ستظهر الدورات المتاحة هنا قريبًا.');
          return LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 16) / cols;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final course in list)
                SizedBox(
                  width: w,
                  child: AppCard(
                    onTap: () => context.go('/courses/${course.id}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text([course.gradeLabel, course.subjectLabel].where((e) => e.isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(course.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
                      if (course.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(course.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.onVariant)),
                      ],
                      const SizedBox(height: 12),
                      Row(children: [
                        Text(course.priceText,
                            style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy)),
                        const Spacer(),
                        Text('${course.accessDays} يومًا', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                      ]),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => context.go('/courses/${course.id}'), child: const Text('تفاصيل الدورة')),
                    ]),
                  ),
                ),
            ]);
          });
        },
      ),
    ]);
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.checklist, 'اختر الدورة', 'اطّلع على التفاصيل ثم اضغط «طلب الاشتراك».'),
      (Icons.account_balance_outlined, 'حوّل المبلغ', 'تظهر لك تعليمات الدفع ورقم طلبك لكتابته في بيان التحويل.'),
      (Icons.upload_file_outlined, 'ارفع الإيصال', 'نتحقق من وصول المبلغ ونفعّل الدورة، وتصلك رسالة داخل المنصة.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('طريقة الاشتراك في 3 خطوات بسيطة', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 800 ? 3 : 1;
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < steps.length; i++)
            SizedBox(
              width: w,
              child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 10),
                    Icon(steps[i].$1, color: AppColors.primary),
                  ]),
                  const SizedBox(height: 10),
                  Text(steps[i].$2, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(steps[i].$3, style: const TextStyle(color: AppColors.onVariant)),
                ]),
              ),
            ),
        ]);
      }),
    ]);
  }
}

class _Faq extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const qa = [
      ('كيف أشترك في دورة؟', 'سجّل حسابًا، ثم افتح الدورة واضغط «طلب الاشتراك»، وحوّل المبلغ وارفع الإثبات من صفحة «طلباتي».'),
      ('متى تُفعَّل الدورة؟', 'بعد أن يتحقق المسؤول من وصول المبلغ فعليًا ويعتمد الطلب، وتصلك رسالة داخل المنصة.'),
      ('كم مدة إتاحة الدورة؟', 'تظهر مدة الإتاحة في صفحة كل دورة، ويظهر تاريخ انتهاء اشتراكك في لوحتك.'),
      ('ماذا لو انقطع الإنترنت أثناء الامتحان؟', 'تُحفظ إجاباتك تلقائيًا كل دقيقة، ويُحسب الوقت من الخادم. راجع شروط الاستخدام لمعرفة التفاصيل.'),
      ('كيف أحضر الحصص المباشرة؟', 'تجد رابط الانضمام في لوحتك وفي صفحة «الحصص المباشرة» بتوقيت القاهرة.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('الأسئلة الشائعة', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
      const SizedBox(height: 16),
      for (final q in qa)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(q.$1, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(q.$2, style: const TextStyle(color: AppColors.onVariant))],
            ),
          ),
        ),
    ]);
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.loggedIn});
  final bool loggedIn;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: AppColors.navyDeep, borderRadius: BorderRadius.circular(24)),
        child: Wrap(spacing: 24, runSpacing: 16, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text('ابدأ رحلتك الآن',
              style: TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white)),
          Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton(
              onPressed: () => context.go(loggedIn ? Services.session.homePath : '/register'),
              child: Text(loggedIn ? 'اذهب إلى لوحتي' : 'إنشاء حساب'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/courses'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x40FFFFFF))),
              child: const Text('تصفّح الدورات'),
            ),
          ]),
        ]),
      );
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(children: [
          const BrandMark(),
          const SizedBox(height: 8),
          const LegalFooter(),
          Text('${LegalConfig.contactEmail} · ${LegalConfig.contactPhone}', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
          const SizedBox(height: 4),
          const Text('جميع الحقوق محفوظة © 2026 — منصة مدرستي للتعليم الرقمي',
              style: TextStyle(fontSize: 12, color: AppColors.outline)),
        ]),
      );
}
