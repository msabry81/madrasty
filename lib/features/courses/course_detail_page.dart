import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../shared/ui.dart';
import '../payments/payment_models.dart';
import 'models.dart';

class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({super.key, required this.courseId});
  final String courseId;
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late final Future<bool> _access;

  @override
  void initState() {
    super.initState();
    final s = Services.session;
    final uid = s.user?.uid;
    if (uid == null) {
      _access = Future.value(false);
    } else if (s.isAdmin) {
      _access = Future.value(true);
    } else {
      _access = Services.courses
          .getMyEnrollment(uid, widget.courseId)
          .then((e) => e?.isActive ?? false)
          .catchError((_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Course?>(
      stream: Services.courses.watchCourse(widget.courseId),
      builder: (context, snap) {
        if (snap.hasError || (snap.connectionState == ConnectionState.active && snap.data == null)) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('الدورة غير متاحة')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final course = snap.data!;
        return Scaffold(
          appBar: AppBar(title: Text(course.title)),
          body: FutureBuilder<bool>(
            future: _access,
            builder: (context, a) {
              if (!a.hasData) return const Center(child: CircularProgressIndicator());
              return Centered(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Header(course: course, hasAccess: a.data!),
                    const SizedBox(height: 16),
                    _Outline(courseId: course.id, fullAccess: a.data!),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.course, required this.hasAccess});
  final Course course;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    final meta = [course.gradeLabel, course.subjectLabel].where((e) => e.isNotEmpty).join(' · ');
    final loggedIn = Services.session.user != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.title, style: Theme.of(context).textTheme.headlineSmall),
            if (meta.isNotEmpty) Text(meta),
            if (course.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(course.description),
            ],
            const SizedBox(height: 8),
            Text('السعر: ${course.priceText} — مدة الإتاحة: ${course.accessDays} يومًا'),
            const SizedBox(height: 12),
            if (hasAccess)
              const Chip(label: Text('أنت مشترك في هذه الدورة'))
            else if (!loggedIn)
              FilledButton(onPressed: () => context.go('/login'), child: const Text('سجّل الدخول للاشتراك'))
            else
              _SubscribeButton(course: course),
          ],
        ),
      ),
    );
  }
}

class _Outline extends StatelessWidget {
  const _Outline({required this.courseId, required this.fullAccess});
  final String courseId;
  final bool fullAccess;

  @override
  Widget build(BuildContext context) {
    final loggedIn = Services.session.user != null;
    return StreamBuilder<List<Unit>>(
      stream: Services.courses.watchUnits(courseId),
      builder: (context, us) {
        if (!us.hasData) return const Center(child: CircularProgressIndicator());
        final units = us.data!;
        if (units.isEmpty) return const Text('لم تُضف وحدات بعد');

        Widget build(List<Lesson> lessons) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final u in units)
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(u.title),
                    children: [
                      for (final l in lessons.where((l) => l.unitId == u.id))
                        ListTile(
                          leading: const Icon(Icons.play_circle_outline),
                          title: Text(l.title),
                          trailing: l.isPreview && !fullAccess ? const Chip(label: Text('معاينة')) : null,
                          onTap: () => context.push('/courses/$courseId/lessons/${l.id}'),
                        ),
                    ],
                  ),
                ),
              if (!fullAccess)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    loggedIn
                        ? 'باقي الدروس تظهر بعد الاشتراك.'
                        : 'سجّل الدخول لمشاهدة دروس المعاينة.',
                  ),
                ),
            ],
          );
        }

        // غير المسجّل لا يقرأ أي دروس (القواعد تشترط تسجيل الدخول)
        if (!loggedIn) return build(const []);
        return StreamBuilder<List<Lesson>>(
          stream: Services.courses.watchLessons(courseId, previewOnly: !fullAccess),
          builder: (context, ls) {
            if (ls.hasError) return const Text('تعذّر تحميل الدروس');
            if (!ls.hasData) return const Center(child: CircularProgressIndicator());
            return build(ls.data!);
          },
        );
      },
    );
  }
}

class _SubscribeButton extends StatefulWidget {
  const _SubscribeButton({required this.course});
  final Course course;
  @override
  State<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends State<_SubscribeButton> {
  bool _busy = false;

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      final r = await Services.payments.requestEnrollment(widget.course.id);
      if (!mounted) return;
      if (r.status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاشتراك في الدورة')));
        context.go('/student');
      } else {
        context.push('/payments/${r.requestId}');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Services.session.user!.uid;
    return StreamBuilder<List<PaymentRequest>>(
      stream: Services.payments.watchMyRequests(uid),
      builder: (context, snap) {
        final open = (snap.data ?? const <PaymentRequest>[])
            .where((r) => r.courseId == widget.course.id && r.isOpen)
            .firstOrNull;
        if (open != null) {
          return FilledButton.tonal(
            onPressed: () => context.push('/payments/${open.id}'),
            child: const Text('لديك طلب اشتراك — متابعة'),
          );
        }
        return FilledButton(
          onPressed: _busy ? null : _go,
          child: Text(widget.course.isPaid ? 'طلب الاشتراك' : 'اشترك مجانًا'),
        );
      },
    );
  }
}
