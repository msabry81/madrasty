import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/auth_scaffold.dart';
import 'auth_repository.dart';

class ResetPage extends StatefulWidget {
  const ResetPage({super.key});
  @override
  State<ResetPage> createState() => _ResetPageState();
}

class _ResetPageState extends State<ResetPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _isError = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Services.auth.sendReset(_email.text);
      _msg = 'إذا كان البريد مسجّلًا فسيصلك رابط إعادة التعيين';
      _isError = false;
    } catch (e) {
      _msg = authErrorMessage(e);
      _isError = true;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AuthScaffold(
      title: 'استعادة كلمة المرور',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: Validators.email,
            ),
            if (_msg != null) ...[
              const SizedBox(height: 12),
              Text(_msg!, style: TextStyle(color: _isError ? scheme.error : scheme.primary)),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _submit, child: const Text('إرسال الرابط')),
            TextButton(onPressed: () => context.go('/login'), child: const Text('رجوع لتسجيل الدخول')),
          ],
        ),
      ),
    );
  }
}
