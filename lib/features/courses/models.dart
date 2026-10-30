import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

class Course {
  const Course({
    this.id = '',
    required this.title,
    this.description = '',
    this.gradeLabel = '',
    this.subjectLabel = '',
    this.price = 0,
    this.accessDays = 90,
    this.status = 'draft',
  });

  final String id, title, description, gradeLabel, subjectLabel, status;
  final num price;
  final int accessDays;

  bool get isPublished => status == 'published';
  bool get isPaid => price > 0;
  String get priceText =>
      isPaid ? '${price.toStringAsFixed(price % 1 == 0 ? 0 : 2)} ج.م' : 'مجانية';

  factory Course.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Course(
      id: d.id,
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      gradeLabel: m['gradeLabel'] as String? ?? '',
      subjectLabel: m['subjectLabel'] as String? ?? '',
      price: m['price'] as num? ?? 0,
      accessDays: (m['accessDays'] as num?)?.toInt() ?? 90,
      status: m['status'] as String? ?? 'draft',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'gradeLabel': gradeLabel,
        'subjectLabel': subjectLabel,
        'price': price,
        'isPaid': isPaid,
        'accessDays': accessDays,
        'status': status,
      };

  Course copyWith({String? status}) => Course(
        id: id,
        title: title,
        description: description,
        gradeLabel: gradeLabel,
        subjectLabel: subjectLabel,
        price: price,
        accessDays: accessDays,
        status: status ?? this.status,
      );
}

class Unit {
  const Unit({this.id = '', required this.title, this.order = 1});
  final String id, title;
  final int order;

  factory Unit.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Unit(
      id: d.id,
      title: m['title'] as String? ?? '',
      order: (m['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'title': title, 'order': order};
}

class Lesson {
  const Lesson({
    this.id = '',
    required this.unitId,
    required this.title,
    required this.youtubeVideoId,
    this.order = 1,
    this.isPreview = false,
  });

  final String id, unitId, title, youtubeVideoId;
  final int order;
  final bool isPreview;

  factory Lesson.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Lesson(
      id: d.id,
      unitId: m['unitId'] as String? ?? '',
      title: m['title'] as String? ?? '',
      youtubeVideoId: m['youtubeVideoId'] as String? ?? '',
      order: (m['order'] as num?)?.toInt() ?? 0,
      isPreview: m['isPreview'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'unitId': unitId,
        'title': title,
        'youtubeVideoId': youtubeVideoId,
        'order': order,
        'isPreview': isPreview,
      };
}

class Enrollment {
  const Enrollment({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.status,
    this.endAt,
  });

  final String id, studentId, courseId, status;
  final DateTime? endAt;

  /// يطابق شرط القواعد: status == active و endAt في المستقبل.
  bool get isActive =>
      status == 'active' && endAt != null && endAt!.isAfter(DateTime.now());

  factory Enrollment.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return Enrollment(
      id: d.id,
      studentId: m['studentId'] as String? ?? '',
      courseId: m['courseId'] as String? ?? '',
      status: m['status'] as String? ?? '',
      endAt: _ts(m['endAt']),
    );
  }
}
