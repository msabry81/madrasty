import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import 'exam_models.dart';

/// مراجعة الإجابات الصحيحة (متاحة بعد إغلاق الامتحان فقط، والخادم هو من يقرر).
class ExamReviewPage extends StatelessWidget {
  const ExamReviewPage({super.key, required this.attemptId});
  final String attemptId;

  String _fmt(ExamQuestion q, Object? v) {
    if (v == null) return 'بدون إجابة';
    if (q.isMcq) return v is int && v >= 0 && v < q.options.length ? q.options[v] : 'بدون إجابة';
    return v == true ? 'صح' : 'خطأ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة المحاولة')),
      body: FutureBuilder<List<ReviewItem>>(
        future: Services.exams.review(attemptId),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(friendlyError(snap.error!))));
          }
          final items = snap.data!;
          return Centered(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (var i = 0; i < items.length; i++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1}. ${items[i].question.prompt}', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('إجابتك: ${_fmt(items[i].question, items[i].myAnswer)}'),
                      Text('الإجابة الصحيحة: ${_fmt(items[i].question, items[i].correct)}'),
                      if (items[i].explanation.isNotEmpty) Text('الشرح: ${items[i].explanation}'),
                    ]),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}
