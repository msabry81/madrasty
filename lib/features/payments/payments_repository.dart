import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../courses/models.dart';
import 'payment_models.dart';

class PaymentsRepository {
  PaymentsRepository(this._db, this._fn, this._storage);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  final FirebaseStorage _storage;

  List<PaymentRequest> _sorted(Iterable<PaymentRequest> l) => l.toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  Stream<List<PaymentRequest>> watchMyRequests(String uid) => _db
      .collection('paymentRequests')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) => _sorted(s.docs.map(PaymentRequest.fromDoc)));

  Stream<List<PaymentRequest>> watchAll() => _db
      .collection('paymentRequests')
      .snapshots()
      .map((s) => _sorted(s.docs.map(PaymentRequest.fromDoc)));

  Stream<PaymentRequest?> watchRequest(String id) => _db
      .doc('paymentRequests/$id')
      .snapshots()
      .map((d) => d.exists ? PaymentRequest.fromDoc(d) : null);

  Stream<String> watchInstructions() => _db
      .doc('settings/payment')
      .snapshots()
      .map((d) => (d.data()?['instructions'] as String?) ?? '');

  Future<void> saveInstructions(String text) => _db
      .doc('settings/payment')
      .set({'instructions': text, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  Future<EnrollResult> requestEnrollment(String courseId) async {
    final r = await _fn.httpsCallable('requestEnrollment').call({'courseId': courseId});
    final m = Map<String, dynamic>.from(r.data as Map);
    return EnrollResult(m['requestId'] as String, m['status'] as String);
  }

  static String _mime(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => throw ArgumentError('نوع ملف غير مدعوم'),
      };

  Future<void> submitProof({
    required String uid,
    required String requestId,
    required Uint8List bytes,
    required String ext,
    required String reference,
  }) async {
    final path = 'paymentProofs/$uid/${requestId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _storage.ref(path).putData(bytes, SettableMetadata(contentType: _mime(ext)));
    await _fn.httpsCallable('submitPaymentProof')
        .call({'requestId': requestId, 'proofPath': path, 'reference': reference});
  }

  Future<String> proofUrl(String path) => _storage.ref(path).getDownloadURL();

  Future<void> review(String requestId, {required bool approve, String reason = ''}) => _fn
      .httpsCallable('reviewPaymentRequest')
      .call({'requestId': requestId, 'decision': approve ? 'approve' : 'reject', 'reason': reason});
}

class AdminRepository {
  AdminRepository(this._db, this._fn);
  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  Stream<List<UserDoc>> watchUsers() => _db.collection('users').snapshots().map(
      (s) => s.docs.map(UserDoc.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  Stream<List<Enrollment>> watchEnrollmentsOf(String uid) => _db
      .collection('enrollments')
      .where('studentId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(Enrollment.fromDoc).toList());

  Future<void> setUserStatus(String uid, String status) =>
      _fn.httpsCallable('setUserStatus').call({'uid': uid, 'status': status});

  Future<void> grantAccess(String studentId, String courseId, int? days, String reason) => _fn
      .httpsCallable('grantManualAccess')
      .call({'studentId': studentId, 'courseId': courseId, 'days': days, 'reason': reason});

  Future<void> revokeAccess(String studentId, String courseId, String reason) => _fn
      .httpsCallable('revokeAccess')
      .call({'studentId': studentId, 'courseId': courseId, 'reason': reason});
}
