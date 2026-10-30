import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

const paymentStatusLabels = {
  'pending_payment': 'بانتظار الدفع',
  'proof_submitted': 'قيد المراجعة',
  'approved': 'معتمد',
  'rejected': 'مرفوض',
  'expired': 'منتهي',
  'refunded': 'مسترد',
};

class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.courseId,
    required this.courseTitle,
    required this.amount,
    required this.status,
    this.reference = '',
    this.proofPath = '',
    this.rejectReason = '',
    this.createdAt,
  });

  final String id, code, studentId, studentName, studentEmail, courseId, courseTitle, status;
  final String reference, proofPath, rejectReason;
  final num amount;
  final DateTime? createdAt;

  bool get isOpen => status == 'pending_payment' || status == 'proof_submitted';
  bool get canUploadProof => status == 'pending_payment' || status == 'rejected';
  String get statusLabel => paymentStatusLabels[status] ?? status;
  String get amountText => '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} ج.م';

  factory PaymentRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    String s(String k) => m[k] as String? ?? '';
    return PaymentRequest(
      id: d.id,
      code: s('code'),
      studentId: s('studentId'),
      studentName: s('studentName'),
      studentEmail: s('studentEmail'),
      courseId: s('courseId'),
      courseTitle: s('courseTitle'),
      amount: m['amount'] as num? ?? 0,
      status: s('status'),
      reference: s('reference'),
      proofPath: s('proofPath'),
      rejectReason: s('rejectReason'),
      createdAt: _ts(m['createdAt']),
    );
  }
}

class EnrollResult {
  const EnrollResult(this.requestId, this.status);
  final String requestId, status;
}

class UserDoc {
  const UserDoc({required this.uid, required this.name, required this.email, required this.phone, required this.role, required this.status});
  final String uid, name, email, phone, role, status;

  factory UserDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    String s(String k) => m[k] as String? ?? '';
    return UserDoc(uid: d.id, name: s('displayName'), email: s('email'), phone: s('phone'), role: s('role'), status: s('status'));
  }
}
