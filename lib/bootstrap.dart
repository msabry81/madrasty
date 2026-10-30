import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/cairo_time.dart';
import 'core/services.dart';

Future<void> bootstrap(FirebaseOptions options) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: options);

  if (AppConfig.useEmulator && kDebugMode) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion)
        .useFunctionsEmulator('localhost', 5001);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }

  // TODO(App Check): فعّله في الإنتاج بعد إنشاء reCAPTCHA v3 key.
  // اسم باراميتر الويب (providerWeb / webProvider) يختلف حسب إصدار الحزمة،
  // راجع توثيق firebase_app_check للإصدار المثبّت عندك.

  CairoTime.init();
  Services.init();
  runApp(const MadrastyApp());
}
