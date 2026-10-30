import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_announcements_page.dart';
import '../features/admin/admin_attendance_page.dart';
import '../features/admin/admin_course_detail_page.dart';
import '../features/admin/admin_courses_page.dart';
import '../features/admin/admin_exam_detail_page.dart';
import '../features/admin/admin_exam_results_page.dart';
import '../features/admin/admin_exams_page.dart';
import '../features/admin/admin_payments_page.dart';
import '../features/admin/admin_sessions_page.dart';
import '../features/admin/admin_settings_page.dart';
import '../features/admin/admin_students_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/reset_page.dart';
import '../features/auth/session_controller.dart';
import '../features/comms/announcements_page.dart';
import '../features/comms/notifications_page.dart';
import '../features/courses/catalog_page.dart';
import '../features/courses/course_detail_page.dart';
import '../features/courses/lesson_page.dart';
import '../features/exams/exam_page.dart';
import '../features/exams/exam_review_page.dart';
import '../features/exams/exams_page.dart';
import '../features/home/home_pages.dart';
import '../features/home/landing_page.dart';
import '../features/legal/legal_pages.dart';
import '../features/payments/payment_request_page.dart';
import '../features/payments/payments_page.dart';
import '../features/sessions/my_attendance_page.dart';
import '../features/sessions/sessions_page.dart';
import '../shell/admin_shell.dart';
import '../shell/student_shell.dart';

GoRouter buildRouter(SessionController s) {
  const publicPaths = {
    '/',
    '/login',
    '/register',
    '/reset',
    '/courses',
    '/privacy',
    '/terms',
    '/refund',
  };
  final courseDetail = RegExp(
    r'^/courses/[^/]+$',
  ); // صفحة الدورة عامة؛ الدرس يتطلب دخولًا

  return GoRouter(
    initialLocation: '/',
    refreshListenable: s,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!s.ready) return loc == '/splash' ? null : '/splash';

      final loggedIn = s.user != null;
      if (loc == '/splash') return loggedIn ? s.homePath : '/';
      final isPublic = publicPaths.contains(loc) || courseDetail.hasMatch(loc);
      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && (loc == '/login' || loc == '/register'))
        return s.homePath;
      // هذا فحص للواجهة فقط؛ الحماية الفعلية في قواعد Firestore/Functions.
      if (loc.startsWith('/admin') && !s.isAdmin) return s.homePath;
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/', builder: (_, _) => const LandingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/reset', builder: (_, _) => const ResetPage()),
      // صفحة حل الامتحان بملء الشاشة (بدون قوائم تنقل أثناء الامتحان)
      GoRoute(
        path: '/exams/:id',
        builder: (_, st) => ExamPage(examId: st.pathParameters['id']!),
      ),

      // ===== إطار الطالب / الزائر =====
      ShellRoute(
        builder: (context, state, child) =>
            StudentShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/student', builder: (_, _) => const StudentHomePage()),
          GoRoute(path: '/courses', builder: (_, _) => const CatalogPage()),
          GoRoute(
            path: '/courses/:id',
            builder: (_, st) =>
                CourseDetailPage(courseId: st.pathParameters['id']!),
          ),
          GoRoute(
            path: '/courses/:id/lessons/:lessonId',
            builder: (_, st) => LessonPage(
              courseId: st.pathParameters['id']!,
              lessonId: st.pathParameters['lessonId']!,
            ),
          ),
          GoRoute(path: '/payments', builder: (_, _) => const PaymentsPage()),
          GoRoute(
            path: '/payments/:id',
            builder: (_, st) =>
                PaymentRequestPage(requestId: st.pathParameters['id']!),
          ),
          GoRoute(path: '/sessions', builder: (_, _) => const SessionsPage()),
          GoRoute(
            path: '/attendance',
            builder: (_, _) => const MyAttendancePage(),
          ),
          GoRoute(path: '/exams', builder: (_, _) => const ExamsPage()),
          GoRoute(
            path: '/exams/:id/review/:attemptId',
            builder: (_, st) =>
                ExamReviewPage(attemptId: st.pathParameters['attemptId']!),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (_, _) => const AnnouncementsPage(),
          ),
          GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
          GoRoute(path: '/terms', builder: (_, _) => const TermsPage()),
          GoRoute(path: '/refund', builder: (_, _) => const RefundPage()),
        ],
      ),

      // ===== إطار الإدارة =====
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminHomePage()),
          GoRoute(
            path: '/admin/courses',
            builder: (_, _) => const AdminCoursesPage(),
          ),
          GoRoute(
            path: '/admin/courses/:id',
            builder: (_, st) =>
                AdminCourseDetailPage(courseId: st.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/payments',
            builder: (_, _) => const AdminPaymentsPage(),
          ),
          GoRoute(
            path: '/admin/students',
            builder: (_, _) => const AdminStudentsPage(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, _) => const AdminSettingsPage(),
          ),
          GoRoute(
            path: '/admin/sessions',
            builder: (_, _) => const AdminSessionsPage(),
          ),
          GoRoute(
            path: '/admin/sessions/:id',
            builder: (_, st) =>
                AdminAttendancePage(sessionId: st.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/exams',
            builder: (_, _) => const AdminExamsPage(),
          ),
          GoRoute(
            path: '/admin/exams/:id',
            builder: (_, st) =>
                AdminExamDetailPage(examId: st.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/exams/:id/results',
            builder: (_, st) =>
                AdminExamResultsPage(examId: st.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/announcements',
            builder: (_, _) => const AdminAnnouncementsPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('الصفحة غير موجودة (404)'))),
  );
}
