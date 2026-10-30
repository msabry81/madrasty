import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../shared/design.dart';
import '../../shared/ui.dart';
import '../payments/payment_models.dart';
import 'payment_actions.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});
  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  String _filter = 'all';
  String _q = '';

  static const _tabs = {
    'all': 'الكل',
    'proof_submitted': 'بانتظار التحقق',
    'pending_payment': 'بانتظار الدفع',
    'approved': 'المقبولة',
    'rejected': 'المرفوضة',
  };

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context, 1000);
    return StreamBuilder<List<PaymentRequest>>(
      stream: Services.payments.watchAll(),
      builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text('تعذّر تحميل الطلبات'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final all = snap.data!;
        int count(String s) => s == 'all' ? all.length : all.where((r) => r.status == s).length;
        final collected = all.where((r) => r.status == 'approved').fold<num>(0, (a, r) => a + r.amount);
        final pendingList = all.where((r) => r.status == 'proof_submitted').toList();
        final pendingSum = pendingList.fold<num>(0, (a, r) => a + r.amount);
        final q = _q.trim().toLowerCase();
        final rows = all.where((r) {
          if (_filter != 'all' && r.status != _filter) return false;
          if (q.isEmpty) return true;
          return r.studentName.toLowerCase().contains(q) ||
              r.studentEmail.toLowerCase().contains(q) ||
              r.code.toLowerCase().contains(q) ||
              r.courseTitle.toLowerCase().contains(q);
        }).toList();

        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('إدارة طلبات الاشتراك والتحويلات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
                      const Text('راجع إيصالات التحويل وتحقق من وصول المبلغ ثم فعّل الكورسات للطلاب.',
                          style: TextStyle(color: AppColors.onVariant)),
                    ]),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/settings'),
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('تعديل بيانات الاستلام والدفع'),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
                    final w = (c.maxWidth - (cols - 1) * 16) / cols;
                    Widget card(Widget child) => SizedBox(width: w, child: child);
                    return Wrap(spacing: 16, runSpacing: 16, children: [
                      card(StatCard(icon: Icons.payments_outlined, label: 'إجمالي المبالغ المحصّلة', value: money(collected),
                          footer: 'من الطلبات المقبولة')),
                      card(StatCard(icon: Icons.verified_outlined, label: 'الاشتراكات المؤكدة', value: '${count('approved')}',
                          footer: 'طالب مفعّل', fg: AppColors.successFg, bg: AppColors.successBg)),
                      card(StatCard(icon: Icons.pending_actions_outlined, label: 'بانتظار التأكيد والتدقيق', value: '${pendingList.length}',
                          footer: 'بقيمة ${money(pendingSum)}', fg: AppColors.warnFg, bg: AppColors.warnBg)),
                      card(StatCard(icon: Icons.receipt_long_outlined, label: 'إيصالات مرفوضة', value: '${count('rejected')}',
                          footer: 'يمكن للطالب إعادة الرفع', fg: AppColors.errorFg, bg: AppColors.errorBg)),
                    ]);
                  }),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'ابحث باسم الطالب أو البريد أو كود الطلب أو الدورة',
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final e in _tabs.entries)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                label: Text('${e.value} (${count(e.key)})'),
                                selected: _filter == e.key,
                                onSelected: (_) => setState(() => _filter = e.key),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SectionTitle('جدول تدقيق ومطابقة الحوالات', icon: Icons.fact_check_outlined,
                            trailing: Text('${rows.length} تسجيل', style: const TextStyle(color: AppColors.outline))),
                      ),
                      if (wide) const _TableHeader(),
                      if (rows.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('لا توجد طلبات مطابقة'))),
                      for (final r in rows) wide ? _WideRow(r: r) : _CompactRow(r: r),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const _InstructionsCard(),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.navy);
    return Container(
      color: AppColors.sand,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Row(children: [
        Expanded(flex: 3, child: Text('بيانات الطالب', style: s)),
        Expanded(flex: 3, child: Text('الكورس والمبلغ', style: s)),
        Expanded(flex: 2, child: Text('المرجع', style: s)),
        Expanded(flex: 2, child: Text('الإيصال', style: s)),
        Expanded(flex: 2, child: Text('الحالة', style: s)),
        Expanded(flex: 2, child: Text('التوقيت (القاهرة)', style: s)),
        Expanded(flex: 3, child: Text('إجراءات المراجعة', style: s)),
      ]),
    );
  }
}

Widget _actions(BuildContext context, PaymentRequest r) {
  if (r.status != 'proof_submitted') {
    return r.status == 'rejected' && r.rejectReason.isNotEmpty
        ? Text(r.rejectReason, style: const TextStyle(fontSize: 12, color: AppColors.errorFg))
        : const SizedBox.shrink();
  }
  return Wrap(spacing: 8, runSpacing: 8, children: [
    FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
      onPressed: () => approveRequest(context, r),
      icon: const Icon(Icons.check, size: 18),
      label: const Text('قبول'),
    ),
    TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.errorFg,
        backgroundColor: AppColors.errorBg,
        minimumSize: const Size(0, 38),
      ),
      onPressed: () => rejectRequest(context, r),
      icon: const Icon(Icons.close, size: 18),
      label: const Text('رفض'),
    ),
  ]);
}

Widget _proofButton(BuildContext context, PaymentRequest r) => r.proofPath.isEmpty
    ? const Text('—', style: TextStyle(color: AppColors.outline))
    : OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 10)),
        onPressed: () => openProof(context, r),
        icon: const Icon(Icons.description_outlined, size: 16),
        label: const Text('فحص الإيصال', style: TextStyle(fontSize: 12)),
      );

class _WideRow extends StatelessWidget {
  const _WideRow({required this.r});
  final PaymentRequest r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.sand))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          flex: 3,
          child: Row(children: [
            InitialAvatar(r.studentName, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.studentName.isEmpty ? '—' : r.studentName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                Text(r.studentEmail, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
              ]),
            ),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.courseTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(r.amountText, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.reference.isEmpty ? '—' : r.reference, style: const TextStyle(fontSize: 13)),
            Text('كود: ${r.code}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
          ]),
        ),
        Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: _proofButton(context, r))),
        Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: StatusBadge.payment(r.status))),
        Expanded(
          flex: 2,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.createdAt == null ? '' : CairoTime.formatTime(r.createdAt!), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(fmtDate(r.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.outline)),
            Text(ago(r.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.outline)),
          ]),
        ),
        Expanded(flex: 3, child: _actions(context, r)),
      ]),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.r});
  final PaymentRequest r;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.sand))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          InitialAvatar(r.studentName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.studentName.isEmpty ? '—' : r.studentName, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(r.studentEmail, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
            ]),
          ),
          StatusBadge.payment(r.status),
        ]),
        const SizedBox(height: 8),
        Text('${r.courseTitle} — ${r.amountText}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('كود: ${r.code}${r.reference.isEmpty ? '' : ' · ${r.reference}'} · ${ago(r.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.outline)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [_proofButton(context, r), _actions(context, r)]),
      ]),
    );
  }
}

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard();
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('تعليمات السداد الظاهرة للطلاب', icon: Icons.account_balance_wallet_outlined),
        const SizedBox(height: 8),
        const Text('هذه التعليمات تظهر للطالب عند طلب الاشتراك. يمكنك تحديث أرقام المحافظ والحسابات في أي وقت.',
            style: TextStyle(color: AppColors.onVariant)),
        const SizedBox(height: 12),
        StreamBuilder<String>(
          stream: Services.payments.watchInstructions(),
          builder: (context, snap) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
            child: Text((snap.data ?? '').isEmpty ? 'لم تُضف تعليمات بعد.' : snap.data!),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: () => context.go('/admin/settings'),
            icon: const Icon(Icons.edit_note),
            label: const Text('تحديث التعليمات'),
          ),
        ),
      ]),
    );
  }
}
