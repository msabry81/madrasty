import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../payments/payment_models.dart';

Future<void> approveRequest(BuildContext context, PaymentRequest r) async {
  final ok = await confirm(
      context, 'هل تأكدت من وصول مبلغ ${r.amountText} فعليًا في الحساب/المحفظة؟ الإيصال وحده لا يثبت الدفع.');
  if (!ok) return;
  try {
    await Services.payments.review(r.id, approve: true);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> rejectRequest(BuildContext context, PaymentRequest r) async {
  final reason = await promptText(context, title: 'رفض الطلب', label: 'سبب الرفض (يظهر للطالب)');
  if (reason == null || reason.isEmpty) return;
  try {
    await Services.payments.review(r.id, approve: false, reason: reason);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Future<void> openProof(BuildContext context, PaymentRequest r) async {
  try {
    final url = await Services.payments.proofUrl(r.proofPath);
    web.window.open(url, '_blank');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
