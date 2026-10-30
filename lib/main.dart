// نقطة الدخول الوحيدة:
//   تشغيل محلي:  flutter run -d chrome
//   مع Emulator: flutter run -d chrome --dart-define=USE_EMULATOR=true
//   نشر:         flutter build web --release
import 'bootstrap.dart';
import 'firebase_options.dart';

Future<void> main() => bootstrap(DefaultFirebaseOptions.currentPlatform);
