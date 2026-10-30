import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'comms_models.dart';

Stream<List<T>> _mergeLists<T>(List<Stream<List<T>>> streams, int Function(T, T) cmp) {
  late StreamController<List<T>> c;
  final subs = <StreamSubscription<List<T>>>[];
  final latest = <int, List<T>>{};
  c = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(streams[i].listen((l) {
          latest[i] = l;
          c.add(latest.values.expand((e) => e).toList()..sort(cmp));
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

class CommsRepository {
  CommsRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  CollectionReference<Map<String, dynamic>> get _notes => _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _anns => _db.collection('announcements');

  static int _newest(DateTime? a, DateTime? b) => (b ?? DateTime(0)).compareTo(a ?? DateTime(0));

  // ---------- الإشعارات ----------
  Stream<List<AppNotification>> watchNotifications(String uid) => _notes
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  Stream<int> watchUnreadCount(String uid) => _notes
      .where('userId', isEqualTo: uid)
      .where('readAt', isNull: true)
      .limit(10)
      .snapshots()
      .map((s) => s.size);

  Future<void> markRead(String id) => _notes.doc(id).update({'readAt': FieldValue.serverTimestamp()});

  Future<void> markAllRead(Iterable<String> ids) async {
    final batch = _db.batch();
    for (final id in ids) {
      batch.update(_notes.doc(id), {'readAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // ---------- الإعلانات ----------
  List<Announcement> _ann(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map(Announcement.fromDoc).toList();

  /// القواعد تتحقق من الاشتراك لكل دورة: استعلام للعامة + استعلام لكل دورة نشطة.
  Stream<List<Announcement>> watchAnnouncementsFor(List<String> courseIds) => _mergeLists<Announcement>([
        _anns.where('audience', isEqualTo: 'all').snapshots().map(_ann),
        for (final id in courseIds)
          _anns
              .where('audience', isEqualTo: 'course')
              .where('courseId', isEqualTo: id)
              .snapshots()
              .map(_ann),
      ], (a, b) => _newest(a.createdAt, b.createdAt));

  Stream<List<Announcement>> watchAllAnnouncements() =>
      _anns.snapshots().map((s) => _ann(s)..sort((a, b) => _newest(a.createdAt, b.createdAt)));

  Future<int> publish(AnnouncementDraft d) async {
    final r = await _fn.httpsCallable('publishAnnouncement').call({
      'title': d.title,
      'body': d.body,
      'audience': d.audience,
      'courseId': d.courseId,
      'expiresAtMs': d.expiresAt?.millisecondsSinceEpoch,
    });
    return ((Map<String, dynamic>.from(r.data as Map))['notified'] as num).toInt();
  }

  Future<void> delete(String id) => _fn.httpsCallable('deleteAnnouncement').call({'id': id});
}
