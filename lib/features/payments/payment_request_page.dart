import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/file_pick.dart';
import '../../shared/ui.dart';
import 'payment_models.dart';

class PaymentRequestPage extends StatefulWidget {
  const PaymentRequestPage({super.key, required this.requestId});
  final String requestId;
  @override
  State<PaymentRequestPage> createState() => _PaymentRequestPageState();
}

class _PaymentRequestPageState extends State<PaymentRequestPage> {
  final _ref = TextEditingController();
  Uint8List? _bytes;
  String? _ext, _fileName;
  bool _busy = false;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await pickFile(
      accept: '.jpg,.jpeg,.png,.webp,.pdf,image/*,application/pdf',
    );
    if (f == null || !mounted) return;
    void warn(String m) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    if (!const {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(f.extension)) {
      warn('نوع الملف غير مدعوم (صورة أو PDF فقط)');
      return;
    }
    if (f.bytes.length >= 5 * 1024 * 1024) {
      warn('حجم الملف يجب أن يكون أقل من 5 ميجا');
      return;
    }
    setState(() {
      _bytes = f.bytes;
      _ext = f.extension;
      _fileName = f.name;
    });
  }

  Future<void> _submit() async {
    if (_bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر صورة أو ملف الإثبات')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Services.payments.submitProof(
        uid: Services.session.user!.uid,
        requestId: widget.requestId,
        bytes: _bytes!,
        ext: _ext!,
        reference: _ref.text.trim(),
      );
      if (mounted) {
        setState(() {
          _bytes = null;
          _fileName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الإثبات للمراجعة')),
        );
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentRequest?>(
      stream: Services.payments.watchRequest(widget.requestId),
      builder: (context, snap) {
        final r = snap.data;
        if (snap.hasError ||
            (snap.connectionState == ConnectionState.active && r == null)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('الطلب غير موجود')),
          );
        }
        if (r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('طلب اشتراك')),
          body: Centered(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.courseTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('المبلغ: ${r.amountText}'),
                        Text(
                          'رقم الطلب: ${r.code}  (اكتبه في بيان التحويل إن أمكن)',
                        ),
                        const SizedBox(height: 8),
                        Chip(label: Text(r.statusLabel)),
                        if (r.status == 'rejected' && r.rejectReason.isNotEmpty)
                          Text(
                            'سبب الرفض: ${r.rejectReason}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (r.canUploadProof) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<String>(
                    stream: Services.payments.watchInstructions(),
                    builder: (context, s) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'طريقة الدفع',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (s.data ?? '').isEmpty
                                  ? 'ستُعلن تعليمات الدفع قريبًا.'
                                  : s.data!,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'بعد الدفع ارفع الإثبات',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _ref,
                            decoration: const InputDecoration(
                              labelText: 'رقم العملية / ملاحظات (اختياري)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_fileName ?? 'اختيار صورة أو PDF'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('إرسال الإثبات'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (r.status == 'proof_submitted')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'تم استلام الإثبات، وسيراجعه المسؤول ويتحقق من وصول المبلغ.',
                    ),
                  ),
                if (r.status == 'approved')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton(
                      onPressed: () => context.go('/courses/${r.courseId}'),
                      child: const Text('اذهب إلى الدورة'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
