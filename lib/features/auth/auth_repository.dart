import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppRole { admin, student, none }

AppRole parseRole(Object? v) => switch (v) {
      'admin' => AppRole.admin,
      'student' => AppRole.student,
      _ => AppRole.none,
    };

class AuthRepository {
  AuthRepository(this._auth, this._db);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// يُطلق أيضًا عند تحديث التوكن (فتظهر تغييرات الـ Custom Claims).
  Stream<User?> idTokenChanges() => _auth.idTokenChanges();

  /// الدور من Custom Claims (للعرض فقط؛ الحماية الفعلية في القواعد).
  Future<AppRole> roleOf(User u) async {
    final r = await u.getIdTokenResult();
    return parseRole(r.claims?['role']);
  }

  Future<void> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: password);
    final uid = cred.user?.uid;
    if (uid != null) {
      try {
        await _db.doc('users/$uid').update({'lastLoginAt': FieldValue.serverTimestamp()});
      } catch (_) {/* غير حرج */}
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await _db.doc('users/${user.uid}').set({
      'displayName': name.trim(),
      'email': email.trim(),
      'phone': (phone ?? '').trim(),
      'role': 'student', // للعرض فقط
      'status': 'active',
      'guardianConsent': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // الـ Cloud Function تضبط claim الدور بعد الإنشاء؛ ننتظر ظهوره في التوكن.
    for (var i = 0; i < 6; i++) {
      final t = await user.getIdTokenResult(true);
      if (t.claims?['role'] != null) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> sendReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}

String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد مسجّل بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة';
      case 'invalid-email':
        return 'بريد إلكتروني غير صالح';
      case 'user-disabled':
        return 'هذا الحساب معطّل، تواصل مع الإدارة';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقًا';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالإنترنت';
    }
  }
  if (e is FirebaseFunctionsException && (e.message ?? '').isNotEmpty && e.code != 'internal') {
    return e.message!;
  }
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'ليست لديك صلاحية لتنفيذ هذا الإجراء';
  }
  return 'حدث خطأ غير متوقع، حاول مرة أخرى';
}
