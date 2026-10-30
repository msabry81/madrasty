import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../courses/models.dart';
import 'session_models.dart';

class SessionsRepository {
  SessionsRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _sessions => _db.collection('liveSessions');
  CollectionReference<Map<String, dynamic>> get _attendance => _db.collection('attendance');

  List<LiveSession> _sorted(Iterable<LiveSession> l) =>
      l.toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  // ---- الحصص ----
  Stream<List<LiveSession>> watchAll() =>
      _sessions.snapshots().map((s) => _sorted(s.docs.map(LiveSession.fromDoc)));

  Stream<LiveSession?> watchSession(String id) =>
      _sessions.doc(id).snapshots().map((d) => d.exists ? LiveSession.fromDoc(d) : null);

  /// القواعد تتحقق من الاشتراك لكل دورة، فنستعلم عن كل دورة على حدة ثم ندمج النتائج.
  Stream<List<LiveSession>> watchSessionsOf(List<String> courseIds) {
    late StreamController<List<LiveSession>> c;
    final subs = <StreamSubscription<List<LiveSession>>>[];
    final latest = <String, List<LiveSession>>{};
    c = StreamController<List<LiveSession>>(
      onListen: () {
        if (courseIds.isEmpty) c.add(const []);
        for (final id in courseIds) {
          subs.add(_sessions.where('courseId', isEqualTo: id).snapshots()
              .map((s) => s.docs.map(LiveSession.fromDoc).toList())
              .listen((l) {
            latest[id] = l;
            c.add(_sorted(latest.values.expand((e) => e)));
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

  Future<void> save(LiveSession s, String adminUid) async {
    if (s.id.isEmpty) {
      await _sessions.add({...s.toMap(), 'teacherId': adminUid, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _sessions.doc(s.id).update(s.toMap());
    }
  }

  Future<void> setStatus(String id, String status) => _sessions.doc(id).update({'status': status});
  Future<void> delete(String id) => _sessions.doc(id).delete();

  // ---- الحضور ----
  Stream<List<Enrollment>> watchActiveEnrollmentsOfCourse(String courseId) => _db
      .collection('enrollments')
      .where('courseId', isEqualTo: courseId)
      .snapshots()
      .map((s) => s.docs.map(Enrollment.fromDoc).where((e) => e.isActive).toList());

  Stream<List<AttendanceRecord>> watchSessionAttendance(String sessionId) => _attendance
      .where('sessionId', isEqualTo: sessionId)
      .snapshots()
      .map((s) => s.docs.map(AttendanceRecord.fromDoc).toList());

  Stream<List<AttendanceRecord>> watchMyAttendance(String uid) => _attendance
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(AttendanceRecord.fromDoc).toList()
        ..sort((a, b) => (b.sessionStartsAt ?? DateTime(0)).compareTo(a.sessionStartsAt ?? DateTime(0))));

  Map<String, dynamic> _markData(LiveSession s, String studentId, String status, String adminUid) => {
        'sessionId': s.id,
        'courseId': s.courseId,
        'studentId': studentId,
        'status': status,
        'method': 'manual',
        'sessionTitle': s.title,
        'sessionStartsAt': Timestamp.fromDate(s.startsAt),
        'markedBy': adminUid,
        'markedAt': FieldValue.serverTimestamp(),
      };

  Future<void> mark(LiveSession s, String studentId, String status, String adminUid) =>
      _attendance.doc('${s.id}_$studentId').set(_markData(s, studentId, status, adminUid));

  Future<void> markMany(LiveSession s, Iterable<String> studentIds, String status, String adminUid) async {
    final batch = _db.batch();
    for (final id in studentIds) {
      batch.set(_attendance.doc('${s.id}_$id'), _markData(s, id, status, adminUid));
    }
    await batch.commit();
  }

  Future<void> clearMark(String sessionId, String studentId) =>
      _attendance.doc('${sessionId}_$studentId').delete();
}
