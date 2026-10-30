import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import 'admin_dialogs.dart';

class AdminCoursesPage extends StatelessWidget {
  const AdminCoursesPage({super.key});

  Future<void> _add(BuildContext context) async {
    final c = await CourseDialog.show(context);
    if (c == null) return;
    try {
      await Services.courses.saveCourse(c);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدورات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
      body: StreamBuilder<List<Course>>(
        stream: Services.courses.watchAll(),
        builder: (context, snap) {
          if (snap.hasError)
            return const Center(child: Text('تعذّر تحميل الدورات'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty)
            return const Center(child: Text('لا توجد دورات بعد'));
          return Centered(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = list[i];
                return Card(
                  child: ListTile(
                    title: Text(c.title),
                    subtitle: Text('${c.priceText} · ${c.accessDays} يومًا'),
                    trailing: Chip(
                      label: Text(c.isPublished ? 'منشورة' : 'مسودة'),
                    ),
                    onTap: () => context.push('/admin/courses/${c.id}'),
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
