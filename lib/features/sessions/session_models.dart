import 'package:cloud_firestore/cloud_firestore.dart';

class LiveSession {
  const LiveSession({
    this.id = '',
    required this.courseId,
    required this.courseTitle,
    required this.title,
    required this.startsAt,
    this.durationMinutes = 60,
    required this.meetUrl,
    this.status = 'scheduled',
  });

  final String id, courseId, courseTitle, title, meetUrl, status;
  final DateTime startsAt;
  final int durationMinutes;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));
  bool get isCancelled => status == 'cancelled';

  /// قادمة / جارية الآن / انتهت / ملغاة
  String phase([DateTime? now]) {
    final n = now ?? DateTime.now();
    if (isCancelled) return 'ملغاة';
    if (n.isBefore(startsAt)) return 'قادمة';
    if (n.isBefore(endsAt)) return 'جارية الآن';
    return 'انتهت';
  }

  factory LiveSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return LiveSession(
      id: d.id,
      courseId: m['courseId'] as String? ?? '',
      courseTitle: m['courseTitle'] as String? ?? '',
      title: m['title'] as String? ?? '',
      startsAt: (m['startsAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 60,
      meetUrl: m['meetUrl'] as String? ?? '',
      status: m['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toMap() => {
        'courseId': courseId,
        'courseTitle': courseTitle,
        'title': title,
        'startsAt': Timestamp.fromDate(startsAt),
        'durationMinutes': durationMinutes,
        'meetUrl': meetUrl,
        'status': status,
      };
}

const attendanceLabels = {'present': 'حاضر', 'late': 'متأخر', 'absent': 'غائب'};

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.studentId,
    required this.status,
    required this.sessionTitle,
    this.sessionStartsAt,
  });

  final String id, sessionId, courseId, studentId, status, sessionTitle;
  final DateTime? sessionStartsAt;

  String get statusLabel => attendanceLabels[status] ?? status;

  factory AttendanceRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    String s(String k) => m[k] as String? ?? '';
    return AttendanceRecord(
      id: d.id,
      sessionId: s('sessionId'),
      courseId: s('courseId'),
      studentId: s('studentId'),
      status: s('status'),
      sessionTitle: s('sessionTitle'),
      sessionStartsAt: (m['sessionStartsAt'] as Timestamp?)?.toDate(),
    );
  }
}
