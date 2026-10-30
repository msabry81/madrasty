import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/cairo_datetime_field.dart';
import '../../shared/ui.dart';
import '../comms/comms_models.dart';
import '../courses/models.dart';

class AdminAnnouncementsPage extends StatelessWidget {
  const AdminAnnouncementsPage({super.key});

  Future<void> _new(BuildContext context) async {
    final courses = await Services.courses.watchAll().first;
    if (!context.mounted) return;
    final d = await showDialog<AnnouncementDraft>(
      context: context,
      builder: (_) => _AnnouncementDialog(courses: courses),
    );
    if (d == null || !context.mounted) return;
    try {
      final n = await Services.comms.publish(d);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم النشر وإشعار $n طالب')));
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعلانات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
      body: StreamBuilder<List<Announcement>>(
        stream: Services.comms.watchAllAnnouncements(),
        builder: (context, snap) {
          if (snap.hasError)
            return const Center(child: Text('تعذّر تحميل الإعلانات'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد إعلانات'));
          return Centered(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = list[i];
                return Card(
                  child: ListTile(
                    title: Text(a.title),
                    subtitle: Text(
                      '${a.body}\n${a.audience == 'all' ? 'للجميع' : 'لدورة محددة'} · ${fmtDate(a.createdAt)}'
                      '${a.isExpired ? ' · منتهي' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (!await confirm(context, 'حذف الإعلان وإشعاراته؟') ||
                            !context.mounted)
                          return;
                        try {
                          await Services.comms.delete(a.id);
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      },
                    ),
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

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.courses});
  final List<Course> courses;
  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _audience = 'all';
  Course? _course;
  DateTime? _expires;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_audience == 'course' && _course == null) {
      setState(() => _error = 'اختر الدورة');
      return;
    }
    Navigator.pop(
      context,
      AnnouncementDraft(
        title: _title.text.trim(),
        body: _body.text.trim(),
        audience: _audience,
        courseId: _audience == 'course' ? _course!.id : null,
        expiresAt: _expires,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعلان جديد'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _body,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'النص'),
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _audience,
                  decoration: const InputDecoration(labelText: 'الجمهور'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('كل الطلاب')),
                    DropdownMenuItem(
                      value: 'course',
                      child: Text('مشتركو دورة محددة'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _audience = v ?? 'all'),
                ),
                if (_audience == 'course') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Course>(
                    initialValue: _course,
                    decoration: const InputDecoration(labelText: 'الدورة'),
                    items: [
                      for (final c in widget.courses)
                        DropdownMenuItem(value: c, child: Text(c.title)),
                    ],
                    onChanged: (v) => setState(() => _course = v),
                  ),
                ],
                const SizedBox(height: 8),
                CairoDateTimeField(
                  label: 'ينتهي في (اختياري)',
                  onChanged: (v) => _expires = v,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _save, child: const Text('نشر')),
      ],
    );
  }
}
