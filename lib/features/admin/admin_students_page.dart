import 'package:flutter/material.dart';

import '../../core/digits.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import '../payments/payment_models.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});
  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  String _q = '';

  Future<void> _toggle(UserDoc u) async {
    final disable = u.status != 'disabled';
    if (!await confirm(context, disable ? 'تعطيل حساب ${u.name}؟' : 'تفعيل حساب ${u.name}؟')) return;
    try {
      await Services.admin.setUserStatus(u.uid, disable ? 'disabled' : 'active');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      body: Centered(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'بحث بالاسم أو البريد'),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<UserDoc>>(
              stream: Services.admin.watchUsers(),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('تعذّر تحميل المستخدمين'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!
                    .where((u) => _q.isEmpty || u.name.toLowerCase().contains(_q) || u.email.toLowerCase().contains(_q))
                    .toList();
                if (list.isEmpty) return const Center(child: Text('لا نتائج'));
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = list[i];
                    final isAdmin = u.role == 'admin';
                    return Card(
                      child: ListTile(
                        title: Text(u.name.isEmpty ? u.email : u.name),
                        subtitle: Text([u.email, u.phone].where((e) => e.isNotEmpty).join(' · ')),
                        leading: isAdmin ? const Icon(Icons.shield_outlined) : const Icon(Icons.person_outline),
                        trailing: isAdmin
                            ? const Chip(label: Text('مدير'))
                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                if (u.status == 'disabled') const Chip(label: Text('معطّل')),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'access') {
                                      showDialog<void>(context: context, builder: (_) => _AccessDialog(user: u));
                                    } else {
                                      _toggle(u);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'access', child: Text('الوصول للدورات')),
                                    PopupMenuItem(value: 'toggle', child: Text(u.status == 'disabled' ? 'تفعيل الحساب' : 'تعطيل الحساب')),
                                  ],
                                ),
                              ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _AccessDialog extends StatefulWidget {
  const _AccessDialog({required this.user});
  final UserDoc user;
  @override
  State<_AccessDialog> createState() => _AccessDialogState();
}

class _AccessDialogState extends State<_AccessDialog> {
  Course? _course;
  final _days = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;

  static const _statusAr = {'active': 'نشط', 'revoked': 'مسحوب', 'expired': 'منتهي', 'suspended': 'موقوف'};

  @override
  void dispose() {
    _days.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _grant() async {
    final reason = _reason.text.trim();
    if (_course == null || reason.isEmpty) {
      _snack('اختر الدورة واكتب السبب');
      return;
    }
    final d = _days.text.trim().isEmpty ? null : parseNum(_days.text)?.toInt();
    if (_days.text.trim().isNotEmpty && (d == null || d < 1)) {
      _snack('عدد الأيام غير صالح');
      return;
    }
    setState(() => _busy = true);
    try {
      await Services.admin.grantAccess(widget.user.uid, _course!.id, d, reason);
      _reason.clear();
      _snack('تم منح الوصول');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(Enrollment e) async {
    final reason = await promptText(context, title: 'سحب الوصول', label: 'السبب');
    if (reason == null || reason.isEmpty) return;
    try {
      await Services.admin.revokeAccess(widget.user.uid, e.courseId, reason);
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('وصول ${widget.user.name}'),
      content: SizedBox(
        width: 460,
        child: StreamBuilder<List<Course>>(
          stream: Services.courses.watchAll(),
          builder: (context, cs) => StreamBuilder<List<Enrollment>>(
            stream: Services.admin.watchEnrollmentsOf(widget.user.uid),
            builder: (context, es) {
              if (!cs.hasData || !es.hasData) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final courses = cs.data!;
              final title = {for (final c in courses) c.id: c.title};
              return SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (es.data!.isEmpty) const Text('لا توجد تسجيلات'),
                  for (final e in es.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(title[e.courseId] ?? e.courseId),
                      subtitle: Text('${_statusAr[e.status] ?? e.status} · ينتهي ${fmtDate(e.endAt)}'),
                      trailing: e.status == 'active'
                          ? TextButton(onPressed: () => _revoke(e), child: const Text('سحب'))
                          : null,
                    ),
                  const Divider(),
                  Text('منح وصول يدوي', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Course>(
                    initialValue: _course,
                    decoration: const InputDecoration(labelText: 'الدورة'),
                    items: [for (final c in courses) DropdownMenuItem(value: c, child: Text(c.title))],
                    onChanged: (v) => setState(() => _course = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _days,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الأيام (فارغ = مدة الدورة)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: _reason, decoration: const InputDecoration(labelText: 'السبب (إلزامي)')),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _busy ? null : _grant, child: const Text('منح الوصول')),
                ]),
              );
            },
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }
}
