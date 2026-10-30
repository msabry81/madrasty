import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import 'admin_dialogs.dart';

class AdminCourseDetailPage extends StatelessWidget {
  const AdminCourseDetailPage({super.key, required this.courseId});
  final String courseId;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Services.courses;
    return StreamBuilder<Course?>(
      stream: repo.watchCourse(courseId),
      builder: (context, cs) {
        final course = cs.data;
        if (course == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: Text(course.title)),
          body: StreamBuilder<List<Unit>>(
            stream: repo.watchUnits(courseId),
            builder: (context, us) => StreamBuilder<List<Lesson>>(
              stream: repo.watchLessons(courseId),
              builder: (context, ls) {
                if (!us.hasData || !ls.hasData) return const Center(child: CircularProgressIndicator());
                final units = us.data!;
                final lessons = ls.data!;
                final nextUnit = units.isEmpty ? 1 : units.last.order + 1;

                return Centered(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course.title, style: Theme.of(context).textTheme.titleLarge),
                              Text('${course.priceText} · ${course.accessDays} يومًا'),
                              const SizedBox(height: 8),
                              Row(children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('تعديل'),
                                  onPressed: () async {
                                    final c = await CourseDialog.show(context, course: course);
                                    if (c != null && context.mounted) await _run(context, () => repo.saveCourse(c));
                                  },
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: Text(course.isPublished ? 'منشورة' : 'مسودة'),
                                  selected: course.isPublished,
                                  onSelected: (v) => _run(context,
                                      () => repo.saveCourse(course.copyWith(status: v ? 'published' : 'draft'))),
                                ),
                              ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Text('الوحدات والدروس', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('وحدة'),
                          onPressed: () async {
                            final u = await UnitDialog.show(context, nextOrder: nextUnit);
                            if (u != null && context.mounted) await _run(context, () => repo.saveUnit(courseId, u));
                          },
                        ),
                      ]),
                      const SizedBox(height: 8),
                      for (final u in units)
                        _UnitCard(
                          courseId: courseId,
                          unit: u,
                          lessons: lessons.where((l) => l.unitId == u.id).toList(),
                          run: _run,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.courseId, required this.unit, required this.lessons, required this.run});
  final String courseId;
  final Unit unit;
  final List<Lesson> lessons;
  final Future<void> Function(BuildContext, Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final repo = Services.courses;
    final nextLesson = lessons.isEmpty ? 1 : lessons.last.order + 1;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('${unit.order}. ${unit.title}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              final u = await UnitDialog.show(context, unit: unit, nextOrder: unit.order);
              if (u != null && context.mounted) await run(context, () => repo.saveUnit(courseId, u));
            } else if (v == 'delete') {
              if (lessons.isNotEmpty) {
                showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: Text('احذف دروس الوحدة أولًا')),
                );
                return;
              }
              if (await confirm(context, 'حذف الوحدة "${unit.title}"؟') && context.mounted) {
                await run(context, () => repo.deleteUnit(courseId, unit.id));
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
        children: [
          for (final l in lessons)
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: Text('${l.order}. ${l.title}'),
              subtitle: Text(l.isPreview ? 'معاينة · ${l.youtubeVideoId}' : l.youtubeVideoId,
                  textDirection: TextDirection.ltr),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final nl = await LessonDialog.show(context, lesson: l, unitId: unit.id, nextOrder: l.order);
                    if (nl != null && context.mounted) await run(context, () => repo.saveLesson(courseId, nl));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'حذف الدرس "${l.title}"؟') && context.mounted) {
                      await run(context, () => repo.deleteLesson(courseId, l.id));
                    }
                  },
                ),
              ]),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('إضافة درس'),
            onTap: () async {
              final nl = await LessonDialog.show(context, unitId: unit.id, nextOrder: nextLesson);
              if (nl != null && context.mounted) await run(context, () => repo.saveLesson(courseId, nl));
            },
          ),
        ],
      ),
    );
  }
}
