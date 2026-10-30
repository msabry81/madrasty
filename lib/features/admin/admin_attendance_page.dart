import 'package:flutter/material.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import '../payments/payment_models.dart';
import '../sessions/session_models.dart';

class AdminAttendancePage extends StatelessWidget {
  const AdminAttendancePage({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveSession?>(
      stream: Services.sessions.watchSession(sessionId),
      builder: (context, ss) {
        final s = ss.data;
        if (s == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('حضور الحصة')),
          body: StreamBuilder<List<Enrollment>>(
            stream: Services.sessions.watchActiveEnrollmentsOfCourse(s.courseId),
            builder: (context, es) => StreamBuilder<List<UserDoc>>(
              stream: Services.admin.watchUsers(),
              builder: (context, us) => StreamBuilder<List<AttendanceRecord>>(
                stream: Services.sessions.watchSessionAttendance(sessionId),
                builder: (context, as) {
                  if (!es.hasData || !us.hasData || !as.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return _Body(session: s, enrollments: es.data!, users: us.data!, records: as.data!);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.session, required this.enrollments, required this.users, required this.records});
  final LiveSession session;
  final List<Enrollment> enrollments;
  final List<UserDoc> users;
  final List<AttendanceRecord> records;

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final u in users) u.uid: u};
    final marks = {for (final r in records) r.studentId: r.status};
    final adminUid = Services.session.user!.uid;
    final students = enrollments.map((e) => e.studentId).toSet().toList()
      ..sort((a, b) => (byId[a]?.name ?? a).compareTo(byId[b]?.name ?? b));
    int n(String st) => marks.values.where((v) => v == st).length;
    final unmarked = students.where((id) => !marks.containsKey(id)).toList();

    return Centered(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.title, style: Theme.of(context).textTheme.titleLarge),
              Text('${session.courseTitle} · ${CairoTime.format(session.startsAt)}'),
              const SizedBox(height: 8),
              Text('حاضر: ${n('present')} · متأخر: ${n('late')} · غائب: ${n('absent')} · لم يُسجَّل: ${unmarked.length}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.done_all),
                label: const Text('تسجيل غير المسجَّلين كحاضرين'),
                onPressed: unmarked.isEmpty
                    ? null
                    : () => _run(context, () => Services.sessions.markMany(session, unmarked, 'present', adminUid)),
              ),
            ]),
          ),
        ),
        if (students.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد طلاب مشتركون نشطون في هذه الدورة')),
        for (final id in students)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text(byId[id]?.name.isNotEmpty == true ? byId[id]!.name : (byId[id]?.email ?? id)),
                  SegmentedButton<String>(
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    segments: [
                      for (final e in attendanceLabels.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: marks.containsKey(id) ? {marks[id]!} : <String>{},
                    onSelectionChanged: (sel) => _run(
                      context,
                      () => sel.isEmpty
                          ? Services.sessions.clearMark(session.id, id)
                          : Services.sessions.mark(session, id, sel.first, adminUid),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
