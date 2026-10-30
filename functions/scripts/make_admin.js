// إنشاء أول مدير: node scripts/make_admin.js user@example.com
// يحتاج بيانات اعتماد: gcloud auth application-default login
// ومتغير GOOGLE_CLOUD_PROJECT=madrasty-prod (أو اسم مشروع dev)
const admin = require('firebase-admin');

const email = process.argv[2];
if (!email) {
  console.error('Usage: node scripts/make_admin.js <email>');
  process.exit(1);
}
admin.initializeApp();

(async () => {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { role: 'admin' });
  await admin.firestore().doc(`users/${user.uid}`).set({ role: 'admin' }, { merge: true });
  console.log(`OK: ${email} (${user.uid}) is now admin. Sign out/in to refresh the token.`);
})().catch((e) => { console.error(e); process.exit(1); });
