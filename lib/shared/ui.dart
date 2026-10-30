import 'package:flutter/material.dart';

import '../features/auth/auth_repository.dart';

String friendlyError(Object e) => authErrorMessage(e);

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
}

Future<bool> confirm(BuildContext context, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
      ],
    ),
  );
  return r ?? false;
}

/// عمود محتوى بعرض أقصى مناسب للويب.
class Centered extends StatelessWidget {
  const Centered({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

String fmtDate(DateTime? d) => d == null
    ? ''
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<String?> promptText(BuildContext context, {required String title, required String label}) async {
  final c = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('تأكيد')),
      ],
    ),
  );
  c.dispose();
  return r;
}
