import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});
  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _text = TextEditingController();
  bool _loaded = false, _busy = false;

  @override
  void initState() {
    super.initState();
    Services.payments.watchInstructions().first.then((v) {
      if (mounted) {
        setState(() {
          _text.text = v;
          _loaded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Services.payments.saveInstructions(_text.text.trim());
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الدفع')),
      body: Centered(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'تظهر هذه التعليمات للطالب عند طلب الاشتراك (وسائل الدفع، أرقام الحسابات/المحافظ، مدة المراجعة...).',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'تعليمات الدفع',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: const Text('حفظ'),
                  ),
                ],
              ),
      ),
    );
  }
}
