import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/digits.dart';
import '../../core/services.dart';
import '../../core/validators.dart';
import '../../shared/ui.dart';
import '../courses/models.dart';
import '../sessions/session_models.dart';

class AdminSessionsPage extends StatefulWidget {
  const AdminSessionsPage({super.key});
  @override
  State<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends State<AdminSessionsPage> {
  String _filter = 'upcoming';

  Future<void> _edit([LiveSession? s]) async {
    final courses = await Services.courses.watchAll().first;
    if (!mounted) return;
    if (courses.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أنشئ دورة أولًا')));
      return;
    }
    final r = await showDialog<LiveSession>(
      context: context,
      builder: (_) => SessionDialog(courses: courses, session: s),
    );
    if (r == null || !mounted) return;
    try {
      await Services.sessions.save(r, Services.session.user!.uid);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحصص المباشرة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('حصة جديدة'),
      ),
      body: Centered(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final e in const {
                    'upcoming': 'القادمة',
                    'past': 'السابقة',
                    'all': 'الكل',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<LiveSession>>(
                stream: Services.sessions.watchAll(),
                builder: (context, snap) {
                  if (snap.hasError)
                    return const Center(child: Text('تعذّر تحميل الحصص'));
                  if (!snap.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final now = DateTime.now();
                  var list = snap.data!.where((s) {
                    final over = !s.endsAt.isAfter(now);
                    return _filter == 'all' ||
                        (_filter == 'past' ? over : !over);
                  }).toList();
                  if (_filter != 'upcoming') list = list.reversed.toList();
                  if (list.isEmpty)
                    return const Center(child: Text('لا توجد حصص'));
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return Card(
                        child: ListTile(
                          title: Text(s.title),
                          subtitle: Text(
                            '${s.courseTitle}\n${CairoTime.format(s.startsAt)} · ${s.durationMinutes} د',
                          ),
                          isThreeLine: true,
                          onTap: () => context.push('/admin/sessions/${s.id}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Chip(label: Text(s.phase())),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  switch (v) {
                                    case 'attendance':
                                      context.push('/admin/sessions/${s.id}');
                                    case 'edit':
                                      _edit(s);
                                    case 'cancel':
                                      _run(
                                        () => Services.sessions.setStatus(
                                          s.id,
                                          s.isCancelled
                                              ? 'scheduled'
                                              : 'cancelled',
                                        ),
                                      );
                                    case 'delete':
                                      if (await confirm(
                                        context,
                                        'حذف الحصة "${s.title}"؟',
                                      )) {
                                        _run(
                                          () => Services.sessions.delete(s.id),
                                        );
                                      }
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'attendance',
                                    child: Text('الحضور'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('تعديل'),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: Text(
                                      s.isCancelled ? 'استعادة' : 'إلغاء الحصة',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionDialog extends StatefulWidget {
  const SessionDialog({super.key, required this.courses, this.session});
  final List<Course> courses;
  final LiveSession? session;
  @override
  State<SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<SessionDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.session?.title);
  late final _url = TextEditingController(text: widget.session?.meetUrl);
  late final _dur = TextEditingController(
    text: '${widget.session?.durationMinutes ?? 60}',
  );
  Course? _course;
  DateTime? _date; // تاريخ بتوقيت القاهرة
  TimeOfDay? _time; // وقت بتوقيت القاهرة
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s != null) {
      _course = widget.courses.where((c) => c.id == s.courseId).firstOrNull;
      final c = CairoTime.toCairo(s.startsAt);
      _date = DateTime(c.year, c.month, c.day);
      _time = TimeOfDay(hour: c.hour, minute: c.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _dur.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_course == null || _date == null || _time == null) {
      setState(() => _error = 'اختر الدورة والتاريخ والوقت');
      return;
    }
    final startsAt = CairoTime.fromCairoWallClock(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    Navigator.pop(
      context,
      LiveSession(
        id: widget.session?.id ?? '',
        courseId: _course!.id,
        courseTitle: _course!.title,
        title: _title.text.trim(),
        startsAt: startsAt,
        durationMinutes: parseNum(_dur.text)!.toInt(),
        meetUrl: _url.text.trim(),
        status: widget.session?.status ?? 'scheduled',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.session == null ? 'حصة جديدة' : 'تعديل الحصة'),
      content: SizedBox(
        width: 420,
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
                  decoration: const InputDecoration(labelText: 'عنوان الحصة'),
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(_date == null ? 'التاريخ' : fmtDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(
                          _time == null ? 'الوقت' : _time!.format(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'التاريخ والوقت بتوقيت القاهرة',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dur,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المدة (دقيقة)'),
                  validator: (v) {
                    final n = parseNum(v ?? '');
                    return (n == null || n < 1 || n % 1 != 0)
                        ? 'أدخل عددًا صحيحًا'
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رابط Meet'),
                  validator: (v) {
                    final u = Uri.tryParse((v ?? '').trim());
                    return (u == null || u.scheme != 'https' || u.host.isEmpty)
                        ? 'رابط https غير صالح'
                        : null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
