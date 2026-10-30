import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _dt(Object? v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);

const resultsModeLabels = {
  'immediate': 'فورًا بعد التسليم',
  'after_close': 'بعد إغلاق الامتحان',
};

class Exam {
  const Exam({
    this.id = '',
    required this.courseId,
    required this.courseTitle,
    required this.title,
    this.durationMinutes = 30,
    required this.opensAt,
    required this.closesAt,
    this.attemptsAllowed = 1,
    this.totalScore = 0,
    this.resultsMode = 'after_close',
    this.shuffleQuestions = false,
    this.published = false,
  });

  final String id, courseId, courseTitle, title, resultsMode;
  final int durationMinutes, attemptsAllowed;
  final num totalScore;
  final DateTime opensAt, closesAt;
  final bool shuffleQuestions, published;

  /// للعرض فقط (الحسم النهائي في الخادم)
  String phase([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (n.isBefore(opensAt)) return 'لم يبدأ';
    if (n.isAfter(closesAt)) return 'مغلق';
    return 'متاح';
  }

  factory Exam.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Exam(
      id: d.id,
      courseId: m['courseId'] as String? ?? '',
      courseTitle: m['courseTitle'] as String? ?? '',
      title: m['title'] as String? ?? '',
      durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 30,
      opensAt: _dt(m['opensAt']),
      closesAt: _dt(m['closesAt']),
      attemptsAllowed: (m['attemptsAllowed'] as num?)?.toInt() ?? 1,
      totalScore: m['totalScore'] as num? ?? 0,
      resultsMode: m['resultsMode'] as String? ?? 'after_close',
      shuffleQuestions: m['shuffleQuestions'] as bool? ?? false,
      published: m['published'] as bool? ?? false,
    );
  }

  /// لا يتضمن totalScore (يحسبه الخادم) ولا published (يُغيَّر من صفحة الامتحان).
  Map<String, dynamic> toMap() => {
        'courseId': courseId,
        'courseTitle': courseTitle,
        'title': title,
        'durationMinutes': durationMinutes,
        'opensAt': Timestamp.fromDate(opensAt),
        'closesAt': Timestamp.fromDate(closesAt),
        'attemptsAllowed': attemptsAllowed,
        'resultsMode': resultsMode,
        'shuffleQuestions': shuffleQuestions,
      };
}

class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    this.options = const [],
    required this.points,
    this.order = 0,
  });

  final String id, type, prompt;
  final List<String> options;
  final num points;
  final int order;

  bool get isMcq => type == 'mcq';

  factory ExamQuestion.fromMap(String id, Map<String, dynamic> m) => ExamQuestion(
        id: id,
        type: m['type'] as String? ?? 'mcq',
        prompt: m['prompt'] as String? ?? '',
        options: ((m['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
        points: m['points'] as num? ?? 1,
        order: (m['order'] as num?)?.toInt() ?? 0,
      );

  factory ExamQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      ExamQuestion.fromMap(d.id, d.data() ?? {});
}

/// مسودة سؤال من نافذة المدير (الإجابة الصحيحة: int لـ mcq، bool لـ tf)
class QuestionDraft {
  const QuestionDraft({
    this.id = '',
    required this.type,
    required this.prompt,
    this.options = const [],
    required this.points,
    required this.order,
    required this.correct,
    this.explanation = '',
  });
  final String id, type, prompt, explanation;
  final List<String> options;
  final num points;
  final int order;
  final Object correct;
}

class QuestionKey {
  const QuestionKey(this.correct, this.explanation);
  final Object? correct;
  final String explanation;
}

class AttemptSession {
  const AttemptSession({
    required this.attemptId,
    required this.attemptNo,
    required this.examTitle,
    required this.remaining,
    required this.questions,
    required this.answers,
  });

  final String attemptId, examTitle;
  final int attemptNo;
  /// الوقت المتبقي لحظة الاستلام بحسب ساعة الخادم (لا ساعة الجهاز)
  final Duration remaining;
  final List<ExamQuestion> questions;
  final Map<String, Object> answers;

  factory AttemptSession.fromMap(Map<String, dynamic> m) {
    final answers = <String, Object>{};
    ((m['answers'] as Map?) ?? const {}).forEach((k, v) {
      if (v is num) {
        answers[k as String] = v.toInt();
      } else if (v is bool) {
        answers[k as String] = v;
      }
    });
    return AttemptSession(
      attemptId: m['attemptId'] as String,
      attemptNo: (m['attemptNo'] as num).toInt(),
      examTitle: m['examTitle'] as String? ?? '',
      remaining: Duration(milliseconds: ((m['expiresAtMs'] as num) - (m['serverNowMs'] as num)).toInt()),
      questions: (m['questions'] as List).map((q) {
        final mm = Map<String, dynamic>.from(q as Map);
        return ExamQuestion.fromMap(mm['id'] as String, mm);
      }).toList(),
      answers: answers,
    );
  }
}

class SubmitResult {
  const SubmitResult({this.already = false, this.released = false, this.score, this.totalScore});
  final bool already, released;
  final num? score, totalScore;
}

class ResultRow {
  const ResultRow({required this.attemptId, required this.attemptNo, required this.released, this.score, this.totalScore});
  final String attemptId;
  final int attemptNo;
  final bool released;
  final num? score, totalScore;
}

class AttemptRow {
  const AttemptRow({required this.id, required this.attemptNo, required this.status, required this.expiresAt});
  final String id, status;
  final int attemptNo;
  final DateTime expiresAt;

  bool get inProgress => status == 'in_progress' && expiresAt.isAfter(DateTime.now());

  factory AttemptRow.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AttemptRow(
      id: d.id,
      attemptNo: (m['attemptNo'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? '',
      expiresAt: _dt(m['expiresAt']),
    );
  }
}

class ReviewItem {
  const ReviewItem({required this.question, this.myAnswer, this.correct, this.explanation = ''});
  final ExamQuestion question;
  final Object? myAnswer, correct;
  final String explanation;
}

class ResultDoc {
  const ResultDoc({required this.studentName, required this.attemptNo, required this.score, required this.totalScore, required this.status, this.submittedAt});
  final String studentName, status;
  final int attemptNo;
  final num score, totalScore;
  final DateTime? submittedAt;

  factory ResultDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return ResultDoc(
      studentName: m['studentName'] as String? ?? '',
      attemptNo: (m['attemptNo'] as num?)?.toInt() ?? 0,
      score: m['score'] as num? ?? 0,
      totalScore: m['totalScore'] as num? ?? 0,
      status: m['status'] as String? ?? '',
      submittedAt: (m['submittedAt'] as Timestamp?)?.toDate(),
    );
  }
}
