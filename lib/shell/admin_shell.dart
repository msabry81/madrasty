import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/brand_config.dart';
import '../core/services.dart';
import '../core/theme.dart';
import '../features/payments/payment_models.dart';
import '../shared/design.dart';

class _AItem {
  const _AItem(this.label, this.path, this.icon);
  final String label, path;
  final IconData icon;
}

const _items = [
  _AItem('الرئيسية', '/admin', Icons.dashboard_outlined),
  _AItem('إدارة الكورسات', '/admin/courses', Icons.menu_book_outlined),
  _AItem('الحصص المباشرة', '/admin/sessions', Icons.sensors),
  _AItem('الامتحانات', '/admin/exams', Icons.quiz_outlined),
  _AItem('طلبات الاشتراك', '/admin/payments', Icons.receipt_long_outlined),
  _AItem('الطلاب', '/admin/students', Icons.groups_outlined),
  _AItem('الإعلانات', '/admin/announcements', Icons.campaign_outlined),
  _AItem('إعدادات الدفع', '/admin/settings', Icons.settings_outlined),
];

bool _active(String loc, String path) =>
    path == '/admin' ? loc == '/admin' : (loc == path || loc.startsWith('$path/'));

/// إطار الإدارة: قائمة جانبية يمينًا (RTL) + شريط علوي بالتوقيت وملخص الطلبات.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context, 1000);
    return StreamBuilder<List<PaymentRequest>>(
      stream: Services.payments.watchAll(),
      builder: (context, snap) {
        final list = snap.data ?? const <PaymentRequest>[];
        final pending = list.where((r) => r.status == 'proof_submitted').length;
        final collected = list.where((r) => r.status == 'approved').fold<num>(0, (a, r) => a + r.amount);
        final sidebar = _Sidebar(location: location, pending: pending, collected: collected);
        return Scaffold(
          backgroundColor: AppColors.canvas,
          drawer: wide ? null : Drawer(backgroundColor: Colors.white, child: SafeArea(child: sidebar)),
          appBar: wide
              ? null
              : AppBar(
                  backgroundColor: Colors.white,
                  title: const BrandMark(subtitle: BrandConfig.adminTitle),
                  actions: [
                    if (pending > 0)
                      IconButton(
                        tooltip: 'طلبات بانتظار التأكيد',
                        onPressed: () => context.go('/admin/payments'),
                        icon: Badge(label: Text('$pending'), child: const Icon(Icons.receipt_long_outlined)),
                      ),
                  ],
                ),
          body: wide
              ? Row(children: [
                  SizedBox(width: 272, child: sidebar),
                  Expanded(
                    child: Column(children: [
                      _TopBar(pending: pending),
                      Expanded(child: child),
                    ]),
                  ),
                ])
              : child,
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, required this.pending, required this.collected});
  final String location;
  final int pending;
  final num collected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: AppColors.border))),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 20), child: BrandMark(subtitle: BrandConfig.adminTitle)),
        Expanded(
          child: ListView(children: [
            for (final i in _items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: _active(location, i.path) ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.pop(context);
                      context.go(i.path);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Icon(i.icon, size: 22, color: _active(location, i.path) ? Colors.white : AppColors.navy),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(i.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _active(location, i.path) ? Colors.white : AppColors.navy)),
                        ),
                        if (i.path == '/admin/payments' && pending > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(999)),
                            child: Text('$pending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.navy)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text('إجمالي المحصّل', style: TextStyle(fontSize: 12, color: AppColors.onVariant, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(money(collected), style: const TextStyle(fontFamily: kHeadFont, fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: Services.auth.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.pending});
  final int pending;

  @override
  Widget build(BuildContext context) {
    final u = Services.session.user;
    final name = u?.displayName ?? u?.email ?? '';
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(color: AppColors.canvas),
      child: Row(children: [
        const CairoClock(),
        const SizedBox(width: 8),
        if (pending > 0)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.go('/admin/payments'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.warnBg, border: Border.all(color: AppColors.warnBorder), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.warnFg),
                const SizedBox(width: 6),
                Text('$pending طلب اشتراك بانتظار التأكيد',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warnFg)),
              ]),
            ),
          ),
        const Spacer(),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
          const Text('المدير', style: TextStyle(fontSize: 11, color: AppColors.outline)),
        ]),
        const SizedBox(width: 8),
        InitialAvatar(name, size: 38),
      ]),
    );
  }
}
