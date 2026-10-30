import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/cairo_time.dart';
import '../../core/services.dart';
import '../../shared/ui.dart';
import 'exam_models.dart';

class ExamPage extends StatefulWidget {
  const ExamPage({super.key, required this.examId});
  final String examId;
  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  AttemptSession? _session;
  final _answers = <String, Object>{};
  final _sw = Stopwatch();
  Timer? _tick, _saveTimer;
  bool _starting = false, _submitting = false, _dirty = false, _saveError = false;
  SubmitResult? _result;
  List<ResultRow>? _myResults;

  @override
  void dispose() {
    _tick?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  Duration get _remaining {
    final s = _session;
    if (s == null) return Duration.zero;
    final r = s.remaining - _sw.elapsed; // ساعة محلية نسبية فقط؛ الحسم النهائي من الخادم
    return r.isNegative ? Duration.zero : r;
  }

  Future<void> _start() async {
    if (!await confirm(context, 'سيبدأ العدّ التنازلي فورًا ولا يمكن إيقافه. هل تريد البدء؟')) return;
    await _begin();
  }

  Future<void> _begin() async {
    setState(() => _starting = true);
    try {
      final s = await Services.exams.startAttempt(widget.examId);
      _answers
        ..clear()
        ..addAll(s.answers);
      _sw
        ..reset()
        ..start();
      setState(() => _session = s);
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (_remaining == Duration.zero && !_submitting && _result == null) _submit(auto: true);
      });
      // حفظ دوري بفاصل لا يقل عن 60 ثانية وعند وجود تغيير فقط (لتوفير الحصص)
      _saveTimer = Timer.periodic(const Duration(seconds: 60), (_) => _autosave());
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _autosave() async {
    final s = _session;
    if (s == null || !_dirty || _submitting) return;
    final snapshot = Map<String, Object>.from(_answers);
    try {
      await Services.exams.autosave(s.attemptId, snapshot).timeout(const Duration(seconds: 15));
      _dirty = false;
      if (mounted) setState(() => _saveError = false);
    } catch (_) {
      if (mounted) setState(() => _saveError = true); // نعيد المحاولة في الدورة التالية
    }
  }

  Future<void> _submit({bool auto = false}) async {
    final s = _session;
    if (s == null || _submitting) return;
    if (!auto) {
      final unanswered = s.questions.where((q) => !_answers.containsKey(q.id)).length;
      final msg = unanswered > 0 ? 'لديك $unanswered سؤال بدون إجابة. هل تريد التسليم؟' : 'تسليم الإجابات؟';
      if (!await confirm(context, msg)) return;
    }
    setState(() => _submitting = true);
    try {
      final r = await Services.exams.submit(s.attemptId, Map<String, Object>.from(_answers));
      _tick?.cancel();
      _saveTimer?.cancel();
      if (r.already) _myResults = await Services.exams.myResults(widget.examId);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_session?.examTitle ?? 'الامتحان')),
      body: _result != null
          ? _resultView()
          : _session == null
              ? _intro()
              : _taking(),
    );
  }

  // ---------- مقدمة ----------
  Widget _intro() {
    final uid = Services.session.user!.uid;
    return StreamBuilder<Exam?>(
      stream: Services.exams.watchExam(widget.examId),
      builder: (context, xs) {
        final x = xs.data;
        if (xs.hasError || (xs.connectionState == ConnectionState.active && x == null)) {
          return const Center(child: Text('الامتحان غير متاح'));
        }
        if (x == null) return const Center(child: CircularProgressIndicator());
        return StreamBuilder<List<AttemptRow>>(
          stream: Services.exams.watchMyAttempts(uid, x.id),
          builder: (context, as) {
            final attempts = as.data ?? const <AttemptRow>[];
            final resume = attempts.any((a) => a.inProgress);
            final left = x.attemptsAllowed - attempts.length;
            return Centered(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x.title, style: Theme.of(context).textTheme.titleLarge),
                      Text(x.courseTitle),
                      const SizedBox(height: 8),
                      Text('الإتاحة: ${CairoTime.format(x.opensAt)} → ${CairoTime.format(x.closesAt)}'),
                      Text('المدة: ${x.durationMinutes} دقيقة · الدرجة الكلية: ${x.totalScore}'),
                      Text('المحاولات المتبقية: ${left < 0 ? 0 : left} من ${x.attemptsAllowed}'),
                      Text('النتيجة: ${resultsModeLabels[x.resultsMode]}'),
                      const SizedBox(height: 12),
                      const Text('• يُحسب الوقت من الخادم ولا يتوقف عند إغلاق الصفحة.\n'
                          '• تُحفظ إجاباتك تلقائيًا كل دقيقة، ويُسلَّم الامتحان تلقائيًا عند انتهاء الوقت.\n'
                          '• لا يجوز تعديل الإجابات بعد التسليم.'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _starting || (!resume && left <= 0) ? null : (resume ? _begin : _start),
                  child: _starting
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(resume ? 'متابعة المحاولة' : 'ابدأ المحاولة'),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  // ---------- أثناء الحل ----------
  Widget _option(String text, bool selected, VoidCallback onTap) => ListTile(
        dense: true,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? Theme.of(context).colorScheme.primary : null),
        title: Text(text),
        onTap: _submitting ? null : onTap,
      );

  void _set(String qid, Object v) {
    setState(() => _answers[qid] = v);
    _dirty = true;
  }

  Widget _question(int i, ExamQuestion q) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ${q.prompt}  (${q.points} درجة)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          if (q.isMcq)
            for (var k = 0; k < q.options.length; k++)
              _option(q.options[k], _answers[q.id] == k, () => _set(q.id, k))
          else ...[
            _option('صح', _answers[q.id] == true, () => _set(q.id, true)),
            _option('خطأ', _answers[q.id] == false, () => _set(q.id, false)),
          ],
        ]),
      ),
    );
  }

  Widget _taking() {
    final s = _session!;
    final r = _remaining;
    final mm = r.inMinutes.toString().padLeft(2, '0');
    final ss = (r.inSeconds % 60).toString().padLeft(2, '0');
    final low = r.inSeconds < 60;
    return Column(children: [
      Material(
        color: low ? Theme.of(context).colorScheme.errorContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Text('الوقت المتبقي: $mm:$ss', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text('أجبت ${_answers.length} من ${s.questions.length}'),
          ]),
        ),
      ),
      if (_saveError)
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          padding: const EdgeInsets.all(8),
          child: const Text('تعذّر الحفظ التلقائي (تحقق من الاتصال). ستُرسَل إجاباتك كاملة عند التسليم.'),
        ),
      Expanded(
        child: Centered(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            for (var i = 0; i < s.questions.length; i++) _question(i, s.questions[i]),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(),
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تسليم الإجابات'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    ]);
  }

  // ---------- بعد التسليم ----------
  Widget _resultView() {
    final r = _result!;
    String text;
    if (r.already) {
      final last = (_myResults ?? const <ResultRow>[]).isEmpty ? null : _myResults!.last;
      text = last != null && last.released
          ? 'درجتك: ${last.score} من ${last.totalScore}'
          : 'تم تسليم محاولتك. تظهر النتيجة بعد إغلاق الامتحان.';
    } else if (r.released) {
      text = 'درجتك: ${r.score} من ${r.totalScore}';
    } else {
      text = 'تم تسليم إجاباتك بنجاح. ستظهر النتيجة بعد إغلاق الامتحان.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.go('/exams'), child: const Text('رجوع للامتحانات')),
        ]),
      ),
    );
  }
}
