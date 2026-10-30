import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/auth_scaffold.dart';
import 'auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = 'يجب الموافقة على الإقرار للمتابعة');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Services.auth.register(
        name: _name.text,
        email: _email.text,
        password: _pass.text,
        phone: _phone.text,
      );
    } catch (e) {
      if (mounted) setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'إنشاء حساب طالب',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              validator: (v) => Validators.required(v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
              validator: Validators.phoneOptional,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور'),
              validator: Validators.password,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
              validator: (v) => v != _pass.text ? 'كلمتا المرور غير متطابقتين' : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              // TODO: صياغة الإقرار تُراجَع قانونيًا قبل الإطلاق.
              title: const Text('أُقرّ بموافقة ولي الأمر (للطلاب دون 18 سنة) على التسجيل واستخدام البيانات لأغراض التعليم.'),
              subtitle: Wrap(children: [
                TextButton(onPressed: () => context.push('/privacy'), child: const Text('سياسة الخصوصية')),
                TextButton(onPressed: () => context.push('/terms'), child: const Text('شروط الاستخدام')),
              ]),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('إنشاء الحساب'),
            ),
            TextButton(onPressed: () => context.go('/login'), child: const Text('لدي حساب بالفعل')),
          ],
        ),
      ),
    );
  }
}
