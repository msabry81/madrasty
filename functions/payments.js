const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const crypto = require('crypto');

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const DAY = 864e5;
const EXPIRY_DAYS = 7; // انتهاء طلب pending_payment (مقترح الوثيقة)

// ---------- helpers ----------
function requireAuth(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'سجّل الدخول أولًا');
  return request.auth.uid;
}
function requireAdmin(request) {
  if (!request.auth || request.auth.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'للمديرين فقط');
  }
  return request.auth.uid;
}
const str = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const genCode = () => crypto.randomBytes(4).toString('hex').toUpperCase().slice(0, 6);

function auditTx(tx, actorUid, action, targetType, targetId, metadata = {}) {
  tx.set(db.collection('auditLogs').doc(), {
    actorUid, action, targetType, targetId, metadata, timestamp: FieldValue.serverTimestamp(),
  });
}
function notifyTx(tx, userId, title, body, type) {
  tx.set(db.collection('notifications').doc(), {
    userId, title, body, type, readAt: null, createdAt: FieldValue.serverTimestamp(),
  });
}
function isActiveEnrollment(snap, now) {
  if (!snap.exists) return false;
  const d = snap.data();
  return d.status === 'active' && d.endAt && d.endAt.toMillis() > now.toMillis();
}
// تسجيل جديد أو تمديد لتسجيل نشط (الاعتماد المتكرر لا ينشئ تسجيلًا ثانيًا: المعرّف ثابت)
function buildEnrollment(existingSnap, studentId, courseId, days, source, paymentRequestId, approvedBy) {
  const now = Timestamp.now();
  const active = isActiveEnrollment(existingSnap, now);
  const startMs = active ? existingSnap.data().endAt.toMillis() : now.toMillis();
  return {
    studentId, courseId, status: 'active', source, paymentRequestId: paymentRequestId || null,
    startAt: active ? existingSnap.data().startAt : now,
    endAt: Timestamp.fromMillis(startMs + days * DAY),
    approvedBy, approvedAt: now,
  };
}

// ---------- الطالب: طلب اشتراك ----------
exports.requestEnrollment = onCall(async (request) => {
  const uid = requireAuth(request);
  const courseId = str((request.data || {}).courseId, 100);
  if (!courseId) throw new HttpsError('invalid-argument', 'الدورة مطلوبة');

  return db.runTransaction(async (tx) => {
    const courseSnap = await tx.get(db.doc(`courses/${courseId}`));
    if (!courseSnap.exists || courseSnap.data().status !== 'published') {
      throw new HttpsError('failed-precondition', 'الدورة غير متاحة');
    }
    const course = courseSnap.data();
    const enrRef = db.doc(`enrollments/${uid}_${courseId}`);
    const enrSnap = await tx.get(enrRef);
    const mine = await tx.get(
      db.collection('paymentRequests').where('studentId', '==', uid).where('courseId', '==', courseId));
    const userSnap = await tx.get(db.doc(`users/${uid}`));

    if (isActiveEnrollment(enrSnap, Timestamp.now())) {
      throw new HttpsError('already-exists', 'أنت مشترك بالفعل في هذه الدورة');
    }
    const open = mine.docs.find((d) => ['pending_payment', 'proof_submitted'].includes(d.data().status));
    if (open) return { requestId: open.id, status: open.data().status };

    const u = userSnap.exists ? userSnap.data() : {};
    const amount = Number(course.price) || 0;
    const days = Number(course.accessDays) || 90;
    const reqRef = db.collection('paymentRequests').doc();
    const base = {
      studentId: uid, studentName: u.displayName || '', studentEmail: u.email || '',
      courseId, courseTitle: course.title || '', amount, code: genCode(),
      createdAt: FieldValue.serverTimestamp(),
    };

    if (amount <= 0) { // دورة مجانية: تسجيل فوري
      tx.set(reqRef, { ...base, status: 'approved', source: 'free', reviewedBy: 'system',
        reviewedAt: FieldValue.serverTimestamp() });
      tx.set(enrRef, buildEnrollment(enrSnap, uid, courseId, days, 'free', reqRef.id, 'system'));
      auditTx(tx, uid, 'freeEnrollment', 'course', courseId, { requestId: reqRef.id });
      return { requestId: reqRef.id, status: 'approved' };
    }
    tx.set(reqRef, { ...base, status: 'pending_payment' });
    auditTx(tx, uid, 'paymentRequestCreated', 'paymentRequest', reqRef.id, { courseId, amount });
    return { requestId: reqRef.id, status: 'pending_payment' };
  });
});

// ---------- الطالب: تسليم إثبات الدفع (الملف يُرفع للـ Storage قبل الاستدعاء) ----------
exports.submitPaymentProof = onCall(async (request) => {
  const uid = requireAuth(request);
  const { requestId, proofPath, reference } = request.data || {};
  const rid = str(requestId, 100);
  const path = str(proofPath, 300);
  if (!rid || !path.startsWith(`paymentProofs/${uid}/`) || path.includes('..')) {
    throw new HttpsError('invalid-argument', 'بيانات غير صالحة');
  }
  const [exists] = await admin.storage().bucket().file(path).exists();
  if (!exists) throw new HttpsError('failed-precondition', 'لم يتم العثور على الملف المرفوع');

  const ref = db.doc(`paymentRequests/${rid}`);
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (!s.exists || s.data().studentId !== uid) throw new HttpsError('not-found', 'الطلب غير موجود');
    if (!['pending_payment', 'rejected'].includes(s.data().status)) {
      throw new HttpsError('failed-precondition', 'لا يمكن رفع إثبات لهذا الطلب في حالته الحالية');
    }
    tx.update(ref, {
      proofPath: path, reference: str(reference, 120), status: 'proof_submitted',
      submittedAt: FieldValue.serverTimestamp(), rejectReason: FieldValue.delete(),
    });
    auditTx(tx, uid, 'paymentProofSubmitted', 'paymentRequest', rid);
  });
  return { ok: true };
});

// ---------- المدير: اعتماد/رفض (عملية واحدة موثوقة وآمنة عند التكرار) ----------
exports.reviewPaymentRequest = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const { requestId, decision, reason } = request.data || {};
  const rid = str(requestId, 100);
  const rejectReason = str(reason, 300);
  if (!rid || !['approve', 'reject'].includes(decision)) {
    throw new HttpsError('invalid-argument', 'بيانات غير صالحة');
  }
  if (decision === 'reject' && !rejectReason) {
    throw new HttpsError('invalid-argument', 'سبب الرفض مطلوب');
  }

  return db.runTransaction(async (tx) => {
    const reqRef = db.doc(`paymentRequests/${rid}`);
    const rs = await tx.get(reqRef);
    if (!rs.exists) throw new HttpsError('not-found', 'الطلب غير موجود');
    const r = rs.data();

    const target = decision === 'approve' ? 'approved' : 'rejected';
    if (r.status === target) return { ok: true, already: true }; // تكرار: لا تغيير
    if (r.status !== 'proof_submitted') {
      throw new HttpsError('failed-precondition', 'لا يمكن مراجعة هذا الطلب في حالته الحالية');
    }

    const enrRef = db.doc(`enrollments/${r.studentId}_${r.courseId}`);
    const [courseSnap, enrSnap, adminSnap] = await Promise.all([
      tx.get(db.doc(`courses/${r.courseId}`)), tx.get(enrRef), tx.get(db.doc(`users/${adminUid}`)),
    ]);
    const reviewer = { reviewedBy: adminUid, reviewedByName: (adminSnap.data() || {}).displayName || '',
      reviewedAt: FieldValue.serverTimestamp() };

    if (decision === 'approve') {
      if (!courseSnap.exists) throw new HttpsError('failed-precondition', 'الدورة غير موجودة');
      const days = Number(courseSnap.data().accessDays) || 90;
      tx.update(reqRef, { status: 'approved', ...reviewer });
      tx.set(enrRef, buildEnrollment(enrSnap, r.studentId, r.courseId, days, 'payment', rid, adminUid));
      notifyTx(tx, r.studentId, 'تم اعتماد اشتراكك', `تم تفعيل دورة "${r.courseTitle}".`, 'payment');
      auditTx(tx, adminUid, 'approvePayment', 'paymentRequest', rid, { courseId: r.courseId, studentId: r.studentId });
    } else {
      tx.update(reqRef, { status: 'rejected', rejectReason, ...reviewer });
      notifyTx(tx, r.studentId, 'تم رفض طلب الاشتراك', `السبب: ${rejectReason}. يمكنك إعادة رفع الإثبات.`, 'payment');
      auditTx(tx, adminUid, 'rejectPayment', 'paymentRequest', rid, { reason: rejectReason });
    }
    return { ok: true };
  });
});

// ---------- المدير: منح/سحب وصول يدوي (السبب إلزامي ويُسجَّل) ----------
exports.grantManualAccess = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const { studentId, courseId, days, reason } = request.data || {};
  const sid = str(studentId, 100), cid = str(courseId, 100), why = str(reason, 300);
  if (!sid || !cid || !why) throw new HttpsError('invalid-argument', 'الطالب والدورة والسبب مطلوبة');
  const d = days == null ? null : Number(days);
  if (d !== null && (!Number.isInteger(d) || d < 1 || d > 3650)) {
    throw new HttpsError('invalid-argument', 'عدد الأيام غير صالح');
  }
  await db.runTransaction(async (tx) => {
    const [courseSnap, enrSnap] = await Promise.all([
      tx.get(db.doc(`courses/${cid}`)), tx.get(db.doc(`enrollments/${sid}_${cid}`))]);
    if (!courseSnap.exists) throw new HttpsError('not-found', 'الدورة غير موجودة');
    const n = d || Number(courseSnap.data().accessDays) || 90;
    tx.set(db.doc(`enrollments/${sid}_${cid}`), buildEnrollment(enrSnap, sid, cid, n, 'manual', null, adminUid));
    notifyTx(tx, sid, 'تم منحك وصولًا إلى دورة', `تم تفعيل دورة "${courseSnap.data().title || ''}".`, 'access');
    auditTx(tx, adminUid, 'grantAccess', 'enrollment', `${sid}_${cid}`, { days: n, reason: why });
  });
  return { ok: true };
});

exports.revokeAccess = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const { studentId, courseId, reason } = request.data || {};
  const sid = str(studentId, 100), cid = str(courseId, 100), why = str(reason, 300);
  if (!sid || !cid || !why) throw new HttpsError('invalid-argument', 'الطالب والدورة والسبب مطلوبة');
  const ref = db.doc(`enrollments/${sid}_${cid}`);
  await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (!s.exists) throw new HttpsError('not-found', 'لا يوجد تسجيل');
    tx.update(ref, { status: 'revoked', revokedBy: adminUid, revokedAt: FieldValue.serverTimestamp() });
    auditTx(tx, adminUid, 'revokeAccess', 'enrollment', `${sid}_${cid}`, { reason: why });
  });
  return { ok: true };
});

// ---------- انتهاء الطلبات غير المدفوعة تلقائيًا ----------
exports.expirePendingRequests = onSchedule(
  { schedule: 'every day 03:00', timeZone: 'Africa/Cairo' },
  async () => {
    const cutoff = Timestamp.fromMillis(Date.now() - EXPIRY_DAYS * DAY);
    const snap = await db.collection('paymentRequests')
      .where('status', '==', 'pending_payment').where('createdAt', '<', cutoff).limit(400).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.update(d.ref, { status: 'expired', expiredAt: FieldValue.serverTimestamp() }));
    await batch.commit();
  });
