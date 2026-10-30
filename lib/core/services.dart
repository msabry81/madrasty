import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_repository.dart';
import '../features/auth/session_controller.dart';
import '../features/comms/comms_repository.dart';
import '../features/courses/courses_repository.dart';
import '../features/exams/exams_repository.dart';
import '../features/payments/payments_repository.dart';
import '../features/sessions/sessions_repository.dart';
import 'app_config.dart';
import 'router.dart';

/// حاوية بسيطة للخدمات المشتركة (تُهيَّأ مرة واحدة بعد Firebase.initializeApp).
class Services {
  static late final AuthRepository auth;
  static late final SessionController session;
  static late final CoursesRepository courses;
  static late final PaymentsRepository payments;
  static late final AdminRepository admin;
  static late final SessionsRepository sessions;
  static late final ExamsRepository exams;
  static late final CommsRepository comms;
  static late final GoRouter router;

  static void init() {
    final db = FirebaseFirestore.instance;
    final fn = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);
    auth = AuthRepository(FirebaseAuth.instance, db);
    session = SessionController(auth);
    courses = CoursesRepository(db);
    payments = PaymentsRepository(db, fn, FirebaseStorage.instance);
    admin = AdminRepository(db, fn);
    sessions = SessionsRepository(db);
    exams = ExamsRepository(db, fn);
    comms = CommsRepository(db, fn);
    router = buildRouter(session);
  }
}
