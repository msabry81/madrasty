import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'exam_models.dart';

class ExamsRepository {
  ExamsRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v as Map);

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final r = await _fn.httpsCallable(name).call(data);
    return _map(r.data);
  }

  // ---------- المدير ----------
  Stream<List<Exam>> watchAll() => _db.collection('exams').snapshots().map(
      (s) => s.docs.map(Exam.fromDoc).toList()..sort((a, b) => b.opensAt.compareTo(a.opensAt)));

  Stream<Exam?> watchExam(String id) =>
      _db.doc('exams/$id').snapshots().map((d) => d.exists ? Exam.fromDoc(d) : null);

  Stream<List<ExamQuestion>> watchQuestions(String examId) => _db
      .collection('exams/$examId/questions')
      .snapshots()
      .map((s) => s.docs.map(ExamQuestion.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order)));

  Future<void> saveExam(Exam e) async {
    if (e.id.isEmpty) {
      await _db.collection('exams').add(
          {...e.toMap(), 'totalScore': 0, 'published': false, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _db.doc('exams/${e.id}').update(e.toMap());
    }
  }

  Future<void> setPublished(String id, bool v) => _db.doc('exams/$id').update({'published': v});

  Future<void> deleteExam(String id) => _call('deleteExam', {'examId': id});

  Future<void> saveQuestion(String examId, QuestionDraft d) => _call('saveExamQuestion', {
        'examId': examId,
        'questionId': d.id,
        'type': d.type,
        'prompt': d.prompt,
        'options': d.options,
        'points': d.points,
        'order': d.order,
        'correctAnswer': d.correct,
        'explanation': d.explanation,
      });

  Future<void> deleteQuestion(String examId, String questionId) =>
      _call('deleteExamQuestion', {'examId': examId, 'questionId': questionId});

  Future<Map<String, QuestionKey>> getKeys(String examId) async {
    final m = await _call('getExamKeys', {'examId': examId});
    return _map(m['keys']).map((id, v) {
      final k = _map(v);
      return MapEntry(id, QuestionKey(k['correctAnswer'], k['explanation'] as String? ?? ''));
    });
  }

  Stream<List<ResultDoc>> watchResults(String examId) => _db
      .collection('examResults')
      .where('examId', isEqualTo: examId)
      .snapshots()
      .map((s) => s.docs.map(ResultDoc.fromDoc).toList()
        ..sort((a, b) => a.studentName.compareTo(b.studentName)));

  // ---------- الطالب ----------
  /// القواعد تتحقق من الاشتراك لكل دورة، فنستعلم لكل دورة ثم ندمج.
  Stream<List<Exam>> watchExamsOf(List<String> courseIds) {
    late StreamController<List<Exam>> c;
    final subs = <StreamSubscription<List<Exam>>>[];
    final latest = <String, List<Exam>>{};
    c = StreamController<List<Exam>>(
      onListen: () {
        if (courseIds.isEmpty) c.add(const []);
        for (final id in courseIds) {
          subs.add(_db
              .collection('exams')
              .where('courseId', isEqualTo: id)
              .where('published', isEqualTo: true)
              .snapshots()
              .map((s) => s.docs.map(Exam.fromDoc).toList())
              .listen((l) {
            latest[id] = l;
            c.add(latest.values.expand((e) => e).toList()..sort((a, b) => a.opensAt.compareTo(b.opensAt)));
          }, onError: c.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  Stream<List<AttemptRow>> watchMyAttempts(String uid, String examId) => _db
      .collection('examAttempts')
      .where('studentId', isEqualTo: uid)
      .where('examId', isEqualTo: examId)
      .snapshots()
      .map((s) => s.docs.map(AttemptRow.fromDoc).toList()..sort((a, b) => a.attemptNo.compareTo(b.attemptNo)));

  Future<AttemptSession> startAttempt(String examId) async =>
      AttemptSession.fromMap(await _call('startExamAttempt', {'examId': examId}));

  /// حفظ دوري مباشر: القواعد ترفضه بعد انتهاء الوقت بحسب ساعة الخادم.
  Future<void> autosave(String attemptId, Map<String, Object> answers) =>
      _db.doc('examAttempts/$attemptId').update({'answers': answers});

  Future<SubmitResult> submit(String attemptId, Map<String, Object> answers) async {
    final m = await _call('submitExamAttempt', {'attemptId': attemptId, 'answers': answers});
    return SubmitResult(
      already: m['already'] == true,
      released: m['released'] == true,
      score: m['score'] as num?,
      totalScore: m['totalScore'] as num?,
    );
  }

  Future<List<ResultRow>> myResults(String examId) async {
    final m = await _call('getMyExamResults', {'examId': examId});
    return (m['results'] as List).map((e) {
      final r = _map(e);
      return ResultRow(
        attemptId: r['attemptId'] as String,
        attemptNo: (r['attemptNo'] as num).toInt(),
        released: r['released'] == true,
        score: r['score'] as num?,
        totalScore: r['totalScore'] as num?,
      );
    }).toList();
  }

  Future<List<ReviewItem>> review(String attemptId) async {
    final m = await _call('getAttemptReview', {'attemptId': attemptId});
    return (m['items'] as List).map((e) {
      final r = _map(e);
      return ReviewItem(
        question: ExamQuestion.fromMap(r['id'] as String, r),
        myAnswer: r['myAnswer'],
        correct: r['correctAnswer'],
        explanation: r['explanation'] as String? ?? '',
      );
    }).toList();
  }
}
