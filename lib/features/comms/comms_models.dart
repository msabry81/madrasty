import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.courseId,
    this.createdAt,
    this.expiresAt,
  });

  final String id, title, body, audience;
  final String? courseId;
  final DateTime? createdAt, expiresAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Announcement(
      id: d.id,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      audience: m['audience'] as String? ?? 'all',
      courseId: m['courseId'] as String?,
      createdAt: _ts(m['createdAt']),
      expiresAt: _ts(m['expiresAt']),
    );
  }
}

class AnnouncementDraft {
  const AnnouncementDraft({required this.title, required this.body, required this.audience, this.courseId, this.expiresAt});
  final String title, body, audience;
  final String? courseId;
  final DateTime? expiresAt;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.createdAt,
    this.readAt,
  });

  final String id, title, body, type;
  final DateTime? createdAt, readAt;
  bool get unread => readAt == null;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return AppNotification(
      id: d.id,
      title: m['title'] as String? ?? '',
      body: m['body'] as String? ?? '',
      type: m['type'] as String? ?? '',
      createdAt: _ts(m['createdAt']),
      readAt: _ts(m['readAt']),
    );
  }
}
