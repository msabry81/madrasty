import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../shared/design.dart';
import '../../shared/ui.dart';
import '../../shared/youtube_embed.dart';
import 'models.dart';
import 'outline.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key, required this.courseId, required this.lessonId});
  final String courseId, lessonId;
  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late final Future<bool> _access = _computeAccess();
  bool _busy = false;

  Future<bool> _computeAccess() async {
    final s = Services.session;
    final uid = s.user?.uid;
    if (uid == null) return false;
    if (s.isAdmin) return true;
    try {
      final e = await Services.courses.getMyEnrollment(uid, widget.courseId);
      return e?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _complete(Lesson cur, Lesson? next) async {
    final uid = Services.session.user!.uid;
    setState(() => _busy = true);
    try {
      await Services.courses.markLessonComplete(uid, widget.courseId, cur.id);
      if (!mounted) return;
      context.go(next != null ? '/courses/${widget.courseId}/lessons/${next.id}' : '/courses/${widget.courseId}');
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أحسنت! أتممت كل دروس الدورة')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _access,
      builder: (context, a) {
        if (!a.hasData) return const Center(child: CircularProgressIndicator());
        final access = a.data!;
        final canTrack = access && !Services.session.isAdmin;
        final uid = Services.session.user!.uid;
        return StreamBuilder<Course?>(
          stream: Services.courses.watchCourse(widget.courseId),
          builder: (context, cs) => StreamBuilder<List<Unit>>(
            stream: Services.courses.watchUnits(widget.courseId),
            builder: (context, us) => StreamBuilder<List<Lesson>>(
              stream: Services.courses.watchLessons(widget.courseId, previewOnly: !access),
              builder: (context, ls) => StreamBuilder<Set<String>>(
                stream: canTrack ? Services.courses.watchProgress(uid, widget.courseId) : Stream.value(const <String>{}),
                builder: (context, ps) {
                  if (ls.hasError) return const Center(child: Text('ليست لديك صلاحية لمشاهدة هذا الدرس'));
                  if (!us.hasData || !ls.hasData) return const Center(child: CircularProgressIndicator());
                  return _view(cs.data, us.data!, ls.data!, ps.data ?? const <String>{}, canTrack);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _view(Course? course, List<Unit> units, List<Lesson> lessons, Set<String> done, bool canTrack) {
    final ordered = orderLessons(units, lessons);
    final idx = ordered.indexWhere((l) => l.id == widget.lessonId);
    if (idx < 0) return const Center(child: Text('ليست لديك صلاحية لمشاهدة هذا الدرس'));
    final cur = ordered[idx];
    final prev = idx > 0 ? ordered[idx - 1] : null;
    final next = idx < ordered.length - 1 ? ordered[idx + 1] : null;
    final unit = units.where((u) => u.id == cur.unitId).firstOrNull;
    final doneCount = ordered.where((l) => done.contains(l.id)).length;
    final pct = ordered.isEmpty ? 0.0 : doneCount / ordered.length;
    final isDone = done.contains(cur.id);
    final wide = isWide(context, 1000);
    String lessonUrl(Lesson l) => '/courses/${widget.courseId}/lessons/${l.id}';

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
        InkWell(onTap: () => context.go('/courses'), child: const Text('الدورات', style: TextStyle(color: AppColors.onVariant))),
        const Icon(Icons.chevron_left, size: 16, color: AppColors.outline),
        InkWell(
          onTap: () => context.go('/courses/${widget.courseId}'),
          child: Text(course?.title ?? '...', style: const TextStyle(color: AppColors.onVariant)),
        ),
        if (unit != null) ...[
          const Icon(Icons.chevron_left, size: 16, color: AppColors.outline),
          Text(unit.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: YoutubeEmbed(videoId: cur.youtubeVideoId)),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        if (cur.isPreview) const StatusBadge('درس معاينة', BadgeKind.info),
        const StatusBadge('حصة مسجلة', BadgeKind.success, icon: Icons.play_circle_outline),
        if (isDone) const StatusBadge('مكتمل', BadgeKind.success, icon: Icons.check_circle_outline),
      ]),
      const SizedBox(height: 8),
      Text(cur.title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
      const SizedBox(height: 16),
      AppCard(
        child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [
          OutlinedButton.icon(
            onPressed: prev == null ? null : () => context.go(lessonUrl(prev)),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('الدرس السابق'),
          ),
          if (canTrack)
            FilledButton.icon(
              onPressed: _busy ? null : () => _complete(cur, next),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(next == null ? 'تم إكمال الدرس' : 'تم إكمال الدرس والانتقال للتالي'),
            )
          else
            FilledButton.icon(
              onPressed: next == null ? null : () => context.go(lessonUrl(next)),
              icon: const Icon(Icons.arrow_back),
              label: const Text('الدرس التالي'),
            ),
        ]),
      ),
    ]);

    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (canTrack) ...[
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(child: Text('معدل إنجاز المنهج', style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${(pct * 100).round()}%', style: const TextStyle(fontFamily: kHeadFont, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            AppProgressBar(pct, height: 10),
            const SizedBox(height: 6),
            Text('تم إتمام $doneCount من أصل ${ordered.length} درس', style: const TextStyle(fontSize: 12, color: AppColors.onVariant)),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SectionTitle('فهرس الدروس', icon: Icons.menu_book_outlined),
          ),
          for (final u in units)
            ExpansionTile(
              key: PageStorageKey('unit-${u.id}'),
              initiallyExpanded: u.id == cur.unitId,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(u.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy)),
              children: [
                for (final l in ordered.where((l) => l.unitId == u.id))
                  ListTile(
                    dense: true,
                    selected: l.id == cur.id,
                    selectedTileColor: AppColors.primaryTint,
                    leading: Icon(
                      done.contains(l.id)
                          ? Icons.check_circle
                          : (l.id == cur.id ? Icons.play_circle : Icons.radio_button_unchecked),
                      color: done.contains(l.id) || l.id == cur.id ? AppColors.primary : AppColors.outline,
                    ),
                    title: Text(l.title, style: TextStyle(fontWeight: l.id == cur.id ? FontWeight.w800 : FontWeight.w500)),
                    onTap: () => context.go(lessonUrl(l)),
                  ),
              ],
            ),
        ]),
      ),
    ]);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: EdgeInsets.all(wide ? 24 : 16),
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 8, child: main),
                    const SizedBox(width: 24),
                    SizedBox(width: 360, child: side),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, const SizedBox(height: 16), side]),
          ),
        ),
      ),
    );
  }
}
