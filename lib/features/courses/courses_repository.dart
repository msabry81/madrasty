import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

class CoursesRepository {
  CoursesRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _courses => _db.collection('courses');
  CollectionReference<Map<String, dynamic>> _units(String c) => _courses.doc(c).collection('units');
  CollectionReference<Map<String, dynamic>> _lessons(String c) => _courses.doc(c).collection('lessons');

  // الفرز في العميل لتفادي الفهارس المركبة (البيانات صغيرة).
  List<Course> _sortCourses(List<Course> l) => l..sort((a, b) => a.title.compareTo(b.title));
  List<Unit> _sortUnits(List<Unit> l) => l..sort((a, b) => a.order.compareTo(b.order));
  List<Lesson> _sortLessons(List<Lesson> l) => l..sort((a, b) => a.order.compareTo(b.order));

  // ---- الدورات ----
  /// القواعد تسمح للعامة بقراءة المنشورة فقط، فلازم الفلتر.
  Stream<List<Course>> watchPublished() => _courses
      .where('status', isEqualTo: 'published')
      .snapshots()
      .map((s) => _sortCourses(s.docs.map(Course.fromDoc).toList()));

  Stream<List<Course>> watchAll() =>
      _courses.snapshots().map((s) => _sortCourses(s.docs.map(Course.fromDoc).toList()));

  Stream<Course?> watchCourse(String id) =>
      _courses.doc(id).snapshots().map((d) => d.exists ? Course.fromDoc(d) : null);

  Future<void> saveCourse(Course c) async {
    if (c.id.isEmpty) {
      await _courses.add({...c.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _courses.doc(c.id).update({...c.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  // ---- الوحدات ----
  Stream<List<Unit>> watchUnits(String courseId) => _units(courseId)
      .snapshots()
      .map((s) => _sortUnits(s.docs.map(Unit.fromDoc).toList()));

  Future<void> saveUnit(String courseId, Unit u) async {
    if (u.id.isEmpty) {
      await _units(courseId).add(u.toMap());
    } else {
      await _units(courseId).doc(u.id).update(u.toMap());
    }
  }

  Future<void> deleteUnit(String courseId, String unitId) => _units(courseId).doc(unitId).delete();

  // ---- الدروس ----
  /// غير المشترك يقرأ دروس المعاينة فقط (القواعد ترفض الاستعلام الأوسع).
  Stream<List<Lesson>> watchLessons(String courseId, {bool previewOnly = false}) {
    Query<Map<String, dynamic>> q = _lessons(courseId);
    if (previewOnly) q = q.where('isPreview', isEqualTo: true);
    return q.snapshots().map((s) => _sortLessons(s.docs.map(Lesson.fromDoc).toList()));
  }

  Future<Lesson?> getLesson(String courseId, String lessonId) async {
    final d = await _lessons(courseId).doc(lessonId).get();
    return d.exists ? Lesson.fromDoc(d) : null;
  }

  Future<void> saveLesson(String courseId, Lesson l) async {
    if (l.id.isEmpty) {
      await _lessons(courseId).add({...l.toMap(), 'publishedAt': FieldValue.serverTimestamp()});
    } else {
      await _lessons(courseId).doc(l.id).update(l.toMap());
    }
  }

  Future<void> deleteLesson(String courseId, String lessonId) =>
      _lessons(courseId).doc(lessonId).delete();

  // ---- التسجيلات (قراءة فقط للطالب) ----
  Future<Enrollment?> getMyEnrollment(String uid, String courseId) async {
    final d = await _db.doc('enrollments/${uid}_$courseId').get();
    return d.exists ? Enrollment.fromDoc(d) : null;
  }

  Stream<List<Enrollment>> watchMyEnrollments(String uid) => _db
      .collection('enrollments')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Enrollment.fromDoc).where((e) => e.isActive).toList());

  // ---- تقدّم الطالب (الدروس المكتملة) ----
  Stream<Set<String>> watchProgress(String uid, String courseId) =>
      _db.doc('progress/${uid}_$courseId').snapshots().map(
          (d) => ((d.data()?['completed'] as List?) ?? const []).map((e) => e.toString()).toSet());

  Future<void> markLessonComplete(String uid, String courseId, String lessonId) =>
      _db.doc('progress/${uid}_$courseId').set({
        'studentId': uid,
        'courseId': courseId,
        'completed': FieldValue.arrayUnion([lessonId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
