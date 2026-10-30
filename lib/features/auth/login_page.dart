import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/auth_scaffold.dart';
import 'auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Services.auth.signIn(_email.text, _pass.text);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'تسجيل الدخول',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              validator: Validators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('دخول'),
            ),
            TextButton(onPressed: () => context.go('/reset'), child: const Text('نسيت كلمة المرور؟')),
            TextButton(onPressed: () => context.go('/register'), child: const Text('إنشاء حساب جديد')),
          ],
        ),
      ),
    );
  }
}
