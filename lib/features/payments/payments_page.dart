import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import 'payment_models.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي ومدفوعاتي')),
      body: StreamBuilder<List<PaymentRequest>>(
        stream: Services.payments.watchMyRequests(uid),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('تعذّر تحميل الطلبات'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد طلبات اشتراك'));
          return Centered(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = list[i];
                return Card(
                  child: ListTile(
                    title: Text(r.courseTitle),
                    subtitle: Text('${r.amountText} · رقم الطلب ${r.code} · ${fmtDate(r.createdAt)}'),
                    trailing: Chip(label: Text(r.statusLabel)),
                    onTap: () => context.push('/payments/${r.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
