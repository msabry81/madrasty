const fs = require('fs');
const { test, before, after } = require('node:test');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');

let env;
const student = (uid) => env.authenticatedContext(uid, { role: 'student' }).firestore();
const admin = () => env.authenticatedContext('a1', { role: 'admin' }).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-madrasty',
    firestore: { rules: fs.readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc('users/s1').set({ displayName: 'S1', role: 'student', status: 'active' });
    await db.doc('users/s2').set({ displayName: 'S2', role: 'student', status: 'active' });
    await db.doc('courses/c1').set({ title: 'C1', status: 'published' });
    await db.doc('courses/c1/lessons/l1').set({ title: 'L1', isPreview: false, youtubeVideoId: 'x' });
    await db.doc('courses/c1/lessons/l2').set({ title: 'L2', isPreview: true, youtubeVideoId: 'y' });
    await db.doc('enrollments/s1_c1').set({
      studentId: 's1', courseId: 'c1', status: 'active',
      endAt: new Date(Date.now() + 864e5),
    });
    await db.doc('examKeys/e1/answers/q1').set({ correctAnswer: 'B' });
    await db.doc('paymentRequests/p1').set({ studentId: 's1', courseId: 'c1', status: 'pending_payment' });
    await db.doc('settings/payment').set({ instructions: 'x' });
    await db.doc('announcements/an1').set({ title: 'A', body: 'b', audience: 'all' });
    await db.doc('announcements/an2').set({ title: 'B', body: 'b', audience: 'course', courseId: 'c1' });
    await db.doc('notifications/n1').set({ userId: 's1', title: 't', body: 'b', type: 'payment', readAt: null });
    await db.doc('exams/ex1').set({ courseId: 'c1', title: 'E1', published: true });
    await db.doc('exams/ex2').set({ courseId: 'c1', title: 'E2', published: false });
    await db.doc('exams/ex1/questions/q1').set({ type: 'tf', prompt: 'p', points: 1, order: 1 });
    await db.doc('examResults/r1').set({ studentId: 's1', examId: 'ex1', score: 1 });
    await db.doc('examAttempts/at1').set({ studentId: 's1', examId: 'ex1', status: 'in_progress', expiresAt: new Date(Date.now() + 36e5), answers: {} });
    await db.doc('examAttempts/at2').set({ studentId: 's1', examId: 'ex1', status: 'in_progress', expiresAt: new Date(Date.now() - 36e5), answers: {} });
    await db.doc('liveSessions/ls1').set({ courseId: 'c1', title: 'S', startsAt: new Date(), durationMinutes: 60, meetUrl: 'https://meet.google.com/x', status: 'scheduled' });
    await db.doc('attendance/ls1_s1').set({ sessionId: 'ls1', studentId: 's1', status: 'present', method: 'manual', markedBy: 'a1' });
    await db.doc('courses/c1/units/u1').set({ title: 'U1', order: 1 });
    await db.doc('courses/d1').set({ title: 'Draft', status: 'draft' });
    await db.doc('courses/d1/units/u1').set({ title: 'DU', order: 1 });
    await db.doc('courses/d1/lessons/dl1').set({ title: 'DL', isPreview: true, youtubeVideoId: 'z' });
  });
});
after(() => env.cleanup());

test('student reads own profile, not others', async () => {
  await assertSucceeds(student('s1').doc('users/s1').get());
  await assertFails(student('s1').doc('users/s2').get());
});

test('student cannot promote self or edit status', async () => {
  await assertFails(student('s1').doc('users/s1').update({ role: 'admin' }));
  await assertFails(student('s1').doc('users/s1').update({ status: 'disabled' }));
  await assertSucceeds(student('s1').doc('users/s1').update({ displayName: 'New' }));
});

test('student cannot write enrollments', async () => {
  await assertFails(student('s2').doc('enrollments/s2_c1').set({ studentId: 's2', courseId: 'c1', status: 'active' }));
});

test('lesson access follows enrollment', async () => {
  await assertSucceeds(student('s1').doc('courses/c1/lessons/l1').get());
  await assertFails(student('s2').doc('courses/c1/lessons/l1').get());
  await assertSucceeds(student('s2').doc('courses/c1/lessons/l2').get()); // preview
});

test('exam answer keys unreadable by everyone', async () => {
  await assertFails(student('s1').doc('examKeys/e1/answers/q1').get());
  await assertFails(admin().doc('examKeys/e1/answers/q1').get());
});

test('only admin writes courses', async () => {
  await assertSucceeds(admin().doc('courses/c2').set({ title: 'C2', status: 'draft' }));
  await assertFails(student('s1').doc('courses/c3').set({ title: 'C3' }));
});

test('draft course: not readable by students or public', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(student('s1').doc('courses/d1').get());
  await assertFails(anon.doc('courses/d1/units/u1').get());
  await assertFails(student('s1').doc('courses/d1/lessons/dl1').get()); // حتى لو isPreview
  await assertSucceeds(admin().doc('courses/d1/lessons/dl1').get());
});

test('published course: public catalog + units, lessons need login', async () => {
  const anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(anon.doc('courses/c1').get());
  await assertSucceeds(anon.doc('courses/c1/units/u1').get());
  await assertFails(anon.doc('courses/c1/lessons/l2').get());
});

test('payment requests: owner/admin read, nobody writes from client', async () => {
  await assertSucceeds(student('s1').doc('paymentRequests/p1').get());
  await assertFails(student('s2').doc('paymentRequests/p1').get());
  await assertSucceeds(admin().doc('paymentRequests/p1').get());
  await assertFails(student('s1').doc('paymentRequests/p1').update({ status: 'approved' }));
  await assertFails(admin().doc('paymentRequests/p1').update({ status: 'approved' }));
  await assertFails(student('s1').doc('paymentRequests/p9').set({ studentId: 's1', status: 'approved' }));
});

test('settings: signed-in read, admin write', async () => {
  await assertSucceeds(student('s1').doc('settings/payment').get());
  await assertFails(student('s1').doc('settings/payment').set({ instructions: 'hack' }));
  await assertSucceeds(admin().doc('settings/payment').set({ instructions: 'ok' }));
});

test('live sessions: only enrolled students (query by course)', async () => {
  await assertSucceeds(student('s1').collection('liveSessions').where('courseId', '==', 'c1').get());
  await assertFails(student('s2').collection('liveSessions').where('courseId', '==', 'c1').get());
  await assertFails(student('s1').doc('liveSessions/ls2').set({ courseId: 'c1', title: 'x' }));
});

test('attendance: owner reads, only admin writes valid manual marks', async () => {
  await assertSucceeds(student('s1').collection('attendance').where('studentId', '==', 's1').get());
  await assertFails(student('s2').doc('attendance/ls1_s1').get());
  await assertFails(student('s1').doc('attendance/ls1_s1').update({ status: 'absent' }));
  const ok = { sessionId: 'ls1', studentId: 's2', status: 'late', method: 'manual', markedBy: 'a1' };
  await assertSucceeds(admin().doc('attendance/ls1_s2').set(ok));
  await assertFails(admin().doc('attendance/wrong_id').set(ok));
  await assertFails(admin().doc('attendance/ls1_s2').set({ ...ok, status: 'maybe' }));
});

test('exams: published + enrolled only; questions never readable by students', async () => {
  await assertSucceeds(student('s1').collection('exams').where('courseId', '==', 'c1').where('published', '==', true).get());
  await assertFails(student('s2').collection('exams').where('courseId', '==', 'c1').where('published', '==', true).get());
  await assertFails(student('s1').doc('exams/ex2').get()); // غير منشور
  await assertFails(student('s1').doc('exams/ex1/questions/q1').get());
  await assertSucceeds(admin().doc('exams/ex1/questions/q1').get());
  await assertFails(admin().doc('exams/ex1/questions/q9').set({ type: 'tf' })); // الأسئلة عبر Functions فقط
});

test('exam attempts: autosave answers only, before expiry, own attempt', async () => {
  await assertSucceeds(student('s1').doc('examAttempts/at1').update({ answers: { q1: true } }));
  await assertFails(student('s1').doc('examAttempts/at1').update({ status: 'submitted' }));
  await assertFails(student('s1').doc('examAttempts/at1').update({ answers: {}, score: 99 }));
  await assertFails(student('s1').doc('examAttempts/at2').update({ answers: { q1: true } })); // بعد الانتهاء
  await assertFails(student('s2').doc('examAttempts/at1').update({ answers: { q1: false } }));
  await assertFails(student('s1').doc('examAttempts/new').set({ studentId: 's1', status: 'in_progress' }));
});

test('exam results: no direct client read for students', async () => {
  await assertFails(student('s1').doc('examResults/r1').get());
  await assertSucceeds(admin().doc('examResults/r1').get());
});

test('announcements: all-audience for signed-in, course-audience for enrolled, no client writes', async () => {
  await assertSucceeds(student('s2').collection('announcements').where('audience', '==', 'all').get());
  await assertSucceeds(student('s1').collection('announcements').where('audience', '==', 'course').where('courseId', '==', 'c1').get());
  await assertFails(student('s2').collection('announcements').where('audience', '==', 'course').where('courseId', '==', 'c1').get());
  await assertFails(admin().doc('announcements/x').set({ title: 'x', audience: 'all' }));
});

test('notifications: owner reads and marks read only', async () => {
  await assertSucceeds(student('s1').collection('notifications').where('userId', '==', 's1').get());
  await assertFails(student('s2').doc('notifications/n1').get());
  await assertSucceeds(student('s1').doc('notifications/n1').update({ readAt: new Date() }));
  await assertFails(student('s1').doc('notifications/n1').update({ title: 'hacked' }));
  await assertFails(student('s1').doc('notifications/new').set({ userId: 's1', title: 'x' }));
});

test('progress: own doc only, requires active access', async () => {
  await assertSucceeds(student('s1').doc('progress/s1_c1').set({ studentId: 's1', courseId: 'c1', completed: ['l1'] }));
  await assertSucceeds(student('s1').doc('progress/s1_c1').get());
  await assertFails(student('s2').doc('progress/s1_c1').get());
  await assertFails(student('s2').doc('progress/s2_c1').set({ studentId: 's2', courseId: 'c1', completed: ['l1'] })); // بلا اشتراك
  await assertFails(student('s1').doc('progress/s2_c1').set({ studentId: 's1', courseId: 'c1', completed: [] })); // معرّف غير مطابق
  await assertFails(student('s1').doc('progress/s1_c1').set({ studentId: 's1', courseId: 'c1', completed: [], extra: 1 }));
});
