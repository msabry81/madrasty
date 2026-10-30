import 'package:flutter/material.dart';

import '../../core/digits.dart';
import '../../core/validators.dart';
import '../exams/exam_models.dart';

class QuestionDialog extends StatefulWidget {
  const QuestionDialog({super.key, this.question, this.answerKey, required this.nextOrder});
  final ExamQuestion? question;
  final QuestionKey? answerKey;
  final int nextOrder;
  @override
  State<QuestionDialog> createState() => _QuestionDialogState();
}

class _QuestionDialogState extends State<QuestionDialog> {
  final _form = GlobalKey<FormState>();
  late String _type = widget.question?.type ?? 'mcq';
  late final _prompt = TextEditingController(text: widget.question?.prompt);
  late final _points = TextEditingController(text: '${widget.question?.points ?? 1}');
  late final _order = TextEditingController(text: '${widget.question?.order ?? widget.nextOrder}');
  late final _explain = TextEditingController(text: widget.answerKey?.explanation);
  late final List<TextEditingController> _opts;
  int _correctIdx = 0;
  bool _correctBool = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    final opts = (q != null && q.isMcq && q.options.isNotEmpty) ? q.options : ['', ''];
    _opts = [for (final o in opts) TextEditingController(text: o)];
    final c = widget.answerKey?.correct;
    if (c is num) _correctIdx = c.toInt().clamp(0, _opts.length - 1);
    if (c is bool) _correctBool = c;
  }

  @override
  void dispose() {
    for (final c in [_prompt, _points, _order, _explain, ..._opts]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final isMcq = _type == 'mcq';
    if (isMcq && _opts.any((o) => o.text.trim().isEmpty)) {
      setState(() => _error = 'املأ كل الخيارات أو احذف الفارغ منها');
      return;
    }
    Navigator.pop(
      context,
      QuestionDraft(
        id: widget.question?.id ?? '',
        type: _type,
        prompt: _prompt.text.trim(),
        options: isMcq ? _opts.map((o) => o.text.trim()).toList() : const [],
        points: parseNum(_points.text)!,
        order: parseNum(_order.text)!.toInt(),
        correct: isMcq ? _correctIdx : _correctBool,
        explanation: _explain.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMcq = _type == 'mcq';
    return AlertDialog(
      title: Text(widget.question == null ? 'سؤال جديد' : 'تعديل السؤال'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'نوع السؤال'),
                items: const [
                  DropdownMenuItem(value: 'mcq', child: Text('اختيار من متعدد')),
                  DropdownMenuItem(value: 'tf', child: Text('صح / خطأ')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _prompt,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'نص السؤال'),
                validator: (v) => Validators.required(v),
              ),
              const SizedBox(height: 8),
              if (isMcq) ...[
                for (var i = 0; i < _opts.length; i++)
                  Row(children: [
                    IconButton(
                      tooltip: 'الإجابة الصحيحة',
                      icon: Icon(_correctIdx == i ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                      onPressed: () => setState(() => _correctIdx = i),
                    ),
                    Expanded(
                      child: TextField(controller: _opts[i], decoration: InputDecoration(labelText: 'الخيار ${i + 1}')),
                    ),
                    if (_opts.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _opts.removeAt(i).dispose();
                          if (_correctIdx >= _opts.length) _correctIdx = _opts.length - 1;
                        }),
                      ),
                  ]),
                if (_opts.length < 6)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('خيار'),
                      onPressed: () => setState(() => _opts.add(TextEditingController())),
                    ),
                  ),
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('اضغط الدائرة بجانب الخيار الصحيح', style: TextStyle(fontSize: 12)),
                ),
              ] else
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('الصحيح: صح')),
                    ButtonSegment(value: false, label: Text('الصحيح: خطأ')),
                  ],
                  selected: {_correctBool},
                  onSelectionChanged: (s) => setState(() => _correctBool = s.first),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _points,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الدرجة'),
                    validator: (v) {
                      final n = parseNum(v ?? '');
                      return (n == null || n <= 0 || n > 100) ? 'من 0 إلى 100' : null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _order,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الترتيب'),
                    validator: (v) {
                      final n = parseNum(v ?? '');
                      return (n == null || n % 1 != 0) ? 'رقم صحيح' : null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _explain, maxLines: 2, decoration: const InputDecoration(labelText: 'شرح الإجابة (يظهر بعد الإغلاق)')),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ]),
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
