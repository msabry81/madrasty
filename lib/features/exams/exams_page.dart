import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import 'exam_models.dart';

class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الامتحانات')),
      body: StreamBuilder<List<Enrollment>>(
        stream: Services.courses.watchMyEnrollments(uid),
        builder: (context, es) {
          if (!es.hasData) return const Center(child: CircularProgressIndicator());
          return StreamBuilder<List<Exam>>(
            stream: Services.exams.watchExamsOf(es.data!.map((e) => e.courseId).toList()),
            builder: (context, xs) {
              if (xs.hasError) return const Center(child: Text('تعذّر تحميل الامتحانات'));
              if (!xs.hasData) return const Center(child: CircularProgressIndicator());
              if (xs.data!.isEmpty) return const Center(child: Text('لا توجد امتحانات متاحة'));
              return Centered(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  for (final x in xs.data!) _ExamCard(exam: x, uid: uid),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExamCard extends StatefulWidget {
  const _ExamCard({required this.exam, required this.uid});
  final Exam exam;
  final String uid;
  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  late Future<List<ResultRow>> _results = Services.exams.myResults(widget.exam.id);

  Future<void> _open() async {
    await context.push('/exams/${widget.exam.id}');
    if (mounted) setState(() => _results = Services.exams.myResults(widget.exam.id));
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.exam;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(x.title, style: Theme.of(context).textTheme.titleMedium)),
            Chip(label: Text(x.phase())),
          ]),
          Text(x.courseTitle),
          const SizedBox(height: 4),
          Text('من ${CairoTime.format(x.opensAt)}\nإلى ${CairoTime.format(x.closesAt)}'),
          Text('المدة: ${x.durationMinutes} دقيقة · الدرجة: ${x.totalScore} · المحاولات: ${x.attemptsAllowed}'),
          const SizedBox(height: 8),
          StreamBuilder<List<AttemptRow>>(
            stream: Services.exams.watchMyAttempts(widget.uid, x.id),
            builder: (context, as) {
              final attempts = as.data ?? const <AttemptRow>[];
              return FutureBuilder<List<ResultRow>>(
                future: _results,
                builder: (context, rs) {
                  final rows = rs.data ?? const <ResultRow>[];
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('المحاولات المستخدمة: ${attempts.length} من ${x.attemptsAllowed}'),
                    for (final r in rows)
                      Row(children: [
                        Expanded(
                          child: Text(r.released
                              ? 'المحاولة ${r.attemptNo}: ${r.score} / ${r.totalScore}'
                              : 'المحاولة ${r.attemptNo}: تظهر النتيجة بعد إغلاق الامتحان'),
                        ),
                        // الخادم يسمح بالمراجعة بعد إغلاق الامتحان فقط
                        if (x.phase() == 'مغلق')
                          TextButton(
                            onPressed: () => context.push('/exams/${x.id}/review/${r.attemptId}'),
                            child: const Text('مراجعة'),
                          ),
                      ]),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _open,
                      child: Text(attempts.any((a) => a.inProgress) ? 'متابعة المحاولة' : 'فتح الامتحان'),
                    ),
                  ]);
                },
              );
            },
          ),
        ]),
      ),
    );
  }
}
