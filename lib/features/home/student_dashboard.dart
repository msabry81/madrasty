import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;

import '../../core/brand_config.dart';
import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../shared/design.dart';
import '../../shared/ui.dart';
import '../comms/comms_models.dart';
import '../courses/models.dart';
import '../courses/outline.dart';
import '../exams/exam_models.dart';
import '../sessions/session_models.dart';

class StudentHomePage extends StatelessWidget {
  const StudentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return StreamBuilder<List<Enrollment>>(
      stream: Services.courses.watchMyEnrollments(uid),
      builder: (context, es) {
        if (!es.hasData) return const Center(child: CircularProgressIndicator());
        final enrollments = es.data!;
        final ids = enrollments.map((e) => e.courseId).toList();
        return StreamBuilder<List<LiveSession>>(
          stream: Services.sessions.watchSessionsOf(ids),
          builder: (context, ss) => StreamBuilder<List<Exam>>(
            stream: Services.exams.watchExamsOf(ids),
            builder: (context, xs) => _Dashboard(
              uid: uid,
              enrollments: enrollments,
              sessions: ss.data ?? const <LiveSession>[],
              exams: xs.data ?? const <Exam>[],
            ),
          ),
        );
      },
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.uid, required this.enrollments, required this.sessions, required this.exams});
  final String uid;
  final List<Enrollment> enrollments;
  final List<LiveSession> sessions;
  final List<Exam> exams;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final live = sessions.where((s) => !s.isCancelled && s.endsAt.isAfter(now)).toList();
    final next = live.isEmpty ? null : live.first;
    final cNow = CairoTime.toCairo(now);
    final today = live.where((s) {
      final c = CairoTime.toCairo(s.startsAt);
      return c.year == cNow.year && c.month == cNow.month && c.day == cNow.day;
    }).length;
    final openExams = exams.where((x) => x.phase(now) == 'متاح').length;
    final ids = enrollments.map((e) => e.courseId).toList();
    final wide = isWide(context, 1000);

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('كورساتي الحالية ونسبة التقدم', icon: Icons.auto_stories_outlined,
          trailing: TextButton(onPressed: () => context.go('/courses'), child: const Text('تصفّح الدورات'))),
      const SizedBox(height: 12),
      if (enrollments.isEmpty)
        AppCard(
          child: Column(children: [
            const Text('لست مشتركًا في أي دورة بعد.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/courses'), child: const Text('استعرض الدورات المتاحة')),
          ]),
        ),
      for (final e in enrollments) ...[_CourseCard(uid: uid, enrollment: e), const SizedBox(height: 16)],
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _AnnouncementsCard(courseIds: ids),
      const SizedBox(height: 16),
      _AttendanceCard(uid: uid),
    ]);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: EdgeInsets.all(wide ? 24 : 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Hero(courses: enrollments.length, today: today, exams: openExams),
              const SizedBox(height: 24),
              _NextSession(session: next),
              const SizedBox(height: 24),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 8, child: main),
                  const SizedBox(width: 24),
                  Expanded(flex: 4, child: side),
                ])
              else ...[main, const SizedBox(height: 8), side],
              const SizedBox(height: 24),
              _ResultsCard(key: ValueKey(exams.map((e) => e.id).join(',')), exams: exams),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.courses, required this.today, required this.exams});
  final int courses, today, exams;

  @override
  Widget build(BuildContext context) {
    final first = (Services.session.user?.displayName ?? '').trim().split(' ').first;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(999)),
        child: const Text('لوحة الطالب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
      const SizedBox(height: 8),
      Text('أهلًا بك${first.isEmpty ? '' : ' يا $first'}، جاهز لمتابعة دروسك اليوم؟',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 26)),
      const SizedBox(height: 4),
      const Text('تابع حصصك المباشرة وامتحاناتك وتقدّمك في دوراتك من مكان واحد.', style: TextStyle(color: AppColors.onVariant)),
    ]);
    final counters = Row(mainAxisSize: MainAxisSize.min, children: [
      _Counter('$courses', 'كورسات نشطة', AppColors.primary),
      const SizedBox(width: 8),
      _Counter('$today', 'حصة اليوم', const Color(0xFF734D00)),
      const SizedBox(width: 8),
      _Counter('$exams', 'اختبار متاح', const Color(0xFF4B607B)),
    ]);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFFF6F3EC), Color(0xFFFBEBD6)]),
        border: Border.all(color: AppColors.border),
      ),
      child: isWide(context, 900)
          ? Row(children: [Expanded(child: text), const SizedBox(width: 24), counters])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 16), counters]),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.value, this.label, this.color);
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: kCardShadow),
        child: Column(children: [
          Text(value, style: TextStyle(fontFamily: kHeadFont, fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.onVariant)),
        ]),
      );
}

class _NextSession extends StatelessWidget {
  const _NextSession({required this.session});
  final LiveSession? session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.navyDeep, borderRadius: BorderRadius.circular(20), boxShadow: kCardShadow),
      child: s == null
          ? Row(children: [
              const Icon(Icons.sensors, color: Color(0xFFFFBA47)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('لا توجد حصص مباشرة قادمة حاليًا. سيظهر موعد الحصة القادمة هنا.',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
              TextButton(
                onPressed: () => context.go('/sessions'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('كل الحصص'),
              ),
            ])
          : LayoutBuilder(builder: (context, c) {
              final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Chip(untilText(s.startsAt), const Color(0xFF734D00), Colors.white, Icons.timelapse),
                  const _Chip('Google Meet', Color(0x26FFFFFF), Color(0xFF98F3E5), Icons.videocam_outlined),
                ]),
                const SizedBox(height: 12),
                Text(s.title, style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w700, fontSize: 22, color: Colors.white, height: 1.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _Meta(Icons.person_outline, 'المحاضر: ${BrandConfig.teacherName}'),
                  _Meta(Icons.menu_book_outlined, s.courseTitle),
                  _Meta(Icons.schedule, '${CairoTime.format(s.startsAt)} (بتوقيت القاهرة)'),
                ]),
              ]);
              final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton.icon(
                  onPressed: () => web.window.open(s.meetUrl, '_blank'),
                  icon: const Icon(Icons.video_call),
                  label: const Text('انضمام للحصة الآن (Google Meet)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.go('/sessions'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x40FFFFFF))),
                  child: const Text('كل الحصص'),
                ),
              ]);
              return c.maxWidth > 800
                  ? Row(children: [Expanded(child: info), const SizedBox(width: 24), SizedBox(width: 300, child: actions)])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 16), actions]);
            }),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.bg, this.fg, this.icon);
  final String text;
  final Color bg, fg;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ]),
      );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: const Color(0xFFFFBA47)),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: const TextStyle(color: Color(0xFFE5E2DB)))),
      ]);
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.uid, required this.enrollment});
  final String uid;
  final Enrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final id = enrollment.courseId;
    return StreamBuilder<Course?>(
      stream: Services.courses.watchCourse(id),
      builder: (context, cs) => StreamBuilder<List<Unit>>(
        stream: Services.courses.watchUnits(id),
        builder: (context, us) => StreamBuilder<List<Lesson>>(
          stream: Services.courses.watchLessons(id),
          builder: (context, ls) => StreamBuilder<Set<String>>(
            stream: Services.courses.watchProgress(uid, id),
            builder: (context, ps) {
              final c = cs.data;
              final ordered = orderLessons(us.data ?? const <Unit>[], ls.data ?? const <Lesson>[]);
              final done = (ps.data ?? const <String>{}).where((l) => ordered.any((o) => o.id == l)).length;
              final pct = ordered.isEmpty ? 0.0 : done / ordered.length;
              final nextIdx = ordered.indexWhere((l) => !(ps.data ?? const <String>{}).contains(l.id));
              final next = nextIdx < 0 ? null : ordered[nextIdx];
              final meta = [c?.gradeLabel ?? '', c?.subjectLabel ?? ''].where((e) => e.isNotEmpty).join(' • ');
              return AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (meta.isNotEmpty)
                          Text(meta, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        Text(c?.title ?? '...', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    const StatusBadge('مقبول ونشط', BadgeKind.success, icon: Icons.check_circle_outline),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.timelapse, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('معدل الإنجاز العام', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onVariant)),
                    const Spacer(),
                    Text('${(pct * 100).round()}%',
                        style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 8),
                  AppProgressBar(pct),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(ordered.isEmpty ? 'لم تُضف دروس بعد' : 'تم إكمال $done من أصل ${ordered.length} درس',
                        style: const TextStyle(fontSize: 12, color: AppColors.onVariant)),
                    const Spacer(),
                    if (ordered.isNotEmpty && ordered.length - done > 0)
                      Text('متبقي ${ordered.length - done} دروس',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF734D00))),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_circle_outline, size: 18, color: AppColors.outline),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Text(next == null ? (ordered.isEmpty ? '' : 'أتممت كل الدروس') : 'الدرس القادم: ${next.title}',
                            style: const TextStyle(fontSize: 12, color: AppColors.onVariant)),
                      ),
                    ]),
                    FilledButton.icon(
                      onPressed: () => context.go(next != null ? '/courses/$id/lessons/${next.id}' : '/courses/$id'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: Text(next != null ? 'متابعة التعلم من درس ${nextIdx + 1}' : 'عرض الدورة'),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text('ينتهي الاشتراك: ${fmtDate(enrollment.endAt)}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard({required this.courseIds});
  final List<String> courseIds;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('إعلانات وتنبيهات المدرس', icon: Icons.campaign_outlined,
            trailing: TextButton(onPressed: () => context.go('/announcements'), child: const Text('عرض الكل'))),
        const SizedBox(height: 8),
        StreamBuilder<List<Announcement>>(
          stream: Services.comms.watchAnnouncementsFor(courseIds),
          builder: (context, snap) {
            final list = (snap.data ?? const <Announcement>[]).where((a) => !a.isExpired).take(2).toList();
            if (list.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد إعلانات جديدة'));
            return Column(children: [
              for (final a in list)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceLow, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(a.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(fmtDate(a.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: StreamBuilder<List<AttendanceRecord>>(
        stream: Services.sessions.watchMyAttendance(uid),
        builder: (context, snap) {
          final list = snap.data ?? const <AttendanceRecord>[];
          int n(String s) => list.where((r) => r.status == s).length;
          final rate = list.isEmpty ? 0.0 : (n('present') + n('late')) / list.length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('التزامك بالحضور', trailing: TextButton(onPressed: () => context.go('/attendance'), child: const Text('التفاصيل'))),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: rate,
                      strokeWidth: 9,
                      backgroundColor: AppColors.surfaceMid,
                      color: AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text('${(rate * 100).round()}%',
                      style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navy)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  list.isEmpty
                      ? 'لا توجد سجلات حضور بعد.'
                      : 'حاضر: ${n('present')} · متأخر: ${n('late')} · غائب: ${n('absent')}',
                  style: const TextStyle(color: AppColors.onVariant),
                ),
              ),
            ]),
          ]);
        },
      ),
    );
  }
}

class _ResultLine {
  const _ResultLine(this.exam, this.row);
  final Exam exam;
  final ResultRow row;
}

class _ResultsCard extends StatefulWidget {
  const _ResultsCard({super.key, required this.exams});
  final List<Exam> exams;
  @override
  State<_ResultsCard> createState() => _ResultsCardState();
}

class _ResultsCardState extends State<_ResultsCard> {
  late final Future<List<_ResultLine>> _future = _load();

  Future<List<_ResultLine>> _load() async {
    final out = <_ResultLine>[];
    for (final x in widget.exams) {
      try {
        for (final r in await Services.exams.myResults(x.id)) {
          if (r.released && r.score != null) out.add(_ResultLine(x, r));
        }
      } catch (_) {/* تجاهل */}
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('نتائج آخر الاختبارات', icon: Icons.verified_outlined,
            trailing: TextButton(onPressed: () => context.go('/exams'), child: const Text('كل الامتحانات'))),
        const SizedBox(height: 12),
        FutureBuilder<List<_ResultLine>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            final lines = snap.data ?? const <_ResultLine>[];
            if (lines.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد نتائج ظاهرة بعد.'));
            return Column(children: [
              for (final l in lines)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.sand))),
                  child: Row(children: [
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.exam.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        Text('${l.exam.courseTitle} · المحاولة ${l.row.attemptNo}', style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                      ]),
                    ),
                    Text('${l.row.score} / ${l.row.totalScore}',
                        style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                    const SizedBox(width: 12),
                    Builder(builder: (_) {
                      final total = (l.row.totalScore ?? 0).toDouble();
                      final (label, kind) = gradeLabel(total == 0 ? 0 : (l.row.score ?? 0) / total);
                      return StatusBadge(label, kind);
                    }),
                    if (l.exam.phase() == 'مغلق')
                      TextButton(
                        onPressed: () => context.push('/exams/${l.exam.id}/review/${l.row.attemptId}'),
                        child: const Text('مراجعة'),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
