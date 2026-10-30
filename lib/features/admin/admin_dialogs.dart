import 'package:flutter/material.dart';

import '../../core/digits.dart';
import '../../core/validators.dart';
import '../../shared/youtube.dart';
import '../courses/models.dart';

class CourseDialog extends StatefulWidget {
  const CourseDialog({super.key, this.course});
  final Course? course;

  static Future<Course?> show(BuildContext context, {Course? course}) =>
      showDialog<Course>(context: context, builder: (_) => CourseDialog(course: course));

  @override
  State<CourseDialog> createState() => _CourseDialogState();
}

class _CourseDialogState extends State<CourseDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.course?.title);
  late final _desc = TextEditingController(text: widget.course?.description);
  late final _grade = TextEditingController(text: widget.course?.gradeLabel);
  late final _subject = TextEditingController(text: widget.course?.subjectLabel);
  late final _price = TextEditingController(text: '${widget.course?.price ?? 0}');
  late final _days = TextEditingController(text: '${widget.course?.accessDays ?? 90}');
  late bool _published = widget.course?.isPublished ?? false;

  @override
  void dispose() {
    for (final c in [_title, _desc, _grade, _subject, _price, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Course(
        id: widget.course?.id ?? '',
        title: _title.text.trim(),
        description: _desc.text.trim(),
        gradeLabel: _grade.text.trim(),
        subjectLabel: _subject.text.trim(),
        price: parseNum(_price.text)!,
        accessDays: parseNum(_days.text)!.toInt(),
        status: _published ? 'published' : 'draft',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.course == null ? 'دورة جديدة' : 'تعديل الدورة'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'عنوان الدورة'),
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'الوصف'),
                ),
                const SizedBox(height: 8),
                TextFormField(controller: _grade, decoration: const InputDecoration(labelText: 'الصف / المرحلة')),
                const SizedBox(height: 8),
                TextFormField(controller: _subject, decoration: const InputDecoration(labelText: 'المادة')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر بالجنيه (0 = مجانية)'),
                  validator: (v) {
                    final n = parseNum(v ?? '');
                    return (n == null || n < 0) ? 'أدخل رقمًا صحيحًا' : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مدة الإتاحة (أيام)'),
                  validator: (v) {
                    final n = parseNum(v ?? '');
                    return (n == null || n < 1 || n % 1 != 0) ? 'أدخل عددًا صحيحًا ≥ 1' : null;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('منشورة'),
                  value: _published,
                  onChanged: (v) => setState(() => _published = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}

class UnitDialog extends StatefulWidget {
  const UnitDialog({super.key, this.unit, required this.nextOrder});
  final Unit? unit;
  final int nextOrder;

  static Future<Unit?> show(BuildContext context, {Unit? unit, required int nextOrder}) =>
      showDialog<Unit>(context: context, builder: (_) => UnitDialog(unit: unit, nextOrder: nextOrder));

  @override
  State<UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<UnitDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.unit?.title);
  late final _order = TextEditingController(text: '${widget.unit?.order ?? widget.nextOrder}');

  @override
  void dispose() {
    _title.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.unit == null ? 'وحدة جديدة' : 'تعديل الوحدة'),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'عنوان الوحدة'),
            validator: (v) => Validators.required(v),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'الترتيب'),
            validator: (v) => parseNum(v ?? '') == null ? 'رقم غير صالح' : null,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context,
                Unit(id: widget.unit?.id ?? '', title: _title.text.trim(), order: parseNum(_order.text)!.toInt()));
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class LessonDialog extends StatefulWidget {
  const LessonDialog({super.key, this.lesson, required this.unitId, required this.nextOrder});
  final Lesson? lesson;
  final String unitId;
  final int nextOrder;

  static Future<Lesson?> show(BuildContext context,
          {Lesson? lesson, required String unitId, required int nextOrder}) =>
      showDialog<Lesson>(
          context: context,
          builder: (_) => LessonDialog(lesson: lesson, unitId: unitId, nextOrder: nextOrder));

  @override
  State<LessonDialog> createState() => _LessonDialogState();
}

class _LessonDialogState extends State<LessonDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.lesson?.title);
  late final _url = TextEditingController(text: widget.lesson?.youtubeVideoId);
  late final _order = TextEditingController(text: '${widget.lesson?.order ?? widget.nextOrder}');
  late bool _preview = widget.lesson?.isPreview ?? false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.lesson == null ? 'درس جديد' : 'تعديل الدرس'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان الدرس'),
                validator: (v) => Validators.required(v),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _url,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'رابط YouTube (أو معرّف الفيديو)'),
                validator: (v) => parseYoutubeId(v ?? '') == null ? 'رابط YouTube غير صالح' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب'),
                validator: (v) => parseNum(v ?? '') == null ? 'رقم غير صالح' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('درس معاينة (متاح لأي مسجّل دخول)'),
                value: _preview,
                onChanged: (v) => setState(() => _preview = v),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              Lesson(
                id: widget.lesson?.id ?? '',
                unitId: widget.unitId,
                title: _title.text.trim(),
                youtubeVideoId: parseYoutubeId(_url.text)!,
                order: parseNum(_order.text)!.toInt(),
                isPreview: _preview,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
