const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

function requireAdmin(request) {
  if (!request.auth || request.auth.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'للمديرين فقط');
  }
  return request.auth.uid;
}
const str = (v, max) => (typeof v === 'string' ? v.trim().slice(0, max) : '');
const bad = (m = 'بيانات غير صالحة') => new HttpsError('invalid-argument', m);

// نشر إعلان + إشعار داخل المنصة لكل مستلم (عملية واحدة موثوقة من الخادم)
exports.publishAnnouncement = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const d = request.data || {};
  const title = str(d.title, 150);
  const body = str(d.body, 2000);
  const audience = d.audience === 'course' ? 'course' : 'all';
  const courseId = audience === 'course' ? str(d.courseId, 100) : null;
  if (!title || !body) throw bad('العنوان والنص مطلوبان');
  if (audience === 'course') {
    if (!courseId || !(await db.doc(`courses/${courseId}`).get()).exists) throw bad('الدورة غير موجودة');
  }
  let expiresAt = null;
  if (d.expiresAtMs != null) {
    const ms = Number(d.expiresAtMs);
    if (!Number.isFinite(ms) || ms <= Date.now()) throw bad('تاريخ الانتهاء يجب أن يكون في المستقبل');
    expiresAt = Timestamp.fromMillis(ms);
  }

  const aRef = db.collection('announcements').doc();
  await aRef.set({ title, body, audience, courseId, createdBy: adminUid, createdAt: FieldValue.serverTimestamp(), expiresAt });

  let uids;
  if (audience === 'all') {
    const us = await db.collection('users').where('status', '==', 'active').get();
    uids = us.docs.filter((u) => u.data().role !== 'admin').map((u) => u.id);
  } else {
    const es = await db.collection('enrollments').where('courseId', '==', courseId).where('status', '==', 'active').get();
    const now = Date.now();
    uids = es.docs.filter((e) => e.data().endAt && e.data().endAt.toMillis() > now).map((e) => e.data().studentId);
  }
  uids = [...new Set(uids)];

  for (let i = 0; i < uids.length; i += 400) {
    const batch = db.batch();
    uids.slice(i, i + 400).forEach((uid) => {
      batch.set(db.collection('notifications').doc(), {
        userId: uid, title, body: body.slice(0, 140), type: 'announcement', announcementId: aRef.id,
        readAt: null, createdAt: FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  }
  await db.collection('auditLogs').add({
    actorUid: adminUid, action: 'publishAnnouncement', targetType: 'announcement', targetId: aRef.id,
    metadata: { audience, courseId, notified: uids.length }, timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true, id: aRef.id, notified: uids.length };
});

exports.deleteAnnouncement = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const id = str((request.data || {}).id, 100);
  if (!id) throw bad();
  await db.doc(`announcements/${id}`).delete();
  for (;;) { // حذف الإشعارات المرتبطة على دفعات
    const s = await db.collection('notifications').where('announcementId', '==', id).limit(400).get();
    if (s.empty) break;
    const batch = db.batch();
    s.docs.forEach((n) => batch.delete(n.ref));
    await batch.commit();
  }
  await db.collection('auditLogs').add({
    actorUid: adminUid, action: 'deleteAnnouncement', targetType: 'announcement', targetId: id,
    metadata: {}, timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});
