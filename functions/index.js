const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const functionsV1 = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// نفس القيمة في lib/core/app_config.dart
const REGION = 'europe-west1';
setGlobalOptions({ region: REGION, maxInstances: 10 });
// عند تفعيل App Check في الإنتاج: onCall({ enforceAppCheck: true }, ...)

async function audit(actorUid, action, targetType, targetId, metadata = {}) {
  await db.collection('auditLogs').add({
    actorUid, action, targetType, targetId, metadata,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function requireAdmin(request) {
  if (!request.auth || request.auth.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'للمديرين فقط');
  }
}

// كل حساب جديد = طالب (الدور في Custom Claims)
exports.onUserCreated = functionsV1.region(REGION).auth.user().onCreate(async (user) => {
  await admin.auth().setCustomUserClaims(user.uid, { role: 'student' });
  await audit(user.uid, 'userCreated', 'user', user.uid);
});

// تغيير دور مستخدم (مدير فقط، ولا يغيّر دوره بنفسه)
exports.setUserRole = onCall(async (request) => {
  requireAdmin(request);
  const { uid, role } = request.data || {};
  if (typeof uid !== 'string' || !['admin', 'student'].includes(role)) {
    throw new HttpsError('invalid-argument', 'بيانات غير صالحة');
  }
  if (uid === request.auth.uid) {
    throw new HttpsError('failed-precondition', 'لا يمكنك تغيير دورك بنفسك');
  }
  await admin.auth().setCustomUserClaims(uid, { role });
  await db.doc(`users/${uid}`).set({ role }, { merge: true });
  await audit(request.auth.uid, 'setUserRole', 'user', uid, { role });
  return { ok: true }; // يظهر الدور الجديد للمستخدم عند تجديد التوكن
});

// تعطيل/تفعيل حساب (بدل الحذف للحفاظ على السجلات)
exports.setUserStatus = onCall(async (request) => {
  requireAdmin(request);
  const { uid, status } = request.data || {};
  if (typeof uid !== 'string' || !['active', 'disabled'].includes(status)) {
    throw new HttpsError('invalid-argument', 'بيانات غير صالحة');
  }
  if (uid === request.auth.uid) {
    throw new HttpsError('failed-precondition', 'لا يمكنك تعطيل حسابك بنفسك');
  }
  await admin.auth().updateUser(uid, { disabled: status === 'disabled' });
  if (status === 'disabled') await admin.auth().revokeRefreshTokens(uid);
  await db.doc(`users/${uid}`).set({ status }, { merge: true });
  await audit(request.auth.uid, 'setUserStatus', 'user', uid, { status });
  return { ok: true };
});

// المرحلة 5: الدفع اليدوي والوصول
Object.assign(exports, require("./payments"));

// المرحلة 6: الامتحانات
Object.assign(exports, require("./exams"));

// المرحلة 7: الإعلانات والإشعارات
Object.assign(exports, require("./announcements"));
