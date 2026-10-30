import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import 'session_models.dart';

/// الحصص المباشرة لدورات الطالب النشطة.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('الحصص المباشرة')),
      body: StreamBuilder<List<Enrollment>>(
        stream: Services.courses.watchMyEnrollments(uid),
        builder: (context, es) {
          if (!es.hasData) return const Center(child: CircularProgressIndicator());
          final ids = es.data!.map((e) => e.courseId).toList();
          return StreamBuilder<List<LiveSession>>(
            stream: Services.sessions.watchSessionsOf(ids),
            builder: (context, ss) {
              if (ss.hasError) return const Center(child: Text('تعذّر تحميل الحصص'));
              if (!ss.hasData) return const Center(child: CircularProgressIndicator());
              final now = DateTime.now();
              final all = ss.data!;
              final upcoming = all.where((s) => s.endsAt.isAfter(now)).toList();
              final past = all.where((s) => !s.endsAt.isAfter(now)).toList().reversed.toList();
              if (all.isEmpty) return const Center(child: Text('لا توجد حصص مجدولة'));
              return Centered(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (upcoming.isNotEmpty) Text('القادمة', style: Theme.of(context).textTheme.titleMedium),
                  for (final s in upcoming) _SessionCard(s, joinable: true),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('السابقة', style: Theme.of(context).textTheme.titleMedium),
                    for (final s in past) _SessionCard(s, joinable: false),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.s, {required this.joinable});
  final LiveSession s;
  final bool joinable;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(s.title),
        subtitle: Text('${s.courseTitle}\n${CairoTime.format(s.startsAt)} · ${s.durationMinutes} دقيقة (بتوقيت القاهرة)'),
        isThreeLine: true,
        trailing: s.isCancelled
            ? const Chip(label: Text('ملغاة'))
            : joinable
                ? FilledButton(
                    onPressed: () => web.window.open(s.meetUrl, '_blank'),
                    child: Text(s.phase() == 'جارية الآن' ? 'انضم الآن' : 'رابط الحصة'),
                  )
                : null,
      ),
    );
  }
}
