const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;
const GRACE_MS = 30 * 1000; // مهلة تأخر الشبكة عند الإرسال

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
const bad = (m = 'بيانات غير صالحة') => new HttpsError('invalid-argument', m);

async function audit(actorUid, action, targetType, targetId, metadata = {}) {
  await db.collection('auditLogs').add({
    actorUid, action, targetType, targetId, metadata, timestamp: FieldValue.serverTimestamp(),
  });
}

async function assertNoAttempts(examId) {
  const s = await db.collection('examAttempts').where('examId', '==', examId).limit(1).get();
  if (!s.empty) throw new HttpsError('failed-precondition', 'لا يمكن تعديل أسئلة امتحان بدأ الطلاب حله');
}

async function recomputeTotal(examId) {
  const qs = await db.collection(`exams/${examId}/questions`).get();
  const total = qs.docs.reduce((s, d) => s + (Number(d.data().points) || 0), 0);
  await db.doc(`exams/${examId}`).update({ totalScore: total });
}

function parseQuestion(d) {
  const type = d.type;
  const prompt = str(d.prompt, 1000);
  const points = Number(d.points);
  const order = Number(d.order);
  if (!['mcq', 'tf'].includes(type) || !prompt) throw bad();
  if (!(points > 0 && points <= 100) || !Number.isInteger(order)) throw bad();
  let options = [];
  let correctAnswer;
  if (type === 'mcq') {
    if (!Array.isArray(d.options) || d.options.length < 2 || d.options.length > 6) throw bad('من 2 إلى 6 خيارات');
    options = d.options.map((o) => str(o, 300));
    if (options.some((o) => !o)) throw bad('الخيارات لا تقبل الفراغ');
    if (!Number.isInteger(d.correctAnswer) || d.correctAnswer < 0 || d.correctAnswer >= options.length) {
      throw bad('حدّد الإجابة الصحيحة');
    }
    correctAnswer = d.correctAnswer;
  } else {
    if (typeof d.correctAnswer !== 'boolean') throw bad('حدّد الإجابة الصحيحة');
    correctAnswer = d.correctAnswer;
  }
  return { q: { type, prompt, options, points, order }, key: { correctAnswer, explanation: str(d.explanation, 1000) } };
}

// ---------- المدير: الأسئلة والإجابات (الإجابات في examKeys ولا يقرؤها أي عميل) ----------
exports.saveExamQuestion = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const d = request.data || {};
  const examId = str(d.examId, 100);
  if (!examId || !(await db.doc(`exams/${examId}`).get()).exists) throw bad('الامتحان غير موجود');
  await assertNoAttempts(examId);
  const { q, key } = parseQuestion(d);
  const qid = str(d.questionId, 100);
  const qRef = qid ? db.doc(`exams/${examId}/questions/${qid}`) : db.collection(`exams/${examId}/questions`).doc();
  const batch = db.batch();
  batch.set(qRef, q);
  batch.set(db.doc(`examKeys/${examId}/answers/${qRef.id}`), key);
  await batch.commit();
  await recomputeTotal(examId);
  await audit(adminUid, qid ? 'updateQuestion' : 'createQuestion', 'exam', examId, { questionId: qRef.id });
  return { ok: true, questionId: qRef.id };
});

exports.deleteExamQuestion = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const examId = str((request.data || {}).examId, 100);
  const qid = str((request.data || {}).questionId, 100);
  if (!examId || !qid) throw bad();
  await assertNoAttempts(examId);
  const batch = db.batch();
  batch.delete(db.doc(`exams/${examId}/questions/${qid}`));
  batch.delete(db.doc(`examKeys/${examId}/answers/${qid}`));
  await batch.commit();
  await recomputeTotal(examId);
  await audit(adminUid, 'deleteQuestion', 'exam', examId, { questionId: qid });
  return { ok: true };
});

exports.getExamKeys = onCall(async (request) => {
  requireAdmin(request);
  const examId = str((request.data || {}).examId, 100);
  if (!examId) throw bad();
  const snap = await db.collection(`examKeys/${examId}/answers`).get();
  const keys = {};
  snap.docs.forEach((d) => { keys[d.id] = d.data(); });
  return { keys };
});

exports.deleteExam = onCall(async (request) => {
  const adminUid = requireAdmin(request);
  const examId = str((request.data || {}).examId, 100);
  if (!examId) throw bad();
  await assertNoAttempts(examId);
  const [qs, ks] = await Promise.all([
    db.collection(`exams/${examId}/questions`).get(), db.collection(`examKeys/${examId}/answers`).get()]);
  const batch = db.batch();
  qs.docs.forEach((d) => batch.delete(d.ref));
  ks.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(db.doc(`exams/${examId}`));
  await batch.commit();
  await audit(adminUid, 'deleteExam', 'exam', examId);
  return { ok: true };
});

// ---------- التصحيح (في الخادم فقط) ----------
async function loadGradingData(examId) {
  const [qs, ks] = await Promise.all([
    db.collection(`exams/${examId}/questions`).get(), db.collection(`examKeys/${examId}/answers`).get()]);
  const keys = {};
  ks.docs.forEach((d) => { keys[d.id] = d.data(); });
  const questions = qs.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.order - b.order);
  return { questions, keys };
}

function sanitizeAnswers(questions, raw) {
  const out = {};
  for (const q of questions) {
    const v = raw ? raw[q.id] : undefined;
    if (q.type === 'mcq' && Number.isInteger(v) && v >= 0 && v < q.options.length) out[q.id] = v;
    if (q.type === 'tf' && typeof v === 'boolean') out[q.id] = v;
  }
  return out;
}

function grade(questions, keys, answers) {
  let score = 0;
  for (const q of questions) {
    const k = keys[q.id];
    if (!k) continue;
    const g = answers[q.id];
    const ok = q.type === 'mcq' ? (Number.isInteger(g) && g === k.correctAnswer)
      : (typeof g === 'boolean' && g === k.correctAnswer);
    if (ok) score += Number(q.points) || 0;
  }
  return score;
}

// إنهاء المحاولة وتصحيحها: آمن عند التكرار (لا تُكتب النتيجة إلا مرة واحدة)
async function finalizeAttempt(attemptRef, payload) {
  const pre = await attemptRef.get();
  if (!pre.exists) throw new HttpsError('not-found', 'المحاولة غير موجودة');
  const examId = pre.data().examId;
  const [examSnap, data] = await Promise.all([db.doc(`exams/${examId}`).get(), loadGradingData(examId)]);
  const exam = examSnap.data();

  return db.runTransaction(async (tx) => {
    const aSnap = await tx.get(attemptRef);
    const a = aSnap.data();
    if (a.status !== 'in_progress') return { already: true };

    const nowMs = Date.now();
    const onTime = nowMs <= a.expiresAt.toMillis() + GRACE_MS;
    const useClient = !!payload && onTime; // بعد المهلة تُعتمد الإجابات المحفوظة فقط
    const merged = sanitizeAnswers(data.questions, useClient ? { ...(a.answers || {}), ...payload } : (a.answers || {}));
    const score = grade(data.questions, data.keys, merged);
    const total = data.questions.reduce((s, q) => s + (Number(q.points) || 0), 0);
    const status = useClient ? 'submitted' : 'auto_submitted';
    const releaseAt = exam.resultsMode === 'immediate' ? Timestamp.now() : exam.closesAt;

    tx.update(attemptRef, { answers: merged, status, submittedAt: FieldValue.serverTimestamp() });
    tx.set(db.doc(`examResults/${attemptRef.id}`), {
      attemptId: attemptRef.id, studentId: a.studentId, studentName: a.studentName || '',
      examId, examTitle: exam.title || '', courseId: a.courseId, attemptNo: a.attemptNo,
      score, totalScore: total, status, releaseAt, submittedAt: FieldValue.serverTimestamp(),
    });
    return { already: false, released: releaseAt.toMillis() <= nowMs, score, totalScore: total };
  });
}

async function finalizeExpiredFor(uid, examId) {
  const s = await db.collection('examAttempts')
    .where('studentId', '==', uid).where('examId', '==', examId).where('status', '==', 'in_progress').get();
  for (const d of s.docs) {
    if (d.data().expiresAt.toMillis() <= Date.now()) await finalizeAttempt(d.ref, null);
  }
}

// ---------- الطالب ----------
function buildStartResponse(attemptId, a, questionsById, exam) {
  return {
    attemptId, attemptNo: a.attemptNo, examTitle: exam.title || '',
    durationMinutes: exam.durationMinutes || 0,
    expiresAtMs: a.expiresAt.toMillis(), serverNowMs: Date.now(),
    answers: a.answers || {},
    questions: a.questionOrder.map((id) => questionsById[id]).filter(Boolean).map((q) => ({
      id: q.id, type: q.type, prompt: q.prompt, options: q.options || [], points: q.points,
    })), // لا تحتوي الإجابات الصحيحة
  };
}

exports.startExamAttempt = onCall(async (request) => {
  const uid = requireAuth(request);
  const examId = str((request.data || {}).examId, 100);
  if (!examId) throw bad();

  const examRef = db.doc(`exams/${examId}`);
  const examSnap = await examRef.get();
  if (!examSnap.exists || examSnap.data().published !== true) {
    throw new HttpsError('failed-precondition', 'الامتحان غير متاح');
  }
  const exam = examSnap.data();
  const enr = await db.doc(`enrollments/${uid}_${exam.courseId}`).get();
  const e = enr.exists ? enr.data() : null;
  if (!e || e.status !== 'active' || !e.endAt || e.endAt.toMillis() <= Date.now()) {
    throw new HttpsError('permission-denied', 'يجب الاشتراك في الدورة أولًا');
  }

  await finalizeExpiredFor(uid, examId);
  const [qs, userSnap] = await Promise.all([examRef.collection('questions').get(), db.doc(`users/${uid}`).get()]);
  if (qs.empty) throw new HttpsError('failed-precondition', 'الامتحان لا يحتوي أسئلة');
  const questions = qs.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.order - b.order);
  const questionsById = Object.fromEntries(questions.map((q) => [q.id, q]));

  return db.runTransaction(async (tx) => {
    const attempts = await tx.get(
      db.collection('examAttempts').where('studentId', '==', uid).where('examId', '==', examId));
    const nowMs = Date.now();

    const active = attempts.docs.find((d) => d.data().status === 'in_progress' && d.data().expiresAt.toMillis() > nowMs);
    if (active) return buildStartResponse(active.id, active.data(), questionsById, exam); // استئناف

    if (nowMs < exam.opensAt.toMillis() || nowMs > exam.closesAt.toMillis()) {
      throw new HttpsError('failed-precondition', 'الامتحان غير متاح في هذا الوقت');
    }
    if (attempts.size >= (Number(exam.attemptsAllowed) || 1)) {
      throw new HttpsError('failed-precondition', 'استنفدت عدد المحاولات المسموحة');
    }

    let order = questions.map((q) => q.id);
    if (exam.shuffleQuestions) {
      for (let i = order.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [order[i], order[j]] = [order[j], order[i]];
      }
    }
    const expMs = Math.min(nowMs + (Number(exam.durationMinutes) || 30) * 60000, exam.closesAt.toMillis());
    const ref = db.collection('examAttempts').doc();
    const a = {
      examId, courseId: exam.courseId, studentId: uid,
      studentName: userSnap.exists ? (userSnap.data().displayName || '') : '',
      attemptNo: attempts.size + 1,
      startedAt: Timestamp.fromMillis(nowMs), expiresAt: Timestamp.fromMillis(expMs),
      submittedAt: null, answers: {}, questionOrder: order, status: 'in_progress',
    };
    tx.set(ref, a);
    return buildStartResponse(ref.id, a, questionsById, exam);
  });
});

exports.submitExamAttempt = onCall(async (request) => {
  const uid = requireAuth(request);
  const attemptId = str((request.data || {}).attemptId, 100);
  const payload = (request.data || {}).answers;
  if (!attemptId) throw bad();
  const ref = db.doc(`examAttempts/${attemptId}`);
  const snap = await ref.get();
  if (!snap.exists || snap.data().studentId !== uid) throw new HttpsError('not-found', 'المحاولة غير موجودة');
  const r = await finalizeAttempt(ref, payload && typeof payload === 'object' ? payload : null);
  if (r.already) return { already: true };
  return r.released ? { released: true, score: r.score, totalScore: r.totalScore } : { released: false };
});

exports.getMyExamResults = onCall(async (request) => {
  const uid = requireAuth(request);
  const examId = str((request.data || {}).examId, 100);
  if (!examId) throw bad();
  const s = await db.collection('examResults').where('studentId', '==', uid).where('examId', '==', examId).get();
  const now = Date.now();
  const results = s.docs.map((d) => {
    const r = d.data();
    const released = r.releaseAt.toMillis() <= now;
    return {
      attemptId: d.id, attemptNo: r.attemptNo, released,
      score: released ? r.score : null, totalScore: released ? r.totalScore : null,
      submittedAtMs: r.submittedAt ? r.submittedAt.toMillis() : null,
    };
  }).sort((a, b) => a.attemptNo - b.attemptNo);
  return { results };
});

// مراجعة الإجابات الصحيحة: بعد إغلاق الامتحان لجميع الطلاب فقط
exports.getAttemptReview = onCall(async (request) => {
  const uid = requireAuth(request);
  const attemptId = str((request.data || {}).attemptId, 100);
  if (!attemptId) throw bad();
  const aSnap = await db.doc(`examAttempts/${attemptId}`).get();
  if (!aSnap.exists || aSnap.data().studentId !== uid) throw new HttpsError('not-found', 'المحاولة غير موجودة');
  const a = aSnap.data();
  if (a.status === 'in_progress') throw new HttpsError('failed-precondition', 'المحاولة لم تُسلَّم بعد');
  const exam = (await db.doc(`exams/${a.examId}`).get()).data();
  if (Date.now() < exam.closesAt.toMillis()) {
    throw new HttpsError('failed-precondition', 'تظهر المراجعة والإجابات الصحيحة بعد إغلاق الامتحان');
  }
  const { questions, keys } = await loadGradingData(a.examId);
  return {
    items: questions.map((q) => {
      const k = keys[q.id] || {};
      const mine = (a.answers || {})[q.id];
      return {
        id: q.id, type: q.type, prompt: q.prompt, options: q.options || [], points: q.points,
        myAnswer: mine === undefined ? null : mine,
        correctAnswer: k.correctAnswer === undefined ? null : k.correctAnswer,
        explanation: k.explanation || '',
      };
    }),
  };
});

// ---------- تسليم تلقائي للمحاولات المنتهية التي لم يعد لها الطالب ----------
exports.finalizeStaleAttempts = onSchedule({ schedule: 'every 15 minutes' }, async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - GRACE_MS);
  const s = await db.collection('examAttempts')
    .where('status', '==', 'in_progress').where('expiresAt', '<', cutoff).limit(100).get();
  for (const d of s.docs) {
    try { await finalizeAttempt(d.ref, null); } catch (e) { console.error('finalize failed', d.id, e); }
  }
});
