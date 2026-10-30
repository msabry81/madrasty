import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../shared/design.dart';
import '../../shared/ui.dart';
import '../admin/payment_actions.dart';
import '../comms/comms_models.dart';
import '../exams/exam_models.dart';
import '../payments/payment_models.dart';
import '../sessions/session_models.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context, 1000);
    final name = (Services.session.user?.displayName ?? '').trim();
    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _RecentRequests(),
      const SizedBox(height: 16),
      const _Announcements(),
    ]);
    final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _LiveSessionCard(),
      const SizedBox(height: 16),
      const _ExamResultsCard(),
    ]);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: EdgeInsets.all(wide ? 24 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('أهلًا بك مجددًا${name.isEmpty ? '' : '، $name'}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
              const Text('ملخص نشاط منصتك اليوم.', style: TextStyle(color: AppColors.onVariant)),
              const SizedBox(height: 20),
              const _Kpis(),
              const SizedBox(height: 16),
              const _QuickActions(),
              const SizedBox(height: 16),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 6, child: right),
                  const SizedBox(width: 16),
                  Expanded(flex: 7, child: left),
                ])
              else ...[right, const SizedBox(height: 16), left],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentRequest>>(
      stream: Services.payments.watchAll(),
      builder: (context, ps) => StreamBuilder<List<UserDoc>>(
        stream: Services.admin.watchUsers(),
        builder: (context, us) => StreamBuilder<List<LiveSession>>(
          stream: Services.sessions.watchAll(),
          builder: (context, ss) {
            final pay = ps.data ?? const <PaymentRequest>[];
            final pending = pay.where((r) => r.status == 'proof_submitted').toList();
            final pendingSum = pending.fold<num>(0, (a, r) => a + r.amount);
            final now = DateTime.now();
            final monthSum = pay
                .where((r) => r.status == 'approved' && r.createdAt != null && r.createdAt!.year == now.year && r.createdAt!.month == now.month)
                .fold<num>(0, (a, r) => a + r.amount);
            final totalSum = pay.where((r) => r.status == 'approved').fold<num>(0, (a, r) => a + r.amount);
            final students = (us.data ?? const <UserDoc>[]).where((u) => u.role != 'admin' && u.status != 'disabled').length;
            final upcoming = (ss.data ?? const <LiveSession>[]).where((s) => !s.isCancelled && s.endsAt.isAfter(now)).length;
            return LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
              final w = (c.maxWidth - (cols - 1) * 16) / cols;
              Widget card(Widget x) => SizedBox(width: w, child: x);
              return Wrap(spacing: 16, runSpacing: 16, children: [
                card(StatCard(icon: Icons.pending_actions_outlined, label: 'طلبات بانتظار التأكيد', value: '${pending.length}',
                    footer: 'بقيمة ${money(pendingSum)}', fg: AppColors.warnFg, bg: AppColors.warnBg)),
                card(StatCard(icon: Icons.account_balance_wallet_outlined, label: 'إجمالي التحصيل', value: money(totalSum),
                    footer: 'هذا الشهر: ${money(monthSum)}')),
                card(StatCard(icon: Icons.groups_outlined, label: 'الطلاب المسجلون', value: '$students',
                    footer: 'حسابات نشطة', fg: const Color(0xFF4B607B), bg: const Color(0xFFE0ECFF))),
                card(StatCard(icon: Icons.sensors, label: 'حصص قادمة', value: '$upcoming',
                    footer: 'مجدولة', fg: AppColors.successFg, bg: AppColors.successBg)),
              ]);
            });
          },
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    Widget b(String t, IconData i, String path, {bool primary = false}) => primary
        ? FilledButton.icon(onPressed: () => context.go(path), icon: Icon(i, size: 20), label: Text(t))
        : OutlinedButton.icon(onPressed: () => context.go(path), icon: Icon(i, size: 20), label: Text(t));
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt, color: AppColors.amber),
          SizedBox(width: 6),
          Text('إجراءات سريعة', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
        ]),
        b('جدولة حصة Meet', Icons.video_call_outlined, '/admin/sessions', primary: true),
        b('إدارة الدروس', Icons.note_add_outlined, '/admin/courses'),
        b('إنشاء امتحان', Icons.quiz_outlined, '/admin/exams'),
        b('نشر إعلان', Icons.campaign_outlined, '/admin/announcements'),
      ]),
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  const _LiveSessionCard();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LiveSession>>(
      stream: Services.sessions.watchAll(),
      builder: (context, snap) {
        final now = DateTime.now();
        final up = (snap.data ?? const <LiveSession>[]).where((s) => !s.isCancelled && s.endsAt.isAfter(now)).toList();
        final s = up.isEmpty ? null : up.first;
        return AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.circle, size: 10, color: Color(0xFFB91C1C)),
              const SizedBox(width: 8),
              Text('الحصة المباشرة القادمة', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              const Text('بتوقيت القاهرة', style: TextStyle(fontSize: 11, color: AppColors.outline)),
            ]),
            const SizedBox(height: 12),
            if (s == null)
              const Text('لا توجد حصص مجدولة. استخدم «جدولة حصة Meet» لإضافة حصة جديدة.')
            else ...[
              Text(s.courseTitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              Text(s.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _Info(Icons.schedule, 'الموعد', CairoTime.format(s.startsAt))),
                const SizedBox(width: 8),
                Expanded(child: _Info(Icons.timelapse, 'المدة', '${s.durationMinutes} دقيقة')),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.link, size: 18, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.meetUrl, textDirection: TextDirection.ltr, overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  web.window.open(s.meetUrl, '_blank');
                  context.go('/admin/sessions/${s.id}');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء الحصة وتسجيل الحضور'),
              ),
            ],
          ]),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

class _RecentRequests extends StatelessWidget {
  const _RecentRequests();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StreamBuilder<List<PaymentRequest>>(
        stream: Services.payments.watchAll(),
        builder: (context, snap) {
          final pending = (snap.data ?? const <PaymentRequest>[]).where((r) => r.status == 'proof_submitted').take(3).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('طلبات الاشتراك الأخيرة', icon: Icons.receipt_long_outlined,
                trailing: TextButton(onPressed: () => context.go('/admin/payments'), child: const Text('كل الطلبات'))),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد إيصالات بانتظار المراجعة.')),
            for (final r in pending)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    InitialAvatar(r.studentName, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.studentName.isEmpty ? '—' : r.studentName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                        Text('${r.courseTitle} · ${r.amountText}', style: const TextStyle(fontSize: 12, color: AppColors.onVariant)),
                        Text('${r.reference.isEmpty ? 'بدون مرجع' : r.reference} · ${ago(r.createdAt)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => openProof(context, r),
                      icon: const Icon(Icons.description_outlined, size: 16),
                      label: const Text('فحص الإيصال'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                      onPressed: () => approveRequest(context, r),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('قبول وتفعيل'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.errorFg, backgroundColor: AppColors.errorBg, minimumSize: const Size(0, 38)),
                      onPressed: () => rejectRequest(context, r),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('رفض'),
                    ),
                  ]),
                ]),
              ),
            const SizedBox(height: 8),
            const Text('تحقق من وصول المبلغ فعليًا قبل القبول؛ الإيصال وحده لا يثبت الدفع.',
                style: TextStyle(fontSize: 12, color: AppColors.outline)),
          ]);
        },
      ),
    );
  }
}

class _ExamResultsCard extends StatelessWidget {
  const _ExamResultsCard();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StreamBuilder<List<Exam>>(
        stream: Services.exams.watchAll(),
        builder: (context, es) {
          final exam = (es.data ?? const <Exam>[]).where((x) => x.published).firstOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('نتائج آخر امتحان', icon: Icons.bar_chart,
                trailing: exam == null ? null : TextButton(onPressed: () => context.go('/admin/exams/${exam.id}/results'), child: const Text('التفاصيل'))),
            const SizedBox(height: 8),
            if (exam == null)
              const Text('لا توجد امتحانات منشورة بعد.')
            else
              StreamBuilder<List<ResultDoc>>(
                stream: Services.exams.watchResults(exam.id),
                builder: (context, rs) {
                  final list = rs.data ?? const <ResultDoc>[];
                  if (list.isEmpty) return Text('${exam.title}: لا توجد نتائج بعد.');
                  final total = list.first.totalScore.toDouble();
                  final scores = list.map((r) => r.score.toDouble()).toList();
                  final avg = scores.reduce((a, b) => a + b) / scores.length;
                  final max = scores.reduce((a, b) => a > b ? a : b);
                  final bins = List<int>.filled(5, 0);
                  for (final s in scores) {
                    final p = total == 0 ? 0.0 : s / total;
                    bins[(p * 5).floor().clamp(0, 4)]++;
                  }
                  final peak = bins.reduce((a, b) => a > b ? a : b);
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(exam.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _Info(Icons.groups_outlined, 'المشاركون', '${list.length}')),
                      const SizedBox(width: 8),
                      Expanded(child: _Info(Icons.functions, 'المتوسط', '${avg.toStringAsFixed(1)} / ${total.round()}')),
                      const SizedBox(width: 8),
                      Expanded(child: _Info(Icons.emoji_events_outlined, 'الأعلى', '${max.round()} / ${total.round()}')),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < 5; i++)
                          Expanded(
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Text('${bins[i]}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                height: peak == 0 ? 4 : 4 + 56.0 * bins[i] / peak,
                                decoration: BoxDecoration(
                                  color: i >= 3 ? AppColors.primary : AppColors.primaryTint,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              Text('${i * 20}-${(i + 1) * 20}%', style: const TextStyle(fontSize: 10, color: AppColors.outline)),
                            ]),
                          ),
                      ]),
                    ),
                  ]);
                },
              ),
          ]);
        },
      ),
    );
  }
}

class _Announcements extends StatelessWidget {
  const _Announcements();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StreamBuilder<List<Announcement>>(
        stream: Services.comms.watchAllAnnouncements(),
        builder: (context, snap) {
          final list = (snap.data ?? const <Announcement>[]).take(2).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('أحدث الإعلانات للطلاب', icon: Icons.campaign_outlined,
                trailing: TextButton(onPressed: () => context.go('/admin/announcements'), child: const Text('إعلان جديد'))),
            const SizedBox(height: 8),
            if (list.isEmpty) const Text('لم تنشر إعلانات بعد.'),
            for (final a in list)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy))),
                    StatusBadge(a.audience == 'all' ? 'للجميع' : 'لدورة محددة', BadgeKind.neutral),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(fmtDate(a.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                ]),
              ),
          ]);
        },
      ),
    );
  }
}
