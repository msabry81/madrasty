import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import '../exams/exam_models.dart';
import 'admin_exams_page.dart';
import 'question_dialog.dart';

class AdminExamDetailPage extends StatefulWidget {
  const AdminExamDetailPage({super.key, required this.examId});
  final String examId;
  @override
  State<AdminExamDetailPage> createState() => _AdminExamDetailPageState();
}

class _AdminExamDetailPageState extends State<AdminExamDetailPage> {
  late Future<Map<String, QuestionKey>> _keys = Services.exams.getKeys(widget.examId);

  void _reload() => setState(() => _keys = Services.exams.getKeys(widget.examId));

  Future<void> _run(Future<void> Function() f, {bool reload = false}) async {
    try {
      await f();
      if (reload) _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editQuestion(List<ExamQuestion> qs, Map<String, QuestionKey> keys, [ExamQuestion? q]) async {
    final draft = await showDialog<QuestionDraft>(
      context: context,
      builder: (_) => QuestionDialog(
        question: q,
        answerKey: q == null ? null : keys[q.id],
        nextOrder: qs.isEmpty ? 1 : qs.last.order + 1,
      ),
    );
    if (draft == null) return;
    await _run(() => Services.exams.saveQuestion(widget.examId, draft), reload: true);
  }

  String _answerText(ExamQuestion q, QuestionKey? k) {
    final c = k?.correct;
    if (c == null) return '';
    if (q.isMcq) return c is num && c.toInt() < q.options.length ? 'الصحيح: ${q.options[c.toInt()]}' : '';
    return 'الصحيح: ${c == true ? 'صح' : 'خطأ'}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Exam?>(
      stream: Services.exams.watchExam(widget.examId),
      builder: (context, xs) {
        final x = xs.data;
        if (x == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        return Scaffold(
          appBar: AppBar(title: Text(x.title)),
          body: StreamBuilder<List<ExamQuestion>>(
            stream: Services.exams.watchQuestions(widget.examId),
            builder: (context, qs) => FutureBuilder<Map<String, QuestionKey>>(
              future: _keys,
              builder: (context, ks) {
                if (!qs.hasData) return const Center(child: CircularProgressIndicator());
                final questions = qs.data!;
                final keys = ks.data ?? const <String, QuestionKey>{};
                return Centered(
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.courseTitle),
                          Text('${CairoTime.format(x.opensAt)} → ${CairoTime.format(x.closesAt)}'),
                          Text('المدة: ${x.durationMinutes} د · المحاولات: ${x.attemptsAllowed} · الدرجة الكلية: ${x.totalScore}'),
                          Text('النتيجة: ${resultsModeLabels[x.resultsMode]} · ترتيب عشوائي: ${x.shuffleQuestions ? 'نعم' : 'لا'}'),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('تعديل'),
                              onPressed: () => editExam(context, x),
                            ),
                            FilterChip(
                              label: Text(x.published ? 'منشور' : 'مسودة'),
                              selected: x.published,
                              onSelected: (v) {
                                if (v && questions.isEmpty) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('أضف أسئلة قبل النشر')));
                                  return;
                                }
                                _run(() => Services.exams.setPublished(x.id, v));
                              },
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.bar_chart),
                              label: const Text('النتائج'),
                              onPressed: () => context.push('/admin/exams/${x.id}/results'),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (await confirm(context, 'حذف الامتحان وأسئلته؟ (غير ممكن بعد بدء الطلاب)') && mounted) {
                                  await _run(() => Services.exams.deleteExam(x.id));
                                  if (mounted) context.pop();
                                }
                              },
                              child: const Text('حذف'),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Text('الأسئلة (${questions.length})', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('سؤال'),
                        onPressed: () => _editQuestion(questions, keys),
                      ),
                    ]),
                    if (ks.hasError)
                      const Padding(padding: EdgeInsets.all(8), child: Text('تعذّر تحميل الإجابات الصحيحة')),
                    for (final q in questions)
                      Card(
                        child: ListTile(
                          title: Text('${q.order}. ${q.prompt}'),
                          subtitle: Text([
                            q.isMcq ? 'اختيار من متعدد' : 'صح/خطأ',
                            '${q.points} درجة',
                            _answerText(q, keys[q.id]),
                          ].where((e) => e.isNotEmpty).join(' · ')),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit), onPressed: () => _editQuestion(questions, keys, q)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (await confirm(context, 'حذف السؤال؟') && mounted) {
                                  await _run(() => Services.exams.deleteQuestion(widget.examId, q.id), reload: true);
                                }
                              },
                            ),
                          ]),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
