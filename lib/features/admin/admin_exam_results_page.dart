import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../exams/exam_models.dart';

class AdminExamResultsPage extends StatelessWidget {
  const AdminExamResultsPage({super.key, required this.examId});
  final String examId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نتائج الامتحان')),
      body: StreamBuilder<List<ResultDoc>>(
        stream: Services.exams.watchResults(examId),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('تعذّر تحميل النتائج'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('لا توجد نتائج بعد'));
          final scores = list.map((r) => r.score.toDouble()).toList();
          final avg = scores.reduce((a, b) => a + b) / scores.length;
          final max = scores.reduce((a, b) => a > b ? a : b);
          return Centered(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('عدد المحاولات: ${list.length} · المتوسط: ${avg.toStringAsFixed(1)} · الأعلى: $max'
                      ' (من ${list.first.totalScore})'),
                ),
              ),
              for (final r in list)
                Card(
                  child: ListTile(
                    title: Text(r.studentName.isEmpty ? '—' : r.studentName),
                    subtitle: Text('المحاولة ${r.attemptNo} · ${fmtDate(r.submittedAt)}'
                        '${r.status == 'auto_submitted' ? ' · تسليم تلقائي' : ''}'),
                    trailing: Text('${r.score} / ${r.totalScore}', style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
