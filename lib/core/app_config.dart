class AppConfig {
  /// نفس المنطقة المستخدمة في Cloud Functions (functions/index.js)
  static const functionsRegion = 'europe-west1';

  /// للتجارب المحلية فقط: flutter run -d chrome --dart-define=USE_EMULATOR=true
  /// (لا يعمل في نسخة release حتى لا تشير لـ localhost بالخطأ)
  static const useEmulator = bool.fromEnvironment('USE_EMULATOR');
}
