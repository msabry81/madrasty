import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/digits.dart';
import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/cairo_datetime_field.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import '../exams/exam_models.dart';

Future<void> editExam(BuildContext context, [Exam? exam]) async {
  final courses = await Services.courses.watchAll().first;
  if (!context.mounted) return;
  if (courses.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('أنشئ دورة أولًا')));
    return;
  }
  final r = await showDialog<Exam>(
    context: context,
    builder: (_) => ExamDialog(courses: courses, exam: exam),
  );
  if (r == null || !context.mounted) return;
  try {
    await Services.exams.saveExam(r);
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class AdminExamsPage extends StatelessWidget {
  const AdminExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الامتحانات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editExam(context),
        icon: const Icon(Icons.add),
        label: const Text('امتحان جديد'),
      ),
      body: StreamBuilder<List<Exam>>(
        stream: Services.exams.watchAll(),
        builder: (context, snap) {
          if (snap.hasError)
            return const Center(child: Text('تعذّر تحميل الامتحانات'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty)
            return const Center(child: Text('لا توجد امتحانات'));
          return Centered(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final x = list[i];
                return Card(
                  child: ListTile(
                    title: Text(x.title),
                    subtitle: Text(
                      '${x.courseTitle}\n${CairoTime.format(x.opensAt)} · ${x.durationMinutes} د · ${x.totalScore} درجة',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(x.published ? 'منشور' : 'مسودة'),
                    ),
                    onTap: () => context.push('/admin/exams/${x.id}'),
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

class ExamDialog extends StatefulWidget {
  const ExamDialog({super.key, required this.courses, this.exam});
  final List<Course> courses;
  final Exam? exam;
  @override
  State<ExamDialog> createState() => _ExamDialogState();
}

class _ExamDialogState extends State<ExamDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.exam?.title);
  late final _dur = TextEditingController(
    text: '${widget.exam?.durationMinutes ?? 30}',
  );
  late final _tries = TextEditingController(
    text: '${widget.exam?.attemptsAllowed ?? 1}',
  );
  Course? _course;
  DateTime? _opens, _closes;
  late String _mode = widget.exam?.resultsMode ?? 'after_close';
  late bool _shuffle = widget.exam?.shuffleQuestions ?? false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final x = widget.exam;
    if (x != null) {
      _course = widget.courses.where((c) => c.id == x.courseId).firstOrNull;
      _opens = x.opensAt;
      _closes = x.closesAt;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _dur.dispose();
    _tries.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_course == null || _opens == null || _closes == null) {
      setState(() => _error = 'اختر الدورة وأدخل وقتي البداية والنهاية');
      return;
    }
    if (!_closes!.isAfter(_opens!)) {
      setState(() => _error = 'وقت الإغلاق يجب أن يكون بعد وقت الفتح');
      return;
    }
    Navigator.pop(
      context,
      Exam(
        id: widget.exam?.id ?? '',
        courseId: _course!.id,
        courseTitle: _course!.title,
        title: _title.text.trim(),
        durationMinutes: parseNum(_dur.text)!.toInt(),
        opensAt: _opens!,
        closesAt: _closes!,
        attemptsAllowed: parseNum(_tries.text)!.toInt(),
        resultsMode: _mode,
        shuffleQuestions: _shuffle,
        published: widget.exam?.published ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exam == null ? 'امتحان جديد' : 'تعديل الامتحان'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Course>(
                  initialValue: _course,
                  decoration: const InputDecoration(labelText: 'الدورة'),
                  items: [
                    for (final c in widget.courses)
                      DropdownMenuItem(value: c, child: Text(c.title)),
                  ],
                  onChanged: (v) => setState(() => _course = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الامتحان',
                  ),
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 8),
                CairoDateTimeField(
                  label: 'يفتح في',
                  initial: _opens,
                  onChanged: (v) => _opens = v,
                ),
                const SizedBox(height: 8),
                CairoDateTimeField(
                  label: 'يُغلق في',
                  initial: _closes,
                  onChanged: (v) => _closes = v,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dur,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'مدة الامتحان (دقيقة)',
                  ),
                  validator: (v) {
                    final n = parseNum(v ?? '');
                    return (n == null || n < 1 || n % 1 != 0)
                        ? 'أدخل عددًا صحيحًا'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tries,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد المحاولات'),
                  validator: (v) {
                    final n = parseNum(v ?? '');
                    return (n == null || n < 1 || n > 20 || n % 1 != 0)
                        ? 'من 1 إلى 20'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'إظهار النتيجة'),
                  items: [
                    for (final e in resultsModeLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _mode = v ?? _mode),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ترتيب عشوائي للأسئلة'),
                  value: _shuffle,
                  onChanged: (v) => setState(() => _shuffle = v),
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
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}
